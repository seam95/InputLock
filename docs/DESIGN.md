# InputLock 设计文档 (Design Doc)

| 版本 | 日期 | 作者 | 状态 |
|------|------|------|------|
| 1.0 | 2026-01-27 | Seam | 草案 |

---

## 1. 背景与目标

### 1.1 背景
本设计文档基于 `docs/PRD.md`，面向 macOS 26.2 的菜单栏输入法锁定工具，采用“监听-纠正”技术路线。

### 1.2 目标
- 以菜单栏常驻方式提供输入法锁定能力
- 50ms 级别的纠正响应，用户几乎无感知
- 不申请系统权限，不收集用户数据
- 结构清晰、易维护、易扩展

### 1.3 非目标
- 不实现输入法高级配置（如候选词设置）
- 不做云端同步、多设备协同
- 不做复杂统计或日志采集

---

## 2. 设计原则

- **KISS**：最小实现可行功能，减少状态与逻辑分支
- **YAGNI**：只实现 PRD 中明确需求
- **DRY**：输入法列表、锁定状态、语言等复用统一数据源
- **SOLID**：
  - S：管理器职责单一（输入法、锁定状态、多语言）
  - O：通过协议/抽象扩展系统 API 适配
  - L/I/D：依赖抽象接口，避免 UI 直接调用底层 API

---

## 3. 系统架构

### 3.1 分层架构
```
UI Layer (SwiftUI)
 ├─ MenuBarView
 ├─ MainPanelView
 └─ SettingsView

Business Logic Layer
 ├─ InputMethodManager (核心)
 ├─ LockStateManager
 └─ LanguageManager

System API Layer
 ├─ TIS API
 └─ DistributedNotificationCenter
```

### 3.2 关键依赖
- Carbon/HIToolbox (TIS API)
- DistributedNotificationCenter
- ServiceManagement（登录项）

---

## 4. 关键流程设计

### 4.1 启动流程
1. 应用启动
2. 初始化管理器
3. 枚举输入法并缓存
4. 渲染菜单栏图标与主面板
5. 注册系统输入法变更监听

### 4.2 锁定流程
1. 用户点击输入法项
2. 切换到目标输入法
3. 设置锁定目标 ID 与锁定状态
4. 刷新 UI 状态（🔒）

### 4.3 监听-纠正流程
1. 收到输入法切换通知
2. 获取当前输入法 ID
3. 若锁定且不一致：延迟 50ms 再切回
4. 更新 UI 显示

---

## 5. 模块设计

### 5.1 InputMethodManager
**职责**
- 枚举输入法列表
- 获取当前输入法
- 切换输入法
- 监听系统输入法变化

**接口建议**
- `enumerateInputSources() -> [InputSource]`
- `getCurrentInputSource() -> InputSource?`
- `selectInputSource(_ id: String) -> Bool`
- `startObservingInputSourceChanges()`

**设计要点**
- 仅封装 TIS 相关逻辑
- 不保存 UI 状态，避免职责混杂

### 5.2 LockStateManager
**职责**
- 锁定状态管理
- 锁定目标 ID 保存
- 锁定/解锁切换

**核心状态**
- `isLocked: Bool`
- `lockedInputSourceID: String?`

### 5.3 LanguageManager
**职责**
- 多语言加载
- 获取本地化字符串
- 可选语言手动切换

---

## 6. 数据模型

### 6.1 InputSource
字段建议：
- `id: String`（InputSourceID）
- `name: String`
- `isSelectable: Bool`
- `isEnabled: Bool`
- `icon: NSImage?`（可选）

---

## 7. 状态管理与数据流

- UI 层只订阅状态：输入法列表、锁定状态、当前输入法
- InputMethodManager 提供输入法数据并触发变化事件
- LockStateManager 统一记录锁定状态与目标
- 事件流：系统通知 → InputMethodManager → LockStateManager → UI 刷新

---

## 8. 并发与线程模型

- 监听通知在主线程处理
- 纠正操作延迟 50ms 使用 `DispatchQueue.main.asyncAfter`
- 避免后台线程操作 UI

---

## 9. 错误处理策略

- TIS API 返回失败时：
  - 记录日志（可选 Debug 日志）
  - UI 提示可选（MVP 阶段可不展示）
- 输入法列表为空时：
  - UI 显示“未检测到输入法”

---

## 10. UI 设计与交互

### 10.1 菜单栏图标
- 🔓 未锁定
- 🔒 已锁定

### 10.2 主面板
- 输入法列表
- 当前输入法标识
- 锁定状态按钮

### 10.3 设置页面
- 多语言切换
- 开机自启开关

---

## 11. 配置与持久化

- 使用 `UserDefaults` 保存：
  - `isLocked`
  - `lockedInputSourceID`
  - `preferredLanguage`
  - `launchAtLogin`

---

## 12. 测试设计

### 12.1 单元测试
- InputMethodManager 输入法枚举逻辑
- LockStateManager 状态切换
- LanguageManager 本地化获取

### 12.2 集成测试
- 输入法切换纠正流程
- 锁定/解锁 UI 状态同步

---

## 13. 风险与应对

- **TIS API 未来失效**：持续关注系统更新，准备迁移方案
- **第三方输入法兼容性**：建立输入法黑名单/白名单机制（后续可扩展）
- **系统通知不稳定**：增加补偿检查（定时校验）

---

## 14. 里程碑对齐

- MVP：输入法枚举 + 锁定 + 菜单栏
- 完善：多语言 + 设置 + 开机自启
- 发布：测试、打包、文档

---

## 15. 原则应用说明

- KISS：锁定状态仅保留 `isLocked` 与 `lockedInputSourceID` 两个核心变量
- YAGNI：不实现输入法配置或统计分析
- DRY：输入法数据模型作为全局唯一结构
- SOLID：UI 层不直接触达 TIS API，全部通过管理器抽象

---

**文档结束**
