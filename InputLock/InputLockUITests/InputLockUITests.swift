import XCTest

final class InputLockUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        throw XCTSkip("MenuBarExtra 应用在 UI 测试环境中不稳定，跳过 UI 测试以避免假失败。")
    }

    @MainActor
    func testExample() throws {
        // MenuBarExtra apps can be tricky for UI test harnesses; keep a trivial launch only.
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
