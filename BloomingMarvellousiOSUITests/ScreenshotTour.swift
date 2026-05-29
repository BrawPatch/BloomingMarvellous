import XCTest

/// Drives the app through the main wireframe screens and saves a screenshot
/// of each, named by step. The app is launched with BM_AUTO_LOGIN=1 so the
/// login screen is skipped and we land directly on Home with a mock Pro
/// user. Screenshots land in /tmp/bm_screens for stitching into a PDF.
final class ScreenshotTour: XCTestCase {

    private let outDir = "/tmp/bm_screens"

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)
    }

    func testTourOfAllScreens() throws {
        let app = XCUIApplication()
        app.launchEnvironment["BM_AUTO_LOGIN"] = "1"
        app.launchArguments.append("-BM_AUTO_LOGIN")
        app.launch()

        sleep(2)

        // 01 — Home (Pro, mock user)
        snap(app, name: "01-home")

        // 02 — Garden beds shortcut (first shortcut row → push into beds list)
        let bedsShortcut = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Garden beds' OR label CONTAINS 'beds'")).firstMatch
        if bedsShortcut.waitForExistence(timeout: 3) {
            bedsShortcut.tap()
            sleep(1)
            snap(app, name: "02-garden-beds")

            // 03 — Add bed sheet via toolbar plus
            let toolbarPlus = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS 'plus' OR label CONTAINS 'Add'")).firstMatch
            if toolbarPlus.exists {
                toolbarPlus.tap()
                sleep(1)
                snap(app, name: "03-add-bed")
                let cancel = app.buttons["Cancel"]
                if cancel.exists { cancel.tap() }
                sleep(1)
            }

            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap() }
            sleep(1)
        }

        // 04 — Task list shortcut
        let tasksShortcut = app.buttons.containing(NSPredicate(format: "label CONTAINS 'tasks' OR label CONTAINS 'Tasks'")).firstMatch
        if tasksShortcut.exists {
            tasksShortcut.tap()
            sleep(1)
            snap(app, name: "04-tasks")
            let backBtn = app.buttons["Back"]
            if backBtn.exists { backBtn.tap() } else if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
            sleep(1)
        }

        // 05 — Settings via gear overlay
        let gear = app.images["gearshape.fill"].firstMatch
        let gearBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'gear' OR label CONTAINS 'Settings'")).firstMatch
        if gear.exists {
            gear.tap()
        } else if gearBtn.exists {
            gearBtn.tap()
        }
        sleep(1)
        if app.staticTexts["Settings"].waitForExistence(timeout: 2) {
            snap(app, name: "05-settings")
            let backBtn = app.buttons["Back"]
            if backBtn.exists { backBtn.tap() }
            sleep(1)
        }

        // 06 — Soil tab
        if app.tabBars.buttons["Soil"].waitForExistence(timeout: 2) {
            app.tabBars.buttons["Soil"].tap()
            sleep(1)
            snap(app, name: "06-soil")
        }

        // 07 — Plant Picker tab — month grid
        if app.tabBars.buttons["Plants"].exists {
            app.tabBars.buttons["Plants"].tap()
            sleep(1)
            snap(app, name: "07-picker-month")

            let viewPlants = app.buttons["View plants"]
            if viewPlants.waitForExistence(timeout: 2) {
                viewPlants.tap()
                sleep(4) // wait for /v1/library fetch
                snap(app, name: "08-picker-gallery")

                // Tap first plant tile (a NavigationLink wraps each)
                let firstLink = app.scrollViews.descendants(matching: .button).firstMatch
                if firstLink.waitForExistence(timeout: 2) {
                    firstLink.tap()
                    sleep(1)
                    snap(app, name: "09-plant-detail")
                    let backBtn = app.navigationBars.buttons.firstMatch
                    if backBtn.exists { backBtn.tap() }
                    sleep(1)
                }

                let backBtn = app.navigationBars.buttons.firstMatch
                if backBtn.exists { backBtn.tap() }
                sleep(1)
            }
        }

        // 10 — Bloom Schedule
        if app.tabBars.buttons["Bloom"].exists {
            app.tabBars.buttons["Bloom"].tap()
            sleep(1)
            snap(app, name: "10-bloom-schedule")
        }

        // 11 — Planting Schedule + 12 — Add Event sheet
        if app.tabBars.buttons["Planting"].exists {
            app.tabBars.buttons["Planting"].tap()
            sleep(1)
            snap(app, name: "11-planting-schedule")

            let addEvent = app.buttons["Add to calendar"]
            if addEvent.waitForExistence(timeout: 2) {
                addEvent.tap()
                sleep(1)
                snap(app, name: "12-add-event")
                let cancel = app.buttons["Cancel"]
                if cancel.exists { cancel.tap() }
                sleep(1)
            }
        }

        // 13 — Login screen (final: relaunch without auto-login so the
        // BMFinal login is captured alongside the rest of the journey)
        app.terminate()
        let plain = XCUIApplication()
        plain.launch()
        sleep(2)
        snap(plain, name: "13-login")

        // 14 — Sign Up sheet
        let createAccount = plain.buttons["Create account"]
        if createAccount.waitForExistence(timeout: 2) {
            createAccount.tap()
            sleep(1)
            snap(plain, name: "14-signup")
        }
    }

    private func snap(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.lifetime = .keepAlways
        attachment.name = name
        add(attachment)

        let url = URL(fileURLWithPath: "\(outDir)/\(name).png")
        try? screenshot.pngRepresentation.write(to: url)
    }
}
