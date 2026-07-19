import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../widgets/metric_card.dart';
import '../widgets/page_header.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
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
                description: '每个节点将在独立核心中切换和探测，不修改 Karing 当前连接。',
                trailing: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('检测核心将在第三阶段接入'),
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
                      Text(
                        '隔离检测队列',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      const LinearProgressIndicator(value: 0),
                      const SizedBox(height: 14),
                      const Text(
                        '等待节点导入。后续检测流程会先校验配置，再以受限并发逐个启动、查询真实出口、停止并清理实例。',
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
                          '“可用”只表示测试时能够连接并取得真实出口信息，不代表节点长期稳定、住宅属性或信誉质量。',
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
