import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

import '../models/import_report.dart';
import '../models/node_record.dart';
import '../models/node_status.dart';

class NodeImportException implements Exception {
  const NodeImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImportService {
  static const int _maximumDownloadBytes = 10 * 1024 * 1024;
  static const Set<String> _shareSchemes = <String>{
    'ss',
    'vmess',
    'vless',
    'trojan',
    'hysteria',
    'hysteria2',
    'hy2',
    'tuic',
    'socks',
    'socks5',
    'http',
    'https',
    'anytls',
  };
  static const Set<String> _nonNodeTypes = <String>{
    'selector',
    'urltest',
    'url-test',
    'direct',
    'block',
    'dns',
    'logical',
  };

  Future<String> downloadSubscription(
    String value, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final Uri? uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const NodeImportException('请输入有效的 HTTP 或 HTTPS 订阅地址');
    }

    final HttpClient client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout
      ..userAgent = 'NodeInspector/0.4.0';
    try {
      final HttpClientRequest request = await client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, '*/*');
      final HttpClientResponse response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NodeImportException('订阅服务器返回 HTTP ${response.statusCode}');
      }
      final BytesBuilder bytes = BytesBuilder(copy: false);
      await for (final List<int> chunk in response.timeout(timeout)) {
        bytes.add(chunk);
        if (bytes.length > _maximumDownloadBytes) {
          throw const NodeImportException('订阅内容超过 10 MB 安全限制');
        }
      }
      return utf8.decode(bytes.takeBytes(), allowMalformed: true);
    } on NodeImportException {
      rethrow;
    } on Object catch (error) {
      throw NodeImportException('无法下载订阅：${_safeError(error)}');
    } finally {
      client.close(force: true);
    }
  }

  ImportReport parse(String contents, {required String sourceId}) {
    final String input = contents.replaceFirst('\ufeff', '').trim();
    if (input.isEmpty) {
      throw const NodeImportException('输入内容为空');
    }

    final List<ImportIssue> issues = <ImportIssue>[];
    List<_ParsedNode> parsed = <_ParsedNode>[];
    String format = '分享链接';

    final Object? jsonValue = _tryJson(input);
    if (jsonValue != null) {
      format = 'sing-box / JSON';
      parsed = _parseContainer(jsonValue, issues);
    } else {
      final Object? yamlValue = _tryYaml(input);
      if (_hasProxyContainer(yamlValue)) {
        format = 'Clash / YAML';
        parsed = _parseContainer(yamlValue, issues);
      } else {
        final String? decoded = _tryDecodeSubscription(input);
        if (decoded != null) {
          format = 'Base64 订阅';
          final Object? decodedJson = _tryJson(decoded);
          final Object? decodedYaml = _tryYaml(decoded);
          if (decodedJson != null) {
            parsed = _parseContainer(decodedJson, issues);
          } else if (_hasProxyContainer(decodedYaml)) {
            parsed = _parseContainer(decodedYaml, issues);
          } else {
            parsed = _parseShareLinks(decoded, issues);
          }
        } else {
          parsed = _parseShareLinks(input, issues);
        }
      }
    }

    if (parsed.isEmpty) {
      final String detail = issues.isEmpty ? '没有识别到支持的节点格式' : issues.first.message;
      throw NodeImportException(detail);
    }

    final Set<String> fingerprints = <String>{};
    final List<NodeRecord> nodes = <NodeRecord>[];
    int duplicates = 0;
    for (final _ParsedNode item in parsed) {
      final String fingerprint = _fingerprint(item.config);
      if (!fingerprints.add(fingerprint)) {
        duplicates += 1;
        continue;
      }
      nodes.add(
        NodeRecord(
          id: '${fingerprint.substring(0, 16)}-${nodes.length + 1}',
          sourceId: sourceId,
          originalName: item.name,
          protocol: item.protocol,
          normalizedConfig: item.config,
          dependencies: item.dependencies,
          fingerprint: fingerprint,
          importedAt: DateTime.now().toUtc(),
          status: NodeStatus.queued,
        ),
      );
    }

    return ImportReport(
      format: format,
      nodes: nodes,
      issues: issues,
      duplicates: duplicates,
    );
  }

  List<_ParsedNode> _parseContainer(
    Object? value,
    List<ImportIssue> issues,
  ) {
    final Object? plain = _plain(value);
    final Map<String, Object?>? root = _stringMap(plain);
    Object? items = plain;
    bool clash = false;
    if (root != null) {
      if (root['outbounds'] is List<Object?>) {
        items = root['outbounds'];
      } else if (root['proxies'] is List<Object?>) {
        items = root['proxies'];
        clash = true;
      } else if (root['servers'] is List<Object?>) {
        items = root['servers'];
      }
    }
    if (items is! List<Object?>) {
      return <_ParsedNode>[];
    }

    final List<_ParsedNode> result = <_ParsedNode>[];
    for (int index = 0; index < items.length; index += 1) {
      final Map<String, Object?>? item = _stringMap(items[index]);
      if (item == null) {
        issues.add(ImportIssue(item: '第 ${index + 1} 项', message: '内容不是对象'));
        continue;
      }
      final String type = _text(item['type']).toLowerCase();
      if (_nonNodeTypes.contains(type)) {
        continue;
      }
      try {
        final bool looksClash = clash ||
            item.containsKey('name') ||
            item.containsKey('cipher') ||
            item.containsKey('skip-cert-verify');
        result.add(
          looksClash
              ? _fromClash(item, index)
              : _fromSingBox(item, index),
        );
      } on NodeImportException catch (error) {
        issues.add(
          ImportIssue(
            item: _displayName(item, index),
            message: error.message,
          ),
        );
      }
    }
    return result;
  }

  _ParsedNode _fromSingBox(Map<String, Object?> value, int index) {
    final String type = _text(value['type']).toLowerCase();
    if (type.isEmpty) {
      throw const NodeImportException('缺少协议类型');
    }
    final Map<String, Object?> config = _deepMapCopy(value);
    final String name = _text(config['tag']).trim().ifEmpty('节点-${index + 1}');
    config['type'] = type;
    config['tag'] = name;
    _validateEndpoint(config, type);
    final List<String> dependencies = <String>[
      if (_text(config['detour']).isNotEmpty) _text(config['detour']),
    ];
    return _ParsedNode(
      name: name,
      protocol: type,
      config: config,
      dependencies: dependencies,
    );
  }

  _ParsedNode _fromClash(Map<String, Object?> value, int index) {
    final String clashType = _text(value['type']).toLowerCase();
    final String type = switch (clashType) {
      'ss' => 'shadowsocks',
      'socks5' => 'socks',
      'hy2' => 'hysteria2',
      _ => clashType,
    };
    const Set<String> supported = <String>{
      'shadowsocks',
      'vmess',
      'vless',
      'trojan',
      'hysteria',
      'hysteria2',
      'tuic',
      'socks',
      'http',
      'anytls',
    };
    if (!supported.contains(type)) {
      throw NodeImportException('暂不支持 Clash 协议类型：$clashType');
    }
    final String name = _text(value['name']).trim().ifEmpty('节点-${index + 1}');
    final Map<String, Object?> config = <String, Object?>{
      'type': type,
      'tag': name,
      'server': _text(value['server']),
      'server_port': _integer(value['port']),
    };

    switch (type) {
      case 'shadowsocks':
        config['method'] = _text(value['cipher']);
        config['password'] = _text(value['password']);
        final String plugin = _text(value['plugin']);
        if (plugin.isNotEmpty) {
          config['plugin'] = plugin;
          config['plugin_opts'] = _pluginOptions(value['plugin-opts']);
        }
      case 'vmess':
        config['uuid'] = _text(value['uuid']);
        config['security'] = _text(value['cipher']).ifEmpty('auto');
        final int alterId = _integer(value['alterId']) ?? 0;
        if (alterId > 0) config['alter_id'] = alterId;
      case 'vless':
        config['uuid'] = _text(value['uuid']);
        final String flow = _text(value['flow']);
        if (flow.isNotEmpty) config['flow'] = flow;
      case 'trojan':
      case 'anytls':
        config['password'] = _text(value['password']);
      case 'hysteria':
        config['auth_str'] = _text(value['auth-str']).ifEmpty(
          _text(value['auth']),
        );
      case 'hysteria2':
        config['password'] = _text(value['password']).ifEmpty(
          _text(value['auth']),
        );
        final String obfs = _text(value['obfs']);
        if (obfs.isNotEmpty) {
          config['obfs'] = <String, Object?>{
            'type': obfs,
            'password': _text(value['obfs-password']),
          };
        }
      case 'tuic':
        config['uuid'] = _text(value['uuid']);
        config['password'] = _text(value['password']);
        final String congestion = _text(value['congestion-controller']);
        if (congestion.isNotEmpty) config['congestion_control'] = congestion;
        final String relay = _text(value['udp-relay-mode']);
        if (relay.isNotEmpty) config['udp_relay_mode'] = relay;
      case 'socks':
        config['version'] = '5';
        _copyIfText(config, 'username', value['username']);
        _copyIfText(config, 'password', value['password']);
      case 'http':
        _copyIfText(config, 'username', value['username']);
        _copyIfText(config, 'password', value['password']);
    }

    final bool tlsEnabled = _boolean(value['tls']) ||
        <String>{'trojan', 'hysteria', 'hysteria2', 'tuic', 'anytls'}
            .contains(type);
    final String network = _text(value['network']);
    final Map<String, Object?>? transport = _clashTransport(value, network);
    if (transport != null) config['transport'] = transport;
    final Map<String, Object?>? tls = _clashTls(value, tlsEnabled);
    if (tls != null) config['tls'] = tls;

    final String detour = _text(value['dialer-proxy']);
    if (detour.isNotEmpty) config['detour'] = detour;
    _validateEndpoint(config, type);
    return _ParsedNode(
      name: name,
      protocol: type,
      config: config,
      dependencies: detour.isEmpty ? const <String>[] : <String>[detour],
    );
  }

  List<_ParsedNode> _parseShareLinks(
    String input,
    List<ImportIssue> issues,
  ) {
    final List<String> links = _coalescedLinkLines(input);
    final List<_ParsedNode> result = <_ParsedNode>[];
    for (int index = 0; index < links.length; index += 1) {
      final String link = links[index];
      final String scheme = link.split(':').first.toLowerCase();
      if (!_shareSchemes.contains(scheme)) {
        issues.add(ImportIssue(item: '第 ${index + 1} 行', message: '无法识别分享链接协议'));
        continue;
      }
      try {
        result.add(_parseShareLink(link, index));
      } on NodeImportException catch (error) {
        issues.add(ImportIssue(item: '第 ${index + 1} 个链接', message: error.message));
      } on Object {
        issues.add(const ImportIssue(message: '分享链接格式损坏或包含无效转义'));
      }
    }
    return result;
  }

  _ParsedNode _parseShareLink(String link, int index) {
    final String scheme = link.split(':').first.toLowerCase();
    if (scheme == 'vmess') return _parseVmess(link, index);
    if (scheme == 'ss') return _parseShadowsocks(link, index);

    final Uri uri = Uri.parse(link);
    final Map<String, String> query = uri.queryParameters;
    final String name = _decoded(uri.fragment).ifEmpty('$scheme-${index + 1}');
    final int port = uri.hasPort ? uri.port : _defaultPort(scheme);
    final Map<String, Object?> config = <String, Object?>{
      'type': switch (scheme) {
        'socks5' => 'socks',
        'hy2' => 'hysteria2',
        'https' => 'http',
        _ => scheme,
      },
      'tag': name,
      'server': uri.host,
      'server_port': port,
    };
    final List<String> credentials = _decoded(uri.userInfo).split(':');
    final String first = credentials.isEmpty ? '' : credentials.first;
    final String second = credentials.length > 1
        ? credentials.sublist(1).join(':')
        : '';

    switch (scheme) {
      case 'vless':
        config['uuid'] = first;
        _copyIfText(config, 'flow', query['flow']);
      case 'trojan':
      case 'anytls':
        config['password'] = first;
      case 'hysteria':
        config['auth_str'] = first.ifEmpty(query['auth'] ?? '');
      case 'hysteria2':
      case 'hy2':
        config['password'] = first.ifEmpty(query['auth'] ?? '');
        final String obfs = query['obfs'] ?? '';
        if (obfs.isNotEmpty) {
          config['obfs'] = <String, Object?>{
            'type': obfs,
            'password': query['obfs-password'] ?? query['obfsPassword'] ?? '',
          };
        }
      case 'tuic':
        config['uuid'] = first;
        config['password'] = second.ifEmpty(query['password'] ?? '');
        _copyIfText(config, 'congestion_control', query['congestion_control']);
        _copyIfText(config, 'udp_relay_mode', query['udp_relay_mode']);
      case 'socks':
      case 'socks5':
        config['version'] = '5';
        _copyIfText(config, 'username', first);
        _copyIfText(config, 'password', second);
      case 'http':
      case 'https':
        _copyIfText(config, 'username', first);
        _copyIfText(config, 'password', second);
    }

    final bool defaultTls = <String>{
      'trojan',
      'hysteria',
      'hysteria2',
      'hy2',
      'tuic',
      'anytls',
      'https',
    }.contains(scheme);
    final Map<String, Object?>? tls = _uriTls(query, defaultTls);
    if (tls != null) config['tls'] = tls;
    final Map<String, Object?>? transport = _uriTransport(query);
    if (transport != null) config['transport'] = transport;
    _validateEndpoint(config, _text(config['type']));
    return _ParsedNode(
      name: name,
      protocol: _text(config['type']),
      config: config,
      dependencies: const <String>[],
    );
  }

  _ParsedNode _parseVmess(String link, int index) {
    final String payload = link.substring(link.indexOf('://') + 3).split('#').first;
    final String decoded = _decodeBase64(payload);
    final Map<String, Object?>? value = _stringMap(_tryJson(decoded));
    if (value == null) {
      throw const NodeImportException('VMess Base64 内容不是 JSON 对象');
    }
    final String name = _text(value['ps']).ifEmpty('vmess-${index + 1}');
    final Map<String, Object?> config = <String, Object?>{
      'type': 'vmess',
      'tag': name,
      'server': _text(value['add']),
      'server_port': _integer(value['port']),
      'uuid': _text(value['id']),
      'security': _text(value['scy']).ifEmpty('auto'),
    };
    final int alterId = _integer(value['aid']) ?? 0;
    if (alterId > 0) config['alter_id'] = alterId;
    final Map<String, String> query = <String, String>{
      'type': _text(value['net']),
      'path': _text(value['path']),
      'host': _text(value['host']),
      'serviceName': _text(value['path']),
      'security': _text(value['tls']),
      'sni': _text(value['sni']),
      'fp': _text(value['fp']),
      'alpn': _text(value['alpn']),
    };
    final Map<String, Object?>? transport = _uriTransport(query);
    if (transport != null) config['transport'] = transport;
    final Map<String, Object?>? tls = _uriTls(
      query,
      _text(value['tls']).toLowerCase() == 'tls',
    );
    if (tls != null) config['tls'] = tls;
    _validateEndpoint(config, 'vmess');
    return _ParsedNode(
      name: name,
      protocol: 'vmess',
      config: config,
      dependencies: const <String>[],
    );
  }

  _ParsedNode _parseShadowsocks(String link, int index) {
    final Uri initial = Uri.parse(link);
    final String name = _decoded(initial.fragment).ifEmpty('ss-${index + 1}');
    String body = link.substring(link.indexOf('://') + 3).split('#').first;
    final int queryIndex = body.indexOf('?');
    final String queryPart = queryIndex >= 0 ? body.substring(queryIndex + 1) : '';
    if (queryIndex >= 0) body = body.substring(0, queryIndex);

    String credentials;
    String endpoint;
    if (body.contains('@')) {
      final int at = body.lastIndexOf('@');
      credentials = body.substring(0, at);
      endpoint = body.substring(at + 1);
      if (!credentials.contains(':')) credentials = _decodeBase64(credentials);
    } else {
      final String decoded = _decodeBase64(body);
      final int at = decoded.lastIndexOf('@');
      if (at < 0) throw const NodeImportException('Shadowsocks 链接缺少服务器');
      credentials = decoded.substring(0, at);
      endpoint = decoded.substring(at + 1);
    }
    final int colon = credentials.indexOf(':');
    if (colon <= 0) throw const NodeImportException('Shadowsocks 缺少加密方式或密码');
    final Uri endpointUri = Uri.parse('ss://$endpoint');
    final Map<String, String> query = Uri.splitQueryString(queryPart);
    final Map<String, Object?> config = <String, Object?>{
      'type': 'shadowsocks',
      'tag': name,
      'server': endpointUri.host,
      'server_port': endpointUri.port,
      'method': _decoded(credentials.substring(0, colon)),
      'password': _decoded(credentials.substring(colon + 1)),
    };
    final String plugin = query['plugin'] ?? '';
    if (plugin.isNotEmpty) {
      final List<String> parts = plugin.split(';');
      config['plugin'] = parts.first;
      if (parts.length > 1) config['plugin_opts'] = parts.sublist(1).join(';');
    }
    _validateEndpoint(config, 'shadowsocks');
    return _ParsedNode(
      name: name,
      protocol: 'shadowsocks',
      config: config,
      dependencies: const <String>[],
    );
  }

  static Map<String, Object?>? _uriTls(
    Map<String, String> query,
    bool defaultEnabled,
  ) {
    final String security = (query['security'] ?? '').toLowerCase();
    final bool enabled = defaultEnabled || security == 'tls' || security == 'reality';
    if (!enabled) return null;
    final Map<String, Object?> tls = <String, Object?>{'enabled': true};
    final String serverName = query['sni'] ?? query['serverName'] ?? query['peer'] ?? '';
    if (serverName.isNotEmpty) tls['server_name'] = serverName;
    if (_truthy(query['allowInsecure']) || _truthy(query['insecure'])) {
      tls['insecure'] = true;
    }
    final String alpn = query['alpn'] ?? '';
    if (alpn.isNotEmpty) tls['alpn'] = alpn.split(',');
    final String fingerprint = query['fp'] ?? '';
    if (fingerprint.isNotEmpty && fingerprint != 'none') {
      tls['utls'] = <String, Object?>{
        'enabled': true,
        'fingerprint': fingerprint,
      };
    }
    if (security == 'reality' || (query['pbk'] ?? '').isNotEmpty) {
      tls['reality'] = <String, Object?>{
        'enabled': true,
        'public_key': query['pbk'] ?? query['publicKey'] ?? '',
        'short_id': query['sid'] ?? query['shortId'] ?? '',
      };
    }
    return tls;
  }

  static Map<String, Object?>? _uriTransport(Map<String, String> query) {
    final String type = (query['type'] ?? query['network'] ?? '').toLowerCase();
    if (type.isEmpty || type == 'tcp' || type == 'none') return null;
    switch (type) {
      case 'ws':
        final Map<String, Object?> value = <String, Object?>{
          'type': 'ws',
          'path': query['path'] ?? '/',
        };
        final String host = query['host'] ?? '';
        if (host.isNotEmpty) {
          value['headers'] = <String, Object?>{'Host': host};
        }
        final int earlyData = int.tryParse(query['ed'] ?? '') ?? 0;
        if (earlyData > 0) value['max_early_data'] = earlyData;
        return value;
      case 'grpc':
        return <String, Object?>{
          'type': 'grpc',
          'service_name': query['serviceName'] ?? query['service_name'] ?? '',
        };
      case 'http':
      case 'h2':
        final String host = query['host'] ?? '';
        return <String, Object?>{
          'type': 'http',
          'host': host.isEmpty ? <String>[] : host.split(','),
          'path': query['path'] ?? '/',
        };
      case 'httpupgrade':
        return <String, Object?>{
          'type': 'httpupgrade',
          'host': query['host'] ?? '',
          'path': query['path'] ?? '/',
        };
      default:
        return <String, Object?>{'type': type};
    }
  }

  static Map<String, Object?>? _clashTransport(
    Map<String, Object?> value,
    String network,
  ) {
    if (network.isEmpty || network == 'tcp') return null;
    if (network == 'ws') {
      final Map<String, Object?> options =
          _stringMap(value['ws-opts']) ?? <String, Object?>{};
      final Map<String, Object?> headers =
          _stringMap(options['headers']) ?? <String, Object?>{};
      return <String, Object?>{
        'type': 'ws',
        'path': _text(options['path']).ifEmpty('/'),
        if (headers.isNotEmpty) 'headers': headers,
      };
    }
    if (network == 'grpc') {
      final Map<String, Object?> options =
          _stringMap(value['grpc-opts']) ?? <String, Object?>{};
      return <String, Object?>{
        'type': 'grpc',
        'service_name': _text(options['grpc-service-name']),
      };
    }
    return <String, Object?>{'type': network};
  }

  static Map<String, Object?>? _clashTls(
    Map<String, Object?> value,
    bool enabled,
  ) {
    if (!enabled) return null;
    final Map<String, Object?> tls = <String, Object?>{
      'enabled': true,
      if (_boolean(value['skip-cert-verify'])) 'insecure': true,
    };
    final String serverName = _text(value['servername']).ifEmpty(
      _text(value['sni']),
    );
    if (serverName.isNotEmpty) tls['server_name'] = serverName;
    final String fingerprint = _text(value['client-fingerprint']);
    if (fingerprint.isNotEmpty) {
      tls['utls'] = <String, Object?>{
        'enabled': true,
        'fingerprint': fingerprint,
      };
    }
    final Map<String, Object?> reality =
        _stringMap(value['reality-opts']) ?? <String, Object?>{};
    if (reality.isNotEmpty) {
      tls['reality'] = <String, Object?>{
        'enabled': true,
        'public_key': _text(reality['public-key']),
        'short_id': _text(reality['short-id']),
      };
    }
    return tls;
  }

  static void _validateEndpoint(Map<String, Object?> config, String type) {
    if (_text(config['server']).isEmpty) {
      throw NodeImportException('$type 节点缺少服务器地址');
    }
    final int? port = _integer(config['server_port']);
    if (port == null || port <= 0 || port > 65535) {
      throw NodeImportException('$type 节点端口无效');
    }
    config['server_port'] = port;
  }

  static List<String> _coalescedLinkLines(String input) {
    final List<String> result = <String>[];
    String current = '';
    for (final String raw in input.split(RegExp(r'[\r\n]+'))) {
      final String line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final bool beginsLink = _shareSchemes.any(
        (String scheme) => line.toLowerCase().startsWith('$scheme://'),
      );
      if (beginsLink) {
        if (current.isNotEmpty) result.add(current);
        current = line;
      } else if (current.isNotEmpty &&
          (current.endsWith('?') || line.contains('=') || line.startsWith('&'))) {
        current += line;
      } else {
        if (current.isNotEmpty) result.add(current);
        current = line;
      }
    }
    if (current.isNotEmpty) result.add(current);
    return result;
  }

  static String? _tryDecodeSubscription(String input) {
    final String compact = input.replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 16 || !RegExp(r'^[A-Za-z0-9_\-+/=]+$').hasMatch(compact)) {
      return null;
    }
    try {
      final String decoded = _decodeBase64(compact);
      if (_shareSchemes.any((String scheme) => decoded.contains('$scheme://')) ||
          decoded.trimLeft().startsWith('{') ||
          decoded.contains('proxies:')) {
        return decoded;
      }
    } on Object {
      return null;
    }
    return null;
  }

  static String _decodeBase64(String value) {
    String normalized = value.trim().replaceAll('-', '+').replaceAll('_', '/');
    normalized += '=' * ((4 - normalized.length % 4) % 4);
    return utf8.decode(base64.decode(normalized), allowMalformed: false);
  }

  static String _fingerprint(Map<String, Object?> config) {
    final Map<String, Object?> copy = _deepMapCopy(config)
      ..remove('tag')
      ..remove('name');
    return sha256.convert(utf8.encode(jsonEncode(_canonical(copy)))).toString();
  }

  static Object? _canonical(Object? value) {
    if (value is Map<String, Object?>) {
      final List<String> keys = value.keys.toList()..sort();
      return <String, Object?>{
        for (final String key in keys) key: _canonical(value[key]),
      };
    }
    if (value is List<Object?>) {
      return value.map(_canonical).toList(growable: false);
    }
    return value;
  }

  static Object? _plain(Object? value) {
    if (value is YamlMap) {
      return <String, Object?>{
        for (final MapEntry<Object?, Object?> entry in value.entries)
          entry.key.toString(): _plain(entry.value),
      };
    }
    if (value is YamlList) {
      return value.map(_plain).toList(growable: false);
    }
    if (value is Map<String, Object?>) {
      return <String, Object?>{
        for (final MapEntry<String, Object?> entry in value.entries)
          entry.key: _plain(entry.value),
      };
    }
    if (value is List<Object?>) {
      return value.map(_plain).toList(growable: false);
    }
    return value;
  }

  static Object? _tryJson(String value) {
    final String trimmed = value.trimLeft();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
    try {
      return jsonDecode(value);
    } on FormatException {
      return null;
    }
  }

  static Object? _tryYaml(String value) {
    try {
      return loadYaml(value);
    } on YamlException {
      return null;
    }
  }

  static bool _hasProxyContainer(Object? value) {
    final Map<String, Object?>? map = _stringMap(_plain(value));
    return map != null &&
        (map['proxies'] is List<Object?> || map['outbounds'] is List<Object?>);
  }

  static Map<String, Object?>? _stringMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    return null;
  }

  static Map<String, Object?> _deepMapCopy(Map<String, Object?> value) {
    return _plain(value)! as Map<String, Object?>;
  }

  static String _displayName(Map<String, Object?> value, int index) {
    return _text(value['name']).ifEmpty(
      _text(value['tag']).ifEmpty('第 ${index + 1} 项'),
    );
  }

  static int? _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(_text(value));
  }

  static bool _boolean(Object? value) {
    if (value is bool) return value;
    return _truthy(_text(value));
  }

  static bool _truthy(String? value) {
    return <String>{'1', 'true', 'yes', 'on'}.contains(value?.toLowerCase());
  }

  static String _text(Object? value) => value?.toString() ?? '';

  static String _decoded(String value) {
    try {
      return Uri.decodeComponent(value);
    } on FormatException {
      return value;
    }
  }

  static int _defaultPort(String scheme) {
    return <String>{'https', 'trojan', 'vless', 'vmess', 'tuic', 'anytls'}
            .contains(scheme)
        ? 443
        : 1080;
  }

  static void _copyIfText(
    Map<String, Object?> target,
    String key,
    Object? value,
  ) {
    final String text = _text(value);
    if (text.isNotEmpty) target[key] = text;
  }

  static String _pluginOptions(Object? value) {
    if (value is String) return value;
    final Map<String, Object?>? map = _stringMap(value);
    if (map == null) return '';
    return map.entries
        .map((MapEntry<String, Object?> entry) => '${entry.key}=${entry.value}')
        .join(';');
  }

  static String _safeError(Object error) {
    if (error is SocketException) return error.message;
    if (error is HttpException) return error.message;
    if (error is TimeoutException) return '连接超时';
    return error.runtimeType.toString();
  }
}

class _ParsedNode {
  const _ParsedNode({
    required this.name,
    required this.protocol,
    required this.config,
    required this.dependencies,
  });

  final String name;
  final String protocol;
  final Map<String, Object?> config;
  final List<String> dependencies;
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
