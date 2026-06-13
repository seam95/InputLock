# InputLock MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建一个 macOS 菜单栏常驻应用，提供“输入法一键锁定 + 监听-纠正自动切回（50ms）”，并持久化锁定状态。

**Architecture:** 采用分层结构（UI / 业务 / 系统 API）。业务层通过协议封装 TIS/通知等系统依赖，使核心逻辑可用 XCTest 单测；UI 只订阅状态并触发意图（选择输入法、锁定/解锁）。

**Tech Stack:** Swift 6、SwiftUI、XCTest、Carbon/HIToolbox (TIS API)、DistributedNotificationCenter、UserDefaults。

---

## Preconditions / Repo Notes

- 当前目录仅包含 `docs/`，尚未看到任何 Swift/Xcode 工程文件（未发现 `.xcodeproj` / `Package.swift` / `*.swift`）。本计划包含从零创建工程的步骤。
- 该目录目前不是 git 仓库（`Is directory a git repo: No`）。计划中包含 `git` 提交步骤；若你希望执行这些步骤，请先初始化仓库：
  - Run: `git init`
  - Expected: 输出初始化提示（例如 "Initialized empty Git repository ..."）

## Reference Docs

- `docs/DESIGN.md`
- `docs/PRD.md`

---

### Task 1: Scaffold macOS Menu Bar App

**Files:**
- Create: `InputLock.xcodeproj`（Xcode 自动生成）
- Create: `InputLock/InputLockApp.swift`
- Create: `InputLock/ContentView.swift`

**Step 1: Create Xcode project**

- Action (GUI): Xcode → File → New → Project… → macOS → App
  - Product Name: `InputLock`
  - Interface: `SwiftUI`
  - Language: `Swift`
  - Bundle Identifier: 任选（例如 `com.example.InputLock`）
  - Save Location: 仓库根目录（使 `.xcodeproj` 位于 `./InputLock.xcodeproj`）

**Step 2: Verify build succeeds**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -configuration Debug build`

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add InputLock.xcodeproj InputLock

git commit -m "chore: scaffold InputLock macOS app"
```

---

### Task 2: Define Core Model `InputSource`

**Files:**
- Create: `InputLock/Models/InputSource.swift`
- Test: `InputLockTests/InputSourceTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import InputLock

final class InputSourceTests: XCTestCase {
    func testInitStoresFields() {
        let source = InputSource(id: "com.apple.keylayout.US", name: "U.S.", isSelectable: true, isEnabled: true)
        XCTAssertEqual(source.id, "com.apple.keylayout.US")
        XCTAssertEqual(source.name, "U.S.")
        XCTAssertTrue(source.isSelectable)
        XCTAssertTrue(source.isEnabled)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`

Expected: FAIL（例如 `Cannot find 'InputSource' in scope`）

**Step 3: Write minimal implementation**

```swift
import Foundation

struct InputSource: Equatable, Identifiable {
    let id: String
    let name: String
    let isSelectable: Bool
    let isEnabled: Bool

    var identifier: String { id }
}
```

> 注：SwiftUI 的 `Identifiable` 需要 `id` 属性；这里直接用输入法 `id`。

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`

Expected: PASS（`** TEST SUCCEEDED **`）

**Step 5: Commit**

```bash
git add InputLock/Models/InputSource.swift InputLockTests/InputSourceTests.swift

git commit -m "feat: add InputSource model"
```

---

### Task 3: Add `LockStateManager` (state + persistence)

**Files:**
- Create: `InputLock/Managers/LockStateManager.swift`
- Test: `InputLockTests/LockStateManagerTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import InputLock

final class LockStateManagerTests: XCTestCase {
    func testLockAndUnlock() {
        let store = InMemoryKeyValueStore()
        let manager = LockStateManager(store: store)

        XCTAssertFalse(manager.isLocked)
        XCTAssertNil(manager.lockedInputSourceID)

        manager.lock(to: "com.apple.keylayout.US")
        XCTAssertTrue(manager.isLocked)
        XCTAssertEqual(manager.lockedInputSourceID, "com.apple.keylayout.US")

        manager.unlock()
        XCTAssertFalse(manager.isLocked)
        XCTAssertNil(manager.lockedInputSourceID)
    }
}

final class InMemoryKeyValueStore: KeyValueStore {
    private var storage: [String: Any] = [:]

    func bool(forKey key: String) -> Bool { storage[key] as? Bool ?? false }
    func string(forKey key: String) -> String? { storage[key] as? String }
    func set(_ value: Any?, forKey key: String) { storage[key] = value }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`

Expected: FAIL（例如 `Cannot find 'LockStateManager' in scope`）

**Step 3: Write minimal implementation**

```swift
import Foundation

protocol KeyValueStore {
    func bool(forKey key: String) -> Bool
    func string(forKey key: String) -> String?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: KeyValueStore {
    func set(_ value: Any?, forKey key: String) {
        self.set(value, forKey: key)
    }
}

final class LockStateManager: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published private(set) var lockedInputSourceID: String?

