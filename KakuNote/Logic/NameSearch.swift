//
//  NameSearch.swift
//  KakuNote
//

import Foundation

/// 格の種類。
nonisolated enum KakuKind: String, CaseIterable, Sendable {
    case tenkaku, jinkaku, chikaku, soukaku, gaikaku
}

extension Kaku {
    nonisolated func value(of kind: KakuKind) -> Int {
        switch kind {
        case .tenkaku: return tenkaku
        case .jinkaku: return jinkaku
        case .chikaku: return chikaku
        case .soukaku: return soukaku
        case .gaikaku: return gaikaku
        }
    }
}

/// 位置ごとの文字の種類。
nonisolated enum ScriptFilter: String, CaseIterable, Sendable {
    case kanji, hiragana, katakana, any

    func accepts(_ script: Script) -> Bool {
        switch self {
        case .any: return true
        case .kanji: return script == .kanji
        case .hiragana: return script == .hiragana
        case .katakana: return script == .katakana
        }
    }
}

/// 名の 1 つの位置の条件。
nonisolated enum PositionCondition: Hashable, Sendable {
    /// この字にする
    case fixed(String)
    /// n 画の字にする
    case strokes(Int, ScriptFilter)
    /// 何画でもよい
    case free(ScriptFilter)
}

/// 検索の条件（仕様書 search.md「入力」）。
nonisolated struct SearchQuery: Hashable, Sendable {
    /// 姓。nil なら姓なし（名前のみ検索）
    var sei: String?
    /// 名の位置 1〜L の条件（L は 1〜4）
    var positions: [PositionCondition]
    /// 格ごとに許す値の集合。すべてを満たす名だけを候補にする
    var conditions: [KakuKind: Set<Int>]
}

nonisolated enum SearchError: Error, Equatable {
    /// 文字数が 1〜4 でない
    case invalidLength
    /// 格の条件がない、または値が空
    case noCondition
    /// 条件にできない格（天格、姓なしの人格・総格・外格）
    case invalidCondition(KakuKind)
    /// 姓や固定の字の入力文字列が前処理の規則に合わない
    case invalidInput(InputError)
    /// 固定の字が 1 文字でない（position は 1 から数える）
    case fixedNotSingleChar(position: Int)
    /// 画数がわからない字がある
    case unknownStrokes([String])
}

