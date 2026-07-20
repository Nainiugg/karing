# Node Inspector

Node Inspector 是一个独立的 Windows Flutter 应用，用于把来源混杂的代理节点导入、隔离检测，并导出可供 Karing 使用的 sing-box JSON 配置。

当前版本：`0.6.1`。在多格式导入、真实出口检测、自动重命名和 Karing 配置导出的基础上，新增稳定的跨格式、跨批次和旧工作区节点去重，并保留有效节点详情、IPv4/IPv6 双栈出口、IP 情报、参考纯净度、出口轮换历史和安全报告。

![Node Inspector 背景](assets/background/app_background.jpg)

## 已实现功能

- 从订阅 URL、本地文件或粘贴文本导入节点；
- 从整页网页复制内容中定位分享链接，过滤普通网页 URL、参数说明和无关文本；
- 修复常见 HTML 实体、JSON 转义斜杠、全角冒号、零宽字符、链接内错误空格和查询参数断行；
- 识别 Clash / Mihomo YAML、sing-box JSON、整段 Base64 订阅和常见分享链接；
- 按连接参数生成版本化 SHA-256 指纹，在单次导入、工作区合并和应用启动时去重；
- 去重忽略节点名称、JSON/YAML 字段顺序、域名大小写、IPv6 文本写法和明确的默认空值，但保留协议、端口、凭据、TLS、传输及链式依赖差异；
- 保存 `detour` / `dialer-proxy` 依赖，检测和导出时自动带上依赖节点；
- 使用独立 sing-box 进程和随机本机端口检测，不切换 Karing 当前节点，也不修改系统代理或 TUN；
- 查询实际出口 IP、国家、ASN、运营商和本次请求延迟；
- 只把检测成功的节点命名为 `国家-真实出口IP`，重名自动追加 `-2`、`-3`；
- 只导出可用节点和必要依赖，生成 Karing 可导入的 sing-box JSON；
- 检测并发、超时、出口查询地址和物理网卡 IPv4 均可配置；
- 在结果页点击可用节点，进入独立的详细检测页面；
- 通过同一个被测节点分别访问 IPv4-only 与 IPv6-only 地址，显示 IPv4-only、IPv6-only 或双栈出口；
- 按需查询国家、城市、时区、ASN、机构、ISP、CIDR、反向域名和网络类型；
- 可选接入 IPinfo 与 AbuseIPDB，显示 VPN、代理、Tor、中继、托管、住宅代理和滥用置信分；
- 使用透明规则计算“参考纯净度”，没有风险数据时明确显示“数据不足”，不会伪造满分；
- 最多保留最近 20 次深度检测出口，提示动态轮换 IPv4/IPv6；
- 导出不包含服务器、端口、密钥和传输凭据的节点检测 JSON 报告；
- 可选 API 密钥使用 Windows DPAPI 按当前用户加密，与普通设置分开保存；
- 本机工作区保存在 `%APPDATA%\NodeInspector\data.json`。

## 推荐使用方式：下载完整 Windows 包

从 `feature/node-inspector-app` 分支最新一次成功的 **Node Inspector Windows** 工作流中下载 `node-inspector-windows`：

1. 解压 ZIP 到普通文件夹，不要只在压缩软件内打开；
2. 双击 `node_inspector_app.exe`；
3. 在“导入”页粘贴订阅地址、分享链接或选择配置文件；
4. 查看导入报告，确认新增、重复和解析失败数量；
5. 进入“检测”页，点击“检测全部节点”；
6. 检测完成后进入“结果”页，点击“导出 Karing 配置”；
7. 点击任一“可用”节点或右侧详细检测按钮，查看 IPv4/IPv6 和参考纯净度；
8. 需要增强风险信息时，在“设置”页填写自己的 IPinfo Token 或 AbuseIPDB API Key；
9. 在 Karing 中导入保存的 JSON 文件。

