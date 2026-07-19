import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/import_report.dart';
import '../models/node_record.dart';
import '../models/node_status.dart';
import '../models/node_test_result.dart';
import '../services/import_service.dart';
import '../services/karing_export_service.dart';
import '../services/node_naming_service.dart';
import '../services/node_probe.dart';
import '../storage/app_store.dart';

class NodeCounters {
  const NodeCounters({
    required this.total,
    required this.checked,
    required this.usable,
    required this.failed,
  });

  final int total;
  final int checked;
  final int usable;
  final int failed;
}

class AppController extends ChangeNotifier {
  AppController({
    required AppStore store,
    ImportService? importer,
    NodeProbe? probe,
    NodeNamingService? naming,
    KaringExportService? exporter,
  })  : _store = store,
        _importer = importer ?? ImportService(),
        _probe = probe ?? const UnavailableNodeProbe(),
        _naming = naming ?? const NodeNamingService(),
        _exporter = exporter ?? const KaringExportService();

  final AppStore _store;
  final ImportService _importer;
  final NodeProbe _probe;
  final NodeNamingService _naming;
  final KaringExportService _exporter;
  final List<NodeRecord> _nodes = <NodeRecord>[];

  AppSettings _settings = const AppSettings();
  int _pageIndex = 0;
  bool _initialized = false;
  bool _busy = false;
  bool _scanning = false;
  bool _cancelRequested = false;
  int _scanCompleted = 0;
  int _scanTotal = 0;
  String _currentNode = '';
  String? _startupWarning;
  String? _lastError;
  ImportReport? _lastImportReport;

  UnmodifiableListView<NodeRecord> get nodes =>
      UnmodifiableListView<NodeRecord>(_nodes);
  AppSettings get settings => _settings;
  int get pageIndex => _pageIndex;
  bool get initialized => _initialized;
  bool get busy => _busy;
  bool get scanning => _scanning;
  int get scanCompleted => _scanCompleted;
  int get scanTotal => _scanTotal;
  double get scanProgress => _scanTotal == 0 ? 0 : _scanCompleted / _scanTotal;
  String get currentNode => _currentNode;
  String get bindingDescription => _probe.bindingDescription;
  String? get startupWarning => _startupWarning;
  String? get lastError => _lastError;
  ImportReport? get lastImportReport => _lastImportReport;

  NodeCounters get counters {
    final int usable = _nodes
        .where((NodeRecord node) => node.status == NodeStatus.usable)
        .length;
    final int failed = _nodes
        .where((NodeRecord node) => node.status == NodeStatus.failed)
        .length;
    final int checked = _nodes
        .where(
          (NodeRecord node) =>
              node.status == NodeStatus.usable ||
              node.status == NodeStatus.failed ||
              node.status == NodeStatus.skipped,
        )
        .length;
    return NodeCounters(
      total: _nodes.length,
      checked: checked,
      usable: usable,
      failed: failed,
    );
  }

  Future<void> initialize() async {
    try {
      final AppSnapshot snapshot = await _store.load();
      _nodes
        ..clear()
        ..addAll(snapshot.nodes);
      _settings = snapshot.settings;
    } on Object catch (error) {
      _startupWarning = '无法读取本地数据，已使用空白工作区：$error';
    }
    _initialized = true;
    notifyListeners();
  }

  void selectPage(int index) {
    if (index == _pageIndex || index < 0 || index > 3) return;
    _pageIndex = index;
    notifyListeners();
  }

  void clearLastError() {
    _lastError = null;
    notifyListeners();
  }

  Future<ImportReport> importSubscription(String url) async {
    return _runImport(() async {
      final String contents = await _importer.downloadSubscription(url);
      return _importer.parse(
        contents,
        sourceId: 'subscription-${DateTime.now().microsecondsSinceEpoch}',
      );
    });
  }

