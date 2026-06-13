import XCTest
@testable import InputLock

@MainActor
final class ClipboardWindowControllerTests: XCTestCase {
    func test_toggleShowsAndHidesWindow() {
        let controller = ClipboardWindowController(state: makeState())

        XCTAssertFalse(controller.isVisible)

        controller.toggleVisibility()

        XCTAssertTrue(controller.isVisible)

        controller.toggleVisibility()

        XCTAssertFalse(controller.isVisible)
    }

    func test_escapeKeyClosesWindow() {
        let state = makeState()
        let controller = ClipboardWindowController(state: state)

        controller.show()
        defer { controller.hide() }

        XCTAssertTrue(controller.isVisible)

        controller.handleEscapeKey()

        XCTAssertFalse(controller.isVisible)
    }

    func test_windowResigningKeyClosesWindow() {
        let state = makeState()
        let controller = ClipboardWindowController(state: state)

        controller.show()
        defer { controller.hide() }

        let title = state.language.localized("clipboard.title")
        guard let window = NSApp.windows.first(where: { $0.title == title }) else {
            XCTFail("Window not found")
            return
        }

        controller.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: window))

        XCTAssertFalse(controller.isVisible)
    }

    func test_windowIsBorderlessAndHidesTrafficLights() {
        let state = makeState()
        let controller = ClipboardWindowController(state: state)

        controller.show()
        defer { controller.hide() }

        let title = state.language.localized("clipboard.title")
        guard let window = NSApp.windows.first(where: { $0.title == title }) else {
            XCTFail("Window not found")
            return
        }

        XCTAssertTrue(window.styleMask.contains(.borderless))
        XCTAssertTrue(window.isMovableByWindowBackground)
        XCTAssertEqual(window.standardWindowButton(.closeButton), nil)
        XCTAssertEqual(window.standardWindowButton(.miniaturizeButton), nil)
        XCTAssertEqual(window.standardWindowButton(.zoomButton), nil)
    }

    func test_showKeepsLastWindowPosition() {
        let state = makeState()
        let controller = ClipboardWindowController(state: state)

        controller.show()
        defer { controller.hide() }

        let title = state.language.localized("clipboard.title")
        guard let window = NSApp.windows.first(where: { $0.title == title }) else {
            XCTFail("Window not found")
            return
        }

        let movedOrigin = NSPoint(x: window.frame.origin.x + 80, y: window.frame.origin.y + 80)
        window.setFrameOrigin(movedOrigin)

        controller.hide()
        controller.show()

        XCTAssertEqual(window.frame.origin.x, movedOrigin.x, accuracy: 0.5)
        XCTAssertEqual(window.frame.origin.y, movedOrigin.y, accuracy: 0.5)
    }

    func test_hideAndShowReuseExistingContentViewController() {
        let state = makeState()
        let controller = ClipboardWindowController(state: state)

        controller.show()
        let panel = tryUnwrapPanel(from: controller)
        let initialContentViewController = panel.contentViewController

        controller.hide()

        XCTAssertTrue(panel.contentViewController === initialContentViewController)

        controller.show()
        defer { controller.hide() }

        XCTAssertTrue(panel.contentViewController === initialContentViewController)
    }

    func test_windowIsNonActivatingPanelAndFloatsAboveStatusBar() {
        let state = makeState()
        let controller = ClipboardWindowController(state: state)

        controller.show()
        defer { controller.hide() }

        let title = state.language.localized("clipboard.title")
        guard let window = NSApp.windows.first(where: { $0.title == title }) else {
            XCTFail("Window not found")
            return
        }

        XCTAssertTrue(window is NSPanel)
        XCTAssertTrue(window.styleMask.contains(.nonactivatingPanel))
        XCTAssertEqual(window.level, .statusBar)
        XCTAssertTrue((window as? NSPanel)?.isFloatingPanel == true)
        XCTAssertTrue(window.canBecomeKey)
        XCTAssertTrue(window.collectionBehavior.contains(.moveToActiveSpace))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
    }
}

@MainActor
private func tryUnwrapPanel(from controller: ClipboardWindowController, file: StaticString = #filePath, line: UInt = #line) -> NSPanel {
    let mirror = Mirror(reflecting: controller)
    guard let panel = mirror.children.first(where: { $0.label == "panel" })?.value as? NSPanel else {
        XCTFail("Panel not found", file: file, line: line)
        return NSPanel()
    }
    return panel
}

@MainActor
private func makeState() -> AppState {
    let tis = FakeTISClient(
        inputSources: [
            .init(id: "a", name: "A", isSelectable: true, isEnabled: true, icon: nil)
        ],
        currentID: "a"
    )
    let notifications = FakeNotificationCenterClient()
    let scheduler = ImmediateScheduler()
    let defaults = UserDefaults(suiteName: "ClipboardWindowControllerTests")!
    defaults.removePersistentDomain(forName: "ClipboardWindowControllerTests")
    let hotkeyManager = ClipboardHotkeyManager(userDefaults: defaults)

    return AppState(
        inputMethods: InputMethodManager(tis: tis, scheduler: scheduler, notifications: notifications),
        lockState: LockStateManager(userDefaults: defaults),
        language: LanguageManager(userDefaults: defaults),
        launchAtLogin: LaunchAtLoginManager(client: FakeLaunchAtLoginClient(), userDefaults: defaults),
        clipboardHistory: ClipboardHistoryManager(store: FakeClipboardStore(entries: []), userDefaults: defaults),
        clipboardHotkey: hotkeyManager,
        quickPhrases: QuickPhraseManager(store: FakeQuickPhraseStore()),
        userDefaults: defaults
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
