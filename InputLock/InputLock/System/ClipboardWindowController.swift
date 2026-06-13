import AppKit
import Carbon
import SwiftUI

@MainActor
final class ClipboardWindowController: NSObject, NSWindowDelegate {
    private final class KeyablePanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    private let panel: NSPanel
    private let uiState = ClipboardOverlayState()
    private let quickPhraseState = QuickPhraseOverlayState()
    private let tabState = TabPanelState()
    private var previousActiveApp: NSRunningApplication?
    private var pasteTargetPID: pid_t?
    private var keyEventMonitor: Any?
    private var activeAppObserver: Any?
    private var lastNonSelfActiveApp: NSRunningApplication?
    private var isProgrammaticDismiss = false

    // 保存视图重建所需的引用
    private let clipboardHistory: ClipboardHistoryManager
    private let quickPhrases: QuickPhraseManager
    private let languageManager: LanguageManager
    private let scratchpadView = ScratchpadView()
    private let pasteService = ClipboardPasteService()

    deinit {
        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
        }
        if let activeAppObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeAppObserver)
        }
    }

    init(state: AppState) {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
            styleMask: [.borderless, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.panel = panel
        self.clipboardHistory = state.clipboardHistory
        self.quickPhrases = state.quickPhrases
        self.languageManager = state.language
        super.init()

        panel.title = state.language.localized("clipboard.title")
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.styleMask.insert(.fullSizeContentView)
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .statusBar
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        installView()

        restoreWindowFrame()

        startActiveAppObserver()
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func toggleVisibility() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if panel.isVisible {
            panel.orderFrontRegardless()
            panel.makeKey()
            requestSearchFocus()
            return
        }
        rememberPreviousApp()
        tabState.selectedTab = .clipboard
        resetCurrentTabState()
        updatePasteTargetName()
        requestSearchFocus()
        installViewIfNeeded()
        startKeyMonitor()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        // 临时激活应用以支持中文输入法
        NSApp.activate(ignoringOtherApps: true)
    }

    private func resetCurrentTabState() {
        switch tabState.selectedTab {
        case .clipboard:
            uiState.resetForNewSession()
        case .quickPhrase:
            quickPhraseState.resetForNewSession()
        case .scratchpad:
            break
        }
    }

    private func requestSearchFocus() {
        switch tabState.selectedTab {
        case .clipboard:
            uiState.requestSearchFocus()
        case .quickPhrase:
            quickPhraseState.requestSearchFocus()
        case .scratchpad:
            break
        }
    }

    private func updatePasteTargetName() {
        let appName = previousActiveApp?.localizedName ?? NSWorkspace.shared.frontmostApplication?.localizedName
        uiState.pasteTargetAppName = appName
        quickPhraseState.updatePasteTargetName(appName)
    }

    func hide() {
        dismiss(shouldRestorePreviousApp: true)
    }

    func windowWillClose(_ notification: Notification) {
        saveWindowFrame()
        scratchpadView.save()
        dismiss(shouldRestorePreviousApp: true)
    }

    func windowDidResize(_ notification: Notification) {
        saveWindowFrame()
    }

    func windowDidMove(_ notification: Notification) {
        saveWindowFrame()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard panel.isVisible else { return }
        guard !isProgrammaticDismiss else { return }
        // 有 sheet（如快捷短语编辑器）显示时，不关闭面板
        if panel.attachedSheet != nil { return }
        // 用户点击窗口外导致窗口失去焦点时，不要再强行激活”之前的应用”，避免抢走用户刚点击的焦点。
        dismiss(shouldRestorePreviousApp: false)
    }

    func handleEscapeKey() {
        guard panel.isVisible else { return }

        let hasSearchText: Bool
        switch tabState.selectedTab {
        case .clipboard:
            hasSearchText = !uiState.searchText.isEmpty
            if hasSearchText {
                uiState.searchText = ""
                uiState.requestSearchFocus()
                return
            }
        case .quickPhrase:
            hasSearchText = !quickPhraseState.searchText.isEmpty
            if hasSearchText {
                quickPhraseState.searchText = ""
                quickPhraseState.requestSearchFocus()
                return
            }
        case .scratchpad:
            break
        }

        hide()
    }

    private func installView() {
        panel.contentViewController = NSHostingController(
            rootView: TabPanelView(
                tabState: tabState,
                clipboardView: ClipboardHistoryView(
                    history: clipboardHistory,
                    language: languageManager,
                    uiState: uiState,
                    onRequestClose: { [weak self] in
                        self?.hide()
                    },
                    isReadyToPaste: { [weak self] in
                        self?.isReadyToPaste() ?? true
                    },
                    pasteTargetPIDProvider: { [weak self] in
                        self?.pasteTargetPID
                    }
                ),
                quickPhraseView: QuickPhraseView(
                    manager: quickPhrases,
                    uiState: quickPhraseState,
                    tabState: tabState,
                    language: languageManager,
                    onRequestClose: { [weak self] in
                        self?.hide()
                    },
                    isReadyToPaste: { [weak self] in
                        self?.isReadyToPaste() ?? true
                    },
                    pasteTargetPIDProvider: { [weak self] in
                        self?.pasteTargetPID
                    }
                ),
                scratchpadView: scratchpadView
            )
        )
    }

    private func installViewIfNeeded() {
        guard panel.contentViewController == nil else { return }
        installView()
    }

    private func rememberPreviousApp() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if isSelfApp(frontmost) {
            previousActiveApp = lastNonSelfActiveApp
        } else {
            previousActiveApp = frontmost
        }
        pasteTargetPID = previousActiveApp?.processIdentifier
        updatePasteTargetName()
    }

    private func dismiss(shouldRestorePreviousApp: Bool) {
        guard panel.isVisible else {
            if !shouldRestorePreviousApp {
                previousActiveApp = nil
            }
            return
        }

        saveWindowFrame()
        isProgrammaticDismiss = true
        stopKeyMonitor()
        panel.contentView?.discardCursorRects()
        panel.orderOut(nil)
        NSCursor.arrow.set()

        let app = previousActiveApp
        previousActiveApp = nil
        isProgrammaticDismiss = false

        guard shouldRestorePreviousApp, let app else { return }
        // non-activating panel 模式下，原应用可能仍是 frontmost，但再次 activate 能确保其拿回键盘焦点，
        // 避免后续 CGEvent 的 Cmd+V 落到本应用的 key window（搜索框）里。
        app.activate(options: [.activateIgnoringOtherApps])
    }

    private func isPasteTargetActive() -> Bool {
        guard let pasteTargetPID else { return true }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == pasteTargetPID
    }

    private func isReadyToPaste() -> Bool {
        // 非激活面板模式下 NSApp.isActive 可能始终为 false，
        // 需要额外确保面板已隐藏，否则 Cmd+V 可能仍会落到搜索框里。
        guard panel.isVisible == false else { return false }
        return isPasteTargetActive()
    }

    private func startActiveAppObserver() {
        guard activeAppObserver == nil else { return }
        activeAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard !self.isSelfApp(app) else { return }
            self.lastNonSelfActiveApp = app
        }
    }

    private func isSelfApp(_ app: NSRunningApplication?) -> Bool {
        guard let app else { return false }
        guard let selfBundleID = Bundle.main.bundleIdentifier else { return false }
        return app.bundleIdentifier == selfBundleID
    }

    private func saveWindowFrame() {
        let frame = panel.frame
        let frameDict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        UserDefaults.standard.set(frameDict, forKey: UserDefaultsKeys.clipboardWindowFrame)
    }

    private func restoreWindowFrame() {
        guard let frameDict = UserDefaults.standard.object(forKey: UserDefaultsKeys.clipboardWindowFrame) as? [String: CGFloat],
              let x = frameDict["x"],
              let y = frameDict["y"],
              let width = frameDict["width"],
              let height = frameDict["height"] else {
            panel.center()
            return
        }
        let minSize = NSSize(width: 400, height: 300)
        let clampedWidth = max(width, minSize.width)
        let clampedHeight = max(height, minSize.height)
        panel.setFrame(NSRect(x: x, y: y, width: clampedWidth, height: clampedHeight), display: false)
    }

    private func startKeyMonitor() {
        guard keyEventMonitor == nil else { return }
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // Tab 切换
            if event.keyCode == UInt16(kVK_Tab) {
                if event.modifierFlags.contains(.shift) {
                    self.tabState.selectPreviousTab()
                } else {
                    self.tabState.selectNextTab()
                }
                self.resetCurrentTabState()
                self.requestSearchFocus()
                return nil
            }

            // Escape 键
            if event.keyCode == UInt16(kVK_Escape) {
                self.handleEscapeKey()
                return nil
            }

            // 快捷短语面板：上/下导航 + 左/右切换分组 + 回车粘贴
            if self.tabState.selectedTab == .quickPhrase {
                if event.keyCode == UInt16(kVK_DownArrow) {
                    self.navigateQuickPhrase(down: true)
                    return nil
                }
                if event.keyCode == UInt16(kVK_UpArrow) {
                    self.navigateQuickPhrase(down: false)
                    return nil
                }
                if event.keyCode == UInt16(kVK_LeftArrow) {
                    self.navigateQuickPhraseGroup(forward: false)
                    return nil
                }
                if event.keyCode == UInt16(kVK_RightArrow) {
                    self.navigateQuickPhraseGroup(forward: true)
                    return nil
                }
                if event.keyCode == UInt16(kVK_Return) || event.keyCode == UInt16(kVK_ANSI_KeypadEnter) {
                    self.pasteSelectedQuickPhrase()
                    return nil
                }
            }

            return event
        }
    }

    private func stopKeyMonitor() {
        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
        }
        keyEventMonitor = nil
    }

    private func navigateQuickPhrase(down: Bool) {
        let phrases = quickPhrases.filtered(searchText: quickPhraseState.searchText, group: quickPhraseState.selectedGroup)
        guard !phrases.isEmpty else { return }

        if let selectedID = quickPhraseState.selectedPhraseID,
           let currentIndex = phrases.firstIndex(where: { $0.id == selectedID }) {
            if down && currentIndex < phrases.count - 1 {
                quickPhraseState.selectedPhraseID = phrases[currentIndex + 1].id
            } else if !down && currentIndex > 0 {
                quickPhraseState.selectedPhraseID = phrases[currentIndex - 1].id
            }
        } else {
            quickPhraseState.selectedPhraseID = (down ? phrases.first : phrases.last)?.id
        }
    }

    private func navigateQuickPhraseGroup(forward: Bool) {
        let groups: [String?] = [nil] + quickPhrases.allGroups()
        let currentIndex = groups.firstIndex(where: { $0 == quickPhraseState.selectedGroup }) ?? 0
        if forward && currentIndex < groups.count - 1 {
            quickPhraseState.selectedGroup = groups[currentIndex + 1]
        } else if !forward && currentIndex > 0 {
            quickPhraseState.selectedGroup = groups[currentIndex - 1]
        }
    }

    private func pasteSelectedQuickPhrase() {
        guard let selectedID = quickPhraseState.selectedPhraseID else { return }
        let phrases = quickPhrases.filtered(searchText: quickPhraseState.searchText, group: quickPhraseState.selectedGroup)
        guard let phrase = phrases.first(where: { $0.id == selectedID }) else { return }

        let entry = ClipboardEntry(
            id: UUID(),
            createdAt: Date(),
            type: .text,
            preview: String(phrase.content.prefix(80)),
            sourceAppBundleID: nil,
            sourceAppName: nil,
            content: .text(phrase.content),
            thumbnailData: nil,
            blobSize: nil,
            imageWidth: nil,
            imageHeight: nil,
            contentHash: nil
        )
        pasteService.paste(
            entry: entry,
            close: { [weak self] in self?.hide() },
            isReadyToPaste: { [weak self] in self?.isReadyToPaste() ?? true },
            targetPID: pasteTargetPID
        )
    }
}
