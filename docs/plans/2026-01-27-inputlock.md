# InputLock Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建一个 macOS 菜单栏常驻的输入法锁定工具，采用“监听-纠正”模式在锁定时将输入法自动纠正回目标输入法。

**Architecture:** 采用三层结构：SwiftUI UI Layer 仅订阅状态并触发意图；Business Logic Layer（`InputMethodManager`/`LockStateManager`/`LanguageManager`）承载业务；System API Layer 通过可注入协议封装 Carbon TIS 与 `DistributedNotificationCenter`，以便单元测试与解耦。

**Tech Stack:** Swift 6 + SwiftUI（macOS）+ XCTest；System API：Carbon/HIToolbox TIS、DistributedNotificationCenter、ServiceManagement（登录项）。

---

## 0) 先决条件与约定

- 项目根目录为仓库根（当前为 `docs/`），代码放在 `InputLock/` 下（与 PRD 建议结构一致）。
- 使用 Xcode 创建 `InputLock.xcodeproj`，并确保包含：
  - App target：`InputLock`
  - Unit Test target：`InputLockTests`
- 统一使用以下命令跑测试（scheme 名以实际为准，计划中统一写成 `InputLock`）：
  - Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
  - 预期：测试阶段 `** TEST SUCCEEDED **`
- Git（可选但强烈建议）：如果仓库尚未初始化，先 `git init`，后续每个 Task 的“Commit”步骤都能直接执行。

---

### Task 1: 初始化 Xcode 工程与测试目标

**Files:**
- Create: `InputLock/InputLock.xcodeproj`（通过 Xcode GUI 创建）
- Create: `InputLock/InputLockApp.swift`（Xcode 模板生成）
- Create: `InputLockTests/InputLockTests.swift`（Xcode 模板生成）

**Step 1: 写一个可运行的最小测试（先让测试框架跑通）**

```swift
import XCTest

final class InputLockSmokeTests: XCTestCase {
    func test_smoke() {
        XCTAssertTrue(true)
    }
}
```

**Step 2: 跑测试确认环境 OK**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: `** TEST SUCCEEDED **`

**Step 3: （可选）git 初始化**

Run: `git init`
Expected: 初始化成功

**Step 4: Commit**

```bash
git add InputLock InputLockTests
git commit -m "chore: bootstrap Xcode project"
```

---

### Task 2: 增加输入法数据模型 `InputSource`

**Files:**
- Create: `InputLock/Models/InputSource.swift`
- Test: `InputLockTests/Models/InputSourceTests.swift`

**Step 1: 写失败测试（编译失败即可）**

```swift
import XCTest
@testable import InputLock

final class InputSourceTests: XCTestCase {
    func test_initStoresFields() {
        let source = InputSource(id: "com.test.abc", name: "ABC", isSelectable: true, isEnabled: true, icon: nil)
        XCTAssertEqual(source.id, "com.test.abc")
        XCTAssertEqual(source.name, "ABC")
        XCTAssertTrue(source.isSelectable)
        XCTAssertTrue(source.isEnabled)
    }
}
```

**Step 2: 跑测试确认失败**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: FAIL（`InputSource` 未定义 / 编译错误）

**Step 3: 写最小实现**

```swift
import AppKit

struct InputSource: Equatable, Identifiable {
    let id: String
    let name: String
    let isSelectable: Bool
    let isEnabled: Bool
    let icon: NSImage?

    var identifier: String { id }
}
```

**Step 4: 跑测试确认通过**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/Models/InputSource.swift InputLockTests/Models/InputSourceTests.swift
git commit -m "feat: add InputSource model"
```

---

### Task 3: 增加 `LockStateManager`（状态 + UserDefaults 持久化）

**Files:**
- Create: `InputLock/Managers/LockStateManager.swift`
- Create: `InputLock/Managers/UserDefaultsKeys.swift`
- Test: `InputLockTests/Managers/LockStateManagerTests.swift`

**Step 1: 写失败测试（先描述行为）**

```swift
import XCTest
@testable import InputLock

