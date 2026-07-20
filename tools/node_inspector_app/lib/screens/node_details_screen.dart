import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/app_controller.dart';
import '../models/ip_profile.dart';
import '../models/node_deep_inspection.dart';
import '../models/node_record.dart';
import '../widgets/app_background.dart';

class NodeDetailsScreen extends StatefulWidget {
  const NodeDetailsScreen({
    required this.controller,
    required this.nodeId,
    super.key,
  });

  final AppController controller;
  final String nodeId;

  @override
  State<NodeDetailsScreen> createState() => _NodeDetailsScreenState();
}

class _NodeDetailsScreenState extends State<NodeDetailsScreen> {
  Future<void> _inspect() async {
    try {
      final NodeDeepInspection inspection = await widget.controller.inspectNode(
        widget.nodeId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('深度检测完成：${inspection.addressMode}')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _exportReport(NodeRecord node) async {
    try {
      const XTypeGroup jsonType = XTypeGroup(
        label: 'Node Inspector JSON 报告',
        extensions: <String>['json'],
      );
      final String safeName = (node.exportedName ?? node.originalName)
          .replaceAll(RegExp(r'[^A-Za-z0-9._\-\u4e00-\u9fff]'), '_');
      final FileSaveLocation? location = await getSaveLocation(
        suggestedName: 'node-report-$safeName.json',
        acceptedTypeGroups: const <XTypeGroup>[jsonType],
      );
      if (location == null) return;
      await File(location.path).writeAsString(
        widget.controller.buildInspectionReport(node.id),
        flush: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('报告已保存到 ${location.path}')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final NodeRecord? node = widget.controller.nodeById(widget.nodeId);
        final bool inspecting = widget.controller.isInspectingNode(
          widget.nodeId,
        );
        return AppBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('节点详细检测'),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
            body: node == null
                ? const Center(child: Text('节点已经不存在'))
                : _DetailsBody(
                    node: node,
                    inspecting: inspecting,
                    onInspect: _inspect,
                    onExport: () => _exportReport(node),
                  ),
          ),
        );
      },
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.node,
    required this.inspecting,
    required this.onInspect,
    required this.onExport,
  });

  final NodeRecord node;
  final bool inspecting;
  final VoidCallback onInspect;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final NodeDeepInspection? inspection = node.inspection;
    final Set<String> ipv4Values = node.inspectionHistory
        .map((NodeInspectionHistoryEntry entry) => entry.ipv4)
        .whereType<String>()
        .toSet();
    final Set<String> ipv6Values = node.inspectionHistory
        .map((NodeInspectionHistoryEntry entry) => entry.ipv6)
        .whereType<String>()
        .toSet();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 650,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          node.exportedName ?? node.originalName,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${node.protocol.toUpperCase()} · ${node.status.label} · 原名称：${node.originalName}',
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: inspecting ? null : onInspect,
                    icon: inspecting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.travel_explore_rounded),
                    label: Text(inspecting ? '检测中' : '深度检测'),
                  ),
                  OutlinedButton.icon(
                    onPressed: inspection == null ? null : onExport,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('导出安全报告'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 28,
                    runSpacing: 12,
                    children: <Widget>[
                      _SummaryItem(
                        label: '地址能力',
                        value: inspection?.addressMode ?? '尚未深度检测',
                      ),
                      _SummaryItem(label: '节点服务器', value: _serverLabel(node)),
                      _SummaryItem(
                        label: '可用性出口',
                        value: node.result?.exitIp ?? '—',
                      ),
                      _SummaryItem(
                        label: '请求延迟',
                        value: node.result?.latencyMs == null
                            ? '—'
                            : '${node.result!.latencyMs} ms',
                      ),
                      _SummaryItem(
                        label: '最近检测',
                        value: inspection == null
                            ? '—'
                            : _formatDate(inspection.checkedAt),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool sideBySide = constraints.maxWidth >= 820;
                  final double width = sideBySide
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: <Widget>[
                      SizedBox(
                        width: width,
                        child: _IpCard(
                          title: 'IPv4 出口',
                          profile: inspection?.ipv4,
                          error: inspection?.ipv4Error,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _IpCard(
                          title: 'IPv6 出口',
                          profile: inspection?.ipv6,
                          error: inspection?.ipv6Error,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '出口稳定性与轮换记录',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'IPv4 已观察 ${ipv4Values.length} 个地址 · IPv6 已观察 ${ipv6Values.length} 个地址',
                      ),
                      if (ipv4Values.length > 1 ||
                          ipv6Values.length > 1) ...<Widget>[
                        const SizedBox(height: 8),
                        const Text(
                          '检测到出口地址轮换。节点名称只代表命名时的出口，后续连接可能出现不同地址。',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (node.inspectionHistory.isEmpty)
                        const Text('暂无历史。每次深度检测最多保留最近 20 条。')
                      else
                        ...node.inspectionHistory
                            .take(8)
                            .map(
                              (NodeInspectionHistoryEntry entry) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: const Icon(Icons.history_rounded),
                                title: Text(
                                  'IPv4 ${entry.ipv4 ?? '—'} · IPv6 ${entry.ipv6 ?? '—'}',
                                ),
                                subtitle: Text(_formatDate(entry.checkedAt)),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              if (inspection?.warnings.isNotEmpty == true) ...<Widget>[
                const SizedBox(height: 16),
                Card(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '数据源提示',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...inspection!.warnings.map(
                          (String warning) => Text('• $warning'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                '“参考纯净度”由可见的 VPN、代理、Tor、托管和滥用信号按固定规则计算；数据不足时不会默认给满分，也不代表任何网站一定接受该 IP。',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IpCard extends StatelessWidget {
  const _IpCard({required this.title, this.profile, this.error});

  final String title;
  final IpProfile? profile;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final IpProfile? value = profile;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: value == null
            ? SizedBox(
                height: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    const Icon(Icons.public_off_rounded, size: 38),
                    const SizedBox(height: 8),
                    Text(error ?? '尚未检测'),
                    const Spacer(),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: '复制地址',
                        onPressed: () async {
                          final ScaffoldMessengerState messenger =
                              ScaffoldMessenger.of(context);
                          await Clipboard.setData(
                            ClipboardData(text: value.ip),
                          );
                          messenger.showSnackBar(
                            const SnackBar(content: Text('IP 地址已复制')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                  SelectableText(
                    value.ip,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PurityIndicator(profile: value),
                  const SizedBox(height: 14),
                  _InfoLine(label: '位置', value: value.locationLabel),
                  _InfoLine(
                    label: 'ASN / 机构',
                    value: <String?>[
                      value.asn,
                      value.organization,
                    ].whereType<String>().join(' · ').ifEmpty('—'),
                  ),
                  _InfoLine(label: 'ISP', value: value.isp ?? '—'),
                  _InfoLine(label: '网络类型', value: value.networkType ?? '—'),
                  _InfoLine(label: 'CIDR', value: value.cidr ?? '—'),
                  _InfoLine(label: '反向域名', value: value.hostname ?? '—'),
                  _InfoLine(label: '时区', value: value.timezone ?? '—'),
                  _InfoLine(
                    label: '出口请求',
                    value: value.latencyMs == null
                        ? '—'
                        : '${value.latencyMs} ms',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: <Widget>[
                      _SignalChip(label: 'VPN', value: value.isVpn),
                      _SignalChip(label: '代理', value: value.isProxy),
                      _SignalChip(label: 'Tor', value: value.isTor),
                      _SignalChip(label: '中继', value: value.isRelay),
                      _SignalChip(label: '托管', value: value.isHosting),
                      _SignalChip(label: 'Anycast', value: value.isAnycast),
                      _SignalChip(label: '移动网络', value: value.isMobile),
                      _SignalChip(
                        label: '住宅代理',
                        value: value.isResidentialProxy,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    value.sources.isEmpty
                        ? '数据源：仅出口检测'
                        : '数据源：${value.sources.join('、')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}

class _PurityIndicator extends StatelessWidget {
  const _PurityIndicator({required this.profile});

  final IpProfile profile;

  @override
  Widget build(BuildContext context) {
    final int? purity = profile.purityScore;
    final Color color = profile.riskScore == null
        ? Colors.blueGrey
        : profile.riskScore! >= 80
        ? Colors.red
        : profile.riskScore! >= 45
        ? Colors.orange
        : Colors.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          purity == null
              ? '参考纯净度：数据不足'
              : '参考纯净度：$purity / 100 · ${profile.riskLabel}',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: purity == null ? 0 : purity / 100,
          color: color,
          backgroundColor: color.withValues(alpha: 0.16),
        ),
        if (profile.abuseConfidenceScore != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'AbuseIPDB 滥用置信分：${profile.abuseConfidenceScore} · 报告 ${profile.totalReports ?? 0} 条',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.label, required this.value});

  final String label;
  final bool? value;

  @override
  Widget build(BuildContext context) {
    final Color color = value == null
        ? Colors.blueGrey
        : value!
        ? Colors.orange.shade800
        : Colors.green.shade700;
    return Chip(
      avatar: Icon(
        value == null
            ? Icons.help_outline_rounded
            : value!
            ? Icons.warning_amber_rounded
            : Icons.check_rounded,
        size: 17,
        color: color,
      ),
      label: Text(
        '$label ${value == null
            ? '未知'
            : value!
            ? '是'
            : '否'}',
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 86, child: Text(label)),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final DateTime local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

String _serverLabel(NodeRecord node) {
  final String server =
      node.normalizedConfig['server']?.toString().trim() ?? '';
  final String port = node.normalizedConfig['server_port']?.toString() ?? '';
  if (server.isEmpty) return '未提供';
  return port.isEmpty ? server : '$server:$port';
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
