import AppKit
import Carbon
import NaturalLanguage
import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var history: ClipboardHistoryManager
    @ObservedObject var language: LanguageManager
    @ObservedObject var uiState: ClipboardOverlayState
    let onRequestClose: () -> Void
    let isReadyToPaste: () -> Bool
    let pasteTargetPIDProvider: () -> pid_t?

    @State private var keyEventMonitor: Any?
    @State private var hoveredEntryID: UUID?
    @State private var loadedEntryCount: Int = 15
    @State private var selectionChangeSource: SelectionChangeSource = .programmatic
    @FocusState private var isSearchFocused: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    private let pasteService = ClipboardPasteService()

    private enum SelectionChangeSource {
        case programmatic
        case keyboard
        case pointer
    }

    private var windowBackgroundColor: Color {
        if colorScheme == .dark {
            return Color(.sRGB, red: 0.13, green: 0.14, blue: 0.17, opacity: 1)
        }
        return Color(.sRGB, red: 0.84, green: 0.85, blue: 0.87, opacity: reduceTransparency ? 1 : 0.98)
    }

    private var headerBackgroundColor: Color {
        Color.clear
    }

    private var footerBackgroundColor: Color {
        Color.clear
    }

    private var listPaneBackgroundColor: Color {
        Color.clear
    }

    private var detailPaneBackgroundColor: Color {
        Color.clear
    }

    private var dividerColor: Color {
        if colorScheme == .dark {
            return Color(.sRGB, red: 0.27, green: 0.29, blue: 0.34, opacity: 1)
        }
        return Color(.sRGB, red: 0.74, green: 0.76, blue: 0.80, opacity: 1)
    }

    private var rowSelectedBackgroundColor: Color {
        if colorScheme == .dark {
            return Color(.sRGB, red: 0.30, green: 0.33, blue: 0.39, opacity: 0.85)
        }
        return Color(.sRGB, red: 0.78, green: 0.80, blue: 0.84, opacity: 0.78)
    }

    private var rowHoveredBackgroundColor: Color {
        if colorScheme == .dark {
            return Color(.sRGB, red: 0.23, green: 0.25, blue: 0.30, opacity: 0.70)
        }
        return Color(.sRGB, red: 0.82, green: 0.84, blue: 0.87, opacity: 0.60)
    }

    private static let detailTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()

    private static let initialLoadCount = 15
    private static let loadMoreBatchCount = 15
    private static let loadMoreTriggerDistance = 5

    private var filteredEntries: [ClipboardEntry] {
        uiState.filteredEntries(from: history.entries)
    }

    private var visibleEntries: [ClipboardEntry] {
        Array(filteredEntries.prefix(loadedEntryCount))
    }

    private var groupedEntries: [(titleKey: String, entries: [ClipboardEntry])] {
        groupedEntries(from: visibleEntries)
    }

    private var displayedEntries: [ClipboardEntry] {
        groupedEntries.flatMap { $0.entries }
    }

    private func groupedEntries(from entries: [ClipboardEntry]) -> [(titleKey: String, entries: [ClipboardEntry])] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4

        let now = Date()
        let lastWeekAnchor = calendar.date(byAdding: .weekOfYear, value: -1, to: now)

        let today = entries.filter { calendar.isDateInToday($0.createdAt) }
        let yesterday = entries.filter { calendar.isDateInYesterday($0.createdAt) }
        let thisWeek = entries.filter { entry in
            guard !calendar.isDateInToday(entry.createdAt), !calendar.isDateInYesterday(entry.createdAt) else { return false }
            return calendar.isDate(entry.createdAt, equalTo: now, toGranularity: .weekOfYear)
        }
        let lastWeek = entries.filter { entry in
            guard !calendar.isDateInToday(entry.createdAt), !calendar.isDateInYesterday(entry.createdAt) else { return false }
            guard let lastWeekAnchor else { return false }
            return calendar.isDate(entry.createdAt, equalTo: lastWeekAnchor, toGranularity: .weekOfYear)
        }
        let thisMonth = entries.filter { entry in
            guard !calendar.isDate(entry.createdAt, equalTo: now, toGranularity: .weekOfYear) else { return false }
            if let lastWeekAnchor, calendar.isDate(entry.createdAt, equalTo: lastWeekAnchor, toGranularity: .weekOfYear) {
                return false
            }
            return calendar.isDate(entry.createdAt, equalTo: now, toGranularity: .month)
        }
        let thisYear = entries.filter { entry in
            guard !calendar.isDate(entry.createdAt, equalTo: now, toGranularity: .month) else { return false }
            return calendar.isDate(entry.createdAt, equalTo: now, toGranularity: .year)
        }

        return [
            ("clipboard.section.today", today),
            ("clipboard.section.yesterday", yesterday),
            ("clipboard.section.thisWeek", thisWeek),
            ("clipboard.section.lastWeek", lastWeek),
            ("clipboard.section.thisMonth", thisMonth),
            ("clipboard.section.thisYear", thisYear)
        ].filter { !$0.entries.isEmpty }
    }

    private var selectedEntry: ClipboardEntry? {
        guard let selectedEntryID = uiState.selectedEntryID else { return nil }
        return history.entries.first { $0.id == selectedEntryID }
    }

    private var pasteTargetAppName: String {
        if let name = uiState.pasteTargetAppName, !name.isEmpty {
            return name
        }
        return language.localized("clipboard.pasteUnknown")
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()

            contentArea

            Divider()

            footer
        }
        .onAppear {
            ensureSelectedEntryVisibleInLoadedEntries()
            updateSelectionIfNeeded()
            startKeyMonitor()
            focusSearchField()
        }
        .onDisappear {
            stopKeyMonitor()
        }
        .onChange(of: filteredEntries) { _, _ in
            clampVisibleEntriesToFilteredCount()
            ensureSelectedEntryVisibleInLoadedEntries()
            updateSelectionIfNeeded()
        }
        .onChange(of: uiState.searchFocusToken) { _, _ in
            focusSearchField()
        }
    }

    private var footer: some View {
        HStack {
            Text(language.localized("clipboard.title"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            pasteHint
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            searchField
            filterMenu
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(language.localized("clipboard.search"), text: $uiState.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isSearchFocused)

            if !uiState.searchText.isEmpty {
                Button(action: { uiState.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private var filterMenu: some View {
        Picker("", selection: $uiState.filter) {
            ForEach(ClipboardFilter.allCases) { item in
                Text(language.localized(item.labelKey)).tag(item)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .font(.system(size: 13))
        .controlSize(.small)
        .frame(width: 100)
    }

    private var contentArea: some View {
        HSplitView {
            historyList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320, maxHeight: .infinity)
                .background(Color.clear)

            detailPane
                .frame(minWidth: 360, maxHeight: .infinity)
                .background(Color.clear)
        }
    }

    private var detailPane: some View {
        Group {
            if let entry = selectedEntry {
                VStack(spacing: 0) {
                    detailPreview(entry)
                        .frame(maxHeight: .infinity)

                    Divider()

                    detailInfo(entry)
                        .frame(height: 180)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text(language.localized("clipboard.empty"))
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var pasteHint: some View {
        HStack(spacing: 10) {
            Text(language.localized("clipboard.pasteHint"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(pasteTargetAppName)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Image(systemName: "return")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private var historyList: some View {
        ScrollViewReader { proxy in
            List {
                if groupedEntries.isEmpty {
                    Text(language.localized("clipboard.empty"))
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(groupedEntries, id: \.titleKey) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                historyRow(entry)
                                    .id(entry.id)
                                    .onAppear {
                                        loadMoreIfNeeded(currentEntry: entry)
                                    }
                            }
                        } header: {
                            sectionHeader(title: language.localized(group.titleKey))
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .thinScrollIndicators()
            .scrollContentBackground(.hidden)
            .onAppear {
                resetLoadedEntriesForNewSession()
                updateSelectionIfNeeded()
                scrollToTop(proxy: proxy, animated: false)
            }
            .onChange(of: uiState.sessionResetToken) { _, _ in
                resetLoadedEntriesForNewSession()
                updateSelectionIfNeeded()
                scrollToTop(proxy: proxy, animated: false)
            }
            .onChange(of: uiState.selectedEntryID) { _, newValue in
                defer { selectionChangeSource = .programmatic }
                guard let newValue else { return }
                guard selectionChangeSource == .keyboard else { return }

                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(newValue)
                }
            }
        }
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }

    private func historyRow(_ entry: ClipboardEntry) -> some View {
        HStack(spacing: 12) {
            rowLeadingIcon(for: entry)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.preview)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let appName = entry.sourceAppName {
                    Text(appName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(rowBackground(for: entry))
        .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
        .listRowBackground(Color.clear)
        .contextMenu {
            Button(language.localized("clipboard.action.paste")) {
                pasteEntry(entry)
            }
        }
        .onTapGesture {
            selectionChangeSource = .pointer
            uiState.selectedEntryID = entry.id
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                pasteEntry(entry)
            }
        )
        .onHover { hovering in
            if hovering {
                hoveredEntryID = entry.id
            } else if hoveredEntryID == entry.id {
                hoveredEntryID = nil
            }
        }
        .listRowSeparator(.hidden)
    }

    private func rowLeadingIcon(for entry: ClipboardEntry) -> some View {
        ZStack {
            if entry.type == .image,
               let thumbnail = ClipboardImageCache.shared.thumbnailImage(for: entry.id, data: entry.thumbnailData) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 32, height: 32)

                Image(systemName: entry.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 32, height: 32)
    }

    private func rowBackground(for entry: ClipboardEntry) -> some View {
        let isSelected = uiState.selectedEntryID == entry.id
        let isHovered = hoveredEntryID == entry.id

        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            .padding(.horizontal, 4)
            .opacity(isSelected ? 1.0 : 1.0)
    }

    private func detailPreview(_ entry: ClipboardEntry) -> some View {
        detailContent(entry)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func detailInfo(_ entry: ClipboardEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                detailGroupHeader
                    .padding(.bottom, 4)

                VStack(spacing: 8) {
                    detailRow(
                        title: language.localized("clipboard.detail.source"),
                        value: entry.sourceAppName ?? "-"
                    )
                    detailRow(
                        title: language.localized("clipboard.detail.type"),
                        value: language.localized(entry.type.labelKey)
                    )
                    if let dimensionLabel = dimensionDescription(for: entry) {
                        detailRow(
                            title: language.localized("clipboard.detail.dimensions"),
                            value: dimensionLabel
                        )
                    }
                    if let sizeLabel = sizeDescription(for: entry) {
                        detailRow(
                            title: language.localized("clipboard.detail.size"),
                            value: sizeLabel
                        )
                    }
                    detailRow(
                        title: language.localized("clipboard.detail.characters"),
                        value: metadataDescription(for: entry)
                    )
                    detailRow(
                        title: language.localized("clipboard.detail.time"),
                        value: formattedTime(entry.createdAt)
                    )
                }
            }
            .padding(16)
        }
    }

    private func detailContent(_ entry: ClipboardEntry) -> some View {
        Group {
            switch entry.content {
            case .text(let text):
                SelectableTextView(text: text, font: .systemFont(ofSize: 16))
            case .url(let url):
                SelectableTextView(text: url.absoluteString, font: .systemFont(ofSize: 16))
            case .files(let files):
                SelectableTextView(
                    text: files.map(\.lastPathComponent).joined(separator: "\n"),
                    font: .systemFont(ofSize: 16)
                )
            case .image:
                if let image = ClipboardImageCache.shared.detailImage(for: entry.id, loader: {
                    guard let fullContent = history.fullContent(for: entry.id),
                          case .image(let data) = fullContent, let data else { return nil }
                    return NSImage(data: data)
                }) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 320)
                } else {
                    Text(language.localized("clipboard.detail.unavailable"))
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            case .rtf:
                Text(language.localized("clipboard.detail.rtf"))
                    .font(.system(size: 15))
            case .unknown:
                Text(language.localized("clipboard.detail.unavailable"))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detailGroupHeader: some View {
        Text(language.localized("clipboard.detail.information"))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metadataDescription(for entry: ClipboardEntry) -> String {
        switch entry.content {
        case .text(let text):
            let characters = text.count
            let words = wordCount(for: text)
            let characterLabel = language.localized("clipboard.detail.charactersCount")
            let wordLabel = language.localized("clipboard.detail.wordsCount")
            if words > 0 {
                return "\(characters) \(characterLabel) · \(words) \(wordLabel)"
            } else {
                return "\(characters) \(characterLabel)"
            }
        default:
            return "-"
        }
    }

    private func dimensionDescription(for entry: ClipboardEntry) -> String? {
        guard entry.type == .image else { return nil }
        if let w = entry.imageWidth, let h = entry.imageHeight {
            return "\(w) × \(h) px"
        }
        return language.localized("clipboard.detail.imageUnknown")
    }

    private func sizeDescription(for entry: ClipboardEntry) -> String? {
        switch entry.type {
        case .image:
            guard entry.blobSize > 0 else { return nil }
            return Self.byteFormatter.string(fromByteCount: entry.blobSize)
        case .text:
            guard entry.blobSize > 0 else { return nil }
            return Self.byteFormatter.string(fromByteCount: entry.blobSize)
        default:
            return nil
        }
    }

    private func wordCount(for text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if !text[range].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                count += 1
            }
            return true
        }
        return count
    }

    private func formattedTime(_ date: Date) -> String {
        Self.detailTimeFormatter.string(from: date)
    }

    private func updateSelectionIfNeeded() {
        uiState.updateSelectionIfNeeded(in: filteredEntries)
    }

    private func ensureSelectedEntryVisibleInLoadedEntries() {
        guard let selectedEntryID = uiState.selectedEntryID,
              let selectedIndex = filteredEntries.firstIndex(where: { $0.id == selectedEntryID }) else {
            return
        }

        loadedEntryCount = min(filteredEntries.count, max(loadedEntryCount, selectedIndex + 1))
    }

    private func clampVisibleEntriesToFilteredCount() {
        loadedEntryCount = min(max(loadedEntryCount, Self.initialLoadCount), filteredEntries.count)
    }

    private func loadMoreIfNeeded(currentEntry: ClipboardEntry) {
        guard let currentIndex = visibleEntries.firstIndex(where: { $0.id == currentEntry.id }) else { return }
        let thresholdIndex = max(0, visibleEntries.count - Self.loadMoreTriggerDistance)
        guard currentIndex >= thresholdIndex else { return }
        guard loadedEntryCount < filteredEntries.count else { return }

        loadedEntryCount = min(loadedEntryCount + Self.loadMoreBatchCount, filteredEntries.count)
    }

    private func scrollToSelectedEntry(proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedEntryID = uiState.selectedEntryID,
              visibleEntries.contains(where: { $0.id == selectedEntryID }) else {
            return
        }

        let action = {
            proxy.scrollTo(selectedEntryID, anchor: .center)
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.12)) {
                action()
            }
        } else {
            action()
        }
    }

    private func scrollToTop(proxy: ScrollViewProxy, animated: Bool) {
        guard let firstEntryID = visibleEntries.first?.id else { return }

        let action = {
            proxy.scrollTo(firstEntryID, anchor: .top)
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.12)) {
                action()
            }
        } else {
            action()
        }
    }

    private func resetLoadedEntriesForNewSession() {
        loadedEntryCount = min(Self.initialLoadCount, filteredEntries.count)
    }

    private func focusSearchField() {
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private func startKeyMonitor() {
        guard keyEventMonitor == nil else { return }
        let handler = ClipboardHistoryKeyHandler(
            moveSelection: { direction in
                selectionChangeSource = .keyboard
                uiState.moveSelection(in: displayedEntries, direction: direction)
            },
            paste: {
                pasteSelectedEntry()
            }
        )
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let handled = handler.handleKeyDown(keyCode: event.keyCode)
            return handled ? nil : event
        }
    }

    private func stopKeyMonitor() {
        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
        }
        keyEventMonitor = nil
    }

    private func pasteSelectedEntry() {
        guard let entry = selectedEntry else { return }
        pasteEntry(entry)
    }

    private func pasteEntry(_ entry: ClipboardEntry) {
        // blob 类型的条目可能 Data 为 nil（轻量模式），需要先从 DB 加载完整内容
        var entryToPaste = entry
        switch entry.content {
        case .image(nil), .rtf(nil), .unknown(nil):
            if let fullContent = history.fullContent(for: entry.id) {
                entryToPaste = entry.withContent(fullContent)
            }
        default:
            break
        }
        pasteService.paste(
            entry: entryToPaste,
            close: onRequestClose,
            isReadyToPaste: isReadyToPaste,
            targetPID: pasteTargetPIDProvider()
        )
    }

}

@MainActor
struct ClipboardHistoryRowActionHandler {
    let select: (UUID) -> Void
    let paste: (ClipboardEntry) -> Void

    func handleClick(entry: ClipboardEntry, clickCount: Int) {
        if clickCount >= 2 {
            paste(entry)
        } else {
            select(entry.id)
        }
    }
}

@MainActor
struct ClipboardHistoryKeyHandler {
    let moveSelection: (Int) -> Void
    let paste: () -> Void

    nonisolated static func scrollAnchor(forMoveDirection direction: Int) -> ClipboardHistoryScrollAnchor {
        direction > 0 ? .bottom : .top
    }

    func handleKeyDown(keyCode: UInt16) -> Bool {
        switch keyCode {
        case UInt16(kVK_UpArrow):
            moveSelection(-1)
            return true
        case UInt16(kVK_DownArrow):
            moveSelection(1)
            return true
        case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
            paste()
            return true
        default:
            return false
        }
    }
}

enum ClipboardHistoryScrollAnchor: Equatable {
    case top
    case bottom

    var unitPoint: UnitPoint {
        switch self {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }
}

struct ClipboardHistoryScrollPlanner {
    static func plannedAnchor(
        oldSelectedID: UUID?,
        newSelectedID: UUID,
        entries: [ClipboardEntry]
    ) -> ClipboardHistoryScrollAnchor? {
        guard let oldSelectedID else { return nil }
        guard let oldIndex = entries.firstIndex(where: { $0.id == oldSelectedID }) else { return nil }
        guard let newIndex = entries.firstIndex(where: { $0.id == newSelectedID }) else { return nil }

        let direction = newIndex - oldIndex
        guard direction != 0 else { return nil }

        return ClipboardHistoryKeyHandler.scrollAnchor(forMoveDirection: direction)
    }
}

struct ClipboardHistoryScrollDecider {
    static func shouldScroll(selectedID: UUID, visibleIDs: Set<UUID>) -> Bool {
        guard !visibleIDs.isEmpty else { return false }
        return visibleIDs.contains(selectedID) == false
    }
}

struct ThinScrollIndicatorVisibilityTracker {
    private(set) var isVisible = false

    mutating func requestShow() -> Bool {
        guard !isVisible else { return false }
        isVisible = true
        return true
    }

    mutating func requestHide() -> Bool {
        guard isVisible else { return false }
        isVisible = false
        return true
    }
}

private extension ClipboardContentType {
    var labelKey: String {
        switch self {
        case .text:
            return "clipboard.filter.text"
        case .image:
            return "clipboard.filter.image"
        case .file:
            return "clipboard.filter.file"
        case .url:
            return "clipboard.filter.url"
        case .rtf:
            return "clipboard.filter.rtf"
        case .unknown:
            return "clipboard.filter.unknown"
        }
    }
}

private struct ThinScrollIndicatorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(ThinScrollIndicatorApplier())
    }
}

private struct ThinScrollIndicatorApplier: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = nsView.enclosingScrollView else { return }
            context.coordinator.attach(to: scrollView)
        }
    }

    final class Coordinator: NSObject {
        private weak var scrollView: NSScrollView?
        private var hideTask: DispatchWorkItem?
        private var isObserving = false
        private var visibilityTracker = ThinScrollIndicatorVisibilityTracker()

        func attach(to scrollView: NSScrollView) {
            if self.scrollView !== scrollView {
                detach()
                self.scrollView = scrollView
                prepare(scrollView)
            }
            showTemporarily()
        }

        private func prepare(_ scrollView: NSScrollView) {
            scrollView.scrollerStyle = .overlay
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            configure(scroller: scrollView.verticalScroller)
            configure(scroller: scrollView.horizontalScroller)

            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(contentBoundsDidChange),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
            isObserving = true
            setIndicatorsVisible(false, animated: false)
        }

        private func configure(scroller: NSScroller?) {
            scroller?.controlSize = .mini
        }

        @objc private func contentBoundsDidChange() {
            showTemporarily()
        }

        private func showTemporarily() {
            if visibilityTracker.requestShow() {
                setIndicatorsVisible(true, animated: true)
            }
            scheduleHide()
        }

        private func scheduleHide() {
            hideTask?.cancel()
            let task = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if self.visibilityTracker.requestHide() {
                    self.setIndicatorsVisible(false, animated: true)
                }
            }
            hideTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: task)
        }

        private func setIndicatorsVisible(_ isVisible: Bool, animated: Bool) {
            guard let scrollView else { return }
            let alpha: CGFloat = isVisible ? 0.9 : 0
            let animator: (NSScroller?) -> Void = { scroller in
                guard let scroller else { return }
                if animated {
                    scroller.animator().alphaValue = alpha
                } else {
                    scroller.alphaValue = alpha
                }
            }

            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    animator(scrollView.verticalScroller)
                    animator(scrollView.horizontalScroller)
                }
            } else {
                animator(scrollView.verticalScroller)
                animator(scrollView.horizontalScroller)
            }
        }

        private func detach() {
            hideTask?.cancel()
            if isObserving, let contentView = scrollView?.contentView {
                NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: contentView)
            }
            isObserving = false
            visibilityTracker = ThinScrollIndicatorVisibilityTracker()
            scrollView = nil
        }

        deinit {
            detach()
        }
    }
}

private extension View {
    func thinScrollIndicators() -> some View {
        modifier(ThinScrollIndicatorModifier())
    }
}

// MARK: - 可选中文本视图

/// 包裹 NSTextView 的只读可选文本视图，支持鼠标拖选和 ⌘C 复制
private struct SelectableTextView: NSViewRepresentable {
    let text: String
    let font: NSFont

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = font
        textView.textColor = .labelColor
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticLinkDetectionEnabled = false

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            textView.font = font
            textView.textColor = .labelColor
        }
    }
}

private extension ClipboardEntry {
    var iconName: String {
        switch type {
        case .text:
            return "doc.text"
        case .image:
            return "photo"
        case .file:
            return "doc"
        case .url:
            return "link"
        case .rtf:
            return "doc.richtext"
        case .unknown:
            return "questionmark"
        }
    }
}
