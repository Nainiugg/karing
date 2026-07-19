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

  test('extracts nodes from noisy webpage text and filters ordinary URLs', () {
    const String text = r'''
抓取来源：https://example.com/articles/free-nodes.html
更新时间、客户端教程和其他网页说明。
<div>节点一：[复制](vless：／／00000000-0000-0000-0000-000000000001@example .invalid:443?security=tls&amp;sni=example.invalid#Tokyo)</div>
普通下载：https://example.com:8443/download/client
"trojan:\/\/pass word@example.invalid:443?security=tls\u0026sni=example.invalid#Singapore",
代理：http://192.0.2.8:8080#HTTP
''';

    final report = importer.parse(text, sourceId: 'web-noise-test');

    expect(report.format, '网页文本 / 分享链接');
    expect(report.candidates, 3);
    expect(report.nodes, hasLength(3));
    expect(report.nodes.map((node) => node.protocol),
        <String>['vless', 'trojan', 'http']);
    expect(report.filteredNoise, greaterThanOrEqualTo(3));
    expect(report.issues, isEmpty);
    expect(report.nodes.first.normalizedConfig['server'], 'example.invalid');
    expect(report.nodes[1].normalizedConfig['password'], 'password');
  });

  test('extracts multiple share links embedded on one line', () {
    const String text =
        '可用节点 vless://00000000-0000-0000-0000-000000000001@one.invalid:443?security=tls#one | trojan://test@two.invalid:443?sni=two.invalid#two 点击复制';

    final report = importer.parse(text, sourceId: 'inline-web-test');

    expect(report.nodes, hasLength(2));
    expect(report.nodes.first.protocol, 'vless');
    expect(report.nodes.last.protocol, 'trojan');
  });

  test('does not mistake a normal HTTPS webpage for a proxy node', () {
    expect(
      () => importer.parse(
        '教程：https://example.com:8443/download/client',
        sourceId: 'webpage-only',
      ),
      throwsA(isA<NodeImportException>()),
    );
  });

  test('reports unsupported input instead of fabricating nodes', () {
    expect(
      () => importer.parse('not a proxy configuration', sourceId: 'bad'),
      throwsA(isA<NodeImportException>()),
    );
  });
}
