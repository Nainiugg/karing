import '../models/app_settings.dart';
import '../models/node_deep_inspection.dart';
import '../models/node_record.dart';
import '../models/node_test_result.dart';

abstract interface class NodeProbe {
  String get bindingDescription;

  Future<void> prepare(AppSettings settings);

  Future<NodeTestResult> probe(
    NodeRecord node,
    List<NodeRecord> allNodes,
    AppSettings settings,
  );

  Future<NodeDeepInspection> inspect(
    NodeRecord node,
    List<NodeRecord> allNodes,
    AppSettings settings,
  );

  Future<void> cancel();
}

class UnavailableNodeProbe implements NodeProbe {
  const UnavailableNodeProbe();

  @override
  String get bindingDescription => '检测核心未配置';

  @override
  Future<void> prepare(AppSettings settings) async {
    throw UnsupportedError('当前构建没有配置节点检测核心');
  }

  @override
  Future<NodeTestResult> probe(
    NodeRecord node,
    List<NodeRecord> allNodes,
    AppSettings settings,
  ) async {
    return NodeTestResult(
      checkedAt: DateTime.now().toUtc(),
      error: '当前构建没有配置节点检测核心',
    );
  }

  @override
  Future<NodeDeepInspection> inspect(
    NodeRecord node,
    List<NodeRecord> allNodes,
    AppSettings settings,
  ) async {
    return NodeDeepInspection(
      checkedAt: DateTime.now().toUtc(),
      ipv4Error: '当前构建没有配置节点检测核心',
      ipv6Error: '当前构建没有配置节点检测核心',
    );
  }

  @override
  Future<void> cancel() async {}
}
