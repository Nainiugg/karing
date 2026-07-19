import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/node_record.dart';
import '../models/node_test_result.dart';
import 'node_probe.dart';

class SingBoxNodeProbe implements NodeProbe {
  static const String coreVersion = '1.13.14';
  static const String coreExecutableSha256 =
      'db0d779948214cf761011d154c3a5da36df20394fa01a9fc798f1dc39fe9d183';
  static const String coreLibrarySha256 =
      'c7434cfa93c3041321dd19111c4de6c52b8a9531a65661ba45425d3c51ec69e2';
  static const String _targetTag = 'NODE_INSPECTOR_TARGET';
  static const String _dnsTag = 'NODE_INSPECTOR_LOCAL_DNS';

  final Set<Process> _processes = <Process>{};
  File? _core;
  String _bindingAddress = '';
  bool _cancelled = false;

  @override
  String get bindingDescription => _bindingAddress.isEmpty
      ? '未绑定物理出口；请在设置中填写网卡 IPv4'
      : '物理出口 IPv4：$_bindingAddress';

  @override
  Future<void> prepare(AppSettings settings) async {
    _cancelled = false;
    _core ??= await _CoreLocator.ensureAvailable();
    _bindingAddress = settings.bindAddress.trim();
    if (_bindingAddress.isEmpty) {
      _bindingAddress = await _WindowsBindingResolver.discover();
    }
  }

