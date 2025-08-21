<div align="center">

# Kelivo

开源移动端 AI 助手（Flutter 示例项目）

</div>

## 简介

Kelivo 是一个基于 Flutter 构建的多模型 AI 助手 Demo，演示如何在移动端整合多家模型服务商、统一配置与对话体验，并提供现代化的 UI/UX。项目包含设置页、模型/供应商管理、MCP 工具集成、聊天体验优化等模块。

本仓库用于演示与学习，代码结构清晰，适合二次开发。

## 主要特性

- 多供应商/模型管理：统一管理与切换默认模型、供应商详情页等。
- 聊天体验：Markdown 渲染、代码高亮、图片查看与分享等。
- 设置页：主题与显示设置、MCP、数据统计；新增“关于 / 使用文档 / 赞助 / 分享”。
- 关于页：展示版本、系统信息、官网、GitHub、许可证等，并可快速分享项目。
- 代理感知网络层：按供应商独立配置 HTTP 客户端与代理（ProviderManager）。
- 本地持久化：关键设置与 Provider 配置持久化到 SharedPreferences。

## 技术栈

- Flutter + Dart（Provider 状态管理，Material 3 动态取色）
- 第三方依赖：
  - `provider`、`dynamic_color`
  - `share_plus`（分享）、`url_launcher`（外链）、`package_info_plus`（版本信息）
  - `flutter_highlight`、`gpt_markdown`（Markdown + 代码高亮）
  - `shared_preferences`、`hive`（本地存储）

## 目录结构

```
lib/
  main.dart                 # 入口（Providers 注入与 RouteObserver）
  providers/                # 设置/模型/聊天/MCP 等 Provider
  services/                 # 业务服务（例如 ChatService）
  ui/                       # 页面与组件（settings、about、provider detail 等）
  widgets/                  # 复用组件（ChatInputBar 等）
  theme/                    # 主题与色板
  icons/                    # 图标适配（Lucide）
test/                       # 单元/组件测试（与 lib/ 结构镜像）
assets/                     # 图标与静态资源
```

重点页面/文件：

- `lib/ui/settings_page.dart`：设置页，包含“关于 / 使用文档 / 赞助 / 分享”入口。
- `lib/ui/about_page.dart`：关于子页面（版本、系统、官网、GitHub、许可证、分享）。
- `lib/providers/settings_provider.dart`：主题、显示与通用设置。
- `lib/ui/providers_page.dart`、`lib/ui/provider_detail_page.dart`：供应商管理。
- `lib/services/chat_service.dart`：聊天相关服务。

## 快速开始

环境准备：

- 安装 Flutter（稳定版），并确保可用的设备/模拟器。
- Dart SDK 版本以 `pubspec.yaml` 为准（本项目标注 `environment: sdk: ^3.8.1`）。

安装与运行：

```bash
flutter pub get           # 安装依赖
flutter analyze           # 代码静态检查
flutter test              # 运行测试
dart format .             # 代码格式化
flutter run               # 选择设备运行（或指定 -d <device-id>）
```

常用命令（节选）：

```bash
flutter test --coverage   # 生成覆盖率
flutter build apk --release  # Android 发布包
```

## 配置与安全

- 不要提交任何密钥/Token 到仓库。运行时通过 `--dart-define=KEY=VALUE` 注入配置，代码内通过 `String.fromEnvironment('KEY')` 读取。
- Provider 配置持久化键为 `provider_configs_v1`（`SharedPreferences`）。
- 按供应商走独立 HTTP 客户端，确保代理/网络配置在 `ProviderManager` 生效。

## 架构说明

- `SettingsProvider.currentModelProvider/Id` 与 `setCurrentModel()` 负责当前模型的选择与切换。
- `ProviderManager` 负责模型列表与连接检测（适配 OpenAI / Claude / Google 等）。
- 聊天入口：`ChatInputBar.onSend` 通过 `ChatService` 与网络层复用。

## 关于页面（新增）

- 入口：设置 → 关于
- 功能：
  - 展示版本号、构建号与系统信息（`package_info_plus` + `dart:io`）
  - 快捷访问：官网（https://psycheas.top/）、GitHub、许可证
  - 分享文案：`Kelivo - 开源移动端AI助手`（`share_plus`）

说明：仓库中当前未附带 LICENSE 文件，如需开源发布，请补充相应许可证（如 MIT），并同步更新关于页链接。

## 代码规范

- 2 空格缩进、尾随逗号、移除未使用的 import。
- 文件命名 `lower_snake_case.dart`，类/组件使用 UpperCamelCase，变量/方法使用 lowerCamelCase。
- 提交信息遵循 Conventional Commits，例如：
  - `feat(settings): add about/docs/sponsor/share`
  - `fix(ui): handle null provider state`

## 测试

- 使用 `flutter_test` / `test`，测试放在 `test/`，命名 `*_test.dart`。
- Widget 测试使用 `pumpWidget`/`pump` 明确等待。

## 贡献

欢迎提交 Issue 与 PR。请在本地通过以下质量门禁后再提交：

```bash
dart format .
flutter analyze
flutter test
```

## 致谢

- 图标基于 [lucide_icons_flutter](https://pub.dev/packages/lucide_icons_flutter)
- 高亮与 Markdown 基于 `flutter_highlight` 与 `gpt_markdown`

## 许可

本仓库当前未包含 LICENSE 文件。如需使用或发布，请先选择并添加适用许可证（例如 MIT），并在 PR 中附上相应声明。
