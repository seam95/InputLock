# 贡献指南

感谢你愿意为 InputLock 贡献代码！请阅读以下约定。

## 开发环境

- macOS 15.7+
- Xcode 16+
- Swift 5

## 快速开始

```bash
git clone https://github.com/Seam95/inputLock.git
cd inputLock
open InputLock/InputLock.xcodeproj
```

在 Xcode 的 **Signing & Capabilities** 中为目标 `InputLock` 选择你自己的开发者团队（个人免费账号即可本地运行与调试）。

## 构建与测试

```bash
# 构建
xcodebuild build \
  -project InputLock/InputLock.xcodeproj \
  -scheme InputLock \
  -configuration Debug

# 运行全部测试
xcodebuild test \
  -project InputLock/InputLock.xcodeproj \
  -scheme InputLock \
  -destination 'platform=macOS'

# 运行单个测试套件
xcodebuild test \
  -project InputLock/InputLock.xcodeproj \
  -scheme InputLock \
  -only-testing:InputLockTests/ClipboardHistoryManagerTests \
  -destination 'platform=macOS'
```

## 架构与代码风格

### 分层

- **UI 层（`Views/`，SwiftUI）**：View 只订阅状态、触发意图，不含业务逻辑。
- **业务逻辑层（`Managers/`）**：每个 Manager 职责单一，通过构造器注入依赖。
- **系统 API 层（`System/`）**：所有 macOS 系统 API 封装在协议后面，便于测试。

### 核心原则

- **`AppState` 是唯一的中心状态对象**（`@MainActor ObservableObject`），聚合所有 Manager，通过 Combine 转发 `objectWillChange`。
- **协议驱动的依赖注入**：为外部依赖定义协议（如 `TISClient`、`PasteboardClient`），并提供 Fake 实现用于测试。
- 遵循 SOLID、DRY、关注点分离、YAGNI。

### 代码风格

- 缩进：**4 个空格**
- 命名：类型 `UpperCamelCase`，成员 `lowerCamelCase`
- **注释语言：中文**（关键流程、核心逻辑、重点难点必须注释）
- SwiftUI-first：业务逻辑下沉到 Manager，View 保持纯净
- 删除无用代码，不保留旧的兼容性代码

## 测试约定

- 使用 XCTest 框架，Fake / Stub 模式做单元测试。
- `ImmediateScheduler` 替代 `MainQueueScheduler` 保证测试同步执行。
- 测试文件目录结构与源码完全镜像。

## 提交规范

- 使用清晰的提交信息，推荐 [Conventional Commits](https://www.conventionalcommits.org/) 风格，例如：
  - `feat(clipboard): 支持文件类型剪贴项`
  - `fix(input-method): 修复纠正重试逻辑`
  - `docs: 更新 README`
- 一个 PR 聚焦一件事，便于 review。

## PR 流程

1. Fork 仓库并新建分支。
2. 确保本地测试通过。
3. 如有必要，更新相关文档。
4. 提交 PR，描述变更内容与动机。

再次感谢你的贡献！
