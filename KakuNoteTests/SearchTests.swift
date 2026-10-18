//
//  SearchTests.swift
//  KakuNoteTests
//

import XCTest
@testable import KakuNote

/// 共通テストケース（testcases/search.json）で、名前の候補の検索を確かめる。
final class SearchTests: XCTestCase {

    private var data: KanjiData!
    private let school: any KakuSchool = ShinjitaiSchool()

    override func setUpWithError() throws {
        data = try KanjiData.bundled.get()
    }

    /// 姓なしのケース（エラーのケースを含む）。
    func testCommonNameOnlyCases() throws {
        let cases = try Self.searchCases().filter { ($0["input"] as? [String: Any])?["sei"] is NSNull }
        XCTAssertFalse(cases.isEmpty)
        for testCase in cases {
            try check(testCase)
        }
    }

    /// 姓ありのケース（エラーのケースを含む）。
    func testCommonSeiCases() throws {
        let cases = try Self.searchCases().filter { ($0["input"] as? [String: Any])?["sei"] is String }
        XCTAssertFalse(cases.isEmpty)
        for testCase in cases {
            try check(testCase)
        }
    }

    /// 共通テストケースが、姓なし・姓ありのどちらかで全部確かめられている。
    func testAllCommonCasesAreCovered() throws {
        let cases = try Self.searchCases()
        let covered = cases.filter {
            let sei = ($0["input"] as? [String: Any])?["sei"]
            return sei is NSNull || sei is String
        }
        XCTAssertEqual(covered.count, cases.count)
    }

    func testOneCharSeiGaikakuUsesSingleCharRule() throws {
        // 姓「林」（8 画）・1 文字・外格 20 → 外格 = 0 + 8 + n なので 12 画の字
        let search = try NameSearch(
            query: SearchQuery(sei: "林", positions: [.free(.kanji)], conditions: [.gaikaku: [20]]),
            data: data, school: school
        )
        XCTAssertEqual(search.breakdowns.map(\.strokes), [[12]])
        XCTAssertTrue(search.page(offset: 0, limit: search.total).contains("翔"))
    }

    func testTwoCharsOrder() throws {
        let search = try NameSearch(
            query: SearchQuery(sei: nil, positions: [.free(.kanji), .free(.kanji)], conditions: [.chikaku: [2]]),
            data: data, school: school
        )
        XCTAssertEqual(search.total, 4)
        XCTAssertEqual(search.page(offset: 0, limit: 10), ["一一", "一乙", "乙一", "乙乙"])
        XCTAssertEqual(search.page(offset: 3, limit: 10), ["乙乙"])
        XCTAssertEqual(search.page(offset: 4, limit: 10), [])
    }

    func testPagesMatchFullListing() throws {
        let search = try NameSearch(
            query: SearchQuery(sei: nil, positions: [.free(.kanji), .free(.hiragana)], conditions: [.chikaku: [14]]),
            data: data, school: school
        )
        let everything = search.page(offset: 0, limit: search.total)
        XCTAssertEqual(everything.count, search.total)
        XCTAssertEqual(Set(everything.map { $0.unicodeScalars.map(\.value) }).count, search.total)
        for offset in [0, 1, 37, search.total - 3] {
            XCTAssertEqual(search.page(offset: offset, limit: 5), Array(everything[offset..<min(offset + 5, everything.count)]))
        }
    }

    func testLargeSearchIsLazy() throws {
        let query = SearchQuery(sei: nil, positions: Array(repeating: .free(.kanji), count: 4), conditions: [.chikaku: [8]])
        let start = Date()
        let search = try NameSearch(query: query, data: data, school: school)
        XCTAssertEqual(search.page(offset: 0, limit: 50).count, 50)
        XCTAssertEqual(search.page(offset: search.total - 1, limit: 50).count, 1)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    func testFixedCharMustBeSingle() {
        let query = SearchQuery(sei: nil, positions: [.fixed("陽菜")], conditions: [.chikaku: [23]])
        XCTAssertThrowsError(try NameSearch(query: query, data: data, school: school)) { error in
            XCTAssertEqual(error as? SearchError, .fixedNotSingleChar(position: 1))
        }
    }

    // MARK: - 共通テストケースの読み込み

    static func searchCases() throws -> [[String: Any]] {
        let json = try SharedTestCases.load("search.json")
        return try XCTUnwrap(json["cases"] as? [[String: Any]])
    }

    /// 1 ケースを確かめる。04 の姓ありのケースでも使う。
    func check(_ testCase: [String: Any]) throws {
        let id = testCase["id"] as? String ?? "?"
        let input = try XCTUnwrap(testCase["input"] as? [String: Any], id)
        let expected = try XCTUnwrap(testCase["expected"] as? [String: Any], id)
        let query = try Self.query(from: input)

        if let expectedError = expected["error"] as? String {
            XCTAssertThrowsError(try NameSearch(query: query, data: data, school: school), id) { error in
                XCTAssertEqual(Self.errorType(error), expectedError, "\(id): \(error)")
            }
            return
        }

        let search = try NameSearch(query: query, data: data, school: school)
        XCTAssertEqual(search.total, expected["total"] as? Int, id)
        XCTAssertEqual(search.breakdowns.count, expected["breakdown_count"] as? Int, id)
        for page in try XCTUnwrap(expected["pages"] as? [[String: Any]], id) {
            let offset = try XCTUnwrap(page["offset"] as? Int)
            let limit = try XCTUnwrap(page["limit"] as? Int)
            let names = try XCTUnwrap(page["names"] as? [String])
            // String の == は正準等価な字を同じとみなすので、コードポイントで比べる
            XCTAssertEqual(
                search.page(offset: offset, limit: limit).map { $0.unicodeScalars.map(\.value) },
                names.map { $0.unicodeScalars.map(\.value) },
                "\(id) offset \(offset)"
            )
        }
    }

    static func query(from input: [String: Any]) throws -> SearchQuery {
        let positions = try XCTUnwrap(input["positions"] as? [[String: Any]]).map { item -> PositionCondition in
            let script = ScriptFilter(rawValue: item["script"] as? String ?? "kanji") ?? .kanji
            switch item["kind"] as? String {
            case "fixed": return .fixed(item["char"] as? String ?? "")
            case "strokes": return .strokes(item["strokes"] as? Int ?? 0, script)
            default: return .free(script)
            }
        }
        var conditions: [KakuKind: Set<Int>] = [:]
        for (key, values) in try XCTUnwrap(input["conditions"] as? [String: [Int]]) {
            conditions[try XCTUnwrap(KakuKind(rawValue: key))] = Set(values)
        }
        return SearchQuery(sei: input["sei"] as? String, positions: positions, conditions: conditions)
    }

    static func errorType(_ error: Error) -> String {
        switch error as? SearchError {
        case .invalidInput, .fixedNotSingleChar: return "invalid_input"
        case .unknownStrokes: return "unknown_stroke"
        case .invalidLength, .noCondition, .invalidCondition: return "invalid_condition"
        case nil: return "other: \(error)"
        }
    }
}