final class LockStateManagerTests: XCTestCase {
    func test_lockAndUnlockPersistToUserDefaults() {
        let defaults = UserDefaults(suiteName: "LockStateManagerTests")!
        defaults.removePersistentDomain(forName: "LockStateManagerTests")

        let manager = LockStateManager(userDefaults: defaults)
        XCTAssertFalse(manager.isLocked)
        XCTAssertNil(manager.lockedInputSourceID)

        manager.lock(to: "com.test.input")
        XCTAssertTrue(manager.isLocked)
        XCTAssertEqual(manager.lockedInputSourceID, "com.test.input")

        let reloaded = LockStateManager(userDefaults: defaults)
        XCTAssertTrue(reloaded.isLocked)
        XCTAssertEqual(reloaded.lockedInputSourceID, "com.test.input")

        reloaded.unlock()
        XCTAssertFalse(reloaded.isLocked)
        XCTAssertNil(reloaded.lockedInputSourceID)
    }
}
```

**Step 2: 跑测试确认失败**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: FAIL（`LockStateManager` 未定义 / 编译错误）

**Step 3: 写最小实现（可注入 UserDefaults）**

`InputLock/Managers/UserDefaultsKeys.swift`
```swift
enum UserDefaultsKeys {
    static let isLocked = "isLocked"
    static let lockedInputSourceID = "lockedInputSourceID"
    static let preferredLanguage = "preferredLanguage"
    static let launchAtLogin = "launchAtLogin"
}
```

`InputLock/Managers/LockStateManager.swift`
```swift
import Foundation

final class LockStateManager: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published private(set) var lockedInputSourceID: String?

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isLocked = userDefaults.bool(forKey: UserDefaultsKeys.isLocked)
        self.lockedInputSourceID = userDefaults.string(forKey: UserDefaultsKeys.lockedInputSourceID)
    }

    func lock(to inputSourceID: String) {
        isLocked = true
        lockedInputSourceID = inputSourceID
        userDefaults.set(true, forKey: UserDefaultsKeys.isLocked)
        userDefaults.set(inputSourceID, forKey: UserDefaultsKeys.lockedInputSourceID)
    }

    func unlock() {
        isLocked = false
        lockedInputSourceID = nil
        userDefaults.set(false, forKey: UserDefaultsKeys.isLocked)
        userDefaults.removeObject(forKey: UserDefaultsKeys.lockedInputSourceID)
    }
}
```

**Step 4: 跑测试确认通过**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/Managers/UserDefaultsKeys.swift InputLock/Managers/LockStateManager.swift InputLockTests/Managers/LockStateManagerTests.swift
git commit -m "feat: persist lock state"
```

---

### Task 4: 封装 System API：定义 `TISClient` 协议 + Fake（为 TDD 做准备）

**Files:**
- Create: `InputLock/System/TISClient.swift`
- Create: `InputLock/System/FakeTISClient.swift`（仅用于 Debug/Tests 也可放到 Tests 目录）
- Test: `InputLockTests/System/FakeTISClientTests.swift`

**Step 1: 写失败测试（确保 Fake 行为稳定）**

```swift
import XCTest
@testable import InputLock

final class FakeTISClientTests: XCTestCase {
    func test_selectChangesCurrentID() {
        let fake = FakeTISClient(inputSources: [
            .init(id: "a", name: "A", isSelectable: true, isEnabled: true, icon: nil),
            .init(id: "b", name: "B", isSelectable: true, isEnabled: true, icon: nil)
        ], currentID: "a")

        XCTAssertEqual(fake.currentInputSourceID(), "a")
        XCTAssertTrue(fake.selectInputSource(id: "b"))
        XCTAssertEqual(fake.currentInputSourceID(), "b")
    }
}
```

**Step 2: 跑测试确认失败**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: FAIL（`FakeTISClient` 未定义）

**Step 3: 写最小实现（协议 + Fake）**

`InputLock/System/TISClient.swift`
```swift
protocol TISClient {
    func listInputSources() -> [InputSource]
    func currentInputSourceID() -> String?
    func selectInputSource(id: String) -> Bool
}
```

