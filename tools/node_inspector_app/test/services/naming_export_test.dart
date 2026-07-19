import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_inspector_app/models/node_record.dart';
import 'package:node_inspector_app/models/node_status.dart';
import 'package:node_inspector_app/models/node_test_result.dart';
import 'package:node_inspector_app/services/karing_export_service.dart';
import 'package:node_inspector_app/services/node_naming_service.dart';

NodeRecord _node({
  required String id,
  required String name,
  required Map<String, Object?> config,
  List<String> dependencies = const <String>[],
  NodeStatus status = NodeStatus.usable,
}) {
  return NodeRecord(
    id: id,
    sourceId: 'source',
    originalName: name,
    protocol: config['type']! as String,
    normalizedConfig: config,
    dependencies: dependencies,
    fingerprint: 'fingerprint-$id',
    importedAt: DateTime.utc(2026),
    status: status,
    result: status == NodeStatus.usable
        ? NodeTestResult(
            checkedAt: DateTime.utc(2026),
            exitIp: '203.0.113.7',
            country: '日本',
            countryCode: 'JP',
          )
        : null,
  );
}

void main() {
  test('assigns country-IP names with stable duplicate suffixes', () {
    final List<NodeRecord> named = const NodeNamingService().assign(<NodeRecord>[
      _node(
        id: '1',
        name: 'one',
        config: <String, Object?>{
          'type': 'trojan',
          'tag': 'one',
          'server': 'one.invalid',
          'server_port': 443,
          'password': 'test',
        },
      ),
      _node(
        id: '2',
        name: 'two',
        config: <String, Object?>{
          'type': 'socks',
          'tag': 'two',
          'server': '192.0.2.2',
          'server_port': 1080,
        },
      ),
    ]);

    expect(named.first.exportedName, '日本-203.0.113.7');
    expect(named.last.exportedName, '日本-203.0.113.7-2');
  });

  test('exports usable nodes and rewrites required detour tags', () {
    final NodeRecord dependency = _node(
      id: 'base',
      name: 'base',
      status: NodeStatus.failed,
      config: <String, Object?>{
        'type': 'shadowsocks',
        'tag': 'base',
        'server': '192.0.2.3',
        'server_port': 443,
        'method': 'aes-128-gcm',
        'password': 'test',
      },
    );
    final NodeRecord target = _node(
      id: 'target',
      name: 'chain',
      dependencies: <String>['base'],
      config: <String, Object?>{
        'type': 'trojan',
        'tag': 'chain',
        'server': 'example.invalid',
        'server_port': 443,
        'password': 'test',
        'detour': 'base',
      },
    ).copyWith(exportedName: '日本-203.0.113.7');

    final String json = const KaringExportService().buildJson(
      <NodeRecord>[dependency, target],
    );
    final Map<String, Object?> root = jsonDecode(json) as Map<String, Object?>;
    final List<Object?> outbounds = root['outbounds']! as List<Object?>;
    final List<Map<String, Object?>> maps =
        outbounds.cast<Map<String, Object?>>();

    expect(maps.first['type'], 'selector');
    expect(maps.first['outbounds'], <String>['日本-203.0.113.7']);
    expect(
      maps.any(
        (Map<String, Object?> value) =>
            value['tag'].toString().startsWith('依赖-base'),
      ),
      isTrue,
    );
    final Map<String, Object?> exportedTarget = maps.firstWhere(
      (Map<String, Object?> value) => value['tag'] == '日本-203.0.113.7',
    );
    expect(exportedTarget['detour'].toString(), startsWith('依赖-base'));
  });
}