/// 名前の候補の検索（仕様書 search.md）。候補は全部を作らず、page で必要な範囲だけを作る。
nonisolated struct NameSearch: Sendable {

    /// 条件を満たす内訳と、その内訳の候補の数。
    struct Breakdown: Equatable, Sendable {
        let strokes: [Int]
        let count: Int
    }

    let breakdowns: [Breakdown]
    let total: Int

    /// 位置ごと: 画数 → その画数の候補の字（仕様の順番）
    private let candidates: [[Int: [String]]]

    init(query: SearchQuery, data: KanjiData, school: any KakuSchool) throws {
        guard (1...4).contains(query.positions.count) else { throw SearchError.invalidLength }
        guard !query.conditions.isEmpty, query.conditions.values.allSatisfy({ !$0.isEmpty }) else {
            throw SearchError.noCondition
        }
        let allowed: Set<KakuKind> = query.sei == nil ? [.chikaku] : [.jinkaku, .chikaku, .soukaku, .gaikaku]
        if let invalid = KakuKind.allCases.first(where: { query.conditions[$0] != nil && !allowed.contains($0) }) {
            throw SearchError.invalidCondition(invalid)
        }

        let seiStrokes: [Int]?
        if let sei = query.sei {
            seiStrokes = try Self.strokes(of: Self.characters(sei), data: data)
        } else {
            seiStrokes = nil
        }

        // 位置ごとの候補の字
        var candidates: [[Int: [String]]] = []
        for (index, position) in query.positions.enumerated() {
            switch position {
            case .fixed(let text):
                let chars = try Self.characters(text)
                guard chars.count == 1 else { throw SearchError.fixedNotSingleChar(position: index + 1) }
                let strokes = try Self.strokes(of: chars, data: data)
                candidates.append([strokes[0]: chars])
            case .strokes(let strokes, let script):
                let chars = data.autoCandidates(script: script, initial: index == 0).filter { $0.strokes == strokes }
                candidates.append(chars.isEmpty ? [:] : [strokes: chars.map(\.char)])
            case .free(let script):
                candidates.append(Dictionary(grouping: data.autoCandidates(script: script, initial: index == 0), by: \.strokes)
                    .mapValues { $0.map(\.char) })
            }
        }
        self.candidates = candidates

        // 条件を満たす内訳を、辞書式の小さい順に求める
        let strokeValues = candidates.map { $0.keys.sorted() }
        var breakdowns: [Breakdown] = []
        var current: [Int] = []
        func visit(_ index: Int) {
            if index == strokeValues.count {
                if Self.matches(mei: current, sei: seiStrokes, conditions: query.conditions, school: school) {
                    let count = current.enumerated().reduce(1) { $0 * candidates[$1.offset][$1.element]!.count }
                    breakdowns.append(Breakdown(strokes: current, count: count))
                }
                return
            }
            for value in strokeValues[index] {
                current.append(value)
                visit(index + 1)
                current.removeLast()
            }
        }
        visit(0)
        self.breakdowns = breakdowns
        self.total = breakdowns.reduce(0) { $0 + $1.count }
    }

    /// 先頭から offset 件目（0 始まり）から、最大 limit 件の候補を返す。
    func page(offset: Int, limit: Int) -> [String] {
        guard offset >= 0, limit > 0 else { return [] }
        var result: [String] = []
        var index = offset
        for breakdown in breakdowns {
            if index >= breakdown.count {
                index -= breakdown.count
                continue
            }
            let lists = breakdown.strokes.enumerated().map { candidates[$0.offset][$0.element]! }
            while index < breakdown.count && result.count < limit {
                result.append(Self.combination(lists, at: index))
                index += 1
            }
            if result.count >= limit { break }
            index = 0
        }
        return result
    }

    // MARK: - 内部

    private static func matches(mei: [Int], sei: [Int]?, conditions: [KakuKind: Set<Int>], school: any KakuSchool) -> Bool {
        guard let sei else {
            return conditions[.chikaku]?.contains(school.nameOnlyTotal(mei: mei)) ?? false
        }
        let kaku = school.kaku(sei: sei, mei: mei)
        return conditions.allSatisfy { $0.value.contains(kaku.value(of: $0.key)) }
    }

    /// 位置 1 がいちばんゆっくり変わる順番で、n 番目（0 始まり）の組み合わせ。
    private static func combination(_ lists: [[String]], at n: Int) -> String {
        var n = n
        var chars = [String](repeating: "", count: lists.count)
        for i in stride(from: lists.count - 1, through: 0, by: -1) {
            chars[i] = lists[i][n % lists[i].count]
            n /= lists[i].count
        }
        return chars.joined()
    }

    private static func characters(_ text: String) throws -> [String] {
        do {
            return try TextPreprocessor.characters(from: text)
        } catch let error as InputError {
            throw SearchError.invalidInput(error)
        }
    }

    private static func strokes(of chars: [String], data: KanjiData) throws -> [Int] {
        do {
            return try data.strokes(of: chars)
        } catch let error as UnknownStrokeError {
            throw SearchError.unknownStrokes(error.chars)
        }
    }
}

extension KanjiData {

    /// 「探す」で自動の候補に入れる字（仕様書 search.md「位置ごとの候補の字」）。
    /// 漢字 → ひらがな → カタカナ、同じ種類の中ではコードポイントの小さい順。
    nonisolated func autoCandidates(script: ScriptFilter, initial: Bool) -> [CharInfo] {
        chars
            .filter { script.accepts($0.value.script) && $0.value.autoOK && $0.value.nameOK && ($0.value.initialOK || !initial) }
            .sorted { lhs, rhs in
                let left = Self.scriptOrder(lhs.value.script), right = Self.scriptOrder(rhs.value.script)
                return left != right ? left < right : lhs.key.value < rhs.key.value
            }
            .map(\.value)
    }

    private nonisolated static func scriptOrder(_ script: Script) -> Int {
        switch script {
        case .kanji: return 0
        case .hiragana: return 1
        case .katakana: return 2
        }
    }
}
