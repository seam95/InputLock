import Combine
import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    let inputMethods: InputMethodManager
    let lockState: LockStateManager
    let language: LanguageManager
    let launchAtLogin: LaunchAtLoginManager
    let clipboardHistory: ClipboardHistoryManager
    let clipboardHotkey: ClipboardHotkeyManager
    let quickPhrases: QuickPhraseManager
    private let userDefaults: UserDefaults
    private let startClipboardMonitoring: () -> Void
    private let stopClipboardMonitoring: () -> Void

    @Published private(set) var inputSources: [InputSource] = []
    @Published private(set) var selectedInputSourceID: String?
    @Published private(set) var isClipboardFeatureEnabled: Bool
    @Published private(set) var hideDockIcon: Bool {
        didSet {
            userDefaults.set(hideDockIcon, forKey: UserDefaultsKeys.hideDockIcon)
            updateDockIconVisibility()
        }
    }
    private var cancellables = Set<AnyCancellable>()

    init(
        inputMethods: InputMethodManager,
        lockState: LockStateManager,
        language: LanguageManager,
        launchAtLogin: LaunchAtLoginManager,
        clipboardHistory: ClipboardHistoryManager,
        clipboardHotkey: ClipboardHotkeyManager,
        quickPhrases: QuickPhraseManager,
        userDefaults: UserDefaults = .standard,
        startClipboardMonitoring: (() -> Void)? = nil,
        stopClipboardMonitoring: (() -> Void)? = nil
    ) {
        self.inputMethods = inputMethods
        self.lockState = lockState
        self.language = language
        self.launchAtLogin = launchAtLogin
        self.clipboardHistory = clipboardHistory
        self.clipboardHotkey = clipboardHotkey
        self.quickPhrases = quickPhrases
        self.userDefaults = userDefaults
        self.startClipboardMonitoring = startClipboardMonitoring ?? { clipboardHistory.startMonitoring() }
        self.stopClipboardMonitoring = stopClipboardMonitoring ?? { clipboardHistory.stopMonitoring() }
        self.hideDockIcon = userDefaults.bool(forKey: UserDefaultsKeys.hideDockIcon)
        self.isClipboardFeatureEnabled = AppState.featureEnabled(
            for: UserDefaultsKeys.clipboardFeatureEnabled,
            in: userDefaults
        )

        refreshInputSources()
        selectedInputSourceID = lockState.lockedInputSourceID ?? inputMethods.currentInputSourceID()

        updateDockIconVisibility()

        lockState.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        language.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        launchAtLogin.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        clipboardHistory.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        quickPhrases.objectWillChange
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        inputMethods.startObservingInputSourceChanges { [weak self] in
            guard let self else { return }
            self.handleInputSourceChange()
        }

        if isClipboardFeatureEnabled {
            self.startClipboardMonitoring()
        } else {
            self.stopClipboardMonitoring()
        }

        // App 启动时如果已处于锁定状态，也需要立即纠正一次。
        inputMethods.correctIfNeeded(isLocked: lockState.isLocked, lockedID: lockState.lockedInputSourceID)
    }

    private func handleInputSourceChange() {
        if lockState.isLocked {
            let lockedID = lockState.lockedInputSourceID
            selectedInputSourceID = lockedID ?? inputMethods.currentInputSourceID()
            inputMethods.correctIfNeeded(isLocked: true, lockedID: lockedID)
            return
        }

        selectedInputSourceID = inputMethods.currentInputSourceID()
    }

    func refreshInputSources() {
        inputSources = inputMethods.enumerateInputSources()
    }

    func selectInputSource(id: String) {
        selectedInputSourceID = id
        _ = inputMethods.selectInputSource(id)

        if lockState.isLocked {
            lockState.lock(to: id)
        }
    }

    func setLocked(_ locked: Bool) {
        guard locked != lockState.isLocked else { return }

        if locked {
            let targetID = selectedInputSourceID ?? inputMethods.currentInputSourceID()
            guard let targetID else { return }

            selectedInputSourceID = targetID
            _ = inputMethods.selectInputSource(targetID)
            lockState.lock(to: targetID)
        } else {
            lockState.unlock()
        }
    }

    func setHideDockIcon(_ hide: Bool) {
        guard hide != hideDockIcon else { return }
        hideDockIcon = hide
    }

    func setClipboardFeatureEnabled(_ enabled: Bool) {
        guard enabled != isClipboardFeatureEnabled else { return }

        isClipboardFeatureEnabled = enabled
        userDefaults.set(enabled, forKey: UserDefaultsKeys.clipboardFeatureEnabled)

        if enabled {
            startClipboardMonitoring()
        } else {
            stopClipboardMonitoring()
        }
    }

    private func updateDockIconVisibility() {
        guard !isRunningUnitTests else { return }
        guard let app = NSApp else { return }

        let policy: NSApplication.ActivationPolicy = hideDockIcon ? .accessory : .regular
        guard app.activationPolicy() != policy else { return }
        _ = app.setActivationPolicy(policy)
    }

    private var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static func featureEnabled(for key: String, in userDefaults: UserDefaults) -> Bool {
        guard userDefaults.object(forKey: key) != nil else {
            return true
        }
        return userDefaults.bool(forKey: key)
    }
}
