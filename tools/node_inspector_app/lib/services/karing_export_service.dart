import 'dart:convert';

import '../models/node_record.dart';
import '../models/node_status.dart';

class KaringExportException implements Exception {
  const KaringExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class KaringExportService {
  const KaringExportService();

  String buildJson(List<NodeRecord> nodes) {
    final List<NodeRecord> usable = nodes
        .where(
          (NodeRecord node) =>
              node.status == NodeStatus.usable &&
              node.result?.isUsable == true &&
              (node.exportedName ?? '').isNotEmpty,
        )
        .toList(growable: false);
    if (usable.isEmpty) {
      throw const KaringExportException('没有检测成功的可用节点');
    }

    final Map<String, NodeRecord> sourceTags = <String, NodeRecord>{
      for (final NodeRecord node in nodes) _sourceKey(node, node.originalName): node,
    };
    final Map<String, String> exportTags = <String, String>{
      for (final NodeRecord node in usable) node.id: node.exportedName!,
    };
    final Set<String> includedIds = usable.map((NodeRecord node) => node.id).toSet();

    void includeDependencies(NodeRecord owner) {
      for (final String dependency in owner.dependencies) {
        final NodeRecord? match = sourceTags[_sourceKey(owner, dependency)] ??
            _firstByName(nodes, dependency);
        if (match == null) {
          throw KaringExportException(
            '${owner.exportedName ?? owner.originalName} 缺少依赖节点 $dependency',
          );
        }
        exportTags.putIfAbsent(
          match.id,
          () => _uniqueDependencyTag(match, exportTags.values.toSet()),
        );
        if (includedIds.add(match.id)) includeDependencies(match);
      }
    }

    for (final NodeRecord node in usable) {
      includeDependencies(node);
    }

    final List<Map<String, Object?>> outbounds = <Map<String, Object?>>[];
    for (final NodeRecord node in nodes) {
      if (!includedIds.contains(node.id)) continue;
      final Map<String, Object?> config = _copyMap(node.normalizedConfig);
      config['tag'] = exportTags[node.id]!;
      final String dependency = config['detour']?.toString() ?? '';
      if (dependency.isNotEmpty) {
        final NodeRecord? match = sourceTags[_sourceKey(node, dependency)] ??
            _firstByName(nodes, dependency);
        if (match == null || exportTags[match.id] == null) {
          throw KaringExportException('${node.originalName} 的 detour 依赖无法导出');
        }
        config['detour'] = exportTags[match.id];
      }
      outbounds.add(config);
    }

    final List<String> selectable = usable
        .map((NodeRecord node) => exportTags[node.id]!)
        .toList(growable: false);
    final Map<String, Object?> result = <String, Object?>{
      'log': <String, Object?>{'level': 'warn'},
      'outbounds': <Object?>[
        <String, Object?>{
          'type': 'selector',
          'tag': '节点选择',
          'outbounds': selectable,
          'default': selectable.first,
        },
        <String, Object?>{'type': 'direct', 'tag': 'direct'},
        <String, Object?>{'type': 'block', 'tag': 'block'},
        ...outbounds,
      ],
      'route': <String, Object?>{
        'auto_detect_interface': true,
        'final': '节点选择',
      },
    };
    return '${const JsonEncoder.withIndent('  ').convert(result)}\n';
  }

  static String _sourceKey(NodeRecord node, String name) {
    return '${node.sourceId}\u0000$name';
  }

  static NodeRecord? _firstByName(List<NodeRecord> nodes, String name) {
    for (final NodeRecord node in nodes) {
      if (node.originalName == name) return node;
    }
    return null;
  }

  static String _uniqueDependencyTag(
    NodeRecord node,
    Set<String> existing,
  ) {
    final String base = '依赖-${node.originalName}'
        .replaceAll(RegExp(r'[\u0000-\u001f]+'), '-')
        .trim();
    String candidate = base;
    int suffix = 2;
    while (existing.contains(candidate)) {
      candidate = '$base-$suffix';
      suffix += 1;
    }
    return candidate;
  }

  static Map<String, Object?> _copyMap(Map<String, Object?> value) {
    return jsonDecode(jsonEncode(value)) as Map<String, Object?>;
  }
}