    private let store: KeyValueStore

    private enum Keys {
        static let isLocked = "isLocked"
        static let lockedInputSourceID = "lockedInputSourceID"
    }

    init(store: KeyValueStore = UserDefaults.standard) {
        self.store = store
        self.isLocked = store.bool(forKey: Keys.isLocked)
        self.lockedInputSourceID = store.string(forKey: Keys.lockedInputSourceID)
    }

    func lock(to inputSourceID: String) {
        isLocked = true
        lockedInputSourceID = inputSourceID
        store.set(true, forKey: Keys.isLocked)
        store.set(inputSourceID, forKey: Keys.lockedInputSourceID)
    }

    func unlock() {
        isLocked = false
        lockedInputSourceID = nil
        store.set(false, forKey: Keys.isLocked)
        store.set(nil, forKey: Keys.lockedInputSourceID)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`

Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/Managers/LockStateManager.swift InputLockTests/LockStateManagerTests.swift

git commit -m "feat: add LockStateManager with persistence"
```

---

### Task 4: Add System Abstractions for TIS + Notifications

**Files:**
- Create: `InputLock/System/TextInputSourceClient.swift`
- Create: `InputLock/System/InputSourceChangeNotifier.swift`
- Test: `InputLockTests/Fakes/SystemFakes.swift`

**Step 1: Write the failing test (compilation-level)**

```swift
import XCTest
@testable import InputLock

final class SystemAbstractionsCompileTests: XCTestCase {
    func testTypesExist() {
        _ = FakeTextInputSourceClient()
        _ = FakeInputSourceChangeNotifier()
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`

Expected: FAIL（缺少类型定义）

**Step 3: Write minimal implementation**

`TextInputSourceClient.swift`:

```swift
import Foundation

protocol TextInputSourceClient {
    func listInputSources() -> [InputSource]
    func currentInputSourceID() -> String?
    @discardableResult func selectInputSource(id: String) -> Bool
}
```

`InputSourceChangeNotifier.swift`:

```swift
import Foundation

protocol InputSourceChangeNotifier {
    func start(_ handler: @escaping () -> Void)
    func stop()
}
```

`SystemFakes.swift`:

```swift
import Foundation
@testable import InputLock

final class FakeTextInputSourceClient: TextInputSourceClient {
    var sources: [InputSource] = []
    var currentID: String?
    var selectedIDs: [String] = []

    func listInputSources() -> [InputSource] { sources }
    func currentInputSourceID() -> String? { currentID }
    func selectInputSource(id: String) -> Bool {
        selectedIDs.append(id)
        currentID = id
        return true
    }
}

final class FakeInputSourceChangeNotifier: InputSourceChangeNotifier {
    private var handler: (() -> Void)?

    func start(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    func stop() {
        handler = nil
    }

    func emitChange() {
        handler?()
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`

Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/System/TextInputSourceClient.swift InputLock/System/InputSourceChangeNotifier.swift InputLockTests/Fakes/SystemFakes.swift InputLockTests/SystemAbstractionsCompileTests.swift

git commit -m "feat: add system abstraction protocols"
```

---

### Task 5: Implement `InputMethodManager` (business core)

**Files:**
- Create: `InputLock/Managers/InputMethodManager.swift`
- Test: `InputLockTests/InputMethodManagerTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import InputLock

final class InputMethodManagerTests: XCTestCase {
    func testEnumerateReturnsClientSources() {
        let client = FakeTextInputSourceClient()
        client.sources = [
            InputSource(id: "a", name: "A", isSelectable: true, isEnabled: true),
            InputSource(id: "b", name: "B", isSelectable: true, isEnabled: true)
        ]

        let notifier = FakeInputSourceChangeNotifier()
        let manager = InputMethodManager(client: client, notifier: notifier)

        XCTAssertEqual(manager.enumerateInputSources(), client.sources)
    }

    func testObserveTriggersCorrectionWhenLockedAndDifferent() {
        let client = FakeTextInputSourceClient()
        client.currentID = "other"

        let notifier = FakeInputSourceChangeNotifier()
        let lockState = LockStateManager(store: InMemoryKeyValueStore())
        lockState.lock(to: "target")

        let manager = InputMethodManager(client: client, notifier: notifier)
        manager.startObservingInputSourceChanges(lockState: lockState, correctionDelay: 0)

        notifier.emitChange()

        XCTAssertEqual(client.selectedIDs, ["target"]) // should correct
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`

Expected: FAIL（缺少 `InputMethodManager` / 方法签名不匹配）

**Step 3: Write minimal implementation**

```swift
import Foundation

final class InputMethodManager {
    private let client: TextInputSourceClient
    private let notifier: InputSourceChangeNotifier

    init(client: TextInputSourceClient, notifier: InputSourceChangeNotifier) {
        self.client = client
        self.notifier = notifier
    }

    func enumerateInputSources() -> [InputSource] {
        client.listInputSources()
    }

    func getCurrentInputSourceID() -> String? {
        client.currentInputSourceID()
    }

    @discardableResult
    func selectInputSource(_ id: String) -> Bool {
        client.selectInputSource(id: id)
    }

    func startObservingInputSourceChanges(
        lockState: LockStateManager,
        correctionDelay: TimeInterval = 0.05
    ) {
        notifier.start { [weak self, weak lockState] in
            guard let self, let lockState else { return }
            self.handleInputSourceChange(lockState: lockState, correctionDelay: correctionDelay)
        }
    }

    private func handleInputSourceChange(lockState: LockStateManager, correctionDelay: TimeInterval) {
        guard lockState.isLocked, let target = lockState.lockedInputSourceID else { return }
        guard getCurrentInputSourceID() != target else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + correctionDelay) { [weak self] in
            _ = self?.selectInputSource(target)
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`

Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/Managers/InputMethodManager.swift InputLockTests/InputMethodManagerTests.swift

git commit -m "feat: add InputMethodManager with correction logic"
```

---

### Task 6: Implement Real macOS Clients (TIS + DistributedNotificationCenter)

**Files:**
- Create: `InputLock/System/MacTextInputSourceClient.swift`
- Create: `InputLock/System/MacInputSourceChangeNotifier.swift`

**Step 1: Write the failing test (smoke compile)**

```swift
import XCTest
@testable import InputLock

final class MacClientsCompileTests: XCTestCase {
    func testClientsConstruct() {
        _ = MacTextInputSourceClient()
        _ = MacInputSourceChangeNotifier()
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`

Expected: FAIL（缺少实现）

**Step 3: Write minimal implementation**

`MacTextInputSourceClient.swift`:

```swift
import Carbon
import Foundation

final class MacTextInputSourceClient: TextInputSourceClient {
    func listInputSources() -> [InputSource] {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }

        return list.compactMap { src in
            let id = (TISGetInputSourceProperty(src, kTISPropertyInputSourceID) as? NSString) as String?
            let name = (TISGetInputSourceProperty(src, kTISPropertyLocalizedName) as? NSString) as String?
            let selectable = (TISGetInputSourceProperty(src, kTISPropertyInputSourceIsSelectCapable) as? NSNumber)?.boolValue ?? true
            let enabled = (TISGetInputSourceProperty(src, kTISPropertyInputSourceIsEnabled) as? NSNumber)?.boolValue ?? true

            guard let id, let name else { return nil }
            return InputSource(id: id, name: name, isSelectable: selectable, isEnabled: enabled)
        }
    }

    func currentInputSourceID() -> String? {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        let id = (TISGetInputSourceProperty(current, kTISPropertyInputSourceID) as? NSString) as String?
        return id
    }

    @discardableResult
    func selectInputSource(id: String) -> Bool {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return false
        }

        guard let match = list.first(where: { src in
            let srcID = (TISGetInputSourceProperty(src, kTISPropertyInputSourceID) as? NSString) as String?
            return srcID == id
        }) else {
            return false
        }

        return TISSelectInputSource(match) == noErr
    }
}
```

`MacInputSourceChangeNotifier.swift`:

```swift
import Carbon
import Foundation

final class MacInputSourceChangeNotifier: InputSourceChangeNotifier {
    private var observer: NSObjectProtocol?

    func start(_ handler: @escaping () -> Void) {
        stop()

        let name = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        observer = DistributedNotificationCenter.default().addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { _ in
            handler()
        }
    }

    func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
            self.observer = nil
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`

Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/System/MacTextInputSourceClient.swift InputLock/System/MacInputSourceChangeNotifier.swift InputLockTests/MacClientsCompileTests.swift

git commit -m "feat: add macOS TIS and notification clients"
```

---

### Task 7: Wire App State (Single Source of Truth)

**Files:**
- Modify: `InputLock/InputLockApp.swift`
- Create: `InputLock/App/AppModel.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import InputLock

final class AppModelTests: XCTestCase {
    func testSelectingSourceLocksAndSelects() {
        let client = FakeTextInputSourceClient()
        let notifier = FakeInputSourceChangeNotifier()
        let lockState = LockStateManager(store: InMemoryKeyValueStore())
        let inputManager = InputMethodManager(client: client, notifier: notifier)

        let model = AppModel(inputManager: inputManager, lockState: lockState)
        model.selectAndLock(inputSourceID: "target")

        XCTAssertTrue(lockState.isLocked)
        XCTAssertEqual(lockState.lockedInputSourceID, "target")
        XCTAssertEqual(client.selectedIDs, ["target"])
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`

Expected: FAIL（缺少 `AppModel` / 行为未实现）

**Step 3: Write minimal implementation**

```swift
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let inputManager: InputMethodManager
    let lockState: LockStateManager

    init(inputManager: InputMethodManager, lockState: LockStateManager) {
        self.inputManager = inputManager
        self.lockState = lockState
    }

    func selectAndLock(inputSourceID: String) {
        _ = inputManager.selectInputSource(inputSourceID)
        lockState.lock(to: inputSourceID)
    }

    func toggleLock() {
        if lockState.isLocked {
            lockState.unlock()
        } else if let current = inputManager.getCurrentInputSourceID() {
            lockState.lock(to: current)
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`

Expected: PASS

**Step 5: Commit**

```bash
git add InputLock/App/AppModel.swift InputLockTests/AppModelTests.swift InputLock/InputLockApp.swift

git commit -m "feat: add AppModel and wire app state"
```

---

### Task 8: Build Menu Bar UI (🔒/🔓 + list + actions)

**Files:**
- Create: `InputLock/Views/MenuBarView.swift`
- Create: `InputLock/Views/MainPanelView.swift`
- Modify: `InputLock/ContentView.swift`

**Step 1: Manual acceptance checklist (UI)**

- Launch app → menu bar 出现图标。
- 未锁定时显示 🔓；锁定后显示 🔒。
- 点击图标弹出列表，点击任意输入法项：切换并进入锁定状态。
- 点击“解锁/锁定”按钮可切换锁定状态。

**Step 2: Wire to real system clients**

In `InputLockApp.swift` (or `AppModel` init site):
- `InputMethodManager(client: MacTextInputSourceClient(), notifier: MacInputSourceChangeNotifier())`
- `LockStateManager(store: UserDefaults.standard)`
- `inputManager.startObservingInputSourceChanges(lockState: lockState)`

**Step 3: Run app and verify behavior**

Run (from Xcode): Product → Run

Expected:
- 选定并锁定后，使用系统快捷键切换输入法，会在约 50ms 内自动切回锁定目标。

**Step 4: Commit**

```bash
git add InputLock/Views/MenuBarView.swift InputLock/Views/MainPanelView.swift InputLock/ContentView.swift InputLock/InputLockApp.swift

git commit -m "feat: add menu bar UI and lock controls"
```

---

### Task 9: Add Basic Localization (zh-Hans + en)

**Files:**
- Create: `InputLock/Resources/en.lproj/Localizable.strings`
- Create: `InputLock/Resources/zh-Hans.lproj/Localizable.strings`
- (Xcode) Ensure resources added to target

**Step 1: Add strings (minimal)**

`en.lproj/Localizable.strings`:

```text
"locked" = "Locked";
"unlocked" = "Unlocked";
"lock" = "Lock";
"unlock" = "Unlock";
"no_input_sources" = "No input sources detected";
```

`zh-Hans.lproj/Localizable.strings`:

```text
"locked" = "已锁定";
"unlocked" = "未锁定";
"lock" = "锁定";
"unlock" = "解锁";
"no_input_sources" = "未检测到输入法";
```

**Step 2: Use `LocalizedStringKey` in SwiftUI**

- Replace hard-coded UI strings with `Text("lock")` / `Text("unlock")` / `Text("no_input_sources")` 等。

**Step 3: Verify language switching**

- 系统语言为英文时显示英文；中文时显示中文。

**Step 4: Commit**

```bash
git add InputLock/Resources/en.lproj/Localizable.strings InputLock/Resources/zh-Hans.lproj/Localizable.strings

git commit -m "feat: add basic localization strings"
```

---

## Test Plan (Summary)

- Unit tests: `xcodebuild -project InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test`
- Manual: 运行 app 后锁定任意输入法，使用系统快捷键切换输入法，观察是否 50ms 内自动切回。

## KISS / YAGNI / DRY / SOLID Notes (Applied)

- KISS: 锁定状态只保留 `isLocked` 与 `lockedInputSourceID`，纠正逻辑集中在 `InputMethodManager`。
- YAGNI: 不引入黑名单/白名单、统计、复杂设置项；登录项（ServiceManagement）暂不在 MVP 中实现。
- DRY: 输入法信息统一使用 `InputSource`，系统 API 访问统一经 `TextInputSourceClient`。
- SOLID: 通过 `TextInputSourceClient` / `InputSourceChangeNotifier` 抽象系统依赖，业务逻辑可单测，UI 不直接触达 TIS API。
