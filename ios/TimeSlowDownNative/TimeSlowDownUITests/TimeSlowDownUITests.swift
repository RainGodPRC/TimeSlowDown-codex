import XCTest

@MainActor
final class TimeSlowDownUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEmptyVaultCanCreateAQuickMark() {
        let app = launchApp(fixture: "empty")

        let emptyState = app.descendants(matching: .any)["now.emptyState"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5))

        app.buttons["now.quickMark"].tap()
        let title = app.textFields["quickMark.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        title.typeText("UI 测试第一刻")
        app.buttons["quickMark.save"].tap()

        XCTAssertFalse(emptyState.exists)
        app.tabBars.buttons["切片"].tap()
        XCTAssertTrue(app.staticTexts["UI 测试第一刻"].waitForExistence(timeout: 3))
    }

    func testSeededSliceCanBeEditedDeletedAndUndone() {
        let app = launchApp(fixture: "seeded")
        let originalTitle = app.staticTexts["测试切片：雨后散步"]
        XCTAssertTrue(originalTitle.waitForExistence(timeout: 5))

        originalTitle.tap()
        let title = app.textFields["sliceDetail.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        title.typeText(" · 已编辑")
        app.buttons["sliceDetail.save"].tap()
        app.buttons["sliceDetail.delete"].tap()

        let editedRow = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "已编辑"))
            .firstMatch
        XCTAssertFalse(editedRow.exists)
        let undo = app.buttons["sliceList.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()
        XCTAssertTrue(editedRow.waitForExistence(timeout: 3))
    }

    func testAccountExportsRemainReachableAtAccessibilityTextSize() {
        let app = launchApp(
            fixture: "seeded",
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXL"
        )
        app.tabBars.buttons["我的"].tap()

        let scrollView = app.scrollViews["account.scroll"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["account.memoryExport"].exists)

        let diagnosticsExport = app.buttons["account.diagnosticsExport"]
        XCTAssertTrue(diagnosticsExport.exists)
        for _ in 0..<4 where !diagnosticsExport.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(diagnosticsExport.isHittable)
        diagnosticsExport.tap()

        let diagnosticsStatus = app.staticTexts["account.diagnosticsStatus"]
        XCTAssertTrue(diagnosticsStatus.waitForExistence(timeout: 5))
        XCTAssertNotEqual(app.state, .notRunning)
    }

    func testFirstRunCreatesASourceBackedMemoryBeforeEnteringTheApp() {
        let app = launchApp(fixture: "onboarding")

        let onboarding = app.descendants(matching: .any)["onboarding.container"]
        XCTAssertTrue(onboarding.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboarding.photo"].exists)
        app.buttons["onboarding.person"].tap()

        let text = app.textFields["onboarding.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 3))
        text.tap()
        text.typeText("晚饭时爸爸讲起年轻时的故事")
        app.buttons["onboarding.save"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["onboarding.success"].waitForExistence(timeout: 3))
        app.buttons["onboarding.enter"].tap()
        XCTAssertFalse(onboarding.exists)
        XCTAssertTrue(app.staticTexts["晚饭时爸爸讲起年轻时的故事"].waitForExistence(timeout: 3))
    }

    func testFirstRunChoicesRemainReachableAtAccessibilityTextSize() {
        let app = launchApp(
            fixture: "onboarding",
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXL"
        )

        let scrollView = app.scrollViews["onboarding.container"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        let person = app.buttons["onboarding.person"]
        for _ in 0..<5 where !person.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(person.isHittable)
        XCTAssertTrue(app.buttons["onboarding.turn"].exists)
        XCTAssertTrue(app.buttons["onboarding.skip"].exists)
    }

    func testLifeMarkOpensItsPersistedSourceEvidence() {
        let app = launchApp(fixture: "seeded")
        app.tabBars.buttons["印记"].tap()

        let mark = app.buttons["lifeMark.card.firstLeaf"]
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        mark.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["lifeMark.detail.firstLeaf"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["测试切片：雨后散步"].exists)
        XCTAssertTrue(app.staticTexts["1 张切片 · 0 个影像 · 0 次回望"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Life Mark source detail"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLifeMarkSourceRemainsReadableAtAccessibilityTextSize() {
        let app = launchApp(
            fixture: "seeded",
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXL"
        )
        app.tabBars.buttons["印记"].tap()

        let mark = app.buttons["lifeMark.card.firstLeaf"]
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        mark.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["lifeMark.detail.firstLeaf"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["1 张切片 · 0 个影像 · 0 次回望"].exists)
        XCTAssertNotEqual(app.state, .notRunning)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Life Mark source detail Accessibility XXL"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launchApp(
        fixture: String,
        preferredContentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-test-fixture", fixture,
            "--ui-test-disable-animations"
        ]
        if let preferredContentSizeCategory {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                preferredContentSizeCategory
            ]
        }
        app.launch()
        return app
    }
}
