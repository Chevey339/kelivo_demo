<div align="center">
  <img src="assets/app_icon_foreground.png" alt="App 图标" width="100" />
  <h1>Kelivo</h1>

一个跨平台 Flutter LLM 聊天客户端，支持切换不同供应商 🤖💬

简体中文

</div>

## 🚀 下载

- 从源码运行：

```bash
flutter pub get
flutter run -d <device-id>
```

- 构建发布包：

```bash
flutter build apk --release   # Android
flutter build ios --release   # iOS（需在 Xcode 配置签名）
```

## ✨ 功能特色

- 🎨 现代化设计：Material 3、动态取色、沉浸式系统栏。
- 🌙 深色模式：主题自动/手动切换。
- 🛠️ MCP 工具集成：可连接与管理 MCP 服务器。
- 🔄 多供应商/模型：自定义 API/URL/模型（适配 OpenAI、Google、Anthropic 等）。
- 🖼️ 多模态输入：图片与文档附件，消息发送前预览与移除。
- 📝 Markdown 渲染：代码高亮、表格与数学等。
- 🔍 联网搜索：可切换搜索服务与设置参数。
- 🤳 提供商导入/导出：支持二维码导入与分享配置。
- 🤖 智能体与语音：可自定义助手配置与 TTS 服务。

## 🧩 技术栈

- Flutter + Dart（Provider 状态管理，Dynamic Color，Material 3）
- 主要依赖：`provider`、`dynamic_color`、`share_plus`、`url_launcher`、`package_info_plus`、
  `gpt_markdown`、`flutter_highlight`、`shared_preferences`、`hive`

## 📂 目录结构

```
lib/
  main.dart                 # 入口（Providers 注入 + RouteObserver）
  providers/                # settings/model/chat/mcp/tts 等
  services/                 # ChatService、McpToolService 等
  ui/                       # 页面：home/settings/providers/detail 等
  widgets/                  # 复用组件：chat_input_bar 等
assets/                     # 图标与静态资源
test/                       # 单元/组件测试（与 lib/ 镜像）
```

## 🛡️ 配置与安全

- 切勿提交密钥；用 `--dart-define=KEY=VALUE` 注入，并用 `String.fromEnvironment('KEY')` 读取。
- Provider 配置持久化键：`provider_configs_v1`；按供应商复用代理感知的 HTTP 客户端。

## 🤝 贡献

欢迎 PR！提交前请通过本地质量门禁：

```bash
dart format .
flutter analyze
flutter test
```

> [!TIP]
> 若首次构建失败，请先清理缓存：`flutter clean && flutter pub get`。

## 💖 致谢

- 感谢 RikkaHub 开源项目提供 UI 页面参考：https://github.com/rikkahub/rikkahub
- 图标与渲染依赖：`lucide_icons_flutter`、`flutter_highlight`、`gpt_markdown`

## 📄 许可证

本仓库当前未包含 LICENSE 文件。如需开源发布，请首先添加合适的许可证（如 MIT）并在应用“关于”页同步链接。
