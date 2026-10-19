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
        // 画面の配置は縦向きを前提にしている
        XCUIDevice.shared.orientation = .portrait

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
        search(app, length: 2, total: "2")

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
        search(app, length: 1, total: "100")

        XCTAssertTrue(app.staticTexts["該当する名前がありません"].waitForExistence(timeout: 10))
    }

    /// 文字数のステッパーは 1〜6 の間だけ動く。6 文字の検索もできる。
    @MainActor
    func testLengthStepperRangeAndSixChars() throws {
        let app = XCUIApplication()
        app.launch()
        // 数字と「文字」を 1 つにまとめた要素なので、種類を問わずに探す
        let value = app.descendants(matching: .any)["search.length.value"].firstMatch
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        XCTAssertEqual(value.label, "2文字")

        app.buttons["search.length.minus"].tap()
        XCTAssertEqual(value.label, "1文字")
        XCTAssertFalse(app.buttons["search.length.minus"].isEnabled)

        for _ in 0..<7 {
            app.buttons["search.length.plus"].tap()
        }
        XCTAssertEqual(value.label, "6文字")
        XCTAssertFalse(app.buttons["search.length.plus"].isEnabled)

        // 6 文字・総画数 6 → 一一一一一一 から 64 件
        search(app, length: 6, total: "6")
        XCTAssertTrue(app.staticTexts["result.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result.total"].label, "64件")
        XCTAssertTrue(app.buttons["一一一一一一"].exists)
    }

    /// 名前の形のマスを選んで固定すると、マスにその字が出て、検索の条件になる。6 文字ではマスが横に並ぶ。
    @MainActor
    func testNameShapeCellsFixAChar() throws {
        let app = XCUIApplication()
        app.launch()

        // 最初は 2 文字で、1 文字目のマスが選ばれている
        let cell1 = app.buttons["search.cell.1"]
        XCTAssertTrue(cell1.waitForExistence(timeout: 5))
        XCTAssertEqual(cell1.value as? String, "選択中")
        XCTAssertEqual(cell1.label, "1文字目 自由")

        // 1 文字目を「陽」に固定する
        app.buttons["search.kind.fixed"].tap()
        let fixed = app.textFields["search.fixed"]
        XCTAssertTrue(fixed.waitForExistence(timeout: 5))
        fixed.tap()
        fixed.typeText("陽\n")
        XCTAssertEqual(cell1.label, "1文字目 陽")

        // 2 文字目のマスを選ぶと、条件の切り替えがそのマスのものになる
        app.buttons["search.cell.2"].tap()
        XCTAssertEqual(app.buttons["search.cell.2"].value as? String, "選択中")
        XCTAssertFalse(app.textFields["search.fixed"].exists)

        // 陽（12 画）+ 1 画の漢字（一・乙）= 総画数 13
        search(app, length: 2, total: "13")
        XCTAssertTrue(app.staticTexts["result.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result.total"].label, "2件")
        XCTAssertTrue(app.buttons["陽一"].exists)
        XCTAssertTrue(app.buttons["陽乙"].exists)
    }

    /// 6 文字にすると、名前の形のマスが 6 つ並ぶ（入りきらない分は横にスクロールする）。
    @MainActor
    func testSixCellsScrollHorizontally() throws {
        let app = XCUIApplication()
        app.launch()
        setLength(app, 6)
        let cell6 = app.buttons["search.cell.6"]
        XCTAssertTrue(cell6.waitForExistence(timeout: 5))
        app.buttons["search.cell.1"].swipeLeft()
        XCTAssertTrue(cell6.isHittable)
        cell6.tap()
        XCTAssertEqual(cell6.value as? String, "選択中")
    }

    /// 「この条件で探す」は、スクロールしなくても押せる。
    @MainActor
    func testSubmitButtonIsAlwaysVisible() throws {
        let app = XCUIApplication()
        app.launch()
        let submit = app.buttons["search.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertTrue(submit.isHittable)
        setLength(app, 6)
        XCTAssertTrue(submit.isHittable)
        // 総画数が空なら、その旨が出る
        submit.tap()
        XCTAssertEqual(app.staticTexts["search.formError"].label, "総画数を入力してください")
    }

    /// 件数の多い検索でも先頭が出て、スクロールすると続き（51 件目以降）が出る。
    @MainActor
    func testLargeSearchLoadsMoreOnScroll() throws {
        let app = XCUIApplication()
        app.launch()
        search(app, length: 4, total: "8")

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

        setLength(app, 2)
        // 姓ありでは、一番上のカードが総格。人格は「ほかの格」の折りたたみの中
        type(app, "24", into: "search.total")
        openOtherKaku(app)
        type(app, "15", into: "search.kaku.jinkaku")
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

    /// 一覧の候補をお気に入りに保存し、「お気に入り」タブで五格と条件が見られる。
    /// アプリを終了して起動し直しても残っていて、削除もできる。
    @MainActor
    func testFavoritesSaveListPersistAndDelete() throws {
        let app = XCUIApplication()
        app.launchEnvironment["KAKUNOTE_FAVORITES_FILE"] = "uitest-favorites.sqlite"
        app.launchEnvironment["KAKUNOTE_FAVORITES_RESET"] = "1"
        app.launch()

        app.tabBars.buttons["お気に入り"].tap()
        XCTAssertTrue(app.staticTexts["お気に入りはまだありません"].waitForExistence(timeout: 5))

        // 「探す」: 姓「田中」・2 文字・人格 15・総格 24
        app.tabBars.buttons["探す"].tap()
        let sei = app.textFields["search.sei"]
        XCTAssertTrue(sei.waitForExistence(timeout: 5))
        sei.tap()
        sei.typeText("田中\n")
        setLength(app, 2)
        // 姓ありでは、一番上のカードが総格。人格は「ほかの格」の折りたたみの中
        type(app, "24", into: "search.total")
        openOtherKaku(app)
        type(app, "15", into: "search.kaku.jinkaku")
        let submit = app.buttons["search.submit"]
        for _ in 0..<5 where !submit.isHittable {
            app.swipeUp()
        }
        submit.tap()

        let heart = app.buttons["favorite.toggle.乾不"]
        XCTAssertTrue(heart.waitForExistence(timeout: 10))
        XCTAssertEqual(heart.label, "お気に入りに追加")
        heart.tap()
        XCTAssertEqual(heart.label, "お気に入りから外す")
        XCTAssertEqual(heart.value as? String, "保存済み")

        let expectedRow = "田中 乾不、天格 9画、人格 15画、地格 15画、外格 9画、総格 24画、2文字・人格 15・総格 24"
        app.tabBars.buttons["お気に入り"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[expectedRow].waitForExistence(timeout: 5))

        // 終了して起動し直しても残っている
        app.terminate()
        app.launchEnvironment["KAKUNOTE_FAVORITES_RESET"] = "0"
        app.launch()
        app.tabBars.buttons["お気に入り"].tap()
        let row = app.descendants(matching: .any)[expectedRow].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // スワイプで削除できる
        row.swipeLeft()
        // シミュレータの言語によって、ボタンの名前が変わる
        app.buttons.matching(NSPredicate(format: "label IN %@", ["Delete", "削除"])).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["お気に入りはまだありません"].waitForExistence(timeout: 5))
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

    /// 姓ありのとき、「ほかの格」の折りたたみを開く。
    @MainActor
    private func openOtherKaku(_ app: XCUIApplication) {
        let disclosure = app.buttons["ほかの格も条件にする（人格・地格・外格）"]
        for _ in 0..<5 where !disclosure.isHittable {
            app.swipeUp()
        }
        disclosure.tap()
        XCTAssertTrue(app.textFields["search.kaku.jinkaku"].waitForExistence(timeout: 5))
    }

    /// 文字数のステッパーで、名の文字数を合わせる。
    @MainActor
    private func setLength(_ app: XCUIApplication, _ length: Int) {
        // 数字と「文字」を 1 つにまとめた要素なので、種類を問わずに探す
        let value = app.descendants(matching: .any)["search.length.value"].firstMatch
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        for _ in 0..<6 where value.label != "\(length)文字" {
            let current = Int(value.label.replacingOccurrences(of: "文字", with: "")) ?? length
            app.buttons[current < length ? "search.length.plus" : "search.length.minus"].tap()
        }
        XCTAssertEqual(value.label, "\(length)文字")
    }

    @MainActor
    private func search(_ app: XCUIApplication, length: Int, total: String) {
        setLength(app, length)
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
