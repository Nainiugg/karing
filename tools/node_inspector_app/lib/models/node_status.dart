enum NodeStatus {
  imported,
  queued,
  checking,
  usable,
  failed,
  skipped;

  static NodeStatus fromJson(Object? value) {
    return NodeStatus.values.firstWhere(
      (NodeStatus status) => status.name == value,
      orElse: () => NodeStatus.imported,
    );
  }

  String get label => switch (this) {
    NodeStatus.imported => '已导入',
    NodeStatus.queued => '待检测',
    NodeStatus.checking => '检测中',
    NodeStatus.usable => '可用',
    NodeStatus.failed => '失败',
    NodeStatus.skipped => '已跳过',
  };
}
