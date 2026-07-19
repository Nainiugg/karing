import 'package:flutter_test/flutter_test.dart';
import 'package:node_inspector_app/controllers/app_controller.dart';
import 'package:node_inspector_app/models/node_record.dart';
import 'package:node_inspector_app/models/node_status.dart';
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
}
