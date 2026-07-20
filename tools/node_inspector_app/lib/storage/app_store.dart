import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';
import '../models/node_record.dart';

class AppSnapshot {
  const AppSnapshot({
    this.nodes = const <NodeRecord>[],
    this.settings = const AppSettings(),
  });

  final List<NodeRecord> nodes;
  final AppSettings settings;

  factory AppSnapshot.fromJson(Map<String, Object?> json) {
    final Object? rawNodes = json['nodes'];
    final Object? rawSettings = json['settings'];
    return AppSnapshot(
      nodes: rawNodes is List<Object?>
          ? rawNodes
                .whereType<Map<String, Object?>>()
                .map(NodeRecord.fromJson)
                .toList(growable: false)
          : const <NodeRecord>[],
      settings: rawSettings is Map<String, Object?>
          ? AppSettings.fromJson(rawSettings)
          : const AppSettings(),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': 2,
      'nodes': nodes.map((NodeRecord node) => node.toJson()).toList(),
      'settings': settings.toJson(),
    };
  }
}

abstract interface class AppStore {
  Future<AppSnapshot> load();

  Future<void> save(AppSnapshot snapshot);
}

class LocalJsonAppStore implements AppStore {
  LocalJsonAppStore(this.file);

  final File file;

  static File defaultFile() {
    final Map<String, String> environment = Platform.environment;
    final String root =
        environment['APPDATA'] ?? environment['HOME'] ?? Directory.current.path;
    final String separator = Platform.pathSeparator;
    return File('$root${separator}NodeInspector${separator}data.json');
  }

  @override
  Future<AppSnapshot> load() async {
    File source = file;
    final File backup = File('${file.path}.bak');
    if (!await source.exists() && await backup.exists()) {
      source = backup;
    }
    if (!await source.exists()) {
      return const AppSnapshot();
    }

    final String contents = await source.readAsString();
    final Object? decoded = jsonDecode(contents);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('本地数据文件的顶层内容不是 JSON 对象');
    }
    return AppSnapshot.fromJson(decoded);
  }

  @override
  Future<void> save(AppSnapshot snapshot) async {
    await file.parent.create(recursive: true);
    final File temporary = File('${file.path}.tmp');
    final File backup = File('${file.path}.bak');
    final String contents = const JsonEncoder.withIndent(
      '  ',
    ).convert(snapshot.toJson());

    await temporary.writeAsString('$contents\n', flush: true);
    if (await backup.exists()) {
      await backup.delete();
    }
    if (await file.exists()) {
      await file.rename(backup.path);
    }

    try {
      await temporary.rename(file.path);
      if (await backup.exists()) {
        await backup.delete();
      }
    } on Object {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }
}

class MemoryAppStore implements AppStore {
  MemoryAppStore([this.snapshot = const AppSnapshot()]);

  AppSnapshot snapshot;

  @override
  Future<AppSnapshot> load() async => snapshot;

  @override
  Future<void> save(AppSnapshot value) async {
    snapshot = value;
  }
}
