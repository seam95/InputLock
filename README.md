# InputLock

A macOS menu-bar utility that keeps your input method under control and your clipboard within reach.

> 适用于 macOS 的菜单栏效率工具：锁定输入法、管理剪贴板历史、快捷用语与暂存板。

<!-- 截图待补充：建议放置 app 截图 / GIF 演示 -->

## 功能

- **输入法锁定** — 针对每个 App 锁定输入法，避免中英切换错乱。基于 Carbon TIS API + `DistributedNotificationCenter` 的"监听-纠正"模式，约 50ms 延迟，最多 3 次重试。
- **剪贴板历史** — 0.4s 轮询 `NSPasteboard`，支持文本 / 图片 / 文件 / URL / RTF，SQLite 持久化（[GRDB.swift](https://github.com/groue/GRDB.swift)），按需加载、内存友好。
- **快捷用语（Quick Phrase）** — 管理常用文本片段，快速插入，避免重复输入。
- **暂存板（Scratchpad）** — 随手记录的临时文本草稿。

## 系统要求

- macOS 15.7 或更高版本
- Xcode 16 及以上（构建源码）

## 安装

### 方式一：下载 Release

前往 [Releases](../../releases) 下载最新的 `.dmg` 或 `.zip`，拖入「应用程序」即可。

首次运行需在「系统设置 → 隐私与安全性」中允许 InputLock 运行，并按提示授予相应权限（辅助功能、输入监控等）。

### 方式二：源码构建

```bash
git clone https://github.com/Seam95/inputLock.git
cd inputLock
open InputLock/InputLock.xcodeproj
```

在 Xcode 中选择 `InputLock` scheme，`⌘R` 运行。

或使用命令行：

```bash
xcodebuild build \
  -project InputLock/InputLock.xcodeproj \
  -scheme InputLock \
  -configuration Debug
```

> 签名说明：工程默认未配置 `DEVELOPMENT_TEAM`。贡献者请在 Xcode 的 Signing & Capabilities 中选择自己的开发者团队（个人免费账号即可本地运行）。

## 开发

### 架构

```
UI 层（SwiftUI Views）         只订阅状态、触发意图，不含业务逻辑
   │
业务逻辑层（Managers/）         每个 Manager 职责单一，构造器注入依赖
   │
系统 API 层（System/）          macOS 系统 API 封装在协议之后，便于测试
```

- **`AppState`** 是唯一的中心状态对象（`@MainActor ObservableObject`），聚合所有 Manager，通过 Combine 转发变更。
- **`InputLockApp.swift`** 是依赖组装点 —— 创建所有 Manager 实例并注入 `AppState`。
- **协议驱动的依赖注入**：`TISClient`、`NotificationCenterClient`、`Scheduler`、`PasteboardClient`、`ClipboardStore` 等，每个都有对应 Fake 实现用于测试。

### 运行测试

```bash
cd InputLock
xcodebuild test \
  -project InputLock.xcodeproj \
  -scheme InputLock \
  -destination 'platform=macOS'
```

详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

### 依赖

- [GRDB.swift](https://github.com/groue/GRDB.swift) v7.9.0 — SQLite 数据库
- [KeyboardShortcuts](https://github.com/sindrel/KeyboardShortcuts) v1.17.0 — 全局快捷键

通过 Xcode SPM 管理。

## 贡献

欢迎提 Issue 和 PR。请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 了解开发约定与提交流程。

## 许可证

[MIT License](LICENSE)
