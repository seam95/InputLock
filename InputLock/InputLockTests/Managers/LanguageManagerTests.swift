import XCTest
@testable import InputLock

final class LanguageManagerTests: XCTestCase {
    func test_preferredLanguagePersists() {
        let suiteName = "LanguageManagerTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let manager = LanguageManager(userDefaults: defaults)
        XCTAssertNil(manager.preferredLanguage)

        manager.setPreferredLanguage("en")

        let reloaded = LanguageManager(userDefaults: defaults)
        XCTAssertEqual(reloaded.preferredLanguage, "en")
    }

    func test_clearPreferredLanguageRemovesFromDefaults() {
        let suiteName = "LanguageManagerTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let manager = LanguageManager(userDefaults: defaults)
        manager.setPreferredLanguage("en")
        manager.setPreferredLanguage(nil)

        let reloaded = LanguageManager(userDefaults: defaults)
        XCTAssertNil(reloaded.preferredLanguage)
    }
}
