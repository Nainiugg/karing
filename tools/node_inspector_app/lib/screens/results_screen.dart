import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/node_record.dart';
import '../widgets/page_header.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
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
                description: '查看真实出口、国家和延迟；只有可用节点会进入最终导出。',
                trailing: Wrap(
                  spacing: 10,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: controller.nodes.isEmpty
                          ? null
                          : () => controller.clearNodes(),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('清空'),
                    ),
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('导出 Karing 配置（第四阶段）'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: controller.nodes.isEmpty
                      ? const _EmptyResults()
                      : _ResultsTable(nodes: controller.nodes),
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
            Text('还没有节点结果'),
            SizedBox(height: 6),
            Text('完成导入和检测后，节点会显示在这里。'),
          ],
        ),
      ),
    );
  }
}

class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.nodes});

  final List<NodeRecord> nodes;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const <DataColumn>[
              DataColumn(label: Text('状态')),
              DataColumn(label: Text('原名称')),
              DataColumn(label: Text('导出名称')),
              DataColumn(label: Text('协议')),
              DataColumn(label: Text('出口 IP')),
              DataColumn(label: Text('国家')),
              DataColumn(label: Text('ASN / 运营商')),
              DataColumn(label: Text('延迟')),
            ],
            rows: nodes
                .map(
                  (NodeRecord node) => DataRow(
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