`InputLock/System/FakeTISClient.swift`
```swift
final class FakeTISClient: TISClient {
    private var sources: [InputSource]
    private var currentIDValue: String?

    init(inputSources: [InputSource], currentID: String?) {
        self.sources = inputSources
        self.currentIDValue = currentID
    }

    func listInputSources() -> [InputSource] {
        sources
    }

    func currentInputSourceID() -> String? {
        currentIDValue
    }

    func selectInputSource(id: String) -> Bool {
        guard sources.contains(where: { $0.id == id }) else { return false }
        currentIDValue = id
        return true
    }
}
```

**Step 4: 跑测试确认通过**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/System/TISClient.swift InputLock/System/FakeTISClient.swift InputLockTests/System/FakeTISClientTests.swift
git commit -m "test: add TISClient fake"
```

---

### Task 5: 实现 `InputMethodManager`（输入法枚举 + 当前输入法）

**Files:**
- Create: `InputLock/Managers/InputMethodManager.swift`
- Test: `InputLockTests/Managers/InputMethodManagerTests.swift`

**Step 1: 写失败测试（依赖 FakeTISClient）**

```swift
import XCTest
@testable import InputLock

final class InputMethodManagerTests: XCTestCase {
    func test_enumerateReturnsClientList() {
        let fake = FakeTISClient(inputSources: [
            .init(id: "a", name: "A", isSelectable: true, isEnabled: true, icon: nil),
            .init(id: "b", name: "B", isSelectable: true, isEnabled: true, icon: nil)
        ], currentID: "a")

        let manager = InputMethodManager(tis: fake)
        XCTAssertEqual(manager.enumerateInputSources().map(\.id), ["a", "b"])
    }

    func test_getCurrentReturnsCurrentByID() {
        let fake = FakeTISClient(inputSources: [
            .init(id: "a", name: "A", isSelectable: true, isEnabled: true, icon: nil)
        ], currentID: "a")

        let manager = InputMethodManager(tis: fake)
        XCTAssertEqual(manager.getCurrentInputSource()?.id, "a")
    }
}
```

**Step 2: 跑测试确认失败**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: FAIL（`InputMethodManager` 未定义）

**Step 3: 写最小实现**

```swift
final class InputMethodManager {
    private let tis: TISClient

    init(tis: TISClient) {
        self.tis = tis
    }

    func enumerateInputSources() -> [InputSource] {
        tis.listInputSources()
    }

    func getCurrentInputSource() -> InputSource? {
        guard let id = tis.currentInputSourceID() else { return nil }
        return tis.listInputSources().first(where: { $0.id == id })
    }

    @discardableResult
    func selectInputSource(_ id: String) -> Bool {
        tis.selectInputSource(id: id)
    }
}
```

**Step 4: 跑测试确认通过**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/Managers/InputMethodManager.swift InputLockTests/Managers/InputMethodManagerTests.swift
git commit -m "feat: add InputMethodManager core"
```

---

### Task 6: 监听系统输入法变化（抽象通知中心，便于测试）

**Files:**
- Create: `InputLock/System/NotificationCenterClient.swift`
- Create: `InputLock/System/FakeNotificationCenterClient.swift`
- Modify: `InputLock/Managers/InputMethodManager.swift`
- Test: `InputLockTests/System/FakeNotificationCenterClientTests.swift`
- Test: `InputLockTests/Managers/InputMethodManagerObservationTests.swift`

**Step 1: 写失败测试（模拟发送“输入法变化”事件）**

```swift
import XCTest
@testable import InputLock

final class InputMethodManagerObservationTests: XCTestCase {
    func test_observerInvokesCallback() {
        let tis = FakeTISClient(inputSources: [], currentID: nil)
        let notifications = FakeNotificationCenterClient()
        let manager = InputMethodManager(tis: tis, notifications: notifications)

        let exp = expectation(description: "callback")
        manager.startObservingInputSourceChanges {
            exp.fulfill()
        }

        notifications.post(name: .tisSelectedKeyboardInputSourceChanged)
        wait(for: [exp], timeout: 1.0)
    }
}
```

**Step 2: 跑测试确认失败**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: FAIL（通知抽象未实现 / API 不匹配）

