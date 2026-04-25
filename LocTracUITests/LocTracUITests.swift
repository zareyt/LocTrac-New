//
//  LocTracUITests.swift
//  LocTracUITests
//
//  Created by Tim Arey on 4/23/26.
//

import XCTest

final class LocTracUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments.append("-UITesting")
        app.launch()

        // Safety net: dismiss any modal sheet that slipped through
        dismissModalIfPresent()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Attempts to dismiss common blocking sheets (What's New, First Launch Wizard)
    private func dismissModalIfPresent() {
        // What's New has a "Skip" button
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 2) {
            skipButton.tap()
        }

        // First Launch Wizard — swipe down won't work (interactiveDismissDisabled),
        // but -UITesting launch arg should prevent it from showing at all
    }

    // MARK: - Tests

    @MainActor
    func testAppLaunches() throws {
        // Verify the app launched and the tab bar is visible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should be visible after launch")
    }

    @MainActor
    func testHomeTabExists() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let homeTab = tabBar.buttons["Home"]
        XCTAssertTrue(homeTab.exists, "Home tab should exist")
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let perfApp = XCUIApplication()
            perfApp.launchArguments.append("-UITesting")
            perfApp.launch()
        }
    }

    // MARK: - Tab Navigation

    @MainActor
    func testAllTabsNavigate() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Tap each tab and verify it becomes selected
        let tabNames = ["Home", "Calendar", "Charts", "Travel Map", "Infographic"]
        for tabName in tabNames {
            let tab = tabBar.buttons[tabName]
            XCTAssertTrue(tab.exists, "\(tabName) tab should exist")
            tab.tap()
            // Small delay for tab switch animation
            XCTAssertTrue(tab.isSelected, "\(tabName) tab should be selected after tap")
        }
    }

    // MARK: - Options Menu

    @MainActor
    func testOptionsMenuOpens() throws {
        // Find the Options menu button (ellipsis.circle with accessibilityLabel "Options")
        let optionsButton = app.buttons["Options"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 5), "Options menu button should exist")
        optionsButton.tap()

        // Verify key menu items are visible
        let profileButton = app.buttons["Profile & Account"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 3), "Profile & Account should appear in menu")

        let aboutButton = app.buttons["About LocTrac"]
        XCTAssertTrue(aboutButton.exists, "About LocTrac should appear in menu")

        // Dismiss the menu by tapping elsewhere
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    // MARK: - About Sheet

    @MainActor
    func testAboutSheetOpensAndDismisses() throws {
        let optionsButton = app.buttons["Options"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 5))
        optionsButton.tap()

        let aboutButton = app.buttons["About LocTrac"]
        XCTAssertTrue(aboutButton.waitForExistence(timeout: 3))
        aboutButton.tap()

        // Verify the About sheet appeared (it should have some identifiable content)
        // Look for a Done/dismiss button or the app name text
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
        } else {
            // Swipe down to dismiss if no Done button
            app.swipeDown()
        }

        // Verify we're back to the main view (tab bar visible)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
    }

    // MARK: - Profile Sheet

    @MainActor
    func testProfileSheetOpensAndDismisses() throws {
        let optionsButton = app.buttons["Options"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 5))
        optionsButton.tap()

        let profileButton = app.buttons["Profile & Account"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 3))
        profileButton.tap()

        // Profile sheet has a "Done" cancellation button
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3), "Profile sheet should have Done button")
        doneButton.tap()

        // Verify we're back to the main view
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
    }

    // MARK: - Calendar Tab Content

    @MainActor
    func testCalendarTabShowsContent() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["Calendar"].tap()

        // The calendar view should have some content visible
        // Wait a moment for the view to load
        sleep(1)

        // Verify the navigation area shows the "Stays" title or calendar content exists
        // The calendar should have at least one element visible
        XCTAssertTrue(app.staticTexts.count > 0, "Calendar tab should display content")
    }

    // MARK: - Travel History Sheet

    @MainActor
    func testTravelHistoryOpensAndDismisses() throws {
        let optionsButton = app.buttons["Options"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 5))
        optionsButton.tap()

        let travelHistoryButton = app.buttons["Travel History"]
        XCTAssertTrue(travelHistoryButton.waitForExistence(timeout: 3))
        travelHistoryButton.tap()

        // Travel History view has a "Done" button
        let doneButton = app.buttons["Done"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
        } else {
            app.swipeDown()
        }

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
    }

    // MARK: - Add Event Flow

    @MainActor
    func testAddEventFormOpensFromCalendar() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Navigate to Calendar tab
        tabBar.buttons["Calendar"].tap()
        sleep(1)

        // Tap the add button (plus.circle.fill in the toolbar)
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add'")).firstMatch
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        } else {
            // Try finding by image name
            let plusButton = app.images["plus.circle.fill"].firstMatch
            if plusButton.waitForExistence(timeout: 2) {
                plusButton.tap()
            } else {
                // Fallback: look for any button in the navigation bar area
                let navButtons = app.navigationBars.buttons
                for i in 0..<navButtons.count {
                    let btn = navButtons.element(boundBy: i)
                    if btn.label.isEmpty || btn.label.contains("Add") {
                        btn.tap()
                        break
                    }
                }
            }
        }

        // Wait for the event form to appear — it should have a "Location" or event type picker
        sleep(1)

        // Verify we navigated away from the calendar (back button should exist)
        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 3), "Form should show a navigation back button")

        // Go back to calendar
        backButton.tap()

        // Verify we're back at the calendar
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
    }

    // MARK: - Manage Data Submenu

    @MainActor
    func testManageDataSubmenuItems() throws {
        let optionsButton = app.buttons["Options"]
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 5))
        optionsButton.tap()

        // Tap into Manage Data submenu
        let manageDataButton = app.buttons["Manage Data"]
        XCTAssertTrue(manageDataButton.waitForExistence(timeout: 3), "Manage Data submenu should exist")
        manageDataButton.tap()

        // Verify submenu items appear
        let manageLocations = app.buttons["Manage Locations"]
        XCTAssertTrue(manageLocations.waitForExistence(timeout: 3), "Manage Locations should appear")

        let manageTrips = app.buttons["Manage Trips"]
        XCTAssertTrue(manageTrips.exists, "Manage Trips should appear")

        // Dismiss menu
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
