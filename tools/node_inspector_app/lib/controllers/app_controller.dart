import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/node_record.dart';
import '../models/node_status.dart';
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
  AppController({required AppStore store}) : _store = store;

  final AppStore _store;
  final List<NodeRecord> _nodes = <NodeRecord>[];

  AppSettings _settings = const AppSettings();
  int _pageIndex = 0;
  bool _initialized = false;
  bool _busy = false;
  String? _startupWarning;

  UnmodifiableListView<NodeRecord> get nodes =>
      UnmodifiableListView<NodeRecord>(_nodes);
  AppSettings get settings => _settings;
  int get pageIndex => _pageIndex;
  bool get initialized => _initialized;
  bool get busy => _busy;
  String? get startupWarning => _startupWarning;

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
    if (index == _pageIndex || index < 0 || index > 3) {
      return;
    }
    _pageIndex = index;
    notifyListeners();
  }

  Future<void> replaceNodes(List<NodeRecord> nodes) async {
    _nodes
      ..clear()
      ..addAll(nodes);
    await _persist();
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    await _persist();
  }

  Future<void> clearNodes() async {
    _nodes.clear();
    await _persist();
  }

  Future<void> _persist() async {
    _busy = true;
    notifyListeners();
    try {
      await _store.save(
        AppSnapshot(nodes: List<NodeRecord>.of(_nodes), settings: _settings),
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
