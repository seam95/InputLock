# Clipboard Scrollbar Refinement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让剪贴板历史窗口的所有滚动区域采用更纤细的 overlay 滚动条外观，同时保留键鼠可访问性。

**Architecture:** 通过 SwiftUI + AppKit 桥接，在视图内部注入一个 `NSViewRepresentable`，将相邻的 `NSScrollView` 切换为 `.overlay` 样式并调小 `NSScroller` 的 `controlSize`。然后提供 `View` 扩展易于复用，分别作用于历史列表和详情滚动区。

**Tech Stack:** SwiftUI, AppKit (`NSScrollView`, `NSScroller`).

---

### Task 1: 引入 overlay 滚动条修饰器

**Files:**
- Modify: `InputLock/InputLock/Views/ClipboardHistoryView.swift:300-450`

**Step 1: 写修饰器代码**

```swift
private struct ThinScrollbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(ThinScrollbarApplier())
    }
}

private struct ThinScrollbarApplier: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = nsView.enclosingScrollView else { return }
            scrollView.scrollerStyle = .overlay
            scrollView.verticalScroller?.controlSize = .small
            scrollView.horizontalScroller?.controlSize = .small
        }
    }
}
```

**Step 2: 添加易用扩展**

```swift
private extension View {
    func thinScrollIndicators() -> some View {
        modifier(ThinScrollbarModifier())
    }
}
```

**Task Validation:** Swift 编译应能通过 `NSViewRepresentable` 与 `.overlay` 的使用，无需额外资源文件。

---

### Task 2: 应用于列表与详情滚动区域

**Files:**
- Modify: `InputLock/InputLock/Views/ClipboardHistoryView.swift:160-220`
- Modify: `InputLock/InputLock/Views/ClipboardHistoryView.swift:320-360`

**Step 1: 更新历史列表**

```swift
List(selection: ...) { ... }
    .listStyle(.sidebar)
    .thinScrollIndicators()
```

确保 `.scrollIndicators(.hidden)` 被移除或保留（若需要彻底隐藏则保留），但 overlay 样式仍保持细滚动条。

**Step 2: 更新详情 `ScrollView`**

```swift
ScrollView { ... }
    .thinScrollIndicators()
```

对文本、URL、文件等所有 `ScrollView` 分支添加。图像分支保持原样。

**Task Validation:** 重新运行 `xcodebuild build -scheme InputLock -configuration Debug`，并在运行中的剪贴板历史窗口里滚动列表与详情文本，看到 overlay/小号滚动条即可。

---
