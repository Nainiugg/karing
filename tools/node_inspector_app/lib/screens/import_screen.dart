import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../widgets/page_header.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final TextEditingController _subscriptionController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void dispose() {
    _subscriptionController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _showPhaseNotice() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('导入解析器尚未接入'),
        content: const Text(
          '第一阶段先固定应用边界、数据结构和安全存储。Clash YAML、sing-box JSON、Base64 '
          '订阅与分享链接解析将在第二阶段接入，这里不会把输入内容上传到网络。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const PageHeader(
                title: '导入节点',
                description: '统一接收订阅地址、配置文本和本地文件，原始凭据只保存在本机。',
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '订阅地址',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _subscriptionController,
                        decoration: const InputDecoration(
                          hintText: 'https://example.com/subscription',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _showPhaseNotice,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('读取订阅'),
                        ),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '粘贴配置或分享链接',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _contentController,
                        minLines: 7,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          alignLabelWithHint: true,
                          hintText: '支持格式将在第二阶段逐项启用并显示解析报告。',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: _showPhaseNotice,
                            icon: const Icon(Icons.file_open_outlined),
                            label: const Text('选择文件'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: _showPhaseNotice,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('解析并导入'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.shield_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '安全原则：订阅地址、节点密钥和导出配置不会写入日志，也不会发送到检测服务。'
                          '只有实际检测时，出口 IP 查询服务会看到该节点的出口请求。',
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
