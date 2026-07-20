import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/node_record.dart';
import '../models/node_status.dart';
import '../widgets/page_header.dart';
import 'node_details_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  String _query = '';
  NodeStatus? _status;

  Future<void> _export() async {
    try {
      final String contents = widget.controller.buildKaringExport();
      const XTypeGroup jsonType = XTypeGroup(
        label: 'sing-box JSON',
        extensions: <String>['json'],
      );
      final String date = DateTime.now().toIso8601String().substring(0, 10);
      final FileSaveLocation? location = await getSaveLocation(
        suggestedName: 'karing-usable-nodes-$date.json',
        acceptedTypeGroups: const <XTypeGroup>[jsonType],
      );
      if (location == null) return;
      await File(location.path).writeAsString(contents, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Karing 配置已导出到 ${location.path}')));
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

  Future<void> _clear() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('清空全部节点？'),
        content: const Text('这会删除本机保存的导入内容和检测结果，无法撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.clearNodes();
  }

  void _openDetails(NodeRecord node) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              NodeDetailsScreen(controller: widget.controller, nodeId: node.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String query = _query.toLowerCase();
    final List<NodeRecord> filtered = widget.controller.nodes
        .where((NodeRecord node) {
          if (_status != null && node.status != _status) return false;
          if (query.isEmpty) return true;
          return <String?>[
            node.originalName,
            node.exportedName,
            node.protocol,
            node.result?.exitIp,
            node.result?.country,
            node.result?.organization,
            node.inspection?.ipv4?.ip,
            node.inspection?.ipv6?.ip,
            node.inspection?.ipv4?.organization,
            node.inspection?.ipv6?.organization,
            node.inspection?.ipv4?.isp,
            node.inspection?.ipv6?.isp,
          ].whereType<String>().any(
            (String value) => value.toLowerCase().contains(query),
          );
        })
        .toList(growable: false);
    final List<NodeRecord> visible = filtered.take(200).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PageHeader(
                title: '检测结果',
                description:
                    '可用节点已按“国家-真实出口IP”命名；点击可用节点可继续检测 IPv4/IPv6 和参考纯净度。',
                trailing: Wrap(
                  spacing: 10,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed:
                          widget.controller.nodes.isEmpty ||
                              widget.controller.scanning
                          ? null
                          : _clear,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('清空'),
                    ),
                    FilledButton.icon(
                      onPressed: widget.controller.counters.usable == 0
                          ? null
                          : _export,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('导出 Karing 配置'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '搜索名称、协议、国家、IP、运营商',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (String value) =>
                          setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<NodeStatus?>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: '状态'),
                      items: <DropdownMenuItem<NodeStatus?>>[
                        const DropdownMenuItem<NodeStatus?>(child: Text('全部')),
                        ...NodeStatus.values.map(
                          (NodeStatus status) => DropdownMenuItem<NodeStatus?>(
                            value: status,
                            child: Text(status.label),
                          ),
                        ),
                      ],
                      onChanged: (NodeStatus? value) =>
                          setState(() => _status = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                filtered.length > 200
                    ? '符合条件 ${filtered.length} 个，为保持流畅当前显示前 200 个；可继续使用搜索缩小范围。'
                    : '符合条件 ${filtered.length} 个',
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: visible.isEmpty
                      ? const _EmptyResults()
                      : _ResultsTable(
                          nodes: visible,
                          onOpenDetails: _openDetails,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.inbox_outlined, size: 56),
            SizedBox(height: 14),
            Text('没有符合条件的节点'),
            SizedBox(height: 6),
            Text('请先导入并检测，或修改上方筛选条件。'),
          ],
        ),
      ),
    );
  }
}

class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.nodes, required this.onOpenDetails});

  final List<NodeRecord> nodes;
  final ValueChanged<NodeRecord> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            columns: const <DataColumn>[
              DataColumn(label: Text('状态')),
              DataColumn(label: Text('原名称')),
              DataColumn(label: Text('导出名称')),
              DataColumn(label: Text('协议')),
              DataColumn(label: Text('出口 IP')),
              DataColumn(label: Text('国家')),
              DataColumn(label: Text('ASN / 运营商')),
              DataColumn(label: Text('延迟')),
              DataColumn(label: Text('错误')),
              DataColumn(label: Text('详细检测')),
            ],
            rows: nodes
                .map(
                  (NodeRecord node) => DataRow(
                    onSelectChanged: node.status == NodeStatus.usable
                        ? (bool? _) => onOpenDetails(node)
                        : null,
                    cells: <DataCell>[
                      DataCell(Text(node.status.label)),
                      DataCell(Text(node.originalName)),
                      DataCell(Text(node.exportedName ?? '—')),
                      DataCell(Text(node.protocol)),
                      DataCell(Text(node.result?.exitIp ?? '—')),
                      DataCell(Text(node.result?.country ?? '—')),
                      DataCell(
                        Text(
                          <String?>[
                            node.result?.asn,
                            node.result?.organization,
                          ].whereType<String>().join(' · ').ifEmpty('—'),
                        ),
                      ),
                      DataCell(
                        Text(
                          node.result?.latencyMs != null
                              ? '${node.result!.latencyMs} ms'
                              : '—',
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: Text(node.error ?? node.result?.error ?? '—'),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          tooltip: node.status == NodeStatus.usable
                              ? '打开 IPv4/IPv6 与纯净度检测'
                              : '请先通过可用性检测',
                          onPressed: node.status == NodeStatus.usable
                              ? () => onOpenDetails(node)
                              : null,
                          icon: const Icon(Icons.open_in_new_rounded),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
