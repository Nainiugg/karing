import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_inspector_app/models/node_record.dart';
import 'package:node_inspector_app/services/sing_box_node_probe.dart';

void main() {
  test('bundled core accepts the generated isolated configuration', () async {
    if (!Platform.isWindows) return;
    final NodeRecord node = NodeRecord(
      id: 'schema-test',
      sourceId: 'test',
      originalName: 'schema-test',
      protocol: 'socks',
      normalizedConfig: <String, Object?>{
        'type': 'socks',
        'tag': 'schema-test',
        'server': '192.0.2.1',
        'server_port': 1080,
        'version': '5',
      },
      dependencies: const <String>[],
      fingerprint: 'schema-test',
      importedAt: DateTime.utc(2026),
    );
    final Map<String, Object?> config =
        SingBoxNodeProbe.buildConfigurationForTesting(
      node,
      <NodeRecord>[node],
      bindAddress: '127.0.0.1',
    );
    final Directory directory = await Directory.systemTemp.createTemp(
      'node-inspector-core-schema-',
    );
    final File file = File(
      '${directory.path}${Platform.pathSeparator}isolated.json',
    );
    await file.writeAsString(jsonEncode(config), flush: true);
    try {
      final ProcessResult result = await Process.run(
        'assets${Platform.pathSeparator}core${Platform.pathSeparator}sing-box.exe',
        <String>['check', '-c', file.path],
        runInShell: false,
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