  @override
  Future<NodeTestResult> probe(
    NodeRecord node,
    List<NodeRecord> allNodes,
    AppSettings settings,
  ) async {
    if (_cancelled) {
      return NodeTestResult(
        checkedAt: DateTime.now().toUtc(),
        error: '检测已取消',
      );
    }
    final File core = _core ?? await _CoreLocator.ensureAvailable();
    final int port = await _reservePort();
    final Directory runtime = await _runtimeDirectory(node.id);
    final File configFile = File(
      '${runtime.path}${Platform.pathSeparator}isolated.json',
    );
    final Map<String, Object?> config = _buildConfig(
      node,
      allNodes,
      port,
      _bindingAddress,
    );
    await configFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(config)}\n',
      flush: true,
    );

    Process? process;
    try {
      final ProcessResult check = await Process.run(
        core.path,
        <String>['check', '-c', configFile.path],
        workingDirectory: runtime.path,
        runInShell: false,
      ).timeout(const Duration(seconds: 10));
      if (check.exitCode != 0) {
        return NodeTestResult(
          checkedAt: DateTime.now().toUtc(),
          error: '配置不兼容：${_cleanCoreError(check.stderr, runtime.path)}',
        );
      }
      if (_cancelled) {
        return NodeTestResult(
          checkedAt: DateTime.now().toUtc(),
          error: '检测已取消',
        );
      }

      process = await Process.start(
        core.path,
        <String>['run', '-c', configFile.path],
        workingDirectory: runtime.path,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );
      _processes.add(process);
      final Future<String> stdout = process.stdout
          .transform(utf8.decoder)
          .join()
          .then((String value) => value);
      final Future<String> stderr = process.stderr
          .transform(utf8.decoder)
          .join()
          .then((String value) => value);

      final bool ready = await _waitUntilReady(port);
      if (!ready) {
        process.kill();
        final String error = await stderr.timeout(
          const Duration(seconds: 2),
          onTimeout: () => '',
        );
        await stdout.timeout(const Duration(seconds: 2), onTimeout: () => '');
        return NodeTestResult(
          checkedAt: DateTime.now().toUtc(),
          error: '隔离核心启动失败：${_cleanCoreError(error, runtime.path)}',
        );
      }

      return await _probeGeo(
        port,
        settings.geoEndpoints,
        Duration(seconds: settings.timeoutSeconds),
      );
    } on TimeoutException {
      return NodeTestResult(
        checkedAt: DateTime.now().toUtc(),
        error: '检测超时',
      );
    } on Object catch (error) {
      return NodeTestResult(
        checkedAt: DateTime.now().toUtc(),
        error: '检测进程异常：${_safeError(error)}',
      );
    } finally {
      if (process != null) {
        _processes.remove(process);
        process.kill();
        await process.exitCode.timeout(
          const Duration(seconds: 2),
          onTimeout: () => -1,
        );
      }
      try {
        if (await runtime.exists()) await runtime.delete(recursive: true);
      } on FileSystemException {
        // The process has already been stopped. A locked temporary directory
        // is harmless and will be reused or removed by a later run.
      }
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    final List<Process> active = _processes.toList(growable: false);
    for (final Process process in active) {
      process.kill();
    }
    await Future.wait<int>(
      active.map(
        (Process process) => process.exitCode.timeout(
          const Duration(seconds: 2),
          onTimeout: () => -1,
        ),
      ),
    );
    _processes.clear();
  }

  static Map<String, Object?> _buildConfig(
    NodeRecord node,
    List<NodeRecord> allNodes,
    int port,
    String bindAddress,
  ) {
    final List<Map<String, Object?>> dependencies = <Map<String, Object?>>[];
    final Set<String> added = <String>{};

    void addDependencies(NodeRecord owner) {
      for (final String dependency in owner.dependencies) {
        final NodeRecord? match = _dependencyFor(owner, dependency, allNodes);
        if (match == null || !added.add(match.id)) continue;
        final Map<String, Object?> config = _copyMap(match.normalizedConfig);
        config['tag'] = dependency;
        _applyBinding(config, bindAddress);
        dependencies.add(config);
        addDependencies(match);
      }
    }

    addDependencies(node);
    final Map<String, Object?> target = _copyMap(node.normalizedConfig);
    target['tag'] = _targetTag;
    _applyBinding(target, bindAddress);

    final Map<String, Object?> dnsServer = <String, Object?>{
      'type': 'local',
      'tag': _dnsTag,
      'prefer_go': true,
    };
    _applyBinding(dnsServer, bindAddress);

    return <String, Object?>{
      'log': <String, Object?>{'level': 'warn', 'timestamp': true},
      'dns': <String, Object?>{
        'servers': <Object?>[dnsServer],
      },
      'inbounds': <Object?>[
        <String, Object?>{
          'type': 'mixed',
          'tag': 'NODE_INSPECTOR_IN',
          'listen': '127.0.0.1',
          'listen_port': port,
        },
      ],
      'outbounds': <Object?>[target, ...dependencies],
      'route': <String, Object?>{
        'auto_detect_interface': bindAddress.isEmpty,
        'default_domain_resolver': <String, Object?>{
          'server': _dnsTag,
          'strategy': 'prefer_ipv4',
        },
        'final': _targetTag,
      },
    };
  }

  @visibleForTesting
  static Map<String, Object?> buildConfigurationForTesting(
    NodeRecord node,
    List<NodeRecord> allNodes, {
    int port = 18888,
    String bindAddress = '',
  }) {
    return _buildConfig(node, allNodes, port, bindAddress);
  }

  static NodeRecord? _dependencyFor(
    NodeRecord owner,
    String tag,
    List<NodeRecord> nodes,
  ) {
    for (final NodeRecord node in nodes) {
      if (node.sourceId == owner.sourceId && node.originalName == tag) return node;
    }
    for (final NodeRecord node in nodes) {
      if (node.originalName == tag) return node;
    }
    return null;
  }

  static void _applyBinding(Map<String, Object?> config, String address) {
    if (address.isEmpty) return;
    config
      ..remove('bind_interface')
      ..remove('inet6_bind_address')
      ..remove('network_strategy')
      ..remove('network_type')
      ..remove('fallback_network_type');
    config['inet4_bind_address'] = address;
    config.putIfAbsent('domain_strategy', () => 'prefer_ipv4');
  }

  static Future<NodeTestResult> _probeGeo(
    int port,
    List<String> endpoints,
    Duration timeout,
  ) async {
    String lastError = '所有出口查询接口均失败';
    for (final String value in endpoints) {
      final Uri? endpoint = Uri.tryParse(value);
      if (endpoint == null || endpoint.scheme != 'https') continue;
      final HttpClient client = HttpClient()
        ..connectionTimeout = timeout
        ..idleTimeout = timeout
        ..findProxy = (Uri uri) => 'PROXY 127.0.0.1:$port';
      final Stopwatch stopwatch = Stopwatch()..start();
      try {
        final HttpClientRequest request = await client.getUrl(endpoint).timeout(timeout);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.set(HttpHeaders.connectionHeader, 'close');
        final HttpClientResponse response = await request.close().timeout(timeout);
        final List<int> bytes = await response
            .fold<List<int>>(<int>[], (List<int> data, List<int> chunk) {
              if (data.length + chunk.length > 1024 * 1024) {
                throw const FormatException('响应超过 1 MB');
              }
              data.addAll(chunk);
              return data;
            })
            .timeout(timeout);
        stopwatch.stop();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = '出口查询返回 HTTP ${response.statusCode}';
          continue;
        }
        final Object? decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! Map<String, Object?>) {
          lastError = '出口查询返回格式无效';
          continue;
        }
        final _GeoResult geo = _GeoResult.fromJson(decoded);
        if (geo.ip.isEmpty) {
          lastError = '出口查询没有返回 IP';
          continue;
        }
        return NodeTestResult(
          checkedAt: DateTime.now().toUtc(),
          exitIp: geo.ip,
          countryCode: geo.countryCode,
          country: geo.country,
          asn: geo.asn,
          organization: geo.organization,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } on Object catch (error) {
        lastError = _safeError(error);
      } finally {
        client.close(force: true);
      }
    }
    return NodeTestResult(
      checkedAt: DateTime.now().toUtc(),
      error: lastError,
    );
  }

  Future<bool> _waitUntilReady(int port) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < const Duration(seconds: 6)) {
      if (_cancelled) return false;
      try {
        final Socket socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(milliseconds: 250),
        );
        await socket.close();
        return true;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }
    return false;
  }

  static Future<int> _reservePort() async {
    final ServerSocket socket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    final int port = socket.port;
    await socket.close();
    return port;
  }

  static Future<Directory> _runtimeDirectory(String nodeId) async {
    final Directory root = Directory(
      '${_CoreLocator.appDataRoot.path}${Platform.pathSeparator}runtime',
    );
    await root.create(recursive: true);
    final String safeId = nodeId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    final Directory directory = Directory(
      '${root.path}${Platform.pathSeparator}$safeId-${DateTime.now().microsecondsSinceEpoch}',
    );
    await directory.create(recursive: true);
    return directory;
  }

  static Map<String, Object?> _copyMap(Map<String, Object?> value) {
    final Object? decoded = jsonDecode(jsonEncode(value));
    return decoded as Map<String, Object?>;
  }

  static String _cleanCoreError(Object? value, String runtimePath) {
    String text = value?.toString() ?? '';
    text = text.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
    text = text.replaceAll(runtimePath, '<runtime>');
    final List<String> lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    final String result = lines.isEmpty ? '未知错误' : lines.take(3).join(' · ');
    return result.length > 500 ? '${result.substring(0, 500)}…' : result;
  }

  static String _safeError(Object error) {
    if (error is TimeoutException) return '请求超时';
    if (error is SocketException) return error.message;
    if (error is HandshakeException) return 'TLS 握手失败';
    if (error is FormatException) return error.message;
    if (error is HttpException) return error.message;
    return error.runtimeType.toString();
  }
}