重复导入同一订阅或把多个来源一起粘贴不会重复累积节点。升级到 0.6.1 后，应用第一次启动会重算旧版节点指纹并清理旧工作区中的重复项；保留最早导入的一项及其检测记录。

完整包已经包含经过 SHA-256 校验的 sing-box 1.13.14 Windows 核心及其运行库，不需要安装 Python，也不需要执行 `py -3 app.py`。

## 从源码启动

要求：Windows 10/11、Flutter 3.35.3 或兼容版本，以及 Visual Studio 2022 的“使用 C++ 的桌面开发”组件。

```powershell
git clone https://github.com/Nainiugg/karing.git
cd karing
git switch feature/node-inspector-app
cd tools\node_inspector_app
start_windows.bat
```

`start_windows.bat` 会自动：

1. 检查 Flutter；
2. 生成标准 Windows runner；
3. 从 SagerNet 官方 Release 下载 sing-box 1.13.14；
4. 校验 ZIP、EXE 和 DLL 的 SHA-256；
5. 获取 Dart 依赖并启动应用。

生成完整 Release 包时双击 `build_windows.bat`，输出位于：

```text
build\windows\x64\runner\Release
```

## 支持的输入

| 容器/协议 | 当前处理方式 |
|---|---|
| sing-box JSON | 读取 `outbounds`，忽略 selector、urltest、direct、block 等非节点项 |
| Clash / Mihomo YAML | 读取 `proxies` 并映射常用字段、TLS、WebSocket/gRPC 等传输设置 |
| Base64 订阅 | 自动补齐 Base64 padding，解码后再次识别 JSON、YAML 或分享链接 |
| 分享链接 | SS、VMess、VLESS、Trojan、Hysteria/Hysteria2、TUIC、SOCKS、HTTP/HTTPS、AnyTLS |
| 抓取文本 | 从任意位置提取候选节点，过滤普通网页地址和说明文字，并修复常见转义、空格及查询参数断行 |

不能安全转换的协议或字段会显示在导入报告中，不会伪装成已导入节点。原始凭据不会写入检测错误提示或应用日志。

## 隔离检测原理

每个 worker 为一个节点创建临时 sing-box 配置和随机的 `127.0.0.1` mixed 入口。程序先运行 `sing-box check`，再启动该临时进程，通过本地 HTTP 代理请求设置中的出口查询服务。成功取得真实 IP 才标记为“可用”；随后立即停止进程并删除临时配置。

为避免检测流量重新进入 Karing TUN，程序会优先自动识别 Windows 默认路由对应的物理 IPv4，并排除名称包含 Karing、Wintun、WireGuard、TAP 或 TUN 的网卡。自动识别失败时，请到“设置”页填写物理网卡 IPv4；留空时 sing-box 将自动选择接口。

检测只说明该节点在测试当时能完成 HTTPS 出口查询，不代表长期稳定、住宅属性、信誉或所有网站都可访问。

## 节点详细检测

详细检测只对已经通过可用性检测的节点开放。程序重新启动该节点的独立 sing-box 进程，并通过同一个本地代理入口分别请求：

- `https://api.ipify.org?format=json`：只接受 IPv4 结果；
- `https://api6.ipify.org?format=json`：只接受 IPv6 结果。

两项请求互相独立。IPv6 请求失败不会把已有的 IPv4 节点改为不可用；所有 IP 情报提供商失败也只会生成提示，不会覆盖节点的可用性状态。

基础情报默认按需查询 `ipwho.is`。用户可以选择配置：

- IPinfo：VPN、代理、Tor、中继、托管、住宅代理、Anycast 等信号；
- AbuseIPDB：滥用置信分、报告数量、用途类型和最近报告时间。

增强服务可能有注册、额度、收费或使用条款。Node Inspector 不附带第三方密钥。密钥输入后使用 Windows DPAPI 加密到 `%APPDATA%\NodeInspector\secrets.json`，不会写入 `data.json`、节点配置、应用日志、Karing 导出或安全报告。

