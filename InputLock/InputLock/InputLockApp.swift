//
//  InputLockApp.swift
//  InputLock
//
//  Created by 苏御 on 2026/1/27.
//

import SwiftUI

@main
struct InputLockApp: App {
    @StateObject private var state: AppState
    private let statusBarController: StatusBarController

    init() {
        let userDefaults = UserDefaults.standard

        // 在任何 UI 初始化之前设置 Dock 策略，避免自启时图标闪烁
        if userDefaults.bool(forKey: UserDefaultsKeys.hideDockIcon) {
            NSApp?.setActivationPolicy(.accessory)
        }
        let hotkeyManager = ClipboardHotkeyManager()

        let appState = AppState(
            inputMethods: InputMethodManager(tis: CarbonTISClient()),
            lockState: LockStateManager(),
            language: LanguageManager(),
            launchAtLogin: LaunchAtLoginManager(client: ServiceManagementLaunchAtLoginClient()),
            clipboardHistory: ClipboardHistoryManager(),
            clipboardHotkey: hotkeyManager,
            quickPhrases: QuickPhraseManager(),
            userDefaults: userDefaults
        )

        let clipboardWindowController = ClipboardWindowController(state: appState)
        let statusBarController = StatusBarController(
            state: appState,
            clipboardWindowController: clipboardWindowController
        )
        hotkeyManager.startListening {
            guard appState.isClipboardFeatureEnabled else { return }
            statusBarController.showClipboardPanel()
        }

        _state = StateObject(wrappedValue: appState)
        self.statusBarController = statusBarController
    }

    var body: some Scene {
        Settings {
            SettingsView(state: state)
        }
    }
}
