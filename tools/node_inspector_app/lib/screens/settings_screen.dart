import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../storage/app_store.dart';
import '../widgets/page_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _concurrency;
  late int _timeoutSeconds;

  @override
  void initState() {
    super.initState();
    _concurrency = widget.controller.settings.concurrency;
    _timeoutSeconds = widget.controller.settings.timeoutSeconds;
  }

  Future<void> _save() async {
    await widget.controller.updateSettings(
      widget.controller.settings.copyWith(
        concurrency: _concurrency,
        timeoutSeconds: _timeoutSeconds,
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存在本机')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PageHeader(
                title: '设置',
                description: '控制检测资源占用和超时；敏感节点数据始终留在本机。',
                trailing: FilledButton.icon(
                  onPressed: widget.controller.busy ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存设置'),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '检测参数',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<int>(
                        initialValue: _concurrency,
                        decoration: const InputDecoration(
                          labelText: '并发检测数量',
                          helperText: '建议从 4 开始；并发过高可能触发节点或本机端口限制。',
                        ),
                        items: const <int>[1, 2, 4, 6, 8, 12, 16]
                            .map(
                              (int value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text('$value'),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (int? value) {
                          if (value != null) {
                            setState(() => _concurrency = value);
                          }
                        },
                      ),
                      const SizedBox(height: 22),
                      Text('单节点超时：$_timeoutSeconds 秒'),
                      Slider(
                        value: _timeoutSeconds.toDouble(),
                        min: 3,
                        max: 60,
                        divisions: 57,
                        label: '$_timeoutSeconds 秒',
                        onChanged: (double value) {
                          setState(() => _timeoutSeconds = value.round());
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '数据位置',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(LocalJsonAppStore.defaultFile().path),
                      const SizedBox(height: 10),
                      const Text(
                        '该文件可能包含节点连接凭据。不要上传、截图或发送给他人；导出文件也应按敏感资料处理。',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '关于 Node Inspector',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 10),
                      Text('版本 0.1.0 · 第一阶段应用骨架'),
                      SizedBox(height: 4),
                      Text(
                        '这是基于 GPLv3 代码生态开发的独立工具，不使用 Karing 名称作为应用品牌，也不暗示官方关联。',
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
