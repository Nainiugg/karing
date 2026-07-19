# Node Inspector

Node Inspector 是一个独立的 Windows Flutter 应用，目标是把来源混杂的代理节点整理成可直接导入 Karing 的可用配置。

> 当前版本：`0.1.0`，第一阶段应用骨架。此版本已经可以启动、保存本机工作区和设置，并提供完整页面结构；节点格式解析、隔离检测和最终导出会按下方路线逐阶段接入。未完成的功能在界面中有明确标注，不会产生虚假的检测结果。

## 最终目标

1. 从订阅 URL、本地文件或粘贴文本导入全部节点；
2. 在不切换 Karing、不修改系统代理或 TUN 的独立核心中自动检测；
3. 使用检测到的真实出口，将可用节点重命名为 `国家-对应IP`，重名时稳定追加序号；
4. 生成能直接导入 Karing 的 sing-box JSON 配置，并附导出报告。

## 第一阶段已经完成

- 独立 Flutter 工程，不依赖 Karing 仓库中缺失的私有包；
- Windows 自适应四页界面：导入、检测、结果、设置；
- 规范化节点、依赖、检测结果、真实出口和导出名称的数据模型；
- `%APPDATA%\NodeInspector\data.json` 本机持久化；
- 临时文件、备份和失败回滚，避免写入中断直接损坏工作区；
- 并发数和超时时间设置；
- 模型、存储、控制器和界面测试；
- Windows 自动构建工作流与构建产物；
- 一键启动与一键构建脚本。

## Windows 快速开始

要求：Windows 10/11、Flutter 3.35 或更高版本、Visual Studio 的“使用 C++ 的桌面开发”组件。Flutter 的 Windows 环境只需配置一次。

1. 克隆仓库并切换到 `feature/node-inspector-app` 分支；
2. 进入 `tools\node_inspector_app`；
3. 双击 `start_windows.bat`。

第一次运行时，脚本会自动生成 Flutter 标准 Windows runner、下载依赖并启动应用，不需要手工输入 `flutter create`、`flutter pub get` 或 `flutter run`。

要进行完整检查并生成 Release 目录，双击 `build_windows.bat`。输出位于：

```text
build\windows\x64\runner\Release
```

也可以直接从该分支最新一次成功的 GitHub Actions 运行中下载 `node-inspector-windows` 构建产物。

## 数据边界

- 订阅地址、节点密钥、原始配置和导出配置均为敏感信息；
- 工作区默认只写入当前 Windows 用户的 `%APPDATA%\NodeInspector`；
- 日志和测试报告不得记录服务器密码、UUID、控制密钥或完整订阅地址；
- 只有实际节点检测阶段会访问公开出口 IP 查询接口；服务方将看到该节点的出口请求；
- “可用”只代表测试时成功，不证明长期稳定、住宅属性或信誉质量。

## 计划中的输入格式

解析器会先识别容器格式，再交给协议适配器，无法识别的内容会保留原始来源和错误原因：

- Clash / Mihomo YAML；
- sing-box JSON；
- Base64 行式订阅；
- URI 分享链接：Shadowsocks、VMess、VLESS、Trojan、Hysteria2、TUIC、SOCKS、HTTP；
- Karing 已支持且能够安全映射的扩展字段。

节点会按连接语义生成指纹去重，不按易变的显示名称去重。含 `detour`、链式代理或传输依赖的节点会作为依赖图保存，避免导出后断链。

## 后续阶段

### 第二阶段：导入和规范化

- 内容识别、协议解析器、字段校验和错误报告；
- 来源管理、去重、合并和依赖图；
- 解析器夹具与敏感字段脱敏测试。

### 第三阶段：隔离检测

- 接入与 Karing 兼容的修改版 sing-box 核心；
- 每个检测 worker 使用独立本机端口，不进入 Karing TUN；
- 真实出口 IP、国家、ASN、运营商、延迟和失败原因；
- 超时、取消、进程清理、坏节点隔离和崩溃恢复。

### 第四阶段：重命名和导出

- 仅导出检测成功的节点；
- 名称规则 `国家-出口IP`，同 IP 或同名节点稳定追加 `-2`、`-3`；
- 生成 Karing 可导入的 sing-box JSON，并保留必要的 DNS、路由和节点依赖；
- 导出前再次进行 schema 校验，附带不含凭据的报告。

### 第五阶段：发布质量

- 大订阅压力测试、失败恢复、升级和数据迁移；
- Windows 安装包、版本签名、校验值和正式发布说明。

## 开发检查

```powershell
flutter create --platforms=windows --project-name=node_inspector_app --org=io.nainiugg --no-pub .
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter build windows --release
```

标准 `windows/` runner 由当前 Flutter SDK 生成，因此不在版本库中维护；应用源码、脚本、测试和 CI 配置均在版本库中完整维护。

## 名称与许可证

本工具暂用名称 **Node Inspector**。它不是 Karing 官方产品，不使用 Karing 名称作为应用品牌，也不暗示与 Karing 团队存在官方关系。

本目录是仓库的组成部分，遵循仓库根目录中的 GNU General Public License v3.0 许可证以及上游项目的附加名称限制。修改版 sing-box 核心在后续接入时会保留其对应许可证、来源版本和校验值。
