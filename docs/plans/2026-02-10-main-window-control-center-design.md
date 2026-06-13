# 状态栏主窗口改造设计（Control Center）

## 目标

将当前“点击状态栏图标后显示下拉 Popover”的交互，改为“显示独立主窗口（单实例）”，并在该窗口内完成以下操作：

1. 选择锁定输入法
2. 开关：是否开启锁定输入法
3. 开关：是否开启剪贴板历史功能
4. 开关：是否开启截图功能
5. 顶部“设置”选项，点击后在当前窗口内渲染设置内容

## 已确认设计决策

- 采用**单窗口 + 顶部分段切换**（`主控 | 设置`）
- 主控页面高度固定，设置页面内容区可滚动
- 关闭“锁定输入法”时，**保留上次已选输入法**（不清空）

## 非目标（YAGNI）

- 本期不引入多窗口工作流
- 本期不新增复杂导航层级（如三级路由）
- 本期不扩展新的功能模块，仅重组现有能力入口

---

## 现状与改造点

### 现状

- 状态栏点击逻辑：`InputLock/InputLock/System/StatusBarController.swift`
- 当前容器：`NSPopover`
- 主面板内容：`InputLock/InputLock/Views/MainPanelView.swift`
- 设置入口：`Settings` Scene（`InputLock/InputLock/InputLockApp.swift`）

### 改造方向

- 将 `StatusBarController` 的弹出容器从 `NSPopover` 迁移到 `NSWindow`/`NSPanel` 控制器
- 新增窗口容器视图承载“主控/设置”两页
- 将现有 `SettingsView` 以内嵌方式接入主窗口的设置页

---

## 信息架构与页面布局

```text
┌──────────────────────────────────────────────┐
│ InputLock                      [主控 | 设置] │
├──────────────────────────────────────────────┤
│ 主控页（固定高度）                           │
│                                              │
│ [锁定输入法]      Toggle                     │
│ 目标输入法：      下拉 / 列表选择             │
│                                              │
│ [剪贴板历史]      Toggle + 状态文案          │
│ [截图功能]        Toggle + 权限/状态文案      │
│                                              │
│ 底部：最近操作提示 / 反馈文案                 │
├──────────────────────────────────────────────┤
│ 设置页（与主控同窗切换）                      │
│ 顶部不变，内容区 ScrollView，复用 SettingsView │
└──────────────────────────────────────────────┘
```

布局原则：

- 主框架稳定，不因页面切换改变外层窗口大小
- 主控页密度高但结构简洁，突出“开关 + 输入法选择”
- 设置页使用滚动容器承载详细配置，避免主控页被挤压

---

## 交互流程

### 状态栏点击行为

- 未显示：显示主窗口并激活 App
- 已显示且前台：隐藏主窗口
- 已显示但非前台：将主窗口置前

### 页面切换行为

- 点击 `设置`：在同一窗口内容区切换到设置页
- 点击 `主控`：返回主控页，保留已编辑但未离开状态

### 主控开关联动规则

- 锁定输入法开关
  - `ON`：按当前选中的输入法执行锁定
  - `OFF`：执行 `unlock`，但保留已选输入法 ID
- 剪贴板历史开关
  - `ON`：启动监控与相关入口
  - `OFF`：停止监控，相关入口置为不可用
- 截图功能开关
  - `ON`：允许截图热键触发进入截图流程
  - `OFF`：热键触发短路，不进入截图流程

---

## 状态模型

建议在 `AppState` 增加三个持久化状态（`UserDefaults`）：

- `isInputLockFeatureEnabled: Bool`
- `isClipboardFeatureEnabled: Bool`
- `isScreenshotFeatureEnabled: Bool`

并提供配套 setter，集中承载副作用（而不是分散在 View 层）：

- `setInputLockFeatureEnabled(_:)`
- `setClipboardFeatureEnabled(_:)`
- `setScreenshotFeatureEnabled(_:)`

设计理由（KISS + DRY）：

- 单一状态源，避免多个管理器重复维护“启用/禁用”逻辑
- 所有副作用统一落在 `AppState`，便于测试与回归

---

## 组件拆分建议

### 新增

- `MainWindowController`（窗口生命周期、显示/隐藏/置前）
- `ControlCenterContainerView`（顶部分段 + 内容路由）
- `MainDashboardView`（主控内容）
- `EmbeddedSettingsView`（设置页滚动包装）

### 调整

- `StatusBarController`：从 `popover` 触发改为主窗口控制
- `InputLockApp`：注入并持有 `MainWindowController`

---

## 动效策略（克制、可感知）

- 窗口显隐：`opacity + scale(0.98 -> 1.0)`，120~160ms
- 页面切换：内容区淡入淡出 + 轻微位移
- 开关动画：沿用系统 `Toggle` 默认动画

说明：避免重动画干扰效率场景，保持菜单栏工具“快进快出”的使用节奏。

---

## 异常与边界处理

- 无可选输入法：禁用锁定区并显示提示文案
- 截图权限不足：展示权限提示，不弹多层窗口
- 关闭功能时，立即停止对应后台行为（避免“开关关闭但功能仍在运行”）

---

## 测试计划

### 单元测试

1. `AppState` 三个功能开关的持久化与副作用
2. 锁定开关 `OFF` 后保留选中输入法 ID
3. 剪贴板开关 `OFF` 时监控停止
4. 截图开关 `OFF` 时热键回调不进入截图流程

### 交互测试（手工）

1. 状态栏重复点击的显隐/置前逻辑
2. `主控 | 设置` 切换稳定性（不丢状态）
3. 主控固定高度、设置页独立滚动体验

---

## 实施顺序（最小可交付）

1. 替换状态栏容器（Popover -> 主窗口）
2. 搭建 `主控 | 设置` 容器与页面切换
3. 接入三个功能开关与 `AppState` 副作用
4. 将 `SettingsView` 嵌入当前窗口并支持滚动
5. 补齐单测与关键交互回归

---

## 影响文件（预估）

- `InputLock/InputLock/System/StatusBarController.swift`
- `InputLock/InputLock/InputLockApp.swift`
- `InputLock/InputLock/AppState/AppState.swift`
- `InputLock/InputLock/Views/MainPanelView.swift`（或拆分后由新视图替代）
- `InputLock/InputLock/Views/SettingsView.swift`
- `InputLock/InputLockTests/AppState/AppStateTests.swift`
- `InputLock/InputLockTests/System/ClipboardWindowControllerTests.swift`

（注：`AppState` 构造参数变更时，测试注入点需同步调整。）
