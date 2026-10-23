//
//  SearchInputCheckTests.swift
//  KakuNoteTests
//

import XCTest
@testable import KakuNote

/// 「この条件で探す」を押す前の確かめ（押せないときの理由）。
@MainActor
final class SearchInputCheckTests: XCTestCase {

    private var data: KanjiData!

    override func setUpWithError() throws {
        data = try KanjiData.bundled.get()
    }

    private func check(
        sei: String? = nil, total: String = "16", positions: [PositionInput] = [PositionInput(), PositionInput()],
        reading: String = "", otherKaku: [KakuKind: String] = [:]
    ) -> SearchInputCheck {
        SearchInputCheck.make(
            sei: sei, totalText: total, otherKakuTexts: otherKaku, positions: positions, reading: reading,
            avoid: [], use: [], readingPrefix: false, data: data
        )
    }

    private func fixed(_ text: String) -> [PositionInput] {
        var input = PositionInput()
        input.kind = .fixed
        input.fixedText = text
        return [input, PositionInput()]
    }

    func testReadyQuery() {
        guard case .ready(let query) = check(reading: "はると") else { return XCTFail() }
        XCTAssertEqual(query.conditions, [.chikaku: [16]])
        XCTAssertEqual(query.reading, "はると")
    }

    func testMissingTotal() {
        XCTAssertEqual(check(total: "").problem, "総画数を入力してください")
        XCTAssertEqual(check(sei: "田中", total: "").problem, "総格か、ほかの格の画数を入力してください")
        // 姓ありなら、ほかの格だけでも探せる
        XCTAssertNil(check(sei: "田中", total: "", otherKaku: [.jinkaku: "15"]).problem)
    }

    func testMissingPositionCondition() {
        var strokes = PositionInput()
        strokes.kind = .strokes
        XCTAssertEqual(check(positions: [PositionInput(), strokes]).problem, "2文字目の条件を入力してください")
    }

    func testProblemsFoundBeforeSearching() {
        XCTAssertEqual(check(reading: "haru").problem, "読みは、ひらがな（またはカタカナ）30 文字までで入れてください")
        XCTAssertEqual(check(sei: "田A").problem, "画数がわからない字があります: 「A」")
        XCTAssertEqual(check(positions: fixed("陽菜")).problem, "1文字目に固定する字は 1 文字にしてください")
        XCTAssertEqual(check(positions: fixed("A")).problem, "画数がわからない字があります: 「A」")
        XCTAssertNil(check(positions: fixed("陽")).problem)
    }
}