class _CoreLocator {
  static Directory get appDataRoot {
    final String root = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return Directory('$root${Platform.pathSeparator}NodeInspector');
  }

  static Future<File> ensureAvailable() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('隔离检测核心目前只支持 Windows');
    }
    final Directory executableDirectory = File(Platform.resolvedExecutable).parent;
    final List<File> candidates = <File>[
      File(
        '${Directory.current.path}${Platform.pathSeparator}assets${Platform.pathSeparator}core${Platform.pathSeparator}sing-box.exe',
      ),
      File(
        '${executableDirectory.path}${Platform.pathSeparator}assets${Platform.pathSeparator}core${Platform.pathSeparator}sing-box.exe',
      ),
      File(
        '${executableDirectory.path}${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}assets${Platform.pathSeparator}core${Platform.pathSeparator}sing-box.exe',
      ),
    ];
    for (final File file in candidates) {
      if (await _validBundle(file)) return file;
    }

    final File installed = File(
      '${appDataRoot.path}${Platform.pathSeparator}core${Platform.pathSeparator}sing-box.exe',
    );
    if (await _validBundle(installed)) return installed;
    try {
      final ByteData executableData =
          await rootBundle.load('assets/core/sing-box.exe');
      final ByteData libraryData =
          await rootBundle.load('assets/core/libcronet.dll');
      await installed.parent.create(recursive: true);
      await installed.writeAsBytes(
        executableData.buffer.asUint8List(
          executableData.offsetInBytes,
          executableData.lengthInBytes,
        ),
        flush: true,
      );
      final File library = _libraryBeside(installed);
      await library.writeAsBytes(
        libraryData.buffer.asUint8List(
          libraryData.offsetInBytes,
          libraryData.lengthInBytes,
        ),
        flush: true,
      );
    } on Object {
      throw StateError(
        '找不到 sing-box ${SingBoxNodeProbe.coreVersion}。请运行 prepare_core_windows.ps1 或重新下载完整 Windows 包。',
      );
    }
    if (!await _validBundle(installed)) {
      throw StateError('sing-box 核心校验失败，文件可能不完整或被替换');
    }
    return installed;
  }

  static Future<bool> _validBundle(File file) async {
    final File library = _libraryBeside(file);
    if (!await file.exists() || !await library.exists()) return false;
    return await _validHash(file, SingBoxNodeProbe.coreExecutableSha256) &&
        await _validHash(library, SingBoxNodeProbe.coreLibrarySha256);
  }

  static File _libraryBeside(File executable) {
    return File(
      '${executable.parent.path}${Platform.pathSeparator}libcronet.dll',
    );
  }

  static Future<bool> _validHash(File file, String expected) async {
    final Digest digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expected;
  }
}

