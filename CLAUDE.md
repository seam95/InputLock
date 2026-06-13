# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

InputLock 是一个 macOS 菜单栏工具（最低支持 macOS 15.7），包含四个核心功能：
1. **输入法锁定** — 通过"监听-纠正"模式（Carbon TIS API + DistributedNotificationCenter），50ms 级别延迟，最多 3 次重试
2. **剪贴板历史** — 0.4s 轮询 NSPasteboard，支持文本/图片/文件/URL/RTF，SQLite 持久化（GRDB.swift），blob 按需加载
3. **快捷用语** — 常用文本片段管理，快速插入，SQLite 持久化（GRDB.swift）
4. **暂存板** — 临时文本草稿，随手记录

## 仓库结构

```
inputLock/              # 仓库根（文档、工具脚本、计划）
  InputLock/            # Xcode 工程
    InputLock/          # App 源码
      InputLockApp.swift        # @main 入口，创建所有 Manager 并注入
      AppState/                 # 中心状态：AppState（聚合所有 Manager）
      Managers/                 # 业务逻辑管理器（输入法、锁定、剪贴板、快捷用语等）
      Models/                   # 数据模型（InputSource, ClipboardEntry, QuickPhraseEntry）
      Views/                    # SwiftUI 视图
      System/                   # 系统 API 抽象层（TIS、通知、NSPanel、CGEvent 等）
      Resources/                # 本地化字符串（en, zh-Hans）
    InputLockTests/             # 单元测试（镜像源码目录结构）
    InputLockUITests/           # UI 测试
  docs/                         # PRD、设计文档、开发计划
  tools/                        # Python 图标生成脚本
```

## 常用命令

```bash
# 打开 Xcode 工程
open InputLock/InputLock.xcodeproj

# 构建（Debug）
cd InputLock && xcodebuild build -scheme InputLock -configuration Debug

# 运行全部测试
cd InputLock && xcodebuild test -scheme InputLock -destination 'platform=macOS'
```

## 架构要点

### 分层模式
- **UI 层（SwiftUI）**：View 只订阅状态、触发意图，不含业务逻辑
- **业务逻辑层（Managers/）**：每个 Manager 职责单一，通过构造器注入依赖
- **系统 API 层（System/）**：所有 macOS 系统 API 封装在协议后面

### 核心设计
- **AppState** 是唯一的中心状态对象（`@MainActor ObservableObject`），聚合所有 Manager，通过 Combine 转发 `objectWillChange`
- **InputLockApp.swift** 是依赖组装点 — 创建所有 Manager 实例并注入 AppState
- **协议驱动的依赖注入**：`TISClient`、`NotificationCenterClient`、`Scheduler`、`PasteboardClient`、`ClipboardStore`、`LaunchAtLoginClient` 等，每个都有对应 Fake 实现用于测试

### 窗口与面板管理
- `StatusBarController` — 菜单栏图标 + 蓝点指示器，承载主控中心面板（`ControlCenterContainerView`）
- `ClipboardWindowController` — 剪贴板浮动面板（NSPanel, non-activating）
- 主控中心通过 `TabPanel` 切换三个功能标签：剪贴板历史 / 快捷用语 / 暂存板

## 测试约定

- 使用 XCTest 框架，Fake/Stub 模式做单元测试
- `ImmediateScheduler` 替代 `MainQueueScheduler` 保证测试同步执行
- `FakeTISClient` 带调用计数追踪，可验证交互次数
- 测试文件目录结构与源码完全镜像

## 代码风格

- 缩进：4 spaces
- 命名：类型 `UpperCamelCase`，成员 `lowerCamelCase`
- **注释语言：中文**（保持与现有代码一致）
- SwiftUI-first：业务逻辑下沉到 Manager，View 保持纯净

## 依赖

- **GRDB.swift** v7.9.0 — SQLite 数据库（剪贴板历史、快捷用语存储）
- **KeyboardShortcuts** v1.17.0 — 全局快捷键注册（sindresorhus）
- 通过 Xcode SPM 管理，无独立 Package.swift
