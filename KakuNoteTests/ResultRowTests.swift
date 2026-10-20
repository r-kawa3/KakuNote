//
//  ResultRowTests.swift
//  KakuNoteTests
//

import XCTest
@testable import KakuNote

/// 候補の一覧に出す内容（条件のチップ、各行の画数の内訳）を確かめる。
final class ResultRowTests: XCTestCase {

    private var data: KanjiData!
    private let school: any KakuSchool = ShinjitaiSchool()

    override func setUpWithError() throws {
        data = try KanjiData.bundled.get()
    }

    func testChipsForNameOnlySearch() {
        let query = SearchQuery(
            sei: nil,
            positions: [.fixed("陽"), .strokes(8, .hiragana), .free(.kanji)],
            conditions: [.chikaku: [31, 20]]
        )
        XCTAssertEqual(SearchSummary.chips(for: query), [
            .init(text: "総画数 20・31画", isPrimary: true),
            .init(text: "3文字", isPrimary: false),
            .init(text: "1文字目「陽」固定", isPrimary: false),
            .init(text: "2文字目 8画・ひらがな", isPrimary: false),
        ])
    }

    func testChipsForSearchWithSurname() {
        let query = SearchQuery(
            sei: "田中",
            positions: [.free(.kanji), .free(.any)],
            conditions: [.soukaku: [24], .jinkaku: [15]]
        )
        XCTAssertEqual(SearchSummary.chips(for: query), [
            .init(text: "人格 15画", isPrimary: true),
            .init(text: "総格 24画", isPrimary: true),
            .init(text: "姓「田中」", isPrimary: false),
            .init(text: "2文字", isPrimary: false),
            .init(text: "2文字目 どれでも", isPrimary: false),
        ])
    }

    func testChipShowsAvoidCount() {
        let query = SearchQuery(sei: nil, positions: [.free(.kanji)], conditions: [.chikaku: [2]], avoid: ["乙", "ア", "ぬ"])
        XCTAssertEqual(SearchSummary.chips(for: query).last, .init(text: "避けたい字 3字を除外", isPrimary: false))
        // 登録がないときは出ない
        let plain = SearchQuery(sei: nil, positions: [.free(.kanji)], conditions: [.chikaku: [2]])
        XCTAssertFalse(SearchSummary.chips(for: plain).contains { $0.text.contains("避けたい字") })
    }

    func testChipShowsUseChars() {
        let query = SearchQuery(
            sei: nil, positions: [.free(.kanji)], conditions: [.chikaku: [12]], avoid: ["乙"], use: ["陽", "葵", "翔"]
        )
        XCTAssertEqual(Array(SearchSummary.chips(for: query).suffix(2)), [
            .init(text: "使いたい字: 陽・葵・翔", isPrimary: false),
            .init(text: "避けたい字 1字を除外", isPrimary: false),
        ])
    }

    func testChipShowsReading() {
        let query = SearchQuery(sei: "田中", positions: [.free(.kanji), .free(.kanji)], conditions: [.soukaku: [24]], reading: "はると")
        XCTAssertEqual(SearchSummary.chips(for: query)[1...2], [
            .init(text: "姓「田中」", isPrimary: false),
            .init(text: "読み「はると」", isPrimary: false),
        ])
        XCTAssertEqual(ConditionSummary.text(for: query), "2文字・読み「はると」・総格 24")
        XCTAssertFalse(SearchSummary.chips(for: query).contains { $0.text == "読みの頭の部分も使う" })

        var prefix = query
        prefix.readingPrefix = true
        XCTAssertTrue(SearchSummary.chips(for: prefix).contains { $0.text == "読みの頭の部分も使う" })
    }

    func testCandidatesCarryStrokes() throws {
        let search = try NameSearch(
            query: SearchQuery(sei: nil, positions: [.fixed("陽"), .free(.kanji)], conditions: [.chikaku: [13]]),
            data: data, school: school
        )
        XCTAssertEqual(search.candidates(offset: 0, limit: 10), [
            .init(name: "陽一", strokes: [12, 1]),
            .init(name: "陽乙", strokes: [12, 1]),
        ])
    }

    func testRowBreakdownForNameOnly() {
        let row = ResultRow.make(
            candidate: .init(name: "陽奈", strokes: [12, 8]), seiStrokes: nil, conditions: [.chikaku: [20]], school: school
        )
        XCTAssertEqual(row.name, "陽奈")
        XCTAssertEqual(row.breakdown, "12 + 8 = 20画")
        XCTAssertNil(row.kakuNote)
    }

    func testRowBreakdownForOneChar() {
        let row = ResultRow.make(
            candidate: .init(name: "翔", strokes: [12]), seiStrokes: nil, conditions: [.chikaku: [12]], school: school
        )
        XCTAssertEqual(row.breakdown, "12画")
    }

    func testRowShowsConditionedKakuForSurname() {
        // 田中（5, 4）+ 乾不（11, 4）: 人格 15、総格 24
        let row = ResultRow.make(
            candidate: .init(name: "乾不", strokes: [11, 4]), seiStrokes: [5, 4],
            conditions: [.soukaku: [24], .jinkaku: [15]], school: school
        )
        XCTAssertEqual(row.breakdown, "11 + 4 = 15画")
        XCTAssertEqual(row.kakuNote, "人格 15・総格 24")
    }
}
