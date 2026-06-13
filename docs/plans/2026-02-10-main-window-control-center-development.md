# 状态栏主窗口改造开发文档（Control Center）

## 1. 目标与范围

基于 `docs/plans/2026-02-10-main-window-control-center-design.md`，将 InputLock 从「状态栏弹出 Popover」改为「单实例主窗口（Control Center）」，并在同一窗口内承载：

1. 输入法锁定开关与目标输入法选择
2. 剪贴板历史功能开关
3. 截图功能开关
4. 顶部 `主控 | 设置` 分段切换（设置页内嵌渲染）

### 非目标（本期不做）

- 多窗口导航流
- 新功能模块扩展（仅重组现有能力入口）
- 对截图标注系统、剪贴板窗口详情交互做额外功能升级

---

## 2. 当前代码基线（与改造直接相关）

- 状态栏入口：`InputLock/InputLock/System/StatusBarController.swift`
  - 目前容器为 `NSPopover`，点击行为仅「开/关 popover」
- App 装配：`InputLock/InputLock/InputLockApp.swift`
  - 当前创建 `StatusBarController` + `ClipboardWindowController`
  - 热键监听在此绑定（剪贴板热键、截图热键）
- 主面板视图：`InputLock/InputLock/Views/MainPanelView.swift`
  - 已具备输入法列表选择、锁定开关、设置入口、退出按钮
- 设置页：`InputLock/InputLock/Views/SettingsView.swift`
  - 当前为独立 `Settings` Scene 内表单
- 中央状态：`InputLock/InputLock/AppState/AppState.swift`
  - 已有 `setLocked(_:)`，且在解锁时保留 `selectedInputSourceID`
  - 剪贴板监控当前在 `init` 固定启动 `clipboardHistory.startMonitoring()`

---

## 3. 实施设计（可落地版本）

## 3.1 架构调整

### A. 容器层：Popover -> 主窗口控制器

新增 `MainWindowController`（建议位置：`InputLock/InputLock/System/MainWindowController.swift`），职责：

- 创建并持有单实例 `NSWindow/NSPanel`
- 提供 `toggle() / show() / hide() / bringToFront()`
- 实现状态栏点击三态行为：
  - 未显示 -> 显示并激活
  - 已显示且前台 -> 隐藏
  - 已显示但非前台 -> 置前

`StatusBarController` 仅负责状态栏按钮和点击事件，将具体显隐委托给 `MainWindowController`。

### B. 视图层：统一容器 + 顶部分段

新增视图：

- `ControlCenterContainerView`：顶部 `主控 | 设置` + 内容路由
- `MainDashboardView`：主控页（固定高度）
- `EmbeddedSettingsView`：`SettingsView` 的滚动包装

说明：

- `MainPanelView` 可保留并逐步迁移到 `MainDashboardView`，避免一次性重写 UI。
- `SettingsView` 继续复用，减少重复实现，符合 DRY。

### C. 状态层：开关状态与副作用收敛在 AppState

在 `AppState` 增加两个持久化开关：

- `isClipboardFeatureEnabled: Bool`
- `isScreenshotFeatureEnabled: Bool`

并新增：

- `setClipboardFeatureEnabled(_:)`
- `setScreenshotFeatureEnabled(_:)`

输入法锁定开关复用现有 `lockState.isLocked + setLocked(_:)`，不新增 `isInputLockFeatureEnabled`，避免重复状态源（KISS/DRY）。

副作用规则：

- `setClipboardFeatureEnabled(false)` -> `clipboardHistory.stopMonitoring()`
- `setClipboardFeatureEnabled(true)` -> `clipboardHistory.startMonitoring()`
- `setScreenshotFeatureEnabled(false)` -> 截图热键触发时直接短路
- `setScreenshotFeatureEnabled(true)` -> 恢复截图热键触发路径

### D. 持久化

在 `UserDefaultsKeys` 增加：

- `clipboardFeatureEnabled`
- `screenshotFeatureEnabled`

默认值建议：均为 `true`（保持现有行为兼容）。

---

## 3.2 页面与交互规范

### 主控页

展示项（按优先级）：

1. 输入法锁定开关（绑定 `state.lockState.isLocked` / `state.setLocked`）
2. 目标输入法选择（绑定 `state.selectInputSource(id:)`）
3. 剪贴板历史开关（绑定 `state.isClipboardFeatureEnabled`）
4. 截图功能开关（绑定 `state.isScreenshotFeatureEnabled`）

规则：

- 锁定关闭时，保留已选输入法（现有实现已满足）
- 当功能开关为 OFF，UI 显示禁用状态文案，避免“关闭但仍生效”的感知错误

### 设置页

- 顶部导航不变，内容区为 `ScrollView`
- 使用 `SettingsView(state:)` 内嵌渲染，避免两套设置逻辑分叉

---

## 4. 任务拆分（执行顺序）

