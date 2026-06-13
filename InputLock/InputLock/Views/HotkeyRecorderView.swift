import SwiftUI
import KeyboardShortcuts

struct HotkeyRecorderView: View {
    let hotkeyName: KeyboardShortcuts.Name
    let displayText: String
    let onShortcutChanged: (KeyboardShortcuts.Shortcut?) -> Void
    @ObservedObject var language: LanguageManager
    let recordingTextKey: String

    var body: some View {
        HStack(spacing: 8) {
            KeyboardShortcuts.Recorder(
                for: hotkeyName,
                onChange: onShortcutChanged
            )
            .labelsHidden()

            Text(displayText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityLabel(language.localized(recordingTextKey))
        }
    }
}
