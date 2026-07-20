import 'node_deep_inspection.dart';
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
    this.inspection,
    List<NodeInspectionHistoryEntry> inspectionHistory =
        const <NodeInspectionHistoryEntry>[],
  }) : normalizedConfig = Map<String, Object?>.unmodifiable(normalizedConfig),
       dependencies = List<String>.unmodifiable(dependencies),
       inspectionHistory = List<NodeInspectionHistoryEntry>.unmodifiable(
         inspectionHistory,
       );

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
  final NodeDeepInspection? inspection;
  final List<NodeInspectionHistoryEntry> inspectionHistory;

  factory NodeRecord.fromJson(Map<String, Object?> json) {
    final Object? rawConfig = json['normalizedConfig'];
    final Object? rawDependencies = json['dependencies'];
    final Object? rawResult = json['result'];
    final Object? rawInspection = json['inspection'];
    final Object? rawHistory = json['inspectionHistory'];

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
      importedAt:
          DateTime.tryParse(json['importedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      status: NodeStatus.fromJson(json['status']),
      result: rawResult is Map<String, Object?>
          ? NodeTestResult.fromJson(rawResult)
          : null,
      exportedName: json['exportedName'] as String?,
      error: json['error'] as String?,
      inspection: rawInspection is Map<String, Object?>
          ? NodeDeepInspection.fromJson(rawInspection)
          : null,
      inspectionHistory: rawHistory is List<Object?>
          ? rawHistory
                .whereType<Map<String, Object?>>()
                .map(NodeInspectionHistoryEntry.fromJson)
                .toList(growable: false)
          : const <NodeInspectionHistoryEntry>[],
    );
  }

  NodeRecord copyWith({
    String? fingerprint,
    NodeStatus? status,
    NodeTestResult? result,
    String? exportedName,
    String? error,
    NodeDeepInspection? inspection,
    List<NodeInspectionHistoryEntry>? inspectionHistory,
    bool clearResult = false,
    bool clearExportedName = false,
    bool clearError = false,
    bool clearInspection = false,
  }) {
    return NodeRecord(
      id: id,
      sourceId: sourceId,
      originalName: originalName,
      protocol: protocol,
      normalizedConfig: normalizedConfig,
      dependencies: dependencies,
      fingerprint: fingerprint ?? this.fingerprint,
      importedAt: importedAt,
      status: status ?? this.status,
      result: clearResult ? null : result ?? this.result,
      exportedName: clearExportedName
          ? null
          : exportedName ?? this.exportedName,
      error: clearError ? null : error ?? this.error,
      inspection: clearInspection ? null : inspection ?? this.inspection,
      inspectionHistory: inspectionHistory ?? this.inspectionHistory,
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
      'inspection': inspection?.toJson(),
      'inspectionHistory': inspectionHistory
          .map((NodeInspectionHistoryEntry entry) => entry.toJson())
          .toList(growable: false),
    };
  }
}
