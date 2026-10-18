//
//  KakuTests.swift
//  KakuNoteTests
//

import XCTest
@testable import KakuNote

/// 共通テストケース（testcases/kaku.json と strokes.json の mei_warnings）で、五格と名の警告を確かめる。
final class KakuTests: XCTestCase {

    private var data: KanjiData!
    private let school: any KakuSchool = ShinjitaiSchool()

    override func setUpWithError() throws {
        data = try KanjiData.bundled.get()
    }

    func testCommonKakuCases() throws {
        let json = try SharedTestCases.load("kaku.json")
        let cases = try XCTUnwrap(json["cases"] as? [[String: Any]])
        XCTAssertFalse(cases.isEmpty)

        for testCase in cases {
            let id = testCase["id"] as? String ?? "?"
            let sei = try data.strokes(of: TextPreprocessor.characters(from: try XCTUnwrap(testCase["sei"] as? String)))
            let mei = try data.strokes(of: TextPreprocessor.characters(from: try XCTUnwrap(testCase["mei"] as? String)))
            XCTAssertEqual(sei, testCase["sei_strokes"] as? [Int], id)
            XCTAssertEqual(mei, testCase["mei_strokes"] as? [Int], id)

            let expected = try XCTUnwrap(testCase["kaku"] as? [String: Int], id)
            let kaku = school.kaku(sei: sei, mei: mei)
            XCTAssertEqual(kaku.tenkaku, expected["tenkaku"], id)
            XCTAssertEqual(kaku.jinkaku, expected["jinkaku"], id)
            XCTAssertEqual(kaku.chikaku, expected["chikaku"], id)
            XCTAssertEqual(kaku.soukaku, expected["soukaku"], id)
            XCTAssertEqual(kaku.gaikaku, expected["gaikaku"], id)
        }
    }

    func testCommonNameOnlyCases() throws {
        let json = try SharedTestCases.load("kaku.json")
        let cases = try XCTUnwrap(json["name_only"] as? [[String: Any]])
        XCTAssertFalse(cases.isEmpty)

        for testCase in cases {
            let id = testCase["id"] as? String ?? "?"
            let mei = try data.strokes(of: TextPreprocessor.characters(from: try XCTUnwrap(testCase["mei"] as? String)))
            XCTAssertEqual(mei, testCase["mei_strokes"] as? [Int], id)
            XCTAssertEqual(school.nameOnlyTotal(mei: mei), testCase["chikaku"] as? Int, id)
        }
    }

    func testCommonMeiWarningCases() throws {
        let json = try SharedTestCases.load("strokes.json")
        let cases = try XCTUnwrap(json["mei_warnings"] as? [[String: Any]])
        XCTAssertFalse(cases.isEmpty)

        for testCase in cases {
            let id = testCase["id"] as? String ?? "?"
            let mei = try TextPreprocessor.characters(from: try XCTUnwrap(testCase["mei"] as? String))
            let expected = try XCTUnwrap(testCase["warnings"] as? [[String: Any]], id).map { item -> NameWarning in
                let char = item["char"] as? String ?? ""
                let position = item["position"] as? Int ?? 0
                switch item["type"] as? String {
                case "not_initial": return .notInitial(char: char)
                default: return .notNameChar(char: char, position: position)
                }
            }
            XCTAssertEqual(data.meiWarnings(mei), expected, id)
        }
    }

    func testLookupShowsKakuForSeiAndMei() throws {
        let result = try NameLookup.lookup(sei: "林", mei: "健太", data: data, school: school)
        XCTAssertEqual(result.sei.map(\.strokes), [8])
        XCTAssertEqual(result.mei.map(\.strokes), [11, 4])
        XCTAssertEqual(result.kaku, Kaku(tenkaku: 8, jinkaku: 19, chikaku: 15, soukaku: 23, gaikaku: 12))
        XCTAssertNil(result.nameOnlyTotal)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testLookupNameOnlyShowsTotal() throws {
        let result = try NameLookup.lookup(sei: "", mei: "陽菜", data: data, school: school)
        XCTAssertNil(result.kaku)
        XCTAssertEqual(result.nameOnlyTotal, 23)
    }

    func testLookupDoesNotWarnForSei() throws {
        // 澤 は名前に使えない字だが、姓なら警告しない
        let result = try NameLookup.lookup(sei: "澤", mei: "澤", data: data, school: school)
        XCTAssertEqual(result.warnings, [.notNameChar(char: "澤", position: 1)])
    }

    func testLookupReportsUnknownChars() {
        XCTAssertThrowsError(try NameLookup.lookup(sei: "田A", mei: "健B", data: data, school: school)) { error in
            XCTAssertEqual(error as? LookupError, .unknownStrokes(["A", "B"]))
        }
    }

    func testLookupReportsInvalidInput() {
        XCTAssertThrowsError(try NameLookup.lookup(sei: "田 中", mei: "健", data: data, school: school)) { error in
            XCTAssertEqual(error as? LookupError, .invalidInput(part: .sei, .spaceInside))
        }
    }
}
