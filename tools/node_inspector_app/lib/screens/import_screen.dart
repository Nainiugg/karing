import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/import_report.dart';
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

  Future<void> _importSubscription() async {
    final String value = _subscriptionController.text.trim();
    if (value.isEmpty) {
      _showError('请先输入订阅地址');
      return;
    }
    await _runImport(() => widget.controller.importSubscription(value));
  }

  Future<void> _importContent() async {
    final String value = _contentController.text.trim();
    if (value.isEmpty) {
      _showError('请先粘贴节点、Base64、JSON 或 YAML 内容');
      return;
    }
    await _runImport(() => widget.controller.importText(value));
  }

  Future<void> _selectFile() async {
    const XTypeGroup formats = XTypeGroup(
      label: '代理配置',
      extensions: <String>['json', 'yaml', 'yml', 'txt', 'conf'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[formats],
    );
    if (file == null || !mounted) return;
    await _runImport(() => widget.controller.importFile(file.path));
  }

  Future<void> _runImport(Future<ImportReport> Function() action) async {
    try {
      final ImportReport report = await action();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('导入完成'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('识别格式：${report.format}'),
                Text('新增节点：${report.imported}'),
                Text('重复跳过：${report.duplicates}'),
                Text('无法导入：${report.issues.length}'),
                if (report.issues.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  const Text('前几项原因：'),
                  const SizedBox(height: 4),
                  ...report.issues.take(5).map(
                        (ImportIssue issue) => Text(
                          '• ${issue.item.isEmpty ? '' : '${issue.item}：'}${issue.message}',
                        ),
                      ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('继续导入'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.controller.selectPage(1);
              },
              child: const Text('前往检测'),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.controller.busy || widget.controller.scanning;
    final ImportReport? report = widget.controller.lastImportReport;
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
                title: '导入节点',
                description: '支持订阅 URL、Clash YAML、sing-box JSON、Base64 和常见分享链接。',
                trailing: Chip(
                  avatar: const Icon(Icons.hub_outlined, size: 18),
                  label: Text('当前 ${widget.controller.nodes.length} 个节点'),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('订阅地址', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _subscriptionController,
                        enabled: !disabled,
                        decoration: const InputDecoration(
                          hintText: 'https://example.com/subscription',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                        onSubmitted: disabled ? null : (String _) => _importSubscription(),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: disabled ? null : _importSubscription,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('读取并导入订阅'),
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
                        enabled: !disabled,
                        minLines: 7,
                        maxLines: 14,
                        decoration: const InputDecoration(
                          alignLabelWithHint: true,
                          hintText: '每行一个分享链接，或粘贴完整 Base64、JSON、YAML 内容。',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: disabled ? null : _selectFile,
                            icon: const Icon(Icons.file_open_outlined),
                            label: const Text('选择文件'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: disabled ? null : _importContent,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('解析并导入'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (report != null) ...<Widget>[
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.summarize_outlined),
                    title: Text('最近导入：${report.format}'),
                    subtitle: Text(
                      '新增 ${report.imported} · 重复 ${report.duplicates} · 无法导入 ${report.issues.length}',
                    ),
                  ),
                ),
              ],
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
                          '订阅地址、节点密钥和导出配置不写入日志。订阅只在导入时下载；检测时只有出口查询服务会看到节点出口请求。',
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