**Step 3: 写最小实现（通知抽象 + manager 注入）**

`InputLock/System/NotificationCenterClient.swift`
```swift
import Foundation

protocol NotificationCenterClient {
    @discardableResult
    func addObserver(forName name: Notification.Name, using block: @escaping () -> Void) -> AnyObject
    func post(name: Notification.Name)
}

extension Notification.Name {
    static let tisSelectedKeyboardInputSourceChanged = Notification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged")
}
```

`InputLock/System/FakeNotificationCenterClient.swift`
```swift
import Foundation

final class FakeNotificationCenterClient: NotificationCenterClient {
    private var observers: [Notification.Name: [() -> Void]] = [:]

    func addObserver(forName name: Notification.Name, using block: @escaping () -> Void) -> AnyObject {
        observers[name, default: []].append(block)
        return NSObject()
    }

    func post(name: Notification.Name) {
        observers[name, default: []].forEach { $0() }
    }
}
```

修改 `InputLock/Managers/InputMethodManager.swift`：
```swift
final class InputMethodManager {
    private let tis: TISClient
    private let notifications: NotificationCenterClient

    init(tis: TISClient, notifications: NotificationCenterClient = DistributedNotificationCenterAdapter()) {
        self.tis = tis
        self.notifications = notifications
    }

    func startObservingInputSourceChanges(onChange: @escaping () -> Void) {
        _ = notifications.addObserver(forName: .tisSelectedKeyboardInputSourceChanged) {
            onChange()
        }
    }

    // ...（保留之前方法）
}
```

并新增 `DistributedNotificationCenterAdapter`：
```swift
import Foundation

final class DistributedNotificationCenterAdapter: NotificationCenterClient {
    func addObserver(forName name: Notification.Name, using block: @escaping () -> Void) -> AnyObject {
        let center = DistributedNotificationCenter.default()
        return center.addObserver(forName: name, object: nil, queue: .main) { _ in
            block()
        } as AnyObject
    }

    func post(name: Notification.Name) {
        DistributedNotificationCenter.default().post(name: name, object: nil)
    }
}
```

**Step 4: 跑测试确认通过**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/System/NotificationCenterClient.swift InputLock/System/FakeNotificationCenterClient.swift InputLock/Managers/InputMethodManager.swift InputLockTests/System/FakeNotificationCenterClientTests.swift InputLockTests/Managers/InputMethodManagerObservationTests.swift
git commit -m "test: observe input source changes"
```

---

### Task 7: 实现“监听-纠正”逻辑（50ms 延迟，可注入 Scheduler）

**Files:**
- Create: `InputLock/System/Scheduler.swift`
- Modify: `InputLock/Managers/InputMethodManager.swift`
- Test: `InputLockTests/System/ImmediateSchedulerTests.swift`
- Test: `InputLockTests/Managers/InputMethodManagerCorrectionTests.swift`

**Step 1: 写失败测试（锁定时不一致会纠正）**

```swift
import XCTest
@testable import InputLock

final class InputMethodManagerCorrectionTests: XCTestCase {
    func test_whenLockedAndMismatch_correctsBackAfterDelay() {
        let tis = FakeTISClient(inputSources: [
            .init(id: "a", name: "A", isSelectable: true, isEnabled: true, icon: nil),
            .init(id: "b", name: "B", isSelectable: true, isEnabled: true, icon: nil)
        ], currentID: "b")

        let scheduler = ImmediateScheduler()
        let manager = InputMethodManager(tis: tis, scheduler: scheduler)

        manager.correctIfNeeded(isLocked: true, lockedID: "a")
        XCTAssertEqual(tis.currentInputSourceID(), "a")
    }

    func test_whenUnlocked_noCorrection() {
        let tis = FakeTISClient(inputSources: [
            .init(id: "a", name: "A", isSelectable: true, isEnabled: true, icon: nil),
            .init(id: "b", name: "B", isSelectable: true, isEnabled: true, icon: nil)
        ], currentID: "b")

        let scheduler = ImmediateScheduler()
        let manager = InputMethodManager(tis: tis, scheduler: scheduler)

        manager.correctIfNeeded(isLocked: false, lockedID: "a")
        XCTAssertEqual(tis.currentInputSourceID(), "b")
    }
}
```

**Step 2: 跑测试确认失败**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: FAIL（`Scheduler`/`correctIfNeeded` 未实现）

**Step 3: 写最小实现（Scheduler 抽象 + 50ms 默认实现）**

`InputLock/System/Scheduler.swift`
```swift
import Foundation

