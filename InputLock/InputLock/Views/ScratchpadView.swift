import SwiftUI

struct ScratchpadView: View {
    @State private var text: String
    @FocusState private var isEditorFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    init() {
        let saved = UserDefaults.standard.string(forKey: UserDefaultsKeys.scratchpadContent) ?? ""
        _text = State(initialValue: saved)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .focused($isEditorFocused)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: shadowColor, radius: 2, y: 1)
        .padding(12)
        .background(outerBackground)
        .onAppear {
            isEditorFocused = true
        }
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(nsColor: .textBackgroundColor).opacity(0.7)
            : Color(nsColor: .textBackgroundColor)
    }

    private var outerBackground: Color {
        colorScheme == .dark
            ? Color(nsColor: .windowBackgroundColor).opacity(0.3)
            : Color(nsColor: .windowBackgroundColor).opacity(0.5)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? .black.opacity(0.3)
            : .black.opacity(0.08)
    }

    /// 窗口关闭时调用，将当前文本写入 UserDefaults
    func save() {
        UserDefaults.standard.set(text, forKey: UserDefaultsKeys.scratchpadContent)
    }
}
