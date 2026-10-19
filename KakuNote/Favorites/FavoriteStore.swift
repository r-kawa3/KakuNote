//
//  FavoriteStore.swift
//  KakuNote
//

import Foundation
import SQLite3

/// お気に入りの 1 件。
struct Favorite: Identifiable, Hashable {
    let id: Int64
    /// 姓。姓なしで探した候補なら nil
    let sei: String?
    let mei: String
    /// 探したときの条件。わからなければ nil
    let query: SearchQuery?
    let createdAt: Date
}

enum FavoriteStoreError: Error, Equatable {
    case openFailed(String)
    case queryFailed(String)
}

/// お気に入りの保存。同梱の漢字 DB とは別の SQLite ファイル（Application Support の中）に書く。
/// 同梱 DB を差し替えても、お気に入りは消えない。
final class FavoriteStore {

    /// 保存の形のバージョン（PRAGMA user_version）。形を変えたら上げて、移行の処理を足す
    private static let schemaVersion: Int32 = 1

    private var handle: OpaquePointer?

    /// アプリが使う保存先。
    static func defaultURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return directory.appendingPathComponent("favorites.sqlite")
    }

    init(url: URL) throws {
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw FavoriteStoreError.openFailed(message)
        }
        try migrate()
    }

    deinit {
        sqlite3_close(handle)
    }

    /// 保存したお気に入り。新しく保存したものが先。
    func all() throws -> [Favorite] {
        var favorites: [Favorite] = []
        try run("SELECT id, sei, mei, query, created_at FROM favorite ORDER BY created_at DESC, id DESC") { statement in
            let sei = Self.text(statement, 1)
            let queryJSON = Self.text(statement, 3)
            favorites.append(Favorite(
                id: sqlite3_column_int64(statement, 0),
                sei: sei.isEmpty ? nil : sei,
                mei: Self.text(statement, 2),
                query: queryJSON.isEmpty ? nil : try? JSONDecoder().decode(SearchQuery.self, from: Data(queryJSON.utf8)),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
            ))
        }
        return favorites
    }

    /// 保存する。同じ姓・名がすでにあれば何もせず false を返す。
    @discardableResult
    func add(sei: String?, mei: String, query: SearchQuery?, date: Date = Date()) throws -> Bool {
        let queryJSON = try query.map { String(decoding: try JSONEncoder().encode($0), as: UTF8.self) } ?? ""
        try run(
            "INSERT OR IGNORE INTO favorite (sei, mei, query, created_at) VALUES (?, ?, ?, ?)",
            bind: [.text(sei ?? ""), .text(mei), .text(queryJSON), .double(date.timeIntervalSince1970)]
        )
        return sqlite3_changes(handle) > 0
    }

    func remove(sei: String?, mei: String) throws {
        try run("DELETE FROM favorite WHERE sei = ? AND mei = ?", bind: [.text(sei ?? ""), .text(mei)])
    }

    // MARK: - 内部

    private func migrate() throws {
        var version: Int32 = 0
        try run("PRAGMA user_version") { version = sqlite3_column_int($0, 0) }
        if version < 1 {
            // sei と mei は文字列のまま（バイト列）で比べるので、正準等価な別の字も区別される
            try run("""
                CREATE TABLE IF NOT EXISTS favorite (
                    id         INTEGER PRIMARY KEY AUTOINCREMENT,
                    sei        TEXT    NOT NULL DEFAULT '',
                    mei        TEXT    NOT NULL,
                    query      TEXT    NOT NULL DEFAULT '',
                    created_at REAL    NOT NULL,
                    UNIQUE (sei, mei)
                )
                """)
        }
        try run("PRAGMA user_version = \(Self.schemaVersion)")
    }

    private enum Value {
        case text(String)
        case double(Double)
    }

    private func run(_ sql: String, bind values: [Value] = [], row: ((OpaquePointer) throws -> Void)? = nil) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw FavoriteStoreError.queryFailed(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case .text(let text): sqlite3_bind_text(statement, position, text, -1, transient)
            case .double(let number): sqlite3_bind_double(statement, position, number)
            }
        }
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                try row?(statement)
            case SQLITE_DONE:
                return
            default:
                throw FavoriteStoreError.queryFailed(String(cString: sqlite3_errmsg(handle)))
            }
        }
    }

    private static func text(_ statement: OpaquePointer, _ column: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: pointer)
    }
}
