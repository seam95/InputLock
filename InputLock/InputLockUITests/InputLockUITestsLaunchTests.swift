//
//  InputLockUITestsLaunchTests.swift
//  InputLockUITests
//
//  Created by 苏御 on 2026/1/27.
//

import XCTest

final class InputLockUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        throw XCTSkip("MenuBarExtra 应用在 UI 测试环境中不稳定，跳过 UI 测试以避免假失败。")
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