protocol Scheduler {
    func after(_ delay: TimeInterval, _ block: @escaping () -> Void)
}

final class MainQueueScheduler: Scheduler {
    func after(_ delay: TimeInterval, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
    }
}

final class ImmediateScheduler: Scheduler {
    func after(_ delay: TimeInterval, _ block: @escaping () -> Void) {
        block()
    }
}
```

修改 `InputLock/Managers/InputMethodManager.swift`：
```swift
final class InputMethodManager {
    private let tis: TISClient
    private let scheduler: Scheduler

    init(tis: TISClient, scheduler: Scheduler = MainQueueScheduler(), notifications: NotificationCenterClient = DistributedNotificationCenterAdapter()) {
        self.tis = tis
        self.scheduler = scheduler
        self.notifications = notifications
    }

    func correctIfNeeded(isLocked: Bool, lockedID: String?) {
        guard isLocked, let lockedID else { return }
        guard tis.currentInputSourceID() != lockedID else { return }

        scheduler.after(0.05) { [tis] in
            _ = tis.selectInputSource(id: lockedID)
        }
    }
}
```

**Step 4: 跑测试确认通过**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/System/Scheduler.swift InputLock/Managers/InputMethodManager.swift InputLockTests/Managers/InputMethodManagerCorrectionTests.swift
git commit -m "feat: add listen-correct behavior"
```

---

### Task 8: 建立应用级状态聚合（UI 只订阅状态）

**Files:**
- Create: `InputLock/AppState/AppState.swift`
- Modify: `InputLock/InputLockApp.swift`
- Test: `InputLockTests/AppState/AppStateTests.swift`

**Step 1: 写失败测试（锁定会触发纠正调用路径）**

```swift
import XCTest
@testable import InputLock

final class AppStateTests: XCTestCase {
    func test_selectInputSourceLocksAndRequestsCorrectionOnChange() {
        let tis = FakeTISClient(inputSources: [
            .init(id: "a", name: "A", isSelectable: true, isEnabled: true, icon: nil),
            .init(id: "b", name: "B", isSelectable: true, isEnabled: true, icon: nil)
        ], currentID: "b")
        let notifications = FakeNotificationCenterClient()
        let scheduler = ImmediateScheduler()

        let state = AppState(
            inputMethods: InputMethodManager(tis: tis, scheduler: scheduler, notifications: notifications),
            lockState: LockStateManager(userDefaults: UserDefaults(suiteName: "AppStateTests")!),
            language: LanguageManager(userDefaults: UserDefaults(suiteName: "AppStateTests")!)
        )

        state.selectAndLock(id: "a")
        notifications.post(name: .tisSelectedKeyboardInputSourceChanged)

        XCTAssertEqual(tis.currentInputSourceID(), "a")
    }
}
```

**Step 2: 跑测试确认失败**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: FAIL（`AppState`/`LanguageManager` 未定义）

**Step 3: 写最小实现（先做最薄的粘合层）**

`InputLock/AppState/AppState.swift`
```swift
import Foundation

@MainActor
final class AppState: ObservableObject {
    let inputMethods: InputMethodManager
    let lockState: LockStateManager
    let language: LanguageManager

    @Published private(set) var inputSources: [InputSource] = []

    init(inputMethods: InputMethodManager, lockState: LockStateManager, language: LanguageManager) {
        self.inputMethods = inputMethods
        self.lockState = lockState
        self.language = language

        refreshInputSources()
        inputMethods.startObservingInputSourceChanges { [weak self] in
            guard let self else { return }
            self.inputMethods.correctIfNeeded(isLocked: self.lockState.isLocked, lockedID: self.lockState.lockedInputSourceID)
        }
    }

    func refreshInputSources() {
        inputSources = inputMethods.enumerateInputSources()
    }

    func selectAndLock(id: String) {
        _ = inputMethods.selectInputSource(id)
        lockState.lock(to: id)
    }

    func toggleLockOff() {
        lockState.unlock()
    }
}
```

