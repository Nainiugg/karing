import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_inspector_app/models/app_settings.dart';
import 'package:node_inspector_app/models/node_record.dart';
import 'package:node_inspector_app/storage/app_store.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'node-inspector-store-test-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('store persists nodes and settings', () async {
    final LocalJsonAppStore store = LocalJsonAppStore(
      File('${temporaryDirectory.path}${Platform.pathSeparator}data.json'),
    );
    final NodeRecord node = NodeRecord(
      id: '1',
      sourceId: 'source',
      originalName: 'node',
      protocol: 'trojan',
      normalizedConfig: const <String, Object?>{},
      dependencies: const <String>[],
      fingerprint: 'fingerprint',
      importedAt: DateTime.utc(2026),
    );

    await store.save(
      AppSnapshot(
        nodes: <NodeRecord>[node],
        settings: const AppSettings(
          concurrency: 8,
          timeoutSeconds: 30,
          publicIntelligenceEnabled: false,
          intelligenceCacheHours: 72,
        ),
      ),
    );
    final AppSnapshot restored = await store.load();

    expect(restored.nodes, hasLength(1));
    expect(restored.nodes.single.protocol, 'trojan');
    expect(restored.settings.concurrency, 8);
    expect(restored.settings.timeoutSeconds, 30);
    expect(restored.settings.publicIntelligenceEnabled, isFalse);
    expect(restored.settings.intelligenceCacheHours, 72);
  });

  test('missing store returns an empty snapshot', () async {
    final LocalJsonAppStore store = LocalJsonAppStore(
      File('${temporaryDirectory.path}${Platform.pathSeparator}missing.json'),
    );

    final AppSnapshot snapshot = await store.load();

    expect(snapshot.nodes, isEmpty);
    expect(snapshot.settings.concurrency, 4);
  });
}
