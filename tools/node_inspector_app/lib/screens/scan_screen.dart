import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../widgets/metric_card.dart';
import '../widgets/page_header.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  Future<void> _start() async {
    try {
      await widget.controller.scanAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '检测完成：可用 ${widget.controller.counters.usable}，失败 ${widget.controller.counters.failed}',
          ),
        ),
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

  Future<void> _stop() async {
    await widget.controller.cancelScan();
  }

  @override
  Widget build(BuildContext context) {
    final AppController controller = widget.controller;
    final NodeCounters counters = controller.counters;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PageHeader(
                title: '检测节点',
                description: '每个节点在独立 sing-box 进程中探测，不切换 Karing 当前节点。',
                trailing: controller.scanning
                    ? FilledButton.icon(
                        onPressed: _stop,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('停止检测'),
                      )
                    : FilledButton.icon(
                        onPressed: controller.nodes.isEmpty || controller.busy
                            ? null
                            : _start,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('检测全部节点'),
                      ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final int columns = constraints.maxWidth >= 850 ? 4 : 2;
                  final double width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      SizedBox(
                        width: width,
                        child: MetricCard(
                          label: '节点',
                          value: counters.total,
                          icon: Icons.hub_outlined,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: MetricCard(
                          label: '已检测',
                          value: counters.checked,
                          icon: Icons.radar_rounded,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: MetricCard(
                          label: '可用',
                          value: counters.usable,
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: MetricCard(
                          label: '失败',
                          value: counters.failed,
                          icon: Icons.error_outline_rounded,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              controller.scanning ? '正在隔离检测' : '隔离检测队列',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Text(
                            '${controller.scanCompleted} / ${controller.scanTotal}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: controller.scanning || controller.scanTotal > 0
                            ? controller.scanProgress
                            : 0,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        controller.scanning
                            ? '当前：${controller.currentNode}'
                            : controller.nodes.isEmpty
                            ? '等待节点导入。'
                            : '准备检测 ${controller.nodes.length} 个节点。',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.bindingDescription,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.info_outline_rounded),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '程序会校验配置、分配独立本机端口、查询真实出口后立即停止进程。“可用”只表示本次测试成功，不代表长期稳定或住宅属性。',
                        ),
                      ),
                    ],
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
