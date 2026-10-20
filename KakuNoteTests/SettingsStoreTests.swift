//
//  SettingsStoreTests.swift
//  KakuNoteTests
//

import XCTest
@testable import KakuNote

/// 設定の保存（端末の中の settings.json）を確かめる。
@MainActor
final class SettingsStoreTests: XCTestCase {

    private var url: URL!

    override func setUpWithError() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("settings-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: url)
    }

    func testDefaultsWhenNoFile() {
        XCTAssertEqual(SettingsStore(url: url).load(), SettingsValues())
        XCTAssertNil(AppSettings(store: SettingsStore(url: url)).registeredSei)
    }

    func testSeiIsSavedAndLoadedAgain() {
        let settings = AppSettings(store: SettingsStore(url: url))
        settings.sei = "田中"
        XCTAssertEqual(settings.registeredSei, "田中")

        // 起動し直したのと同じく、ファイルから読み直す
        let reloaded = AppSettings(store: SettingsStore(url: url))
        XCTAssertEqual(reloaded.sei, "田中")

        // 消すと登録なしに戻る
        reloaded.sei = ""
        XCTAssertNil(AppSettings(store: SettingsStore(url: url)).registeredSei)
    }

    func testBlankSeiIsNotRegistered() {
        let settings = AppSettings(store: SettingsStore(url: url))
        settings.sei = "  "
        XCTAssertNil(settings.registeredSei)
        settings.sei = " 林 "
        XCTAssertEqual(settings.registeredSei, "林")
    }

    func testBrokenOrOldFileFallsBackToDefaults() throws {
        try Data("not json".utf8).write(to: url)
        XCTAssertEqual(SettingsStore(url: url).load(), SettingsValues())

        // 項目が足りない古いファイルも読める
        try Data("{}".utf8).write(to: url)
        XCTAssertEqual(SettingsStore(url: url).load(), SettingsValues())
    }

    func testAvoidCharsAddRemoveAndPersist() throws {
        let data = try KanjiData.bundled.get()
        let settings = AppSettings(store: SettingsStore(url: url))
        // 何文字でもまとめて足せる。半角カナは前処理で全角になる。同じ字は 1 つだけ
        XCTAssertNil(settings.addAvoidChars("乙ｱ乙", data: data))
        XCTAssertNil(settings.addAvoidChars("ぬ", data: data))
        XCTAssertEqual(settings.avoidChars, ["乙", "ア", "ぬ"])
        XCTAssertEqual(AppSettings(store: SettingsStore(url: url)).avoidChars, ["乙", "ア", "ぬ"])

        // 正準等価な字は別の字として足せる
        XCTAssertNil(settings.addAvoidChars("\u{6D77}\u{FA45}", data: data))
        XCTAssertEqual(settings.avoidChars.count, 5)

        settings.removeAvoidChar("ア")
        settings.removeAvoidChar("\u{FA45}")
        XCTAssertEqual(settings.avoidChars.map { $0.unicodeScalars.map(\.value) }, [[0x4E59], [0x306C], [0x6D77]])
    }

    func testAvoidCharsRejectsUnknownChars() throws {
        let data = try KanjiData.bundled.get()
        let settings = AppSettings(store: SettingsStore(url: url))
        let message = settings.addAvoidChars("乙A", data: data)
        XCTAssertEqual(message, "「A」は登録できません。漢字・ひらがな・カタカナを入れてください")
        // 1 字でも足せない字があれば、何も足さない
        XCTAssertTrue(settings.avoidChars.isEmpty)
        XCTAssertNotNil(settings.addAvoidChars("乙 一", data: data))
    }

    func testSeiCheckTenkakuAndUnknownStrokes() throws {
        let data = try KanjiData.bundled.get()
        guard case .success(let value) = SeiCheck.tenkaku(of: "田中", data: data) else {
            return XCTFail("田中 の天格が出ない")
        }
        XCTAssertEqual(value, 9)
        guard case .failure(let message) = SeiCheck.tenkaku(of: "田☃", data: data) else {
            return XCTFail("画数がわからない字が分からない")
        }
        XCTAssertTrue(message.text.contains("画数がわからない字"))
    }
}
