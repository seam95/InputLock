import XCTest
@testable import InputLock

@MainActor
final class LockStateManagerTests: XCTestCase {
    func test_lockAndUnlockPersistToUserDefaults() {
        let defaults = UserDefaults(suiteName: "LockStateManagerTests")!
        defaults.removePersistentDomain(forName: "LockStateManagerTests")

        let manager = LockStateManager(userDefaults: defaults)
        XCTAssertFalse(manager.isLocked)
        XCTAssertNil(manager.lockedInputSourceID)

        manager.lock(to: "com.test.input")
        XCTAssertTrue(manager.isLocked)
        XCTAssertEqual(manager.lockedInputSourceID, "com.test.input")

        let reloaded = LockStateManager(userDefaults: defaults)
        XCTAssertTrue(reloaded.isLocked)
        XCTAssertEqual(reloaded.lockedInputSourceID, "com.test.input")

        reloaded.unlock()
        XCTAssertFalse(reloaded.isLocked)
        XCTAssertNil(reloaded.lockedInputSourceID)
    }
}