为了减少额度消耗，同一出口 IP 的情报默认缓存 24 小时。缓存只复用地址情报；IPv4/IPv6 出口本身仍在每次深度检测时重新获取。公共情报查询和缓存时间都可以在“设置”中关闭或修改。

## 参考纯净度规则

“纯净度”不是互联网统一标准。本工具显示原始信号、来源和时间，并用固定规则提供参考分：

- 先采用 AbuseIPDB 的 `abuseConfidenceScore`；
- Tor 将风险分至少提高到 95；
- VPN、普通代理或住宅代理将风险分至少提高到 70；
- 中继至少 60；托管/机房至少 35；
- 最近报告数量达到 10 条时风险分至少 45；
- 风险分限制在 0–100，参考纯净度为 `100 - 风险分`。

如果没有任何可用的隐私或滥用信号，界面显示“数据不足”，而不是默认 100 分。该分数只用于了解出口网络属性，不保证某个网站、服务或风控系统一定接受该 IP。

## 出口历史与安全报告

每次深度检测最多保留最近 20 条 IPv4/IPv6 出口记录。出现多个不同地址时，详情页会提示节点存在出口轮换，因此自动生成的 `国家-对应IP` 名称只代表命名时的出口。

“导出安全报告”只包含节点显示名称、协议、可用性结果、IPv4/IPv6 情报和历史，不包含 `normalizedConfig`、服务器地址、端口、密码、UUID、订阅地址或传输参数。

## 导出结构

导出文件包含：

- 一个名为 `节点选择` 的 selector；
- 所有检测成功并已重命名的节点；
- 这些节点依赖的 detour 出站；
- `direct`、`block` 出站和以 `节点选择` 为最终出口的路由。

导出前请确认结果页存在“可用”节点。依赖缺失时程序会拒绝导出并给出节点名称，避免生成表面完整但无法使用的配置。

## 核心来源与校验

- 核心：SagerNet sing-box `1.13.14` Windows amd64；
- 官方 ZIP SHA-256：`f580782c6dd10f7691c66cea1d7c421813c5fbf7e305d1ee7ce0c3a40d196341`；
- `sing-box.exe` SHA-256：`db0d779948214cf761011d154c3a5da36df20394fa01a9fc798f1dc39fe9d183`；
- `libcronet.dll` SHA-256：`c7434cfa93c3041321dd19111c4de6c52b8a9531a65661ba45425d3c51ec69e2`。

下载脚本、CI 和应用首次安装核心时均执行固定校验；校验不一致会停止运行。

## 开发检查

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File prepare_core_windows.ps1
flutter create --platforms=windows --project-name=node_inspector_app --org=io.nainiugg --no-pub .
flutter pub get
flutter analyze --fatal-infos
flutter test --reporter=expanded
flutter build windows --release
```

标准 `windows/` runner 由当前 Flutter SDK 生成，因此不在版本库中维护。源码、下载与校验脚本、测试和 CI 工作流均在仓库中。

## 数据边界

- 订阅地址、节点密钥、原始配置和导出配置属于敏感信息；
- 工作区默认只写入当前 Windows 用户的 `%APPDATA%\NodeInspector`；
- 出口查询服务会看到通过被测节点发出的请求；
- IP 情报服务会看到被查询的出口地址；默认只在用户点击“深度检测”时查询；
- API 密钥只应从对应服务的官方账户获取，不要使用或分享他人的密钥；
- 清空节点会删除本机保存的导入内容和检测结果；
- 请只测试和使用你有权使用的节点。

## 名称与许可证

本工具名称为 **Node Inspector**。它不是 Karing 官方产品，不使用 Karing 名称作为应用品牌，也不暗示与 Karing 团队存在官方关系。

本目录是仓库的组成部分，遵循仓库根目录中的 GNU General Public License v3.0、上游附加名称限制，以及随隔离核心一同分发的 sing-box 许可证。
