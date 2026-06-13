import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var state: AppState
    let useScrollContainer: Bool

    init(state: AppState, useScrollContainer: Bool = true) {
        self.state = state
        self.useScrollContainer = useScrollContainer
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            Section(state.language.localized("settings.generalSection")) {
                Picker(state.language.localized("settings.language"), selection: Binding(
                    get: { state.language.preferredLanguage ?? "" },
                    set: { state.language.setPreferredLanguage($0.isEmpty ? nil : $0) }
                )) {
                    Text(state.language.localized("settings.system")).tag("")
                    Text("English").tag("en")
                    Text("简体中文").tag("zh-Hans")
                }

                Toggle(state.language.localized("settings.launchAtLogin"), isOn: Binding(
                    get: { state.launchAtLogin.isEnabled },
                    set: { state.launchAtLogin.setEnabled($0) }
                ))

                Toggle(state.language.localized("settings.hideDockIcon"), isOn: Binding(
                    get: { state.hideDockIcon },
                    set: { state.setHideDockIcon($0) }
                ))
            }

            Section(state.language.localized("settings.clipboardSection")) {
                HStack {
                    Text(state.language.localized("settings.clipboardHotkey"))
                    Spacer()
                    HotkeyRecorderView(
                        hotkeyName: .clipboardHistoryHotkey,
                        displayText: state.clipboardHotkey.hotkey.displayString,
                        onShortcutChanged: { shortcut in
                            state.clipboardHotkey.handleRecorderChange(shortcut)
                        },
                        language: state.language,
                        recordingTextKey: "settings.clipboardHotkeyRecording"
                    )
                }

                Stepper(value: Binding(
                    get: { state.clipboardHistory.retentionDays },
                    set: { state.clipboardHistory.retentionDays = $0 }
                ), in: 1...30) {
                    Text("\(state.language.localized("settings.clipboardRetentionDays")) \(state.clipboardHistory.retentionDays) \(state.language.localized("settings.days"))")
                }

                Stepper(value: Binding(
                    get: { state.clipboardHistory.maxEntries },
                    set: { state.clipboardHistory.maxEntries = $0 }
                ), in: 50...500, step: 10) {
                    Text("\(state.language.localized("settings.clipboardMaxEntries")) \(state.clipboardHistory.maxEntries) \(state.language.localized("settings.entries"))")
                }
            }

        }
    }

    var body: some View {
        if useScrollContainer {
            formContent
                .padding(12)
                .frame(width: 400)
        } else {
            formContent
                .padding(12)
        }
    }
}
