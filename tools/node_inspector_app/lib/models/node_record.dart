import 'node_status.dart';
import 'node_test_result.dart';

class NodeRecord {
  NodeRecord({
    required this.id,
    required this.sourceId,
    required this.originalName,
    required this.protocol,
    required Map<String, Object?> normalizedConfig,
    required List<String> dependencies,
    required this.fingerprint,
    required this.importedAt,
    this.status = NodeStatus.imported,
    this.result,
    this.exportedName,
    this.error,
  })  : normalizedConfig = Map<String, Object?>.unmodifiable(normalizedConfig),
        dependencies = List<String>.unmodifiable(dependencies);

  final String id;
  final String sourceId;
  final String originalName;
  final String protocol;
  final Map<String, Object?> normalizedConfig;
  final List<String> dependencies;
  final String fingerprint;
  final DateTime importedAt;
  final NodeStatus status;
  final NodeTestResult? result;
  final String? exportedName;
  final String? error;

  factory NodeRecord.fromJson(Map<String, Object?> json) {
    final Object? rawConfig = json['normalizedConfig'];
    final Object? rawDependencies = json['dependencies'];
    final Object? rawResult = json['result'];

    return NodeRecord(
      id: json['id'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      originalName: json['originalName'] as String? ?? '未命名节点',
      protocol: json['protocol'] as String? ?? 'unknown',
      normalizedConfig: rawConfig is Map<String, Object?>
          ? rawConfig
          : <String, Object?>{},
      dependencies: rawDependencies is List<Object?>
          ? rawDependencies.whereType<String>().toList(growable: false)
          : const <String>[],
      fingerprint: json['fingerprint'] as String? ?? '',
      importedAt: DateTime.tryParse(json['importedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      status: NodeStatus.fromJson(json['status']),
      result: rawResult is Map<String, Object?>
          ? NodeTestResult.fromJson(rawResult)
          : null,
      exportedName: json['exportedName'] as String?,
      error: json['error'] as String?,
    );
  }

  NodeRecord copyWith({
    NodeStatus? status,
    NodeTestResult? result,
    String? exportedName,
    String? error,
  }) {
    return NodeRecord(
      id: id,
      sourceId: sourceId,
      originalName: originalName,
      protocol: protocol,
      normalizedConfig: normalizedConfig,
      dependencies: dependencies,
      fingerprint: fingerprint,
      importedAt: importedAt,
      status: status ?? this.status,
      result: result ?? this.result,
      exportedName: exportedName ?? this.exportedName,
      error: error ?? this.error,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'sourceId': sourceId,
      'originalName': originalName,
      'protocol': protocol,
      'normalizedConfig': normalizedConfig,
      'dependencies': dependencies,
      'fingerprint': fingerprint,
      'importedAt': importedAt.toUtc().toIso8601String(),
      'status': status.name,
      'result': result?.toJson(),
      'exportedName': exportedName,
      'error': error,
    };
  }
}