（`LanguageManager` 在下一 Task 实现；此 Task 可先用最小 stub 让编译通过。）

**Step 4: 跑测试确认通过**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/AppState/AppState.swift InputLockTests/AppState/AppStateTests.swift
git commit -m "feat: add AppState aggregator"
```

---

### Task 9: 实现 `LanguageManager`（系统语言跟随 + 手动选择 + 持久化）

**Files:**
- Create: `InputLock/Managers/LanguageManager.swift`
- Test: `InputLockTests/Managers/LanguageManagerTests.swift`

**Step 1: 写失败测试（偏好语言持久化）**

```swift
import XCTest
@testable import InputLock

final class LanguageManagerTests: XCTestCase {
    func test_preferredLanguagePersists() {
        let defaults = UserDefaults(suiteName: "LanguageManagerTests")!
        defaults.removePersistentDomain(forName: "LanguageManagerTests")

        let manager = LanguageManager(userDefaults: defaults)
        XCTAssertNil(manager.preferredLanguage)

        manager.setPreferredLanguage("en")
        let reloaded = LanguageManager(userDefaults: defaults)
        XCTAssertEqual(reloaded.preferredLanguage, "en")
    }
}
```

**Step 2: 跑测试确认失败**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: FAIL（`LanguageManager` 未定义）

**Step 3: 写最小实现**

```swift
import Foundation

final class LanguageManager: ObservableObject {
    @Published private(set) var preferredLanguage: String?
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.preferredLanguage = userDefaults.string(forKey: UserDefaultsKeys.preferredLanguage)
    }

    func setPreferredLanguage(_ code: String?) {
        preferredLanguage = code
        if let code {
            userDefaults.set(code, forKey: UserDefaultsKeys.preferredLanguage)
        } else {
            userDefaults.removeObject(forKey: UserDefaultsKeys.preferredLanguage)
        }
    }
}
```

**Step 4: 跑测试确认通过**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' test`
Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/Managers/LanguageManager.swift InputLockTests/Managers/LanguageManagerTests.swift
git commit -m "feat: add LanguageManager"
```

---

### Task 10: 构建菜单栏 UI（MVP：列表 + 点击锁定 + 显示🔓/🔒）

**Files:**
- Create: `InputLock/Views/MenuBarView.swift`
- Create: `InputLock/Views/MainPanelView.swift`
- Modify: `InputLock/InputLockApp.swift`

**Step 1: 写一个最小可编译的 SwiftUI View（先让构建通过）**

`InputLock/Views/MainPanelView.swift`
```swift
import SwiftUI

struct MainPanelView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("InputLock")
                .font(.headline)

            ForEach(state.inputSources) { source in
                Button(source.name) {
                    state.selectAndLock(id: source.id)
                }
            }

            Divider()

            HStack {
                Text(state.lockState.isLocked ? "🔒" : "🔓")
                Spacer()
                Button(state.lockState.isLocked ? "解锁" : "锁定") {
                    if state.lockState.isLocked {
                        state.toggleLockOff()
                    }
                }
                .disabled(!state.lockState.isLocked)
            }
        }
        .padding(12)
        .frame(minWidth: 260)
    }
}
```

`InputLock/Views/MenuBarView.swift`
```swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var state: AppState

    var body: some View {
        MainPanelView(state: state)
    }
}
```

**Step 2: 在 App 入口接入 MenuBarExtra**

修改 `InputLock/InputLockApp.swift`（核心片段）：
```swift
@main
struct InputLockApp: App {
    @StateObject private var state = AppState(
        inputMethods: InputMethodManager(tis: CarbonTISClient()),
        lockState: LockStateManager(),
        language: LanguageManager()
    )

    var body: some Scene {
        MenuBarExtra(state.lockState.isLocked ? "🔒" : "🔓") {
            MenuBarView(state: state)
        }
    }
}
```

**Step 3: Build & 手工验证**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`

