import XCTest
@testable import InputLock

final class LaunchAtLoginManagerTests: XCTestCase {
    func test_togglePersistsPreference() {
        let suiteName = "LaunchAtLoginManagerTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let client = FakeLaunchAtLoginClient()
        let manager = LaunchAtLoginManager(client: client, userDefaults: defaults)

        XCTAssertFalse(manager.isEnabled)

        manager.setEnabled(true)
        XCTAssertTrue(manager.isEnabled)

        let reloaded = LaunchAtLoginManager(client: client, userDefaults: defaults)
        XCTAssertTrue(reloaded.isEnabled)
    }

    func test_toggleCallsClient() {
        let suiteName = "LaunchAtLoginManagerTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let client = FakeLaunchAtLoginClient()
        let manager = LaunchAtLoginManager(client: client, userDefaults: defaults)

        manager.setEnabled(true)
        XCTAssertEqual(client.lastEnabled, true)

        manager.setEnabled(false)
        XCTAssertEqual(client.lastEnabled, false)
    }
}
