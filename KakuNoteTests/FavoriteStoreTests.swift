//
//  FavoriteStoreTests.swift
//  KakuNoteTests
//

import XCTest
@testable import KakuNote

/// お気に入りの保存（漢字 DB とは別の SQLite ファイル）を確かめる。
@MainActor
final class FavoriteStoreTests: XCTestCase {

    private var url: URL!

    override func setUpWithError() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("favorites-\(UUID().uuidString).sqlite")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: url)
    }

    private let query = SearchQuery(
        sei: "田中",
        positions: [.fixed("陽"), .free(.hiragana)],
        conditions: [.jinkaku: [16], .soukaku: [24, 31]]
    )

    func testAddListRemove() throws {
        let store = try FavoriteStore(url: url)
        XCTAssertTrue(try store.all().isEmpty)

        XCTAssertTrue(try store.add(sei: "田中", mei: "陽な", query: query))
        XCTAssertTrue(try store.add(sei: nil, mei: "翔", query: nil))

        let all = try store.all()
        // 新しく保存したものが先
        XCTAssertEqual(all.map(\.mei), ["翔", "陽な"])
        XCTAssertNil(all[0].sei)
        XCTAssertNil(all[0].query)
        XCTAssertEqual(all[1].sei, "田中")
        XCTAssertEqual(all[1].query, query)

        try store.remove(sei: "田中", mei: "陽な")
        XCTAssertEqual(try store.all().map(\.mei), ["翔"])
    }

    func testSameNameIsSavedOnce() throws {
        let store = try FavoriteStore(url: url)
        XCTAssertTrue(try store.add(sei: "田中", mei: "健太", query: query))
        XCTAssertFalse(try store.add(sei: "田中", mei: "健太", query: nil))
        XCTAssertEqual(try store.all().count, 1)
        // 姓が違えば別のお気に入り
        XCTAssertTrue(try store.add(sei: "林", mei: "健太", query: nil))
        XCTAssertTrue(try store.add(sei: nil, mei: "健太", query: nil))
        XCTAssertEqual(try store.all().count, 3)
    }

    func testCompatIdeographIsADifferentName() throws {
        // 海 U+6D77 と互換漢字の 海 U+FA45 は、Swift の String では == だが別の名前
        let store = try FavoriteStore(url: url)
        XCTAssertTrue(try store.add(sei: nil, mei: "\u{6D77}", query: nil))
        XCTAssertTrue(try store.add(sei: nil, mei: "\u{FA45}", query: nil))
        XCTAssertEqual(try store.all().count, 2)
    }

    func testFavoritesSurviveReopening() throws {
        do {
            let store = try FavoriteStore(url: url)
            try store.add(sei: "田中", mei: "陽な", query: query)
        }
        let reopened = try FavoriteStore(url: url)
        XCTAssertEqual(try reopened.all().map(\.mei), ["陽な"])
        XCTAssertEqual(try reopened.all().first?.query, query)
    }

    func testDefaultFileIsOutsideTheBundle() throws {
        let defaultURL = try FavoriteStore.defaultURL()
        XCTAssertFalse(defaultURL.path.hasPrefix(Bundle.main.bundleURL.path))
        XCTAssertNotEqual(defaultURL.lastPathComponent, "kanji.sqlite")
    }

    func testModelTogglesAndKnowsSavedNames() throws {
        let model = FavoritesModel(store: try FavoriteStore(url: url))
        XCTAssertFalse(model.isFavorite(sei: "田中", mei: "健太"))
        model.toggle(sei: "田中", mei: "健太", query: query)
        XCTAssertTrue(model.isFavorite(sei: "田中", mei: "健太"))
        XCTAssertFalse(model.isFavorite(sei: nil, mei: "健太"))
        XCTAssertEqual(model.items.count, 1)
        model.toggle(sei: "田中", mei: "健太", query: query)
        XCTAssertFalse(model.isFavorite(sei: "田中", mei: "健太"))
        XCTAssertTrue(model.items.isEmpty)
    }

    func testConditionSummary() {
        XCTAssertEqual(ConditionSummary.text(for: query), "2文字・1文字目「陽」・人格 16・総格 24, 31")
        let nameOnly = SearchQuery(sei: nil, positions: [.free(.kanji)], conditions: [.chikaku: [12]])
        XCTAssertEqual(ConditionSummary.text(for: nameOnly), "1文字・総画数 12")
    }
}