  Future<ImportReport> importText(String contents) async {
    return _runImport(
      () async => _importer.parse(
        contents,
        sourceId: 'paste-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
  }

  Future<ImportReport> importFile(String path) async {
    return _runImport(() async {
      final File file = File(path);
      if (!await file.exists()) throw const NodeImportException('找不到所选文件');
      if (await file.length() > 10 * 1024 * 1024) {
        throw const NodeImportException('配置文件超过 10 MB 安全限制');
      }
      final String contents = await file.readAsString();
      return _importer.parse(
        contents,
        sourceId: 'file-${DateTime.now().microsecondsSinceEpoch}',
      );
    });
  }

  Future<ImportReport> _runImport(
    Future<ImportReport> Function() action,
  ) async {
    if (_busy || _scanning) {
      throw const NodeImportException('当前有任务正在运行');
    }
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final ImportReport parsed = await action();
      final Set<String> existing =
          _nodes.map((NodeRecord node) => node.fingerprint).toSet();
      final List<NodeRecord> added = parsed.nodes
          .where((NodeRecord node) => existing.add(node.fingerprint))
          .toList(growable: false);
      _nodes.addAll(added);
      final ImportReport report = ImportReport(
        format: parsed.format,
        nodes: added,
        issues: parsed.issues,
        duplicates: parsed.duplicates + parsed.nodes.length - added.length,
      );
      _lastImportReport = report;
      await _saveSnapshot();
      return report;
    } on Object catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> scanAll() async {
    if (_scanning || _busy) return;
    if (_nodes.isEmpty) throw StateError('请先导入节点');
    _scanning = true;
    _cancelRequested = false;
    _lastError = null;
    _scanCompleted = 0;
    _scanTotal = _nodes.length;
    _currentNode = '';
    for (int index = 0; index < _nodes.length; index += 1) {
      _nodes[index] = _nodes[index].copyWith(
        status: NodeStatus.queued,
        clearResult: true,
        clearExportedName: true,
        clearError: true,
      );
    }
    notifyListeners();

    try {
      await _probe.prepare(_settings);
      notifyListeners();
      int cursor = 0;
      final int workers = _settings.concurrency.clamp(1, _nodes.length);

      Future<void> worker() async {
        while (!_cancelRequested) {
          if (cursor >= _nodes.length) return;
          final int index = cursor;
          cursor += 1;
          final String nodeId = _nodes[index].id;
          final NodeRecord started = _nodes[index].copyWith(
            status: NodeStatus.checking,
            clearError: true,
          );
          _replaceById(nodeId, started);
          _currentNode = started.originalName;
          notifyListeners();

          final NodeTestResult result = await _probe.probe(
            started,
            List<NodeRecord>.of(_nodes),
            _settings,
          );
          if (_cancelRequested) {
            _replaceById(
              nodeId,
              started.copyWith(
                status: NodeStatus.skipped,
                result: result,
                error: '用户取消检测',
              ),
            );
          } else if (result.isUsable) {
            _replaceById(
              nodeId,
              started.copyWith(
                status: NodeStatus.usable,
                result: result,
                clearError: true,
              ),
            );
          } else {
            _replaceById(
              nodeId,
              started.copyWith(
                status: NodeStatus.failed,
                result: result,
                error: result.error ?? '未取得真实出口 IP',
              ),
            );
          }
          _scanCompleted += 1;
          notifyListeners();
        }
      }

      await Future.wait<void>(
        List<Future<void>>.generate(workers, (int _) => worker()),
      );
      final List<NodeRecord> named = _naming.assign(_nodes);
      _nodes
        ..clear()
        ..addAll(named);
      await _saveSnapshot();
      _pageIndex = 2;
    } on Object catch (error) {
      _lastError = error.toString();
      await _saveSnapshot();
      rethrow;
    } finally {
      _scanning = false;
      _currentNode = '';
      notifyListeners();
    }
  }

  Future<void> cancelScan() async {
    if (!_scanning) return;
    _cancelRequested = true;
    await _probe.cancel();
    notifyListeners();
  }

  String buildKaringExport() => _exporter.buildJson(_nodes);

  Future<void> replaceNodes(List<NodeRecord> nodes) async {
    _nodes
      ..clear()
      ..addAll(nodes);
    await _persistWithBusyState();
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    await _persistWithBusyState();
  }

  Future<void> clearNodes() async {
    if (_scanning) await cancelScan();
    _nodes.clear();
    _lastImportReport = null;
    await _persistWithBusyState();
  }

  void _replaceById(String id, NodeRecord replacement) {
    final int index = _nodes.indexWhere((NodeRecord node) => node.id == id);
    if (index >= 0) _nodes[index] = replacement;
  }

  Future<void> _persistWithBusyState() async {
    _busy = true;
    notifyListeners();
    try {
      await _saveSnapshot();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _saveSnapshot() async {
    await _store.save(
      AppSnapshot(nodes: List<NodeRecord>.of(_nodes), settings: _settings),
    );
  }
}
