//
//  KakuNoteUITests.swift
//  KakuNoteUITests
//
//  Created by KAWA on 2026/07/13.
//

import XCTest

final class KakuNoteUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    /// 「探す」で 2 文字・漢字・総画数 2 → 一一、一乙、乙一、乙乙 の順に出る。
    @MainActor
    func testNameOnlySearchOrder() throws {
        let app = XCUIApplication()
        app.launch()
        search(app, length: "2文字", total: "2")

        XCTAssertTrue(app.staticTexts["result.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result.total"].label, "4件")
        let names = ["一一", "一乙", "乙一", "乙乙"].map { app.buttons[$0] }
        XCTAssertTrue(names.allSatisfy(\.exists))
        // 上から順に並んでいる
        let ys = names.map(\.frame.minY)
        XCTAssertEqual(ys, ys.sorted())
    }

    /// 件数が 0 のときは、その旨が出る。
    @MainActor
    func testNameOnlySearchNoResults() throws {
        let app = XCUIApplication()
        app.launch()
        search(app, length: "1文字", total: "100")

        XCTAssertTrue(app.staticTexts["該当する名前がありません"].waitForExistence(timeout: 10))
    }

    /// 件数の多い検索でも先頭が出て、スクロールすると続き（51 件目以降）が出る。
    @MainActor
    func testLargeSearchLoadsMoreOnScroll() throws {
        let app = XCUIApplication()
        app.launch()
        search(app, length: "4文字", total: "8")

        XCTAssertTrue(app.staticTexts["result.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result.total"].label, "305,520件")
        XCTAssertTrue(app.buttons["一一一且"].exists)

        // 61 件目（2 ページ目）が出るまでスクロールする
        let later = app.buttons["一一一庁"]
        for _ in 0..<15 where !later.exists {
            app.swipeUp()
        }
        XCTAssertTrue(later.exists)
    }

    /// 姓込み検索: 天格が出て、人格・総格の条件を満たす候補が出る。候補を選ぶと五格が出る。
    @MainActor
    func testSearchWithSurname() throws {
        let app = XCUIApplication()
        app.launch()

        let sei = app.textFields["search.sei"]
        XCTAssertTrue(sei.waitForExistence(timeout: 5))
        sei.tap()
        sei.typeText("田中\n")
        let tenkaku = app.staticTexts["search.tenkaku"]
        XCTAssertTrue(tenkaku.waitForExistence(timeout: 5))
        XCTAssertEqual(tenkaku.label, "9画")

        app.buttons["2文字"].tap()
        type(app, "15", into: "search.kaku.jinkaku")
        type(app, "24", into: "search.kaku.soukaku")
        let submit = app.buttons["search.submit"]
        for _ in 0..<5 where !submit.isHittable {
            app.swipeUp()
        }
        submit.tap()

        XCTAssertTrue(app.staticTexts["result.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result.total"].label, "23,716件")
        let first = app.buttons["乾不"]
        XCTAssertTrue(first.exists)
        first.tap()

        let jinkaku = app.staticTexts["lookup.kaku.jinkaku"]
        XCTAssertTrue(jinkaku.waitForExistence(timeout: 5))
        XCTAssertEqual(jinkaku.label, "15画")
        XCTAssertEqual(app.staticTexts["lookup.kaku.tenkaku"].label, "9画")
        for _ in 0..<3 where !app.staticTexts["lookup.kaku.soukaku"].exists {
            app.swipeUp()
        }
        XCTAssertEqual(app.staticTexts["lookup.kaku.soukaku"].label, "24画")
    }

    @MainActor
    private func type(_ app: XCUIApplication, _ text: String, into identifier: String) {
        let field = app.textFields[identifier]
        for _ in 0..<5 where !field.isHittable {
            app.swipeUp()
        }
        field.tap()
        field.typeText(text + "\n")
    }

    @MainActor
    private func search(_ app: XCUIApplication, length: String, total: String) {
        let lengthButton = app.buttons[length]
        XCTAssertTrue(lengthButton.waitForExistence(timeout: 5))
        lengthButton.tap()
        // 文字数が多いと、総画数の欄は画面の下にあるのでスクロールする
        let totalField = app.textFields["search.total"]
        for _ in 0..<5 where !totalField.isHittable {
            app.swipeUp()
        }
        totalField.tap()
        totalField.typeText(total + "\n")
        let submit = app.buttons["search.submit"]
        for _ in 0..<5 where !submit.isHittable {
            app.swipeUp()
        }
        submit.tap()
    }

    /// 「調べる」タブで姓名を入れると、五格が出る。
    @MainActor
    func testLookupShowsKaku() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["調べる"].tap()

        let sei = app.textFields["lookup.sei"]
        XCTAssertTrue(sei.waitForExistence(timeout: 5))
        sei.tap()
        sei.typeText("林")
        let mei = app.textFields["lookup.mei"]
        mei.tap()
        mei.typeText("健太\n")
        app.swipeUp()

        let gaikaku = app.staticTexts["lookup.kaku.gaikaku"]
        XCTAssertTrue(gaikaku.waitForExistence(timeout: 5))
        XCTAssertEqual(gaikaku.label, "12画")
        XCTAssertEqual(app.staticTexts["lookup.kaku.tenkaku"].label, "8画")
        XCTAssertEqual(app.staticTexts["lookup.kaku.jinkaku"].label, "19画")
        XCTAssertEqual(app.staticTexts["lookup.kaku.chikaku"].label, "15画")
        XCTAssertEqual(app.staticTexts["lookup.kaku.soukaku"].label, "23画")
    }

    /// 繰り返し記号やひらがなを含む姓名でも出る。
    @MainActor
    func testLookupWithOdorijiAndHiragana() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["調べる"].tap()

        let sei = app.textFields["lookup.sei"]
        XCTAssertTrue(sei.waitForExistence(timeout: 5))
        sei.tap()
        sei.typeText("佐々木")
        let mei = app.textFields["lookup.mei"]
        mei.tap()
        mei.typeText("さくら\n")
        app.swipeUp()

        let soukaku = app.staticTexts["lookup.kaku.soukaku"]
        XCTAssertTrue(soukaku.waitForExistence(timeout: 5))
        XCTAssertEqual(soukaku.label, "21画")
        XCTAssertEqual(app.staticTexts["lookup.kaku.gaikaku"].label, "14画")
    }

    /// 「探す」「調べる」の右上のボタンから「このアプリについて」を開ける。出典とデータのバージョンが出る。
    @MainActor
    func testAboutScreenFromBothTabs() throws {
        let app = XCUIApplication()
        app.launch()

        for tab in ["探す", "調べる"] {
            app.tabBars.buttons[tab].tap()
            let about = app.buttons["about.open"]
            XCTAssertTrue(about.waitForExistence(timeout: 5), tab)
            about.tap()

            XCTAssertTrue(app.staticTexts["about.KANJIDIC2.version"].waitForExistence(timeout: 5), tab)
            XCTAssertEqual(app.staticTexts["about.KANJIDIC2.version"].label, "2026-291")
            XCTAssertEqual(app.staticTexts["about.Unihan.version"].label, "Unicode 17.0.0")
            XCTAssertTrue(app.descendants(matching: .any)["CC BY-SA 4.0"].exists)

            app.buttons["about.close"].tap()
            XCTAssertTrue(about.waitForExistence(timeout: 5), tab)
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
