//
//  KanjiData.swift
//  KakuNote
//

import Foundation
import SQLite3

/// 文字の種類。
nonisolated enum Script: String, Sendable {
    case kanji
    case hiragana
    case katakana
}

/// 1 文字の情報（仕様書 strokes.md「画数の決め方（新字体式）」）。
nonisolated struct CharInfo: Sendable, Equatable {
    let char: String
    /// 新字体式の画数（漢字は kanji.modern_strokes、それ以外は non_kanji.strokes）
    let strokes: Int
    let script: Script
    /// 名前に使える字なら true（常用漢字・人名用漢字、または non_kanji の字）
    let nameOK: Bool
    /// 名の 1 文字目に置けるなら true
    let initialOK: Bool
    /// 「探す」で自動の候補に入れるなら true
    let autoOK: Bool
    /// 数え間違えやすい別の画数（「調べる」で併記する）
    let altStrokes: [Int]
}

/// 画数がわからない字があるときのエラー。
nonisolated struct UnknownStrokeError: Error, Equatable {
    let chars: [String]
}

nonisolated enum KanjiDataError: Error, Equatable {
    case notBundled
    case openFailed(String)
    case queryFailed(String)
}

/// 同梱の漢字 DB（kanji.sqlite）の中身。起動後に 1 回だけ読み込み、あとはメモリ上で引く。
///
/// 字は String ではなくコードポイント（Unicode.Scalar）で引く。Swift の String は正準等価な字を
/// 同じものとして比べるので、「海」（U+6D77、9 画）と互換漢字の「海」（U+FA45、10 画）が
/// 同じキーになってしまう。
nonisolated struct KanjiData: Sendable {

    let chars: [Unicode.Scalar: CharInfo]
    let meta: [String: String]

    /// アプリに同梱した DB。最初に使われたときに読み込む。
    static let bundled: Result<KanjiData, KanjiDataError> = {
        guard let url = Bundle.main.url(forResource: "kanji", withExtension: "sqlite") else {
            return .failure(.notBundled)
        }
        return Result { try KanjiData.load(from: url) }.mapError { $0 as? KanjiDataError ?? .openFailed("\($0)") }
    }()

    static func load(from url: URL) throws -> KanjiData {
        let database = try ReadOnlyDatabase(url: url)

        var alts: [Unicode.Scalar: [Int]] = [:]
        try database.forEachRow("SELECT char, strokes FROM alt_stroke ORDER BY char, strokes") { row in
            alts[try row.scalar(0), default: []].append(row.int(1))
        }

        var chars: [Unicode.Scalar: CharInfo] = [:]
        try database.forEachRow(
            "SELECT char, modern_strokes, name_ok FROM kanji WHERE modern_strokes IS NOT NULL"
        ) { row in
            let scalar = try row.scalar(0)
            chars[scalar] = CharInfo(
                char: String(scalar), strokes: row.int(1), script: .kanji, nameOK: row.int(2) == 1,
                initialOK: true, autoOK: true, altStrokes: alts[scalar] ?? []
            )
        }
        try database.forEachRow("SELECT char, script, strokes, initial_ok, auto_ok FROM non_kanji") { row in
            let scalar = try row.scalar(0)
            guard let script = Script(rawValue: row.text(1)) else {
                throw KanjiDataError.queryFailed("non_kanji の script が不正: \(scalar)")
            }
            chars[scalar] = CharInfo(
                char: String(scalar), strokes: row.int(2), script: script, nameOK: true,
                initialOK: row.int(3) == 1, autoOK: row.int(4) == 1, altStrokes: []
            )
        }

        var meta: [String: String] = [:]
        try database.forEachRow("SELECT key, value FROM meta") { row in
            meta[row.text(0)] = row.text(1)
        }
        return KanjiData(chars: chars, meta: meta)
    }

    /// 1 文字（コードポイント 1 つ）の情報。2 つ以上のコードポイントからなる文字列なら nil。
    func info(_ char: String) -> CharInfo? {
        let scalars = char.unicodeScalars
        guard scalars.count == 1, let scalar = scalars.first else { return nil }
        return chars[scalar]
    }

    /// 各字の画数。画数がわからない字があれば UnknownStrokeError を投げる。
    func strokes(of chars: [String]) throws -> [Int] {
        let infos = chars.map { info($0) }
        let unknown = zip(chars, infos).filter { $0.1 == nil }.map(\.0)
        if !unknown.isEmpty { throw UnknownStrokeError(chars: unknown) }
        return infos.map { $0!.strokes }
    }
}

// MARK: - SQLite（読み取り専用）

private nonisolated final class ReadOnlyDatabase {

    struct Row {
        let statement: OpaquePointer

        func text(_ column: Int32) -> String {
            guard let pointer = sqlite3_column_text(statement, column) else { return "" }
            return String(cString: pointer)
        }

        func scalar(_ column: Int32) throws -> Unicode.Scalar {
            let scalars = text(column).unicodeScalars
            guard scalars.count == 1, let scalar = scalars.first else {
                throw KanjiDataError.queryFailed("1 文字ではない: \(text(column))")
            }
            return scalar
        }

        func int(_ column: Int32) -> Int {
            Int(sqlite3_column_int64(statement, column))
        }
    }

    private var handle: OpaquePointer?

    init(url: URL) throws {
        // immutable=1: 同梱の DB は書き換えないので、ロックやジャーナルを使わずに開く
        let uri = url.absoluteString + "?immutable=1"
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        guard sqlite3_open_v2(uri, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw KanjiDataError.openFailed(message)
        }
    }

    deinit {
        sqlite3_close(handle)
    }

    func forEachRow(_ sql: String, _ body: (Row) throws -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw KanjiDataError.queryFailed(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(statement) }
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                try body(Row(statement: statement))
            case SQLITE_DONE:
                return
            default:
                throw KanjiDataError.queryFailed(String(cString: sqlite3_errmsg(handle)))
            }
        }
    }
}