class _WindowsBindingResolver {
  static Future<String> discover() async {
    if (!Platform.isWindows) return '';
    const String script = r'''
$routes = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
  Where-Object { $_.NextHop -ne '0.0.0.0' } |
  Sort-Object InterfaceMetric, RouteMetric
foreach ($route in $routes) {
  $adapter = Get-NetAdapter -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue
  if ($null -eq $adapter -or $adapter.Status -ne 'Up') { continue }
  if ($adapter.Name -match 'Karing|Wintun|WireGuard|TAP|TUN') { continue }
  $ip = Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '169.254.*' } |
    Select-Object -First 1 -ExpandProperty IPAddress
  if ($ip) { Write-Output $ip; break }
}
''';
    try {
      final ProcessResult result = await Process.run(
        'powershell.exe',
        <String>[
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
        runInShell: false,
      ).timeout(const Duration(seconds: 8));
      if (result.exitCode != 0) return '';
      final String address = result.stdout.toString().trim().split(RegExp(r'[\r\n]+')).first;
      return InternetAddress.tryParse(address)?.type == InternetAddressType.IPv4
          ? address
          : '';
    } on Object {
      return '';
    }
  }
}

class _GeoResult {
  const _GeoResult({
    required this.ip,
    required this.countryCode,
    required this.country,
    required this.asn,
    required this.organization,
  });

  final String ip;
  final String countryCode;
  final String country;
  final String asn;
  final String organization;

  factory _GeoResult.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> connection =
        json['connection'] is Map<String, Object?>
            ? json['connection'] as Map<String, Object?>
            : <String, Object?>{};
    final String asn = _value(json['asn']).ifEmpty(_value(connection['asn']));
    return _GeoResult(
      ip: _value(json['ip']),
      countryCode: _value(json['country_code']).ifEmpty(
        _value(json['countryCode']),
      ),
      country: _value(json['country']),
      asn: asn.isEmpty || asn.toUpperCase().startsWith('AS') ? asn : 'AS$asn',
      organization: _value(json['isp'])
          .ifEmpty(_value(json['organization']))
          .ifEmpty(_value(connection['isp']))
          .ifEmpty(_value(connection['org'])),
    );
  }

  static String _value(Object? value) => value?.toString() ?? '';
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
