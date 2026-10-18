//
//  NameLookup.swift
//  KakuNote
//

import Foundation

/// 「調べる」の 1 文字分の結果。
nonisolated struct LookupChar: Equatable, Sendable {
    let char: String
    let strokes: Int
    /// 数え間違えやすい別の画数
    let altStrokes: [Int]
}

/// 「調べる」の結果（仕様書 kaku.md「調べる」画面）。
nonisolated struct LookupResult: Equatable, Sendable {
    let sei: [LookupChar]
    let mei: [LookupChar]
    let warnings: [NameWarning]
    /// 姓と名の両方があるときの五格
    let kaku: Kaku?
    /// 名だけのときの総画数（＝ 地格）
    let nameOnlyTotal: Int?
}

nonisolated enum NamePart: Equatable, Sendable {
    case sei
    case mei
}

nonisolated enum LookupError: Error, Equatable {
    /// 入力文字列が前処理の規則に合わない
    case invalidInput(part: NamePart, InputError)
    /// 画数がわからない字がある（姓・名の順）
    case unknownStrokes([String])
}

nonisolated enum NameLookup {

    /// 姓・名の入力文字列から「調べる」の結果を作る。空の欄は入力なしとして扱う。
    static func lookup(sei: String, mei: String, data: KanjiData, school: any KakuSchool) throws -> LookupResult {
        let seiChars = try characters(sei, part: .sei)
        let meiChars = try characters(mei, part: .mei)

        let unknown = (seiChars + meiChars).filter { data.info($0) == nil }
        if !unknown.isEmpty { throw LookupError.unknownStrokes(unknown) }

        let seiRows = seiChars.map { row($0, data: data) }
        let meiRows = meiChars.map { row($0, data: data) }
        let seiStrokes = seiRows.map(\.strokes)
        let meiStrokes = meiRows.map(\.strokes)

        return LookupResult(
            sei: seiRows,
            mei: meiRows,
            warnings: data.meiWarnings(meiChars),
            kaku: seiStrokes.isEmpty || meiStrokes.isEmpty ? nil : school.kaku(sei: seiStrokes, mei: meiStrokes),
            nameOnlyTotal: seiStrokes.isEmpty && !meiStrokes.isEmpty ? school.nameOnlyTotal(mei: meiStrokes) : nil
        )
    }

    private static func characters(_ text: String, part: NamePart) throws -> [String] {
        do {
            return try TextPreprocessor.characters(from: text)
        } catch InputError.empty {
            return []
        } catch let error as InputError {
            throw LookupError.invalidInput(part: part, error)
        }
    }

    private static func row(_ char: String, data: KanjiData) -> LookupChar {
        let info = data.info(char)!
        return LookupChar(char: char, strokes: info.strokes, altStrokes: info.altStrokes)
    }
}
