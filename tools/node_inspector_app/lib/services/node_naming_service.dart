import '../models/node_record.dart';
import '../models/node_status.dart';

class NodeNamingService {
  const NodeNamingService();

  List<NodeRecord> assign(List<NodeRecord> nodes) {
    final Map<String, int> counts = <String, int>{};
    return nodes.map((NodeRecord node) {
      if (node.status != NodeStatus.usable ||
          node.result == null ||
          !node.result!.isUsable) {
        return node.copyWith(clearExportedName: true);
      }
      final String country = _clean(node.result!.country).ifEmpty(
        _clean(node.result!.countryCode).ifEmpty('未知'),
      );
      final String ip = _clean(node.result!.exitIp).ifEmpty('未知IP');
      final String base = '$country-$ip';
      final int number = (counts[base] ?? 0) + 1;
      counts[base] = number;
      return node.copyWith(
        exportedName: number == 1 ? base : '$base-$number',
      );
    }).toList(growable: false);
  }

  static String _clean(String? value) {
    return (value ?? '')
        .replaceAll(RegExp(r'[\u0000-\u001f\\/]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
