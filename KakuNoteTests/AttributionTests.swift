//
//  AttributionTests.swift
//  KakuNoteTests
//

import XCTest
@testable import KakuNote

/// 「このアプリについて」に出す出典とライセンスの内容を確かめる。
final class AttributionTests: XCTestCase {

    func testSourcesAndLicenses() throws {
        let data = try KanjiData.bundled.get()
        let sources = Attribution.sources(meta: data.meta)

        let kanjidic = try XCTUnwrap(sources.first { $0.name == "KANJIDIC2" })
        XCTAssertEqual(kanjidic.version, "2026-291")
        XCTAssertTrue(kanjidic.links.contains { $0.url.absoluteString == "https://www.edrdg.org/wiki/index.php/KANJIDIC_Project" })
        XCTAssertTrue(kanjidic.links.contains { $0.url.absoluteString == "https://creativecommons.org/licenses/by-sa/4.0/" })
        XCTAssertTrue(kanjidic.links.contains { $0.url.absoluteString == "https://www.edrdg.org/edrdg/licence.html" })

        // Unihan は同梱する DB に入れていないので、出典に出さない
        XCTAssertEqual(sources.map(\.name), ["KANJIDIC2"])
        XCTAssertNil(data.meta["unicode_version"])
    }

    func testMissingVersionIsShownAsUnknown() {
        let sources = Attribution.sources(meta: [:])
        XCTAssertTrue(sources.allSatisfy { $0.version == "不明" })
    }
}
