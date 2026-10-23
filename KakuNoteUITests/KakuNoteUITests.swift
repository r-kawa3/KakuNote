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
        let app = launchWithFreshSettings()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    /// 「探す」で 2 文字・漢字・総画数 2 → 一一、一乙、乙一、乙乙 の順に出る。
    @MainActor
    func testNameOnlySearchOrder() throws {
        let app = launchWithFreshSettings()
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
        let app = launchWithFreshSettings()
        search(app, length: 1, total: "100")

        XCTAssertTrue(app.staticTexts["該当する名前がありません"].waitForExistence(timeout: 10))
    }

    /// 文字数のステッパーは 1〜6 の間だけ動く。6 文字の検索もできる。
    @MainActor
    func testLengthStepperRangeAndSixChars() throws {
        let app = launchWithFreshSettings()
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
        let app = launchWithFreshSettings()

        // 最初は 2 文字で、どのマスも選ばれておらず、条件の欄は出ていない
        let cell1 = app.buttons["search.cell.1"]
        XCTAssertTrue(cell1.waitForExistence(timeout: 5))
        XCTAssertNotEqual(cell1.value as? String, "選択中")
        XCTAssertEqual(cell1.label, "1文字目 自由")
        XCTAssertFalse(app.buttons["search.kind.fixed"].exists)

        // 1 文字目のマスを押すと条件の欄が出る。「陽」に固定する
        cell1.tap()
        XCTAssertEqual(cell1.value as? String, "選択中")
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
        // 選んでいるマスをもう一度押すと閉じる
        app.buttons["search.cell.2"].tap()
        XCTAssertFalse(app.buttons["search.kind.fixed"].exists)

        // 陽（12 画）+ 1 画の漢字（一・乙）= 総画数 13
        search(app, length: 2, total: "13")
        XCTAssertTrue(app.staticTexts["result.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result.total"].label, "2件")
        XCTAssertTrue(app.buttons["陽一"].exists)
        XCTAssertTrue(app.buttons["陽乙"].exists)
    }

    /// 総画数の欄は数字専用のキーボードで、値は 1 つだけ（区切りの「,」は出さない）。「完了」で閉じられる。
    @MainActor
    func testTotalFieldTakesOneNumber() throws {
        let app = launchWithFreshSettings()

        let total = app.textFields["search.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        total.tap()
        total.typeText("24")
        XCTAssertTrue(app.buttons["keyboard.done"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["keyboard.comma"].exists)
        XCTAssertEqual(total.value as? String, "24")

        // 「完了」でキーボードが閉じ、「この条件で探す」が押せる
        app.buttons["keyboard.done"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 1))
        let submit = app.buttons["search.submit"]
        XCTAssertTrue(submit.isHittable)
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
        XCTAssertTrue(app.staticTexts["総画数 24画"].waitForExistence(timeout: 10))
    }

    /// ほかの格（人格・地格・外格）の欄は、区切りの「,」で複数の値を入れられる。
    @MainActor
    func testOtherKakuFieldsUseSeparator() throws {
        let app = launchWithFreshSettings()
        registerSei(app, "田中")
        openOtherKaku(app)
        let jinkaku = app.textFields["search.kaku.jinkaku"]
        jinkaku.tap()
        jinkaku.typeText("15")
        let comma = app.buttons["keyboard.comma"]
        XCTAssertTrue(comma.waitForExistence(timeout: 5))
        comma.tap()
        // 区切りで終わっているときは、もう一度押しても重ならない
        comma.tap()
        jinkaku.typeText("16")
        XCTAssertEqual(jinkaku.value as? String, "15,16")
        app.buttons["keyboard.done"].tap()
    }

    /// 画数指定の欄は区切りの「,」を出さない（1 つの値だけ）。
    @MainActor
    func testStrokesFieldHasNoSeparator() throws {
        let app = launchWithFreshSettings()
        let cell1 = app.buttons["search.cell.1"]
        XCTAssertTrue(cell1.waitForExistence(timeout: 5))
        cell1.tap()
        let kind = app.buttons["search.kind.strokes"]
        XCTAssertTrue(kind.waitForExistence(timeout: 5))
        kind.tap()
        let strokes = app.textFields["search.strokes"]
        XCTAssertTrue(strokes.waitForExistence(timeout: 5))
        strokes.tap()
        strokes.typeText("12")
        XCTAssertTrue(app.buttons["keyboard.done"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["keyboard.comma"].exists)
        app.buttons["keyboard.done"].tap()
        XCTAssertEqual(app.buttons["search.cell.1"].label, "1文字目 12画")
    }

    /// 6 文字にすると、名前の形のマスが 6 つ並ぶ（入りきらない分は横にスクロールする）。
    @MainActor
    func testSixCellsScrollHorizontally() throws {
        let app = launchWithFreshSettings()
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
        let app = launchWithFreshSettings()
        let submit = app.buttons["search.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertTrue(submit.isHittable)
        setLength(app, 6)
        XCTAssertTrue(submit.isHittable)
        // 総画数が空なら押せず、その旨が出る。入れると押せる
        XCTAssertFalse(submit.isEnabled)
        XCTAssertEqual(app.staticTexts["search.formError"].label, "総画数を入力してください")
        type(app, "6", into: "search.total")
        XCTAssertTrue(submit.isEnabled)
        XCTAssertFalse(app.staticTexts["search.formError"].exists)
    }

    /// 探す前にわかる誤り（固定の字が 2 文字、読みにひらがな以外）があると押せず、理由が出る。
    @MainActor
    func testSubmitDisabledWithReason() throws {
        let app = launchWithFreshSettings()
        type(app, "16", into: "search.total")
        let submit = app.buttons["search.submit"]
        XCTAssertTrue(submit.isEnabled)

        app.buttons["search.cell.1"].tap()
        app.buttons["search.kind.fixed"].tap()
        let fixed = app.textFields["search.fixed"]
        XCTAssertTrue(fixed.waitForExistence(timeout: 5))
        XCTAssertFalse(submit.isEnabled)
        XCTAssertEqual(app.staticTexts["search.formError"].label, "1文字目の条件を入力してください")
        fixed.tap()
        fixed.typeText("陽菜\n")
        XCTAssertEqual(app.staticTexts["search.formError"].label, "1文字目に固定する字は 1 文字にしてください")
        XCTAssertFalse(submit.isEnabled)
    }

    /// 姓が未登録のときは、総画数のカードの「姓を設定する」から設定画面を開ける。
    @MainActor
    func testSetSeiFromTotalCard() throws {
        let app = launchWithFreshSettings()
        let setSei = app.buttons["search.setSei"]
        XCTAssertTrue(setSei.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["姓を登録すると、総格で探せます"].exists)
        setSei.tap()
        let field = app.textFields["settings.sei"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("田中")
        app.buttons["settings.close"].tap()
        XCTAssertTrue(app.staticTexts["search.tenkaku"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["search.setSei"].exists)
        XCTAssertEqual(app.textFields["search.total"].label, "総格")
    }

    /// 件数の多い検索でも先頭が出て、スクロールすると続き（51 件目以降）が出る。
    @MainActor
    func testLargeSearchLoadsMoreOnScroll() throws {
        let app = launchWithFreshSettings()
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
        let app = launchWithFreshSettings()
        registerSei(app, "田中")

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
        app.launchEnvironment["KAKUNOTE_SETTINGS_FILE"] = "uitest-settings.json"
        app.launchEnvironment["KAKUNOTE_SETTINGS_RESET"] = "1"
        app.launch()

        app.tabBars.buttons["お気に入り"].tap()
        XCTAssertTrue(app.staticTexts["お気に入りはまだありません"].waitForExistence(timeout: 5))

        // 「探しにいく」で「探す」タブに移る。姓「田中」・2 文字・人格 15・総格 24
        app.buttons["favorites.goSearch"].tap()
        XCTAssertTrue(app.buttons["search.submit"].waitForExistence(timeout: 5))
        registerSei(app, "田中")
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
        app.launchEnvironment["KAKUNOTE_SETTINGS_RESET"] = "0"
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
        // 数字の欄は数字専用のキーボードなので、改行ではなく「完了」で閉じる
        field.typeText(text)
        app.buttons["keyboard.done"].tap()
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
        totalField.typeText(total)
        app.buttons["keyboard.done"].tap()
        let submit = app.buttons["search.submit"]
        for _ in 0..<5 where !submit.isHittable {
            app.swipeUp()
        }
        submit.tap()
    }

    /// 「調べる」タブで姓名を入れると、五格が出る。
    @MainActor
    func testLookupShowsKaku() throws {
        let app = launchWithFreshSettings()
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
        let app = launchWithFreshSettings()
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

    /// 3 つの画面の右上の「設定」から設定画面を開き、そこから「このアプリについて」を開ける。出典とデータのバージョンが出る。
    @MainActor
    func testAboutScreenFromSettings() throws {
        let app = launchWithFreshSettings()

        for tab in ["探す", "調べる", "お気に入り"] {
            app.tabBars.buttons[tab].tap()
            let open = app.buttons["settings.open"]
            XCTAssertTrue(open.waitForExistence(timeout: 5), tab)
            open.tap()
            XCTAssertTrue(app.textFields["settings.sei"].waitForExistence(timeout: 5), tab)
            app.buttons["settings.about"].tap()

            XCTAssertTrue(app.staticTexts["about.KANJIDIC2.version"].waitForExistence(timeout: 5), tab)
            XCTAssertEqual(app.staticTexts["about.app.version"].label, "1.0.0")
            XCTAssertEqual(app.staticTexts["about.KANJIDIC2.version"].label, "2026-291")
            XCTAssertFalse(app.staticTexts["about.Unihan.version"].exists)
            XCTAssertTrue(app.descendants(matching: .any)["CC BY-SA 4.0"].exists)

            // 設定画面に戻って閉じる
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["settings.close"].waitForExistence(timeout: 5), tab)
            app.buttons["settings.close"].tap()
            XCTAssertTrue(open.waitForExistence(timeout: 5), tab)
        }
    }

    /// 設定画面で姓を登録・変更・消去でき、起動し直しても残る。画数がわからない字はそれと分かる。
    @MainActor
    func testSettingsSeiPersistsAndShowsUnknownStrokes() throws {
        let app = launchWithFreshSettings()
        // 登録がないときは、「探す」は姓なしの総画数
        XCTAssertTrue(app.textFields["search.total"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["search.total"].label, "総画数")
        XCTAssertFalse(app.descendants(matching: .any)["search.useSei"].firstMatch.exists)

        registerSei(app, "林")
        XCTAssertEqual(app.staticTexts["search.tenkaku"].label, "8画")

        // 起動し直しても残る
        app.terminate()
        app.launchEnvironment["KAKUNOTE_SETTINGS_RESET"] = "0"
        app.launch()
        XCTAssertTrue(app.staticTexts["search.tenkaku"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["search.sei"].label, "姓「林」")

        // 画数がわからない字があると、設定画面と「探す」でそれと分かる
        app.buttons["settings.open"].tap()
        let sei = app.textFields["settings.sei"]
        XCTAssertTrue(sei.waitForExistence(timeout: 5))
        XCTAssertEqual(sei.value as? String, "林")
        XCTAssertEqual(app.staticTexts["settings.tenkaku"].label, "8画")
        sei.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        sei.typeText("☃")
        XCTAssertTrue(app.descendants(matching: .any)["settings.sei.error"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["settings.close"].tap()
        XCTAssertTrue(app.staticTexts["search.tenkaku.error"].waitForExistence(timeout: 5))

        // 消すと、姓なしに戻る
        clearSei(app)
        XCTAssertFalse(app.staticTexts["search.sei"].exists)
        XCTAssertEqual(app.textFields["search.total"].label, "総画数")
    }

    /// 「探す」の「姓を使う」をオフにすると、名前だけの総画数で探す。
    @MainActor
    func testUseSeiToggleOnSearch() throws {
        let app = launchWithFreshSettings()
        registerSei(app, "田中")
        let total = app.textFields["search.total"]
        XCTAssertEqual(total.label, "総格")
        let useSei = app.descendants(matching: .any)["search.useSei"].firstMatch
        XCTAssertEqual(useSei.value as? String, "オン")
        XCTAssertTrue(app.buttons["ほかの格も条件にする（人格・地格・外格）"].exists)

        useSei.tap()
        XCTAssertEqual(useSei.value as? String, "オフ")
        XCTAssertEqual(total.label, "総画数")
        XCTAssertFalse(app.staticTexts["search.tenkaku"].exists)
        XCTAssertFalse(app.buttons["ほかの格も条件にする（人格・地格・外格）"].exists)

        // 名前だけ: 2 文字・総画数 2 → 4 件
        search(app, length: 2, total: "2")
        XCTAssertTrue(app.staticTexts["result.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result.total"].label, "4件")
    }

    /// 「調べる」の「登録した姓を使う」: オンなら設定の姓が入り、オフなら自由に入力できる。
    @MainActor
    func testLookupUsesRegisteredSei() throws {
        let app = launchWithFreshSettings()
        app.tabBars.buttons["調べる"].tap()
        // 登録がないときは、チェックボックスを出さない
        XCTAssertTrue(app.textFields["lookup.sei"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["lookup.useSei"].firstMatch.exists)

        registerSei(app, "林")
        let useSei = app.descendants(matching: .any)["lookup.useSei"].firstMatch
        XCTAssertTrue(useSei.waitForExistence(timeout: 5))
        XCTAssertEqual(useSei.value as? String, "オン")
        let sei = app.textFields["lookup.sei"]
        XCTAssertEqual(sei.value as? String, "林")
        XCTAssertFalse(sei.isEnabled)

        let mei = app.textFields["lookup.mei"]
        mei.tap()
        mei.typeText("健太\n")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["lookup.kaku.tenkaku"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["lookup.kaku.tenkaku"].label, "8画")

        // オフにすると、姓を自由に入力できる
        app.swipeDown()
        useSei.tap()
        XCTAssertEqual(useSei.value as? String, "オフ")
        XCTAssertTrue(sei.isEnabled)
        sei.tap()
        sei.typeText("\u{8}田中\n")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["lookup.kaku.tenkaku"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["lookup.kaku.tenkaku"].label, "9画")
    }

    /// 設定画面で避けたい字を登録すると、自動の候補から外れ、チップに出る。固定した字は外れない。起動し直しても残る。
    @MainActor
    func testAvoidCharsFromSettings() throws {
        let app = launchWithFreshSettings()
        app.buttons["settings.open"].tap()
        let input = app.textFields["settings.avoid.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        // 何も入れていないときは「追加」を押せない
        XCTAssertFalse(app.buttons["settings.avoid.add"].isEnabled)
        // 登録できない字は知らせて、登録しない
        input.tap()
        input.typeText("A")
        XCTAssertTrue(app.buttons["settings.avoid.add"].isEnabled)
        app.buttons["settings.avoid.add"].tap()
        XCTAssertTrue(app.staticTexts["settings.avoid.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.avoid.remove.A"].exists)
        input.typeText("\u{8}乙\n")
        XCTAssertTrue(app.buttons["settings.avoid.remove.乙"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["settings.avoid.error"].exists)
        app.buttons["settings.close"].tap()

        // 2 文字・総画数 2 → 一一 だけ。チップに「避けたい字 1字を除外」
        search(app, length: 2, total: "2")
        XCTAssertTrue(app.staticTexts["result.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result.total"].label, "1件")
        XCTAssertTrue(app.buttons["一一"].exists)
        XCTAssertTrue(app.staticTexts["避けたい字 1字を除外"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 1 文字目を「乙」に固定したら、乙一 が出る
        app.buttons["search.cell.1"].tap()
        app.buttons["search.kind.fixed"].tap()
        let fixed = app.textFields["search.fixed"]
        XCTAssertTrue(fixed.waitForExistence(timeout: 5))
        fixed.tap()
        fixed.typeText("乙\n")
        let submit = app.buttons["search.submit"]
        submit.tap()
        XCTAssertTrue(app.staticTexts["result.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result.total"].label, "1件")
        XCTAssertTrue(app.buttons["乙一"].exists)

        // 起動し直しても残り、外すこともできる
        app.terminate()
        app.launchEnvironment["KAKUNOTE_SETTINGS_RESET"] = "0"
        app.launch()
        app.buttons["settings.open"].tap()
        let remove = app.buttons["settings.avoid.remove.乙"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        // 行の中で字のチップが 1 つだけだと、ボタンの範囲が行全体として見えるので、チップの字を押す
        remove.staticTexts["乙"].tap()
        XCTAssertTrue(remove.waitForNonExistence(timeout: 5))
    }

    /// 設定画面で使いたい字を登録すると、その字を含む候補だけが出て、チップに出る。名前に使えない字は登録しない。
    @MainActor
    func testUseCharsFromSettings() throws {
        let app = launchWithFreshSettings()
        app.buttons["settings.open"].tap()
        let input = app.textFields["settings.use.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        // 名前に使えない字（常用漢字・人名用漢字でない「乂」）
        input.tap()
        input.typeText("乂\n")
        let error = app.staticTexts["settings.use.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(error.label, "「乂」は名前には使えない字です")
        input.tap()
        input.typeText("\u{8}乙\n")
        XCTAssertTrue(app.buttons["settings.use.remove.乙"].waitForExistence(timeout: 5))
        app.buttons["settings.close"].tap()

        // 2 文字・総画数 2 → 一乙、乙一、乙乙（一一 は出ない）
        search(app, length: 2, total: "2")
        XCTAssertTrue(app.staticTexts["result.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result.total"].label, "3件")
        XCTAssertFalse(app.buttons["一一"].exists)
        XCTAssertTrue(app.buttons["乙乙"].exists)
        XCTAssertTrue(app.staticTexts["使いたい字: 乙"].exists)
    }

    /// 「探す」の読みで絞り込むと、その読みになる字の組み合わせだけが出て、チップに出る。カタカナはひらがなに直る。
    @MainActor
    func testSearchByReading() throws {
        let app = launchWithFreshSettings()
        let reading = app.textFields["search.reading"]
        XCTAssertTrue(reading.waitForExistence(timeout: 5))
        reading.tap()
        reading.typeText("ルー\n")
        XCTAssertEqual(reading.value as? String, "るー")

        // 2 文字・カタカナ・総画数 3・読み「るー」→ ルー の 1 件
        for cell in ["search.cell.1", "search.cell.2"] {
            app.buttons[cell].tap()
            app.buttons["search.script"].tap()
            app.buttons["カタカナ"].tap()
        }
        search(app, length: 2, total: "3")
        XCTAssertTrue(app.staticTexts["result.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result.total"].label, "1件")
        XCTAssertTrue(app.buttons["ルー"].exists)
        XCTAssertTrue(app.staticTexts["読み「るー」"].exists)
    }

    /// 設定の「読みの頭の部分も使う」をオンにすると、心春 が「こはる」で出る。オフ（初期値）では出ない。
    @MainActor
    func testReadingPrefixFromSettings() throws {
        let app = launchWithFreshSettings()
        // 1 文字目を「心」、2 文字目を「春」に固定し、読み「こはる」
        for (cell, char) in [("search.cell.1", "心"), ("search.cell.2", "春")] {
            app.buttons[cell].tap()
            app.buttons["search.kind.fixed"].tap()
            let fixed = app.textFields["search.fixed"]
            XCTAssertTrue(fixed.waitForExistence(timeout: 5))
            fixed.tap()
            fixed.typeText(char + "\n")
        }
        let reading = app.textFields["search.reading"]
        reading.tap()
        reading.typeText("こはる\n")

        // オフ（初期値）では出ない
        search(app, length: 2, total: "13")
        XCTAssertTrue(app.staticTexts["該当する名前がありません"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 設定でオンにする
        let open = app.buttons["settings.open"]
        for _ in 0..<3 where !open.isHittable {
            app.swipeDown()
        }
        open.tap()
        let toggle = app.switches["settings.readingPrefix"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        // スイッチの部分（右の端）を押す
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["settings.close"].tap()

        let submit = app.buttons["search.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.staticTexts["result.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result.total"].label, "1件")
        XCTAssertTrue(app.buttons["心春"].exists)
        XCTAssertTrue(app.staticTexts["読みの頭の部分も使う"].exists)
    }

    /// 設定の保存先を一時ファイルにし、空の状態で起動する。
    @MainActor
    private func launchWithFreshSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["KAKUNOTE_SETTINGS_FILE"] = "uitest-settings.json"
        app.launchEnvironment["KAKUNOTE_SETTINGS_RESET"] = "1"
        app.launch()
        return app
    }

    /// 右上の「設定」から姓を登録して、設定画面を閉じる。
    @MainActor
    private func registerSei(_ app: XCUIApplication, _ sei: String) {
        let open = app.buttons["settings.open"]
        for _ in 0..<3 where !open.isHittable {
            app.swipeDown()
        }
        open.tap()
        let field = app.textFields["settings.sei"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(sei)
        app.buttons["settings.close"].tap()
        XCTAssertTrue(open.waitForExistence(timeout: 5))
    }

    /// 設定の姓を消す。
    @MainActor
    private func clearSei(_ app: XCUIApplication) {
        app.buttons["settings.open"].tap()
        let field = app.textFields["settings.sei"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // 右寄せの欄なので、右の端を押して、カーソルを字の後ろに置く
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        let length = (field.value as? String)?.count ?? 0
        field.typeText(String(repeating: "\u{8}", count: length))
        app.buttons["settings.close"].tap()
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
