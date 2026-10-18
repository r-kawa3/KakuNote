//
//  StrokesTests.swift
//  KakuNoteTests
//

import XCTest
@testable import KakuNote

/// 共通テストケース（testcases/strokes.json）で、入力文字の前処理と 1 文字の画数を確かめる。
final class StrokesTests: XCTestCase {

    private var data: KanjiData!

    override func setUpWithError() throws {
        data = try KanjiData.bundled.get()
    }

    func testCommonStrokeCases() throws {
        let json = try SharedTestCases.load("strokes.json")
        let cases = try XCTUnwrap(json["cases"] as? [[String: Any]])
        XCTAssertFalse(cases.isEmpty)

        for testCase in cases {
            let id = testCase["id"] as? String ?? "?"
            let input = try XCTUnwrap(testCase["input"] as? String, id)

            switch testCase["error"] as? String {
            case "invalid_input":
                XCTAssertThrowsError(try TextPreprocessor.characters(from: input), id) { error in
                    XCTAssertTrue(error is InputError, "\(id): \(error)")
                }

            case "unknown_stroke":
                let chars = try TextPreprocessor.characters(from: input)
                XCTAssertThrowsError(try data.strokes(of: chars), id) { error in
                    XCTAssertEqual(
                        (error as? UnknownStrokeError)?.chars,
                        testCase["unknown_chars"] as? [String],
                        id
                    )
                }

            default:
                let chars = try TextPreprocessor.characters(from: input)
                // String の == は正準等価な字（海 U+6D77 と 海 U+FA45）を同じとみなすので、コードポイントで比べる
                XCTAssertEqual(chars.map(codePoints), (testCase["chars"] as? [String])?.map(codePoints), id)
                XCTAssertEqual(try data.strokes(of: chars), testCase["strokes"] as? [Int], id)
                if let expectedAlt = testCase["alt_strokes"] as? [[Int]] {
                    XCTAssertEqual(chars.map { data.info($0)?.altStrokes ?? [] }, expectedAlt, id)
                }
            }
        }
    }

    func testCanonicallyEquivalentCompatIdeographsStayDistinct() throws {
        // 海 U+6D77 と互換漢字の 海 U+FA45 は、Swift の String では == になるが、画数は別
        XCTAssertEqual(data.info("\u{6D77}")?.strokes, 9)
        XCTAssertEqual(data.info("\u{FA45}")?.strokes, 10)
        XCTAssertEqual(try TextPreprocessor.characters(from: "\u{FA45}").map(codePoints), [[0xFA45]])
        // 漢字に濁点を付けても、NFC で別の字に置き換わらずにエラーになる
        XCTAssertThrowsError(try TextPreprocessor.characters(from: "\u{FA45}\u{3099}"))
    }

    private func codePoints(_ text: String) -> [UInt32] {
        text.unicodeScalars.map(\.value)
    }

    func testBundledDataMatchesTestCaseVersion() throws {
        let json = try SharedTestCases.load("search.json")
        let version = try XCTUnwrap(json["data_version"] as? [String: String])
        XCTAssertEqual(data.meta["unicode_version"], version["unicode_version"])
        XCTAssertEqual(data.meta["kanjidic2_database_version"], version["kanjidic2_database_version"])
    }
}

/// リポジトリの testcases/ にある共通テストケースを読む。
enum SharedTestCases {
    static func load(_ name: String, filePath: StaticString = #filePath) throws -> [String: Any] {
        let url = URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()      // KakuNoteTests/
            .deletingLastPathComponent()      // リポジトリ直下
            .appendingPathComponent("testcases")
            .appendingPathComponent(name)
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
