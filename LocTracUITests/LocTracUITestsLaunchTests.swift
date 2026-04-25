//
//  LocTracUITestsLaunchTests.swift
//  LocTracUITests
//
//  Created by Tim Arey on 4/23/26.
//

import XCTest

final class LocTracUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITesting")
        app.launch()

        // Dismiss any modal sheet that slipped through
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 2) {
            skipButton.tap()
        }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
