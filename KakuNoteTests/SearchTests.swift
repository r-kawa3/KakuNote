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

    func testSixCharsLargeSearchIsFast() throws {
        // 打ち切りがないと、約 3 億通りの内訳をたどってしまう。
        // 最適化したビルド（アプリの配布用）では約 0.07 秒（2026-10-19 に Mac で計測）。
        // テストは最適化なしのデバッグビルドで動くので、しきい値は余裕を持たせる
        let query = SearchQuery(sei: nil, positions: Array(repeating: .free(.kanji), count: 6), conditions: [.chikaku: [30]])
        let start = Date()
        let search = try NameSearch(query: query, data: data, school: school)
        XCTAssertLessThan(Date().timeIntervalSince(start), 3.0)
        XCTAssertEqual(search.page(offset: 0, limit: 1), ["一一一一一廳"])
    }

    func testTooManyResultsStopsEarly() {
        // 総画数 6〜200 のどれでもよい 6 文字（種類は any）は、総数が上限を超える
        let query = SearchQuery(
            sei: nil, positions: Array(repeating: .free(.any), count: 6), conditions: [.chikaku: Set(6...200)]
        )
        let start = Date()
        XCTAssertThrowsError(try NameSearch(query: query, data: data, school: school)) { error in
            XCTAssertEqual(error as? SearchError, .tooManyResults)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    func testLengthLimits() {
        for length in [0, 7] {
            let query = SearchQuery(sei: nil, positions: Array(repeating: .free(.kanji), count: length), conditions: [.chikaku: [7]])
            XCTAssertThrowsError(try NameSearch(query: query, data: data, school: school)) { error in
                XCTAssertEqual(error as? SearchError, .invalidLength)
            }
        }
    }

    func testFixedCharMustBeSingle() {
        let query = SearchQuery(sei: nil, positions: [.fixed("陽菜")], conditions: [.chikaku: [23]])
        XCTAssertThrowsError(try NameSearch(query: query, data: data, school: school)) { error in
            XCTAssertEqual(error as? SearchError, .fixedNotSingleChar(position: 1))
        }
    }

    // MARK: - 共通テストケースの読み込み

    /// 避けたい字は、コードポイントの並びで比べる（正準等価な字は別の字）。
    func testAvoidComparesCodePoints() throws {
        let plain = try NameSearch(
            query: SearchQuery(sei: nil, positions: [.free(.kanji)], conditions: [.chikaku: [9]]), data: data, school: school
        )
        let compat = try NameSearch(
            query: SearchQuery(sei: nil, positions: [.free(.kanji)], conditions: [.chikaku: [9]], avoid: ["\u{FA45}"]),
            data: data, school: school
        )
        let names = compat.page(offset: 0, limit: compat.total).map { $0.unicodeScalars.map(\.value) }
        XCTAssertTrue(names.contains([0x6D77]))
        XCTAssertFalse(names.contains([0xFA45]))
        let plainNames = plain.page(offset: 0, limit: plain.total).map { $0.unicodeScalars.map(\.value) }
        XCTAssertEqual(compat.total, plain.total - (plainNames.contains([0xFA45]) ? 1 : 0))
    }

    /// 使いたい字は、全部の候補から「使いたい字を含まないもの」を飛ばしたのと同じ。数・順番・ページ送りが合う。
    func testUseMatchesFilteredListing() throws {
        let positions: [PositionCondition] = [.free(.kanji), .free(.hiragana), .free(.kanji)]
        let plain = try NameSearch(
            query: SearchQuery(sei: nil, positions: positions, conditions: [.chikaku: [12]]), data: data, school: school
        )
        let use = ["一", "ぬ", "乃"]
        let searched = try NameSearch(
            query: SearchQuery(sei: nil, positions: positions, conditions: [.chikaku: [12]], avoid: ["乃"], use: use),
            data: data, school: school
        )
        let usePoints = Set(use.map(\.codePoints))
        let expected = plain.page(offset: 0, limit: plain.total)
            .filter { name in name.unicodeScalars.contains { usePoints.contains([$0.value]) } }
            .map(\.codePoints)
        XCTAssertEqual(searched.total, expected.count)
        XCTAssertEqual(searched.page(offset: 0, limit: searched.total).map(\.codePoints), expected)
        for offset in [0, 7, expected.count - 4] {
            XCTAssertEqual(
                searched.page(offset: offset, limit: 6).map(\.codePoints),
                Array(expected[offset..<min(offset + 6, expected.count)])
            )
        }
        XCTAssertTrue(searched.breakdowns.allSatisfy { $0.count > 0 })
    }

    /// 読みの絞り込みは、全部の候補から「読みが割り振れないもの」を飛ばしたのと同じ。数・順番・ページ送りが合う。
    /// 割り振りは、ここでは素直な総当たり（仕様書 search.md「割り振り」）で確かめる。
    func testReadingMatchesBruteForce() throws {
        for (positions, reading, use) in [
            ([PositionCondition.free(.kanji), .free(.hiragana)], "あいか", [String]()),
            ([.free(.kanji), .free(.kanji)], "ゆうと", ["優"]),
            ([.fixed("人"), .free(.kanji)], "ひとびと", []),
        ] {
            let conditions: [KakuKind: Set<Int>] = [.chikaku: Set(2...40)]
            let plain = try NameSearch(
                query: SearchQuery(sei: nil, positions: positions, conditions: conditions), data: data, school: school
            )
            let searched = try NameSearch(
                query: SearchQuery(sei: nil, positions: positions, conditions: conditions, use: use, reading: reading),
                data: data, school: school
            )
            let target = reading.unicodeScalars.map(\.value)
            let expected = plain.page(offset: 0, limit: plain.total)
                .filter { name in
                    (use.isEmpty || use.contains { name.contains($0) }) && Self.canRead(name, as: target, data: data)
                }
                .map(\.codePoints)
            XCTAssertGreaterThan(expected.count, 0, reading)
            XCTAssertEqual(searched.total, expected.count, reading)
            XCTAssertEqual(searched.page(offset: 0, limit: searched.total).map(\.codePoints), expected, reading)
            XCTAssertEqual(
                searched.page(offset: expected.count / 2, limit: 3).map(\.codePoints),
                Array(expected[(expected.count / 2)..<min(expected.count / 2 + 3, expected.count)]), reading
            )
            XCTAssertTrue(searched.breakdowns.allSatisfy { $0.count > 0 }, reading)
        }
    }

    /// 総当たりの割り振り: 名の各字に、読みの空でない連続した部分を順に割り振れるか。
    static func canRead(_ name: String, as reading: [UInt32], data: KanjiData) -> Bool {
        let chars = name.unicodeScalars.map { $0 }
        func readings(_ i: Int) -> Set<[UInt32]> {
            var c = chars[i]
            var j = i
            while c == "々" {
                guard j > 0 else { return [] }
                j -= 1
                c = chars[j]
            }
            let info = data.chars[c]!
            var own: Set<[UInt32]> = info.script == .kanji
                ? Set((data.readings[c] ?? []).map { $0.unicodeScalars.map(\.value) })
                : [[Reading.hiragana(c.value)]]
            if i > 0 && data.chars[chars[i]]!.script == .kanji {
                for y in own {
                    for v in Reading.rendaku[y[0]] ?? [] { own.insert([v] + y.dropFirst()) }
                }
            }
            return own
        }
        func go(_ i: Int, _ start: Int) -> Bool {
            if i == chars.count { return start == reading.count }
            return readings(i).contains { y in
                !y.isEmpty && start + y.count <= reading.count
                    && reading[start..<(start + y.count)].elementsEqual(y) && go(i + 1, start + y.count)
            }
        }
        return go(0, 0)
    }

    /// 読みの頭の部分: 小さい字の手前では区切らない。
    func testReadingPrefixes() {
        let shou = "しょう".unicodeScalars.map(\.value)
        XCTAssertEqual(Reading.prefixes(of: shou).map { String(String.UnicodeScalarView($0.compactMap(Unicode.Scalar.init))) }, ["しょ", "しょう"])
        let kokoro = "こころ".unicodeScalars.map(\.value)
        XCTAssertEqual(Reading.prefixes(of: kokoro).count, 3)
    }

    /// 読みがあれば、6 文字で格の条件がとても広くても（内訳が約 850 万）、速く数えてページを作れる。
    func testReadingSixCharsWideConditionIsFast() throws {
        let query = SearchQuery(
            sei: nil, positions: Array(repeating: .free(.any), count: 6), conditions: [.chikaku: Set(6...120)],
            reading: "はるかなそら"
        )
        let start = Date()
        let search = try NameSearch(query: query, data: data, school: school)
        XCTAssertEqual(search.total, 4_191_688_453)
        // 真ん中のページは、内訳を全部たどっていたころと同じ（最初の 3 件）
        XCTAssertEqual(
            search.page(offset: search.total / 2, limit: 50).prefix(3).map(\.codePoints),
            ["剝弄坂長粗村", "剝弄坂長粗良", "剝弄坂長組乱"].map(\.codePoints)
        )
        XCTAssertEqual(search.page(offset: 0, limit: 50).count, 50)
        XCTAssertEqual(search.page(offset: search.total - 2, limit: 50).count, 2)
        // デバッグビルドでのしきい値（最適化したビルドでは 0.1 秒ほど）
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    /// 読みがあるときのページ送りは、内訳をまたいでも続いている（1 件ずつ取ったものと、まとめて取ったものが同じ）。
    func testReadingPagesAcrossBreakdowns() throws {
        let query = SearchQuery(
            sei: "田中", positions: [.free(.kanji), .free(.any)], conditions: [.soukaku: Set(10...60)], reading: "はるな"
        )
        let search = try NameSearch(query: query, data: data, school: school)
        let all = search.page(offset: 0, limit: search.total).map(\.codePoints)
        XCTAssertEqual(all.count, search.total)
        XCTAssertEqual(search.breakdowns.map(\.count).reduce(0, +), search.total)
        for offset in stride(from: 0, to: search.total, by: 37) {
            XCTAssertEqual(search.page(offset: offset, limit: 41).map(\.codePoints), Array(all[offset..<min(offset + 41, all.count)]))
        }
    }

    /// 読みの入力: カタカナはひらがなに直し、空なら絞り込まない。ひらがな以外はエラー。
    func testReadingNormalize() throws {
        XCTAssertEqual(try Reading.normalize(" ハルト ")?.count, 3)
        XCTAssertEqual(try Reading.normalize("ハルト"), try Reading.normalize("はると"))
        XCTAssertNil(try Reading.normalize("  "))
        XCTAssertEqual(try Reading.normalize("るー"), [0x308B, 0x30FC])
        XCTAssertThrowsError(try Reading.normalize("haru"))
        XCTAssertThrowsError(try Reading.normalize("は る"))
        XCTAssertThrowsError(try Reading.normalize(String(repeating: "あ", count: 31)))
    }

    /// 避けたい字がなかったころに保存した条件（お気に入り）も読める。
    func testQueryWithoutAvoidDecodes() throws {
        let json = #"{"sei":"田中","positions":[{"free":{"_0":"kanji"}}],"conditions":{"chikaku":[2]}}"#
        let query = try JSONDecoder().decode(SearchQuery.self, from: Data(json.utf8))
        XCTAssertEqual(query.avoid, [])
        XCTAssertEqual(query.sei, "田中")
        let encoded = try JSONEncoder().encode(SearchQuery(sei: nil, positions: [.free(.kanji)], conditions: [.chikaku: [2]], avoid: ["乙"]))
        XCTAssertEqual(try JSONDecoder().decode(SearchQuery.self, from: encoded).avoid, ["乙"])
    }

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
        return SearchQuery(
            sei: input["sei"] as? String, positions: positions, conditions: conditions,
            avoid: input["avoid"] as? [String] ?? [], use: input["use"] as? [String] ?? [],
            reading: input["reading"] as? String, readingPrefix: input["reading_prefix"] as? Bool ?? false
        )
    }

    static func errorType(_ error: Error) -> String {
        switch error as? SearchError {
        case .invalidInput, .fixedNotSingleChar: return "invalid_input"
        case .unknownStrokes: return "unknown_stroke"
        case .tooManyResults: return "too_many"
        case .invalidReading: return "invalid_reading"
        case .invalidLength, .noCondition, .invalidCondition: return "invalid_condition"
        case nil: return "other: \(error)"
        }
    }
}
