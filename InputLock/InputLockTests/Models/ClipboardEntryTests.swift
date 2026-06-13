import XCTest
@testable import InputLock

final class ClipboardEntryTests: XCTestCase {
    func test_initStoresFields() {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = ClipboardEntry(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            createdAt: createdAt,
            type: .text,
            preview: "Hello",
            sourceAppBundleID: "com.test.app",
            sourceAppName: "Test",
            content: .text("Hello")
        )

        XCTAssertEqual(entry.id.uuidString, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(entry.createdAt, createdAt)
        XCTAssertEqual(entry.type, .text)
        XCTAssertEqual(entry.preview, "Hello")
        XCTAssertEqual(entry.sourceAppBundleID, "com.test.app")
        XCTAssertEqual(entry.sourceAppName, "Test")
        XCTAssertEqual(entry.content, .text("Hello"))
        XCTAssertNil(entry.thumbnailData)
    }
}
