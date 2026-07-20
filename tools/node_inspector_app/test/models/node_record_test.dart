import 'package:flutter_test/flutter_test.dart';
import 'package:node_inspector_app/models/ip_profile.dart';
import 'package:node_inspector_app/models/node_deep_inspection.dart';
import 'package:node_inspector_app/models/node_record.dart';
import 'package:node_inspector_app/models/node_status.dart';
import 'package:node_inspector_app/models/node_test_result.dart';

void main() {
  test('node record survives a JSON round trip', () {
    final NodeRecord source = NodeRecord(
      id: 'node-1',
      sourceId: 'subscription-1',
      originalName: '示例节点',
      protocol: 'vless',
      normalizedConfig: <String, Object?>{
        'server': 'example.invalid',
        'server_port': 443,
      },
      dependencies: const <String>['detour-node'],
      fingerprint: 'sha256:test',
      importedAt: DateTime.utc(2026, 7, 19, 1, 2, 3),
      status: NodeStatus.usable,
      result: NodeTestResult(
        checkedAt: DateTime.utc(2026, 7, 19, 1, 3),
        exitIp: '203.0.113.9',
        countryCode: 'JP',
        country: '日本',
        asn: 'AS64500',
        organization: 'Example Network',
        latencyMs: 88,
      ),
      exportedName: '日本-203.0.113.9',
      inspection: NodeDeepInspection(
        checkedAt: DateTime.utc(2026, 7, 19, 1, 4),
        ipv4: IpProfile(
          ip: '203.0.113.9',
          version: 4,
          checkedAt: DateTime.utc(2026, 7, 19, 1, 4),
          isHosting: true,
          sources: const <String>['test'],
        ),
      ),
      inspectionHistory: <NodeInspectionHistoryEntry>[
        NodeInspectionHistoryEntry(
          checkedAt: DateTime.utc(2026, 7, 19, 1, 4),
          ipv4: '203.0.113.9',
        ),
      ],
    );

    final NodeRecord restored = NodeRecord.fromJson(source.toJson());

    expect(restored.id, source.id);
    expect(restored.status, NodeStatus.usable);
    expect(restored.normalizedConfig['server_port'], 443);
    expect(restored.dependencies, <String>['detour-node']);
    expect(restored.result?.exitIp, '203.0.113.9');
    expect(restored.exportedName, '日本-203.0.113.9');
    expect(restored.inspection?.ipv4?.isHosting, isTrue);
    expect(restored.inspectionHistory.single.ipv4, '203.0.113.9');
  });

  test('unknown status safely falls back to imported', () {
    expect(NodeStatus.fromJson('future-status'), NodeStatus.imported);
  });
}