手工验证：运行 App → 菜单栏出现 🔓 → 点击展开列表 → 点某个输入法后变 🔒。

**Step 4: Commit**

```bash
git add InputLock/InputLockApp.swift InputLock/Views/MenuBarView.swift InputLock/Views/MainPanelView.swift
git commit -m "feat: add menu bar MVP UI"
```

---

### Task 11: 接入真实 Carbon TIS（`CarbonTISClient`）

**Files:**
- Create: `InputLock/System/CarbonTISClient.swift`
- Modify: `InputLock/InputLockApp.swift`（若尚未替换）

**Step 1: 写一个最小实现（先能枚举 + 当前 + 选择）**

```swift
import Carbon
import AppKit

final class CarbonTISClient: TISClient {
    func listInputSources() -> [InputSource] {
        guard let unmanaged = TISCreateInputSourceList(nil, false) else { return [] }
        let list = unmanaged.takeRetainedValue() as NSArray

        return list.compactMap { item in
            guard let tis = item as? TISInputSource else { return nil }

            let id = (TISGetInputSourceProperty(tis, kTISPropertyInputSourceID) as? String) ?? ""
            let name = (TISGetInputSourceProperty(tis, kTISPropertyLocalizedName) as? String) ?? id
            let selectable = (TISGetInputSourceProperty(tis, kTISPropertyInputSourceIsSelectCapable) as? Bool) ?? true
            let enabled = (TISGetInputSourceProperty(tis, kTISPropertyInputSourceIsEnabled) as? Bool) ?? true

            return InputSource(id: id, name: name, isSelectable: selectable, isEnabled: enabled, icon: nil)
        }
    }

    func currentInputSourceID() -> String? {
        guard let tis = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return TISGetInputSourceProperty(tis, kTISPropertyInputSourceID) as? String
    }

    func selectInputSource(id: String) -> Bool {
        let properties = [kTISPropertyInputSourceID.takeUnretainedValue() as String: id] as NSDictionary
        guard let unmanaged = TISCreateInputSourceList(properties, false) else { return false }
        let list = unmanaged.takeRetainedValue() as NSArray
        guard let tis = list.firstObject as? TISInputSource else { return false }
        return TISSelectInputSource(tis) == noErr
    }
}
```

**Step 2: 手工验证（真实机器）**

运行 App → 列表显示真实输入法 → 点击切换成功。

**Step 3: Commit**

```bash
git add InputLock/System/CarbonTISClient.swift InputLock/InputLockApp.swift
git commit -m "feat: integrate Carbon TIS client"
```

---

### Task 12: 多语言资源与设置页（P0）

**Files:**
- Create: `InputLock/Views/SettingsView.swift`
- Create: `InputLock/Resources/en.lproj/Localizable.strings`
- Create: `InputLock/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `InputLock/InputLockApp.swift`（挂 Settings 场景）

**Step 1: 添加最小 Localizable keys**

`InputLock/Resources/en.lproj/Localizable.strings`
```text
"app.title" = "InputLock";
"action.unlock" = "Unlock";
"action.lock" = "Lock";
"settings.language" = "Language";
"settings.launchAtLogin" = "Launch at login";
```

`InputLock/Resources/zh-Hans.lproj/Localizable.strings`
```text
"app.title" = "InputLock";
"action.unlock" = "解锁";
"action.lock" = "锁定";
"settings.language" = "语言";
"settings.launchAtLogin" = "开机自启";
```

**Step 2: SettingsView 最小实现**

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            Picker(String(localized: "settings.language"), selection: Binding(
                get: { state.language.preferredLanguage ?? "" },
                set: { state.language.setPreferredLanguage($0.isEmpty ? nil : $0) }
            )) {
                Text("System").tag("")
                Text("English").tag("en")
                Text("简体中文").tag("zh-Hans")
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}
```

**Step 3: App 中增加 Settings Scene**

修改 `InputLock/InputLockApp.swift`：
```swift
var body: some Scene {
    MenuBarExtra(state.lockState.isLocked ? "🔒" : "🔓") {
        MenuBarView(state: state)
    }

    Settings {
        SettingsView(state: state)
    }
}
```

