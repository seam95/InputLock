import XCTest
@testable import InputLock

@MainActor
final class ClipboardHistoryManagerTests: XCTestCase {
    func test_defaultsPersistToUserDefaults() {
        let defaults = UserDefaults(suiteName: "ClipboardHistoryManagerTests")!
        defaults.removePersistentDomain(forName: "ClipboardHistoryManagerTests")

        let store = FakeClipboardStore(entries: [])
        let manager = ClipboardHistoryManager(store: store, userDefaults: defaults)

        XCTAssertEqual(manager.retentionDays, 7)
        XCTAssertEqual(manager.maxEntries, 250)

        manager.retentionDays = 3
        manager.maxEntries = 120

        let reloaded = ClipboardHistoryManager(store: store, userDefaults: defaults)
        XCTAssertEqual(reloaded.retentionDays, 3)
        XCTAssertEqual(reloaded.maxEntries, 120)
    }

    func test_addEntryDeduplicatesLatest() {
        let store = FakeClipboardStore(entries: [])
        let defaults = UserDefaults(suiteName: "ClipboardHistoryManagerTests_dedup")!
        defaults.removePersistentDomain(forName: "ClipboardHistoryManagerTests_dedup")
        let manager = ClipboardHistoryManager(store: store, userDefaults: defaults)

        let entry = ClipboardEntry(
            id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            createdAt: Date(),
            type: .text,
            preview: "Same",
            sourceAppBundleID: nil,
            sourceAppName: nil,
            content: .text("Same")
        )

        manager.addEntry(entry)
        manager.addEntry(entry)

        XCTAssertEqual(manager.entries.count, 1)
    }

    func test_pruneRemovesExpiredAndLimitsCount() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = [
            ClipboardEntry(id: UUID(), createdAt: now, type: .text, preview: "1", sourceAppBundleID: nil, sourceAppName: nil, content: .text("1")),
            ClipboardEntry(id: UUID(), createdAt: now.addingTimeInterval(-60 * 60 * 24 * 10), type: .text, preview: "old", sourceAppBundleID: nil, sourceAppName: nil, content: .text("old")),
            ClipboardEntry(id: UUID(), createdAt: now.addingTimeInterval(-60 * 60 * 24 * 2), type: .text, preview: "2", sourceAppBundleID: nil, sourceAppName: nil, content: .text("2")),
            ClipboardEntry(id: UUID(), createdAt: now.addingTimeInterval(-60 * 60 * 24 * 1), type: .text, preview: "3", sourceAppBundleID: nil, sourceAppName: nil, content: .text("3"))
        ]

        let pruned = ClipboardHistoryManager.pruneEntries(
            entries,
            retentionDays: 7,
            maxEntries: 2,
            now: now
        )

        XCTAssertEqual(pruned.count, 2)
        XCTAssertTrue(pruned.allSatisfy { $0.createdAt >= now.addingTimeInterval(-60 * 60 * 24 * 7) })
    }

    func test_makeDefaultStoreUsesGRDBClipboardStore() {
        let store = ClipboardHistoryManager.makeDefaultStore()

        XCTAssertTrue(store is GRDBClipboardStore)
    }
}

private final class FakeClipboardStore: ClipboardStore {
    private(set) var entries: [ClipboardEntry]
    private(set) var savedEntries: [ClipboardEntry] = []
    private(set) var deletedIDs: Set<UUID> = []

    init(entries: [ClipboardEntry]) {
        self.entries = entries
    }

    func loadEntries() -> [ClipboardEntry] {
        entries
    }

    func saveEntries(_ entries: [ClipboardEntry]) {
        self.entries = entries
    }

    func saveEntry(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
        entries.insert(entry, at: 0)
        savedEntries.append(entry)
    }

    func deleteEntries(ids: Set<UUID>) {
        entries.removeAll { ids.contains($0.id) }
        deletedIDs.formUnion(ids)
    }

    func loadFullContent(for entryID: UUID) -> ClipboardContent? {
        entries.first { $0.id == entryID }?.content
    }
}
