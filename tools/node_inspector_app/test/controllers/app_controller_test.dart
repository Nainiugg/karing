import 'package:flutter_test/flutter_test.dart';
import 'package:node_inspector_app/controllers/app_controller.dart';
import 'package:node_inspector_app/models/app_settings.dart';
import 'package:node_inspector_app/models/ip_profile.dart';
import 'package:node_inspector_app/models/node_deep_inspection.dart';
import 'package:node_inspector_app/models/node_record.dart';
import 'package:node_inspector_app/models/node_status.dart';
import 'package:node_inspector_app/models/node_test_result.dart';
import 'package:node_inspector_app/services/ip_intelligence_service.dart';
import 'package:node_inspector_app/services/node_probe.dart';
import 'package:node_inspector_app/storage/app_secret_store.dart';
import 'package:node_inspector_app/storage/app_store.dart';

NodeRecord _node(String id, NodeStatus status) {
  return NodeRecord(
    id: id,
    sourceId: 'source',
    originalName: 'node-$id',
    protocol: 'socks',
    normalizedConfig: const <String, Object?>{},
    dependencies: const <String>[],
    fingerprint: 'fingerprint-$id',
    importedAt: DateTime.utc(2026),
    status: status,
  );
}

void main() {
  test('controller calculates counters and persists changes', () async {
    final MemoryAppStore store = MemoryAppStore();
    final AppController controller = AppController(store: store);
    await controller.initialize();

    await controller.replaceNodes(<NodeRecord>[
      _node('1', NodeStatus.usable),
      _node('2', NodeStatus.failed),
      _node('3', NodeStatus.queued),
      _node('4', NodeStatus.skipped),
    ]);

    expect(controller.counters.total, 4);
    expect(controller.counters.checked, 3);
    expect(controller.counters.usable, 1);
    expect(controller.counters.failed, 1);
    expect(store.snapshot.nodes, hasLength(4));
  });

  test('navigation ignores indexes outside the four pages', () async {
    final AppController controller = AppController(store: MemoryAppStore());
    await controller.initialize();

    controller.selectPage(2);
    expect(controller.pageIndex, 2);
    controller.selectPage(9);
    expect(controller.pageIndex, 2);
  });

  test(
    'startup upgrades fingerprints and removes persisted duplicates',
    () async {
      const Map<String, Object?> firstConfig = <String, Object?>{
        'type': 'trojan',
        'tag': 'first',
        'server': 'EXAMPLE.invalid',
        'server_port': 443,
        'password': 'secret',
      };
      const Map<String, Object?> secondConfig = <String, Object?>{
        'password': 'secret',
        'server_port': 443,
        'server': 'example.invalid',
        'tag': 'second',
        'type': 'TROJAN',
      };
      final MemoryAppStore store = MemoryAppStore(
        AppSnapshot(
          nodes: <NodeRecord>[
            NodeRecord(
              id: 'legacy-1',
              sourceId: 'old',
              originalName: 'first',
              protocol: 'trojan',
              normalizedConfig: firstConfig,
              dependencies: const <String>[],
              fingerprint: '',
              importedAt: DateTime.utc(2026),
            ),
            NodeRecord(
              id: 'legacy-2',
              sourceId: 'old',
              originalName: 'second',
              protocol: 'trojan',
              normalizedConfig: secondConfig,
              dependencies: const <String>[],
              fingerprint: 'old-hash',
              importedAt: DateTime.utc(2026),
            ),
          ],
        ),
      );
      final AppController controller = AppController(store: store);

      await controller.initialize();

      expect(controller.nodes, hasLength(1));
      expect(controller.nodes.single.fingerprint, startsWith('v2:'));
      expect(store.snapshot.nodes, hasLength(1));
    },
  );

  test('scan records real probe values and assigns export names', () async {
    final AppController controller = AppController(
      store: MemoryAppStore(),
      probe: _FakeProbe(),
    );
    await controller.initialize();
    await controller.replaceNodes(<NodeRecord>[
      _node('1', NodeStatus.queued),
      _node('2', NodeStatus.queued),
    ]);

    await controller.scanAll();

    expect(controller.counters.usable, 2);
    expect(controller.nodes.first.result?.exitIp, '198.51.100.8');
    expect(controller.nodes.first.exportedName, '新加坡-198.51.100.8');
    expect(controller.nodes.last.exportedName, '新加坡-198.51.100.8-2');
    expect(controller.pageIndex, 2);
  });

  test(
    'deep inspection stores dual-stack details, history, and safe report',
    () async {
      final AppController controller = AppController(
        store: MemoryAppStore(),
        secretStore: MemoryAppSecretStore(),
        probe: _FakeProbe(),
        intelligence: const _FakeIntelligence(),
      );
      await controller.initialize();
      await controller.replaceNodes(<NodeRecord>[
        _node('1', NodeStatus.usable),
      ]);

      final NodeDeepInspection result = await controller.inspectNode('1');

      expect(result.addressMode, 'IPv4 / IPv6 双栈');
      expect(result.ipv4?.purityScore, 95);
      expect(controller.nodes.single.inspectionHistory, hasLength(1));
      final String report = controller.buildInspectionReport('1');
      expect(report, contains('198.51.100.8'));
      expect(report, isNot(contains('normalizedConfig')));
    },
  );
}

class _FakeProbe implements NodeProbe {
  @override
  String get bindingDescription => 'test';

  @override
  Future<void> cancel() async {}

  @override
  Future<void> prepare(AppSettings settings) async {}

  @override
  Future<NodeTestResult> probe(
    NodeRecord node,
    List<NodeRecord> allNodes,
    AppSettings settings,
  ) async {
    return NodeTestResult(
      checkedAt: DateTime.utc(2026),
      exitIp: '198.51.100.8',
      country: '新加坡',
      countryCode: 'SG',
      latencyMs: 42,
    );
  }

  @override
  Future<NodeDeepInspection> inspect(
    NodeRecord node,
    List<NodeRecord> allNodes,
    AppSettings settings,
  ) async {
    return NodeDeepInspection(
      checkedAt: DateTime.utc(2026),
      ipv4: IpProfile(
        ip: '198.51.100.8',
        version: 4,
        checkedAt: DateTime.utc(2026),
      ),
      ipv6: IpProfile(
        ip: '2001:db8::8',
        version: 6,
        checkedAt: DateTime.utc(2026),
      ),
    );
  }
}

class _FakeIntelligence implements IpIntelligenceService {
  const _FakeIntelligence();

  @override
  Future<NodeDeepInspection> enrich(
    NodeDeepInspection inspection,
    AppSettings settings,
    AppApiSecrets secrets, {
    NodeDeepInspection? cached,
  }) async {
    final IpProfile risk = IpProfile(
      ip: inspection.ipv4!.ip,
      version: 4,
      checkedAt: inspection.checkedAt,
      isVpn: false,
      isProxy: false,
      isTor: false,
      isHosting: false,
      abuseConfidenceScore: 5,
      sources: const <String>['test'],
    );
    return inspection.copyWith(ipv4: inspection.ipv4!.merge(risk));
  }
}
