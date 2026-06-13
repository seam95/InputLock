import XCTest
@testable import InputLock

@MainActor
final class AppStateFeatureToggleTests: XCTestCase {
    func test_clipboardFeatureDisabledOnInit_stopsMonitoring() {
        let suite = "AppStateFeatureToggleTests_initOff"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(false, forKey: UserDefaultsKeys.clipboardFeatureEnabled)

        var startCount = 0
        var stopCount = 0

        _ = makeState(
            defaults: defaults,
            startClipboardMonitoring: { startCount += 1 },
            stopClipboardMonitoring: { stopCount += 1 }
        )

        XCTAssertEqual(startCount, 0)
        XCTAssertEqual(stopCount, 1)
    }

    func test_setClipboardFeatureEnabled_togglesSideEffectsAndPersists() {
        let suite = "AppStateFeatureToggleTests_clipboardToggle"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        var startCount = 0
        var stopCount = 0

        let state = makeState(
            defaults: defaults,
            startClipboardMonitoring: { startCount += 1 },
            stopClipboardMonitoring: { stopCount += 1 }
        )

        XCTAssertTrue(state.isClipboardFeatureEnabled)
        XCTAssertEqual(startCount, 1)
        XCTAssertEqual(stopCount, 0)

        state.setClipboardFeatureEnabled(false)

        XCTAssertFalse(state.isClipboardFeatureEnabled)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKeys.clipboardFeatureEnabled), false)
        XCTAssertEqual(stopCount, 1)

        state.setClipboardFeatureEnabled(true)

        XCTAssertTrue(state.isClipboardFeatureEnabled)
        XCTAssertEqual(defaults.bool(forKey: UserDefaultsKeys.clipboardFeatureEnabled), true)
        XCTAssertEqual(startCount, 2)
    }

    func test_unlockKeepsSelectedInputSourceID() {
        let suite = "AppStateFeatureToggleTests_unlockKeepsSelected"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let state = makeState(defaults: defaults)

        state.selectInputSource(id: "b")
        state.setLocked(true)
        state.setLocked(false)

        XCTAssertEqual(state.selectedInputSourceID, "b")
    }
}

@MainActor
private func makeState(
    defaults: UserDefaults,
    startClipboardMonitoring: (() -> Void)? = nil,
    stopClipboardMonitoring: (() -> Void)? = nil
) -> AppState {
    let tis = FakeTISClient(
        inputSources: [
            .init(id: "a", name: "A", isSelectable: true, isEnabled: true, icon: nil),
            .init(id: "b", name: "B", isSelectable: true, isEnabled: true, icon: nil)
        ],
        currentID: "a"
    )

    return AppState(
        inputMethods: InputMethodManager(
            tis: tis,
            scheduler: ImmediateScheduler(),
            notifications: FakeNotificationCenterClient()
        ),
        lockState: LockStateManager(userDefaults: defaults),
        language: LanguageManager(userDefaults: defaults),
        launchAtLogin: LaunchAtLoginManager(client: FakeLaunchAtLoginClient(), userDefaults: defaults),
        clipboardHistory: ClipboardHistoryManager(store: FakeClipboardStore(entries: []), userDefaults: defaults),
        clipboardHotkey: ClipboardHotkeyManager(userDefaults: defaults),
        quickPhrases: QuickPhraseManager(store: FakeQuickPhraseStore()),
        userDefaults: defaults,
        startClipboardMonitoring: startClipboardMonitoring,
        stopClipboardMonitoring: stopClipboardMonitoring
    )
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
