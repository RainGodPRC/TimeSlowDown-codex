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

    func testTimelineGroupsMonthsAndDaysAndOpensTheRealSlice() {
        let app = launchApp(fixture: "timeline")

        XCTAssertTrue(app.scrollViews["timeline.scroll"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["timeline.summary"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["timeline.month.2026-07"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["timeline.day.2026-07-02"].exists)
        XCTAssertTrue(app.staticTexts["清晨窗边的光"].exists)
        XCTAssertTrue(app.staticTexts["同一天的晚风"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Month and day grouped native Timeline"
        attachment.lifetime = .keepAlways
        add(attachment)

        let slice = app.staticTexts["同一天的晚风"]
        XCTAssertTrue(slice.exists)
        XCTAssertTrue(slice.isHittable)
        slice.tap()
        XCTAssertTrue(app.textFields["sliceDetail.title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["sliceDetail.title"].value as? String, "同一天的晚风")
    }

    func testTimelineRemainsNavigableAtAccessibilityTextSize() {
        let app = launchApp(
            fixture: "timeline",
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXL"
        )

        let scrollView = app.scrollViews["timeline.scroll"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["timeline.month.2026-07"].exists)
        let olderMonth = app.descendants(matching: .any)["timeline.month.2026-06"]
        for _ in 0..<5 where !olderMonth.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(olderMonth.isHittable)
        XCTAssertTrue(app.staticTexts["六月最后一次长谈"].exists)
        XCTAssertNotEqual(app.state, .notRunning)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Native Timeline Accessibility XXL"
        attachment.lifetime = .keepAlways
        add(attachment)
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

    func testBetaLearningBaselineStoresOnlyCountsAndScaleAnswers() {
        let app = launchApp(fixture: "seeded")
        app.tabBars.buttons["我的"].tap()

        let betaCard = app.buttons["betaLearning.open"]
        XCTAssertTrue(betaCard.waitForExistence(timeout: 5))
        betaCard.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["betaLearning.privacyBoundary"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.steppers["betaLearning.assessment.moments"].exists)
        XCTAssertTrue(app.steppers["betaLearning.assessment.detail"].exists)
        XCTAssertTrue(app.steppers["betaLearning.assessment.blur"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Beta learning Day 0 privacy-safe assessment"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["betaLearning.baseline.save"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["betaLearning.waiting"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.buttons["betaLearning.baseline.save"].exists)
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

    func testActiveRecallKeepsTheSourceHiddenUntilTheUserRequestsACue() {
        let app = launchApp(fixture: "seeded")
        app.tabBars.buttons["此刻"].tap()

        let card = app.buttons["activeRecall.open"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["activeRecall.sourceTitle"].exists)
        XCTAssertFalse(app.staticTexts["测试切片：雨后散步"].exists)
        let concealedAttachment = XCTAttachment(screenshot: app.screenshot())
        concealedAttachment.name = "Active recall concealed source"
        concealedAttachment.lifetime = .keepAlways
        add(concealedAttachment)
        card.tap()

        XCTAssertTrue(app.buttons["给我看看线索"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["测试切片：雨后散步"].exists)
        app.buttons["给我看看线索"].tap()
        XCTAssertTrue(app.staticTexts["测试切片：雨后散步"].waitForExistence(timeout: 3))
        let revealedAttachment = XCTAttachment(screenshot: app.screenshot())
        revealedAttachment.name = "Active recall revealed source"
        revealedAttachment.lifetime = .keepAlways
        add(revealedAttachment)
        app.buttons["安静放回记忆"].tap()

        XCTAssertFalse(app.buttons["给我看看线索"].waitForExistence(timeout: 1))
        XCTAssertFalse(card.waitForExistence(timeout: 1))
    }

    func testActiveRecallQuietSkipRemainsReachableAtAccessibilityTextSize() {
        let app = launchApp(
            fixture: "seeded",
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXL"
        )
        app.tabBars.buttons["此刻"].tap()
        app.buttons["activeRecall.open"].tap()

        let scrollView = app.scrollViews["activeRecall.sheet"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        let skip = app.buttons["activeRecall.skip"]
        for _ in 0..<4 where !skip.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(skip.isHittable)
        let accessibilityAttachment = XCTAttachment(screenshot: app.screenshot())
        accessibilityAttachment.name = "Active recall quiet skip Accessibility XXL"
        accessibilityAttachment.lifetime = .keepAlways
        add(accessibilityAttachment)
        skip.tap()
        XCTAssertFalse(app.scrollViews["activeRecall.sheet"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["activeRecall.open"].waitForExistence(timeout: 1))
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