## Phase 1：窗口容器替换（最小可运行）

### Task 1.1 新增 MainWindowController

- 新建：`InputLock/InputLock/System/MainWindowController.swift`
- 完成标准：
  - 可托管 SwiftUI root view
  - 单实例窗口
  - 支持 show/hide/bringToFront

### Task 1.2 调整 StatusBarController

- 修改：`InputLock/InputLock/System/StatusBarController.swift`
- 改动点：
  - 移除 `NSPopover` 依赖
  - 注入 `MainWindowController` 并转发点击
- 完成标准：点击状态栏图标可驱动主窗口三态行为

### Task 1.3 App 注入改造

- 修改：`InputLock/InputLock/InputLockApp.swift`
- 改动点：
  - 创建 `ControlCenterContainerView`
  - 创建并注入 `MainWindowController`
  - 调整 `StatusBarController` 构造参数

## Phase 2：主控/设置同窗整合

### Task 2.1 新增容器视图与主控页

- 新建：
  - `InputLock/InputLock/Views/ControlCenterContainerView.swift`
  - `InputLock/InputLock/Views/MainDashboardView.swift`
- 建议复用：`MainPanelView` 中现有输入法卡片布局逻辑

### Task 2.2 设置页内嵌

- 新建：`InputLock/InputLock/Views/EmbeddedSettingsView.swift`
- 复用：`InputLock/InputLock/Views/SettingsView.swift`
- 完成标准：
  - 切换至设置页后可滚动
  - 返回主控页后状态不丢失

## Phase 3：功能开关状态化

### Task 3.1 AppState 增加两个功能开关与副作用

- 修改：
  - `InputLock/InputLock/AppState/AppState.swift`
  - `InputLock/InputLock/Managers/UserDefaultsKeys.swift`
- 完成标准：
  - 开关值持久化
  - 副作用集中于 `AppState`

### Task 3.2 热键入口加开关门禁

- 修改：`InputLock/InputLock/InputLockApp.swift`
- 改动点：
  - 剪贴板热键触发前判断 `isClipboardFeatureEnabled`
  - 截图热键触发前判断 `isScreenshotFeatureEnabled`

## Phase 4：测试与回归

### Task 4.1 单元测试更新

- 修改：
  - `InputLock/InputLockTests/AppState/AppStateTests.swift`
  - `InputLock/InputLockTests/System/ClipboardWindowControllerTests.swift`
- 新增建议：
  - `InputLock/InputLockTests/AppState/AppStateFeatureToggleTests.swift`

### Task 4.2 手工交互回归

- 状态栏点击三态行为
- `主控 | 设置` 切换与滚动
- 三个开关的即时生效与持久化

---

## 5. 测试计划

## 5.1 单元测试

1. `AppState`：
   - 剪贴板开关 OFF -> 调用 `stopMonitoring`
   - 剪贴板开关 ON -> 调用 `startMonitoring`
   - 截图开关持久化读写
2. 现有锁定逻辑回归：
   - `setLocked(false)` 后不清空已选输入法
3. 热键门禁：
   - 关闭对应开关时，入口回调不触发实际行为

## 5.2 手工测试

1. 状态栏重复点击：显示/隐藏/置前符合预期
2. 主窗口只创建一个实例
3. 设置页滚动正常，切回主控不丢状态
4. 关闭剪贴板功能后，剪贴板热键无动作
5. 关闭截图功能后，截图热键无动作
6. 重启应用后开关状态保持

---

## 6. 风险与缓解

1. **窗口焦点行为不稳定**（菜单栏应用常见）
   - 缓解：将显隐与置前逻辑集中在 `MainWindowController`，避免分散在视图层
2. **开关与实际行为不一致**
   - 缓解：副作用只在 `AppState` 执行，入口统一读同一状态
3. **AppState 构造参数变更影响测试面广**
   - 缓解：按仓库既有经验同步更新 `InputLockApp.swift`、`AppStateTests.swift`、`ClipboardWindowControllerTests.swift`
4. **UI 迁移期间回归风险**
   - 缓解：保留 `MainPanelView` 可复用片段，分阶段迁移，减少一次性替换

---

## 7. 验收标准（Done Definition）

- 状态栏点击已不再使用 `NSPopover`，而是控制单实例主窗口
- 主窗口内支持 `主控 | 设置` 切换，设置页可滚动
- 主控页可操作输入法锁定、剪贴板、截图三项开关
- 剪贴板/截图开关具备持久化与即时副作用
- 相关单元测试通过，关键手工回归通过

---

## 8. 原则应用说明

- **KISS**：输入法锁定继续复用 `LockStateManager`，不重复引入同义状态
- **YAGNI**：不扩展新模块，仅替换容器与整合入口
- **DRY**：设置页仍复用 `SettingsView`，避免双实现
- **SOLID**：窗口行为下沉到 `MainWindowController`，`StatusBarController` 保持单一职责
