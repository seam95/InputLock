import XCTest
@testable import InputLock

@MainActor
final class AppStateTests: XCTestCase {
    func test_selectAndLock_thenChangeAndNotification_correctsBackToLockedInputSource() {
        let tis = FakeTISClient(
            inputSources: [
                .init(id: "a", name: "A", isSelectable: true, isEnabled: true, icon: nil),
                .init(id: "b", name: "B", isSelectable: true, isEnabled: true, icon: nil)
            ],
            currentID: "b"
        )
        let notifications = FakeNotificationCenterClient()
        let scheduler = ImmediateScheduler()

        let suiteName = "AppStateTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let hotkeyManager = ClipboardHotkeyManager(userDefaults: defaults)

        let state = AppState(
            inputMethods: InputMethodManager(tis: tis, scheduler: scheduler, notifications: notifications),
            lockState: LockStateManager(userDefaults: defaults),
            language: LanguageManager(userDefaults: defaults),
            launchAtLogin: LaunchAtLoginManager(client: FakeLaunchAtLoginClient(), userDefaults: defaults),
            clipboardHistory: ClipboardHistoryManager(store: FakeClipboardStore(entries: []), userDefaults: defaults),
            clipboardHotkey: hotkeyManager,
            quickPhrases: QuickPhraseManager(store: FakeQuickPhraseStore()),
            userDefaults: defaults
        )

        state.selectInputSource(id: "a")
        XCTAssertEqual(tis.currentInputSourceID(), "a")

        state.setLocked(true)
        XCTAssertEqual(state.lockState.lockedInputSourceID, "a")

        XCTAssertTrue(tis.selectInputSource(id: "b"))
        XCTAssertEqual(tis.currentInputSourceID(), "b")

        notifications.post(name: .tisSelectedKeyboardInputSourceChanged)

        XCTAssertEqual(tis.currentInputSourceID(), "a")
        XCTAssertEqual(state.lockState.lockedInputSourceID, "a")
        XCTAssertEqual(state.selectedInputSourceID, "a")
    }

    func test_unlocked_thenInputSourceChangeAndNotification_updatesSelectedInputSource() {
        let tis = FakeTISClient(
            inputSources: [
                .init(id: "a", name: "A", isSelectable: true, isEnabled: true, icon: nil),
                .init(id: "b", name: "B", isSelectable: true, isEnabled: true, icon: nil)
            ],
            currentID: "a"
        )
        let notifications = FakeNotificationCenterClient()
        let scheduler = ImmediateScheduler()

        let suiteName = "AppStateTests_unlocked"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let hotkeyManager = ClipboardHotkeyManager(userDefaults: defaults)

        let state = AppState(
            inputMethods: InputMethodManager(tis: tis, scheduler: scheduler, notifications: notifications),
            lockState: LockStateManager(userDefaults: defaults),
            language: LanguageManager(userDefaults: defaults),
            launchAtLogin: LaunchAtLoginManager(client: FakeLaunchAtLoginClient(), userDefaults: defaults),
            clipboardHistory: ClipboardHistoryManager(store: FakeClipboardStore(entries: []), userDefaults: defaults),
            clipboardHotkey: hotkeyManager,
            quickPhrases: QuickPhraseManager(store: FakeQuickPhraseStore()),
            userDefaults: defaults
        )

        XCTAssertFalse(state.lockState.isLocked)
        XCTAssertEqual(state.selectedInputSourceID, "a")

        XCTAssertTrue(tis.selectInputSource(id: "b"))
        notifications.post(name: .tisSelectedKeyboardInputSourceChanged)

        XCTAssertEqual(state.selectedInputSourceID, "b")
    }

    func test_unlocked_thenNotification_doesNotEnumerateInputSources() {
        let tis = FakeTISClient(
            inputSources: [
                .init(id: "a", name: "A", isSelectable: true, isEnabled: true, icon: nil),
                .init(id: "b", name: "B", isSelectable: true, isEnabled: true, icon: nil)
            ],
            currentID: "a"
        )
        let notifications = FakeNotificationCenterClient()
        let scheduler = ImmediateScheduler()

        let suiteName = "AppStateTests_noEnumerate"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let hotkeyManager = ClipboardHotkeyManager(userDefaults: defaults)

        let state = AppState(
            inputMethods: InputMethodManager(tis: tis, scheduler: scheduler, notifications: notifications),
            lockState: LockStateManager(userDefaults: defaults),
            language: LanguageManager(userDefaults: defaults),
            launchAtLogin: LaunchAtLoginManager(client: FakeLaunchAtLoginClient(), userDefaults: defaults),
            clipboardHistory: ClipboardHistoryManager(store: FakeClipboardStore(entries: []), userDefaults: defaults),
            clipboardHotkey: hotkeyManager,
            quickPhrases: QuickPhraseManager(store: FakeQuickPhraseStore()),
            userDefaults: defaults
        )

        XCTAssertFalse(state.lockState.isLocked)
        let baseline = tis.listInputSourcesCallCount

        XCTAssertTrue(tis.selectInputSource(id: "b"))
        notifications.post(name: .tisSelectedKeyboardInputSourceChanged)

        XCTAssertEqual(state.selectedInputSourceID, "b")
        XCTAssertEqual(tis.listInputSourcesCallCount, baseline)
    }
}

private final class FakeClipboardStore: ClipboardStore {
    private var entries: [ClipboardEntry]

    init(entries: [ClipboardEntry]) {
        self.entries = entries
    }

    func loadEntries() -> [ClipboardEntry] {
        entries
    }

    func saveEntries(_ entries: [ClipboardEntry]) {
        self.entries = entries
    }
}

private final class FakeQuickPhraseStore: QuickPhraseStore {
    func loadPhrases() -> [QuickPhraseEntry] { [] }
    func savePhrase(_ phrase: QuickPhraseEntry) {}
    func deletePhrase(id: UUID) {}
    func updatePhrase(_ phrase: QuickPhraseEntry) {}
}
