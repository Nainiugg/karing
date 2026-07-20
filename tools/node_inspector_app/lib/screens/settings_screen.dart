import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../storage/app_secret_store.dart';
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
  late int _intelligenceCacheHours;
  late int _abuseMaxAgeDays;
  late bool _publicIntelligenceEnabled;
  late final TextEditingController _bindAddressController;
  late final TextEditingController _ipv4EndpointController;
  late final TextEditingController _ipv6EndpointController;
  late final TextEditingController _ipInfoTokenController;
  late final TextEditingController _abuseIpDbKeyController;
  bool _clearIpInfoToken = false;
  bool _clearAbuseIpDbKey = false;

  @override
  void initState() {
    super.initState();
    _concurrency = widget.controller.settings.concurrency;
    _timeoutSeconds = widget.controller.settings.timeoutSeconds;
    _intelligenceCacheHours = widget.controller.settings.intelligenceCacheHours;
    _abuseMaxAgeDays = widget.controller.settings.abuseMaxAgeDays;
    _publicIntelligenceEnabled =
        widget.controller.settings.publicIntelligenceEnabled;
    _bindAddressController = TextEditingController(
      text: widget.controller.settings.bindAddress,
    );
    _ipv4EndpointController = TextEditingController(
      text: widget.controller.settings.ipv4Endpoint,
    );
    _ipv6EndpointController = TextEditingController(
      text: widget.controller.settings.ipv6Endpoint,
    );
    _ipInfoTokenController = TextEditingController();
    _abuseIpDbKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _bindAddressController.dispose();
    _ipv4EndpointController.dispose();
    _ipv6EndpointController.dispose();
    _ipInfoTokenController.dispose();
    _abuseIpDbKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String bindAddress = _bindAddressController.text.trim();
    if (bindAddress.isNotEmpty &&
        InternetAddress.tryParse(bindAddress)?.type !=
            InternetAddressType.IPv4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('物理出口地址必须是有效的 IPv4 地址')));
      return;
    }
    final Uri? ipv4Endpoint = Uri.tryParse(_ipv4EndpointController.text.trim());
    final Uri? ipv6Endpoint = Uri.tryParse(_ipv6EndpointController.text.trim());
    if (ipv4Endpoint?.scheme != 'https' || ipv6Endpoint?.scheme != 'https') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IPv4/IPv6 出口检测地址必须是 HTTPS URL')),
      );
      return;
    }
    try {
      await widget.controller.updateSettings(
        widget.controller.settings.copyWith(
          concurrency: _concurrency,
          timeoutSeconds: _timeoutSeconds,
          bindAddress: bindAddress,
          ipv4Endpoint: ipv4Endpoint.toString(),
          ipv6Endpoint: ipv6Endpoint.toString(),
          publicIntelligenceEnabled: _publicIntelligenceEnabled,
          intelligenceCacheHours: _intelligenceCacheHours,
          abuseMaxAgeDays: _abuseMaxAgeDays,
        ),
      );
      await widget.controller.updateApiSecrets(
        ipInfoToken: _ipInfoTokenController.text,
        abuseIpDbKey: _abuseIpDbKeyController.text,
        clearIpInfoToken: _clearIpInfoToken,
        clearAbuseIpDbKey: _clearAbuseIpDbKey,
      );
      if (!mounted) return;
      setState(() {
        _clearIpInfoToken = false;
        _clearAbuseIpDbKey = false;
        _ipInfoTokenController.clear();
        _abuseIpDbKeyController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存在本机')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存设置失败：$error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
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
                      const SizedBox(height: 18),
                      TextField(
                        controller: _bindAddressController,
                        decoration: const InputDecoration(
                          labelText: '物理出口网卡 IPv4（可选）',
                          hintText: '例如 192.168.1.20；留空时自动检测',
                          helperText: '自动识别错误或存在多个网卡时，填写当前 Wi-Fi/以太网的本机 IPv4。',
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _ipv4EndpointController,
                        decoration: const InputDecoration(
                          labelText: 'IPv4-only 出口检测地址',
                          helperText: '必须返回 JSON {"ip":"..."} 或纯文本 IPv4。',
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _ipv6EndpointController,
                        decoration: const InputDecoration(
                          labelText: 'IPv6-only 出口检测地址',
                          helperText: '没有 IPv6 出口时请求失败属于正常结果。',
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
                        'IP 情报与参考纯净度',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用公共基础情报'),
                        subtitle: const Text(
                          '按需向 ipwho.is 查询国家、城市、ASN 和 ISP；不会影响节点可用性结论。',
                        ),
                        value: _publicIntelligenceEnabled,
                        onChanged: (bool value) {
                          setState(() => _publicIntelligenceEnabled = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _intelligenceCacheHours,
                        decoration: const InputDecoration(
                          labelText: 'IP 情报缓存时间',
                          helperText: '出口 IP 仍会实时检测，只复用对应地址的情报字段。',
                        ),
                        items: const <int>[0, 1, 6, 12, 24, 72, 168]
                            .map(
                              (int value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text(value == 0 ? '不缓存' : '$value 小时'),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (int? value) {
                          if (value != null) {
                            setState(() => _intelligenceCacheHours = value);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('AbuseIPDB 报告回溯：$_abuseMaxAgeDays 天'),
                      Slider(
                        value: _abuseMaxAgeDays.toDouble(),
                        min: 7,
                        max: 365,
                        divisions: 358,
                        label: '$_abuseMaxAgeDays 天',
                        onChanged: (double value) {
                          setState(() => _abuseMaxAgeDays = value.round());
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '增强数据源 API 密钥（可选）',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '密钥使用当前 Windows 用户的 DPAPI 加密，单独保存在本机，不进入节点配置、日志或导出报告。留空会保留原值。',
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _ipInfoTokenController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'IPinfo Token',
                          helperText: _clearIpInfoToken
                              ? '保存后删除现有 Token'
                              : widget.controller.hasIpInfoToken
                              ? '已安全保存；输入新值可替换'
                              : '未配置；用于 VPN、代理、Tor、托管等信号',
                          suffixIcon: widget.controller.hasIpInfoToken
                              ? IconButton(
                                  tooltip: '删除已保存 Token',
                                  onPressed: () {
                                    setState(() {
                                      _clearIpInfoToken = !_clearIpInfoToken;
                                      _ipInfoTokenController.clear();
                                    });
                                  },
                                  icon: Icon(
                                    _clearIpInfoToken
                                        ? Icons.undo_rounded
                                        : Icons.delete_outline_rounded,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _abuseIpDbKeyController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'AbuseIPDB API Key',
                          helperText: _clearAbuseIpDbKey
                              ? '保存后删除现有 Key'
                              : widget.controller.hasAbuseIpDbKey
                              ? '已安全保存；输入新值可替换'
                              : '未配置；用于滥用置信分和报告数量',
                          suffixIcon: widget.controller.hasAbuseIpDbKey
                              ? IconButton(
                                  tooltip: '删除已保存 Key',
                                  onPressed: () {
                                    setState(() {
                                      _clearAbuseIpDbKey = !_clearAbuseIpDbKey;
                                      _abuseIpDbKeyController.clear();
                                    });
                                  },
                                  icon: Icon(
                                    _clearAbuseIpDbKey
                                        ? Icons.undo_rounded
                                        : Icons.delete_outline_rounded,
                                  ),
                                )
                              : null,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '数据位置',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(LocalJsonAppStore.defaultFile().path),
                      const SizedBox(height: 8),
                      const Text('加密 API 密钥：'),
                      SelectableText(
                        WindowsDpapiSecretStore.defaultFile().path,
                      ),
                      const SizedBox(height: 10),
                      const Text('该文件可能包含节点连接凭据。不要上传、截图或发送给他人；导出文件也应按敏感资料处理。'),
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
                      const Text(
                        '关于 Node Inspector',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('版本 0.6.2 · 透明界面、稳定去重、双栈出口与安全报告'),
                      const SizedBox(height: 4),
                      const Text('隔离核心：sing-box 1.13.14，运行时进行 SHA-256 校验。'),
                      const SizedBox(height: 4),
                      Text('当前出口绑定：${widget.controller.bindingDescription}'),
                      const SizedBox(height: 4),
                      const Text(
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
