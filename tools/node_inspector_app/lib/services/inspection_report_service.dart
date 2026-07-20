import 'dart:convert';

import '../models/node_record.dart';

class InspectionReportService {
  const InspectionReportService();

  String buildJson(NodeRecord node) {
    if (node.inspection == null) {
      throw StateError('该节点尚未完成深度检测');
    }
    final Map<String, Object?> report = <String, Object?>{
      'schema': 'node-inspector-report-v1',
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'node': <String, Object?>{
        'originalName': node.originalName,
        'exportedName': node.exportedName,
        'protocol': node.protocol,
        'status': node.status.name,
        'lastAvailabilityCheck': node.result?.toJson(),
      },
      'inspection': node.inspection?.toJson(),
      'history': node.inspectionHistory
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'notice': '风险与纯净度是第三方情报和透明规则的参考结果，不代表任何网站一定接受该出口。报告不包含节点服务器、端口、密钥或传输凭据。',
    };
    return '${const JsonEncoder.withIndent('  ').convert(report)}\n';
  }
}
