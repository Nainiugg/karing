# Node Inspector v0.6.1

> 为 Karing 用户准备的独立节点整理、隔离检测与配置导出工具。

Node Inspector 是 `Nainiugg/karing` 仓库中的实验性独立 Windows 应用。它用于从订阅、配置文件、分享链接以及网页抓取的混乱文本中提取代理节点，去除重复项，通过独立的 sing-box 进程检测节点真实出口，最后把可用节点重新命名并导出为 Karing 可导入的 sing-box JSON。

本工具不是 Karing 官方组件，也不会修改 Karing 当前连接。项目仅用于个人网络诊断、自己网站的连通性测试和获得明确授权的安全演练。

![Node Inspector 应用界面背景](tools/node_inspector_app/assets/background/app_background.jpg)

## 核心功能

- 从订阅 URL、本地文件或粘贴文本批量导入节点；
- 自动从整页网页文本中筛选真正的分享链接，过滤教程、普通网址和无关说明；
- 识别 Clash/Mihomo YAML、sing-box JSON、Base64 订阅及常见分享链接；
- 在同一批导入、多次导入和旧工作区之间自动去除重复节点；
- 为每个节点启动独立的临时 sing-box 进程，不切换 Karing 当前节点；
- 检测真实出口 IP、国家、ASN、运营商和延迟；
- 对可用节点分别检测 IPv4 与 IPv6 出口；
- 显示网络类型、风险信号、参考纯净度和出口轮换历史；
- 将可用节点重命名为 `国家-真实出口IP`，重名自动追加序号；
- 只导出检测成功的节点和必要的链式依赖，生成 Karing 可导入配置；
- 导出不包含节点密码、UUID、服务器和订阅地址的安全检测报告；
- 可选 API 密钥在 Windows 上使用 DPAPI 按当前用户加密保存。

## 支持的输入

| 输入类型 | 处理方式 |
|---|---|
| sing-box JSON | 读取 `outbounds`，忽略 selector、urltest、direct、block 等非节点项 |
| Clash/Mihomo YAML | 读取 `proxies`，转换常用协议、TLS、WebSocket 和 gRPC 字段 |
| Base64 订阅 | 自动补齐 padding，解码后继续识别 JSON、YAML 或分享链接 |
| 分享链接 | SS、VMess、VLESS、Trojan、Hysteria/Hysteria2、TUIC、SOCKS、HTTP/HTTPS、AnyTLS |
| 网页抓取文本 | 修复常见 HTML 实体、转义斜杠、全角符号、零宽字符、错误空格和参数断行 |

无法安全转换的内容会显示在导入报告中，不会伪装成有效节点。

## 节点去重规则

v0.6.1 使用版本化 SHA-256 连接指纹进行去重，覆盖：

1. 同一次批量导入中的重复项；
2. 新导入内容与当前工作区已有节点；
3. 从旧版本恢复的本地历史节点。

指纹会忽略节点显示名称、JSON/YAML 字段顺序、域名大小写、IPv6 的等价文本写法以及明确的默认空值；协议、端口、密码或 UUID、TLS、传输方式和链式代理依赖不同的节点仍会保留，避免把“地址相同但配置不同”的节点误删。

## 隔离检测原理

每个检测 worker 会为一个节点生成临时 sing-box 配置，并分配随机的 `127.0.0.1` 本机代理端口。程序先执行 `sing-box check`，再通过该临时代理请求出口查询服务。成功获得真实出口后立即停止进程并删除临时配置。

为了避免测试流量重新进入 Karing TUN，程序会尝试识别 Windows 默认路由对应的物理 IPv4，并排除名称包含 Karing、Wintun、WireGuard、TAP 或 TUN 的虚拟网卡。

如果检测页显示“未绑定物理出口”：

- Karing、VPN、TUN 和系统代理都已关闭时，可以直接尝试检测；
- Karing 或其他 TUN 仍在运行时，建议在设置中填写当前 Wi-Fi/以太网网卡的局域网 IPv4，例如 `192.168.1.100`；
- 不要填写公网出口 IP、代理服务器 IP、`127.0.0.1` 或虚拟网卡地址。

## 下载和使用

Windows 成品由 GitHub Actions 在 `windows-2022` 环境中构建。进入本分支对应 PR 的 Actions 检查，下载名为：

```text
node-inspector-windows-v0.6.1
```

的 artifact，完整解压后双击：

```text
node_inspector_app.exe
```

不要只复制 EXE。运行目录必须同时保留 `flutter_windows.dll`、插件 DLL 和 `data` 目录；sing-box 与 `libcronet.dll` 位于 Flutter assets 中。

首次使用建议流程：

1. 打开“导入”，粘贴订阅、分享链接、网页文本，或选择 JSON/YAML/TXT 文件；
2. 查看导入报告中的候选、新增、重复、噪声和失败数量；
3. 根据网络环境决定是否在“设置”中绑定物理网卡 IPv4；
4. 打开“检测”，点击“检测全部节点”；
5. 在“结果”中查看可用节点，并点击单个节点进行 IPv4/IPv6 和 IP 情报检测；
6. 点击“导出 Karing 配置”，再在 Karing 中导入生成的 JSON。

## 源码启动与构建

环境要求：Windows 10/11、Flutter 3.35.3 或兼容版本，以及 Visual Studio 2022 的“使用 C++ 的桌面开发”组件。

```powershell
git clone https://github.com/Nainiugg/karing.git
cd karing
git switch agent/node-inspector-v0.6.1-build
cd tools\node_inspector_app
start_windows.bat
```

生成 Release 包：

```powershell
build_windows.bat
```

输出目录：

```text
tools\node_inspector_app\build\windows\x64\runner\Release
```

## 数据与隐私

- 订阅地址、节点密钥、原始配置和导出配置属于敏感信息；
- 工作区默认保存在 `%APPDATA%\NodeInspector\data.json`；
- 出口查询服务会看到通过被测节点发出的查询请求；
- 深度检测时，启用的 IP 情报服务会看到被查询的出口地址；
- 可选 API 密钥使用 Windows DPAPI 加密到当前用户目录；
- 安全报告不会包含节点服务器、端口、密码、UUID、订阅地址或传输凭据；
- “可用”和“参考纯净度”只反映检测当时结果，不代表长期稳定，也不保证第三方网站一定接受该出口。

## 安全与合规

请只检测和使用你有权使用的节点、网站和系统。不得将本工具用于未经授权访问、批量滥用账户、绕过验证码、规避第三方风控或其他违法违规活动。免费公共节点可能记录或篡改流量，不应传输密码、支付信息、私钥或其他敏感资料。

## 分支与构建状态

- 项目仓库：<https://github.com/Nainiugg/karing>
- Node Inspector 分支：<https://github.com/Nainiugg/karing/tree/agent/node-inspector-v0.6.1-build>
- Windows 构建 PR：<https://github.com/Nainiugg/karing/pull/1>
- 当前应用版本：`0.6.1+7`
- 隔离检测核心：sing-box `1.13.14`
- 许可证：GNU General Public License v3.0；随应用分发的第三方核心保留其自身许可证。