**Step 4: Build & 手工验证**

Run: `xcodebuild -scheme InputLock -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`

手工验证：打开 Settings，切换语言后 UI 文案变化（如需完全强制切换语言，可在后续迭代补齐 app-level bundle 切换）。

**Step 5: Commit**

```bash
git add InputLock/Views/SettingsView.swift InputLock/Resources/en.lproj/Localizable.strings InputLock/Resources/zh-Hans.lproj/Localizable.strings InputLock/InputLockApp.swift
git commit -m "feat: add settings and localization resources"
```

---

### Task 13: 开机自启（P1，基于 ServiceManagement）

**Files:**
- Create/Modify: `InputLock/Managers/LaunchAtLoginManager.swift`
- Modify: `InputLock/Views/SettingsView.swift`
- Test: `InputLockTests/Managers/LaunchAtLoginManagerTests.swift`（以协议注入方式测试）

**Step 1: 定义 `LaunchAtLoginClient` 协议并写失败测试**

```swift
import XCTest
@testable import InputLock

final class LaunchAtLoginManagerTests: XCTestCase {
    func test_togglePersistsPreference() {
        let defaults = UserDefaults(suiteName: "LaunchAtLoginManagerTests")!
        defaults.removePersistentDomain(forName: "LaunchAtLoginManagerTests")

        let client = FakeLaunchAtLoginClient()
        let manager = LaunchAtLoginManager(client: client, userDefaults: defaults)

        XCTAssertFalse(manager.isEnabled)
        manager.setEnabled(true)
        XCTAssertTrue(manager.isEnabled)

        let reloaded = LaunchAtLoginManager(client: client, userDefaults: defaults)
        XCTAssertTrue(reloaded.isEnabled)
    }
}
```

**Step 2: 实现 manager（最小：持久化 + 调 client）**

```swift
import Foundation

protocol LaunchAtLoginClient {
    func setEnabled(_ enabled: Bool) throws
}

final class FakeLaunchAtLoginClient: LaunchAtLoginClient {
    private(set) var lastEnabled: Bool?
    func setEnabled(_ enabled: Bool) throws { lastEnabled = enabled }
}

final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled: Bool

    private let client: LaunchAtLoginClient
    private let userDefaults: UserDefaults

    init(client: LaunchAtLoginClient, userDefaults: UserDefaults = .standard) {
        self.client = client
        self.userDefaults = userDefaults
        self.isEnabled = userDefaults.bool(forKey: UserDefaultsKeys.launchAtLogin)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        userDefaults.set(enabled, forKey: UserDefaultsKeys.launchAtLogin)
        try? client.setEnabled(enabled)
    }
}
```

**Step 3: 真实 client（后续接入 SMAppService）**

```swift
import ServiceManagement

final class ServiceManagementLaunchAtLoginClient: LaunchAtLoginClient {
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

**Step 4: SettingsView 增加 Toggle**

```swift
Toggle(String(localized: "settings.launchAtLogin"), isOn: Binding(
    get: { state.launchAtLogin.isEnabled },
    set: { state.launchAtLogin.setEnabled($0) }
))
```

**Step 5: Build & 手工验证**

运行 App → Settings 打开 → 开机自启开关切换后，系统登录项状态随之变化。

**Step 6: Commit**

```bash
git add InputLock/Managers/LaunchAtLoginManager.swift InputLock/Views/SettingsView.swift InputLockTests/Managers/LaunchAtLoginManagerTests.swift
git commit -m "feat: add launch at login toggle"
```

---

## 执行交接

计划已保存到 `docs/plans/2026-01-27-inputlock.md`。两种执行方式：

1. **Subagent-Driven（本会话）**：我在本会话按 Task 逐个派发子代理实现，每个 Task 完成后复核，再进入下一个。
   - REQUIRED SUB-SKILL: 使用 superpowers:subagent-driven-development

2. **Parallel Session（新会话）**：在单独会话/工作树中用 `@superpowers:executing-plans` 按任务逐步执行并设置检查点。

你选哪一种？
