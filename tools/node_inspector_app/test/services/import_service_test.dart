import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_inspector_app/services/import_service.dart';

void main() {
  final ImportService importer = ImportService();

  test('imports Clash YAML and normalizes protocol fields', () {
    const String yaml = '''
proxies:
  - name: Tokyo One
    type: trojan
    server: example.invalid
    port: 443
    password: test-password
    sni: example.invalid
    skip-cert-verify: true
  - name: Socks One
    type: socks5
    server: 192.0.2.10
    port: 1080
''';

    final report = importer.parse(yaml, sourceId: 'yaml-test');

    expect(report.format, 'Clash / YAML');
    expect(report.nodes, hasLength(2));
    expect(report.nodes.first.protocol, 'trojan');
    expect(report.nodes.first.normalizedConfig['server_port'], 443);
    expect(report.nodes.first.normalizedConfig['tls'], isA<Map<String, Object?>>());
    expect(report.nodes.last.protocol, 'socks');
  });

  test('imports sing-box outbounds and preserves detour dependencies', () {
    const String json = '''
{
  "outbounds": [
    {"type":"shadowsocks","tag":"base","server":"192.0.2.1","server_port":443,"method":"aes-128-gcm","password":"test"},
    {"type":"trojan","tag":"chain","server":"example.invalid","server_port":443,"password":"test","detour":"base","tls":{"enabled":true}}
  ]
}
''';

    final report = importer.parse(json, sourceId: 'json-test');

    expect(report.nodes, hasLength(2));
    expect(report.nodes.last.dependencies, <String>['base']);
  });

  test('imports wrapped share links and removes exact duplicates', () {
    const String links = '''
trojan://test@example.invalid:443?
sni=example.invalid#first
trojan://test@example.invalid:443?sni=example.invalid#second
''';

    final report = importer.parse(links, sourceId: 'link-test');

    expect(report.nodes, hasLength(1));
    expect(report.duplicates, 1);
    expect(report.nodes.single.originalName, 'first');
  });

  test('decodes a Base64 line subscription', () {
    const String link = 'vless://00000000-0000-0000-0000-000000000001@example.invalid:443?security=tls&sni=example.invalid#Tokyo';
    final String encoded = base64.encode(utf8.encode(link));

    final report = importer.parse(encoded, sourceId: 'base64-test');

    expect(report.format, 'Base64 订阅');
    expect(report.nodes.single.protocol, 'vless');
    expect(report.nodes.single.originalName, 'Tokyo');
  });

  test('reports unsupported input instead of fabricating nodes', () {
    expect(
      () => importer.parse('not a proxy configuration', sourceId: 'bad'),
      throwsA(isA<NodeImportException>()),
    );
  });
}
