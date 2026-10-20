//
//  NameSearch.swift
//  KakuNote
//

import Foundation

/// 格の種類。
nonisolated enum KakuKind: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
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
nonisolated enum ScriptFilter: String, CaseIterable, Codable, Sendable {
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
nonisolated enum PositionCondition: Hashable, Codable, Sendable {
    /// この字にする
    case fixed(String)
    /// n 画の字にする
    case strokes(Int, ScriptFilter)
    /// 何画でもよい
    case free(ScriptFilter)
}

/// 検索の条件（仕様書 search.md「入力」）。
/// お気に入りには、探したときの条件として JSON で保存する。
nonisolated struct SearchQuery: Hashable, Codable, Sendable {
    /// 姓。nil なら姓なし（名前のみ検索）
    var sei: String?
    /// 名の位置 1〜L の条件（L は 1〜6）
    var positions: [PositionCondition]
    /// 格ごとに許す値の集合。すべてを満たす名だけを候補にする
    var conditions: [KakuKind: Set<Int>]
    /// 避けたい字。固定でない位置の候補から外す（仕様書 search.md「避けたい字」）。
    /// String の Set は正準等価な字を同じとみなすので、配列で持つ
    var avoid: [String] = []
}

extension SearchQuery {
    private enum CodingKeys: String, CodingKey {
        case sei, positions, conditions, avoid
    }

    // 避けたい字がなかったころに保存した条件（お気に入り）も読めるようにする
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sei = try container.decodeIfPresent(String.self, forKey: .sei)
        positions = try container.decode([PositionCondition].self, forKey: .positions)
        conditions = try container.decode([KakuKind: Set<Int>].self, forKey: .conditions)
        avoid = try container.decodeIfPresent([String].self, forKey: .avoid) ?? []
    }
}

nonisolated enum SearchError: Error, Equatable {
    /// 文字数が 1〜6 でない
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
    /// 候補の総数が NameSearch.maxTotal を超える（条件が広すぎる）
    case tooManyResults
}

/// 名前の候補の検索（仕様書 search.md）。候補は全部を作らず、page で必要な範囲だけを作る。
nonisolated struct NameSearch: Sendable {

    /// 条件を満たす内訳と、その内訳の候補の数。
    struct Breakdown: Equatable, Sendable {
        let strokes: [Int]
        let count: Int
    }

    /// 候補 1 件: 名と、その各字の画数（内訳）。
    struct Candidate: Equatable, Sendable {
        let name: String
        let strokes: [Int]
    }

    /// 名の文字数の上限
    static let maxLength = 6
    /// 候補の総数の上限（2^53 - 1）。JSON や多くの言語で整数を正確に扱える範囲に合わせる
    static let maxTotal = 9_007_199_254_740_991

    let total: Int
    /// 名の文字数
    let length: Int
    /// 姓の各字の画数。姓なしなら nil
    let seiStrokes: [Int]?
    /// 条件を満たす内訳の画数を 1 本の配列に並べたもの（内訳ごとに length 個ずつ）。
    /// 内訳は 10 万を超えることがあるので、内訳ごとに配列を作らない
    private let breakdownStrokes: [Int]
    /// 内訳ごとの候補の数
    private let breakdownCounts: [Int]

    /// 条件を満たす内訳（辞書式の小さい順）。テストや表示で使う
    var breakdowns: [Breakdown] {
        breakdownCounts.indices.map { i in
            Breakdown(strokes: Array(breakdownStrokes[(i * length)..<((i + 1) * length)]), count: breakdownCounts[i])
        }
    }

    /// 位置ごと: 画数 → その画数の候補の字（仕様の順番）
    private let candidates: [[Int: [String]]]

    init(query: SearchQuery, data: KanjiData, school: any KakuSchool) throws {
        guard (1...Self.maxLength).contains(query.positions.count) else { throw SearchError.invalidLength }
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

        // 避けたい字。前処理してから、コードポイントの並びで比べる
        let avoided = Set(try query.avoid.flatMap { try Self.characters($0) }.map { $0.unicodeScalars.map(\.value) })
        func autoCandidates(_ script: ScriptFilter, initial: Bool) -> [CharInfo] {
            let chars = data.autoCandidates(script: script, initial: initial)
            return avoided.isEmpty ? chars : chars.filter { !avoided.contains($0.char.unicodeScalars.map(\.value)) }
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
                let chars = autoCandidates(script, initial: index == 0).filter { $0.strokes == strokes }
                candidates.append(chars.isEmpty ? [:] : [strokes: chars.map(\.char)])
            case .free(let script):
                candidates.append(Dictionary(grouping: autoCandidates(script, initial: index == 0), by: \.strokes)
                    .mapValues { $0.map(\.char) })
            }
        }
        self.candidates = candidates

        // 条件を満たす内訳を、辞書式の小さい順に求める。
        // 条件を満たせないとわかった途中の組み合わせは打ち切る（仕様書 search.md「内訳の列挙の打ち切り」）
        let strokeValues = candidates.map { $0.keys.sorted() }
        let counts = zip(candidates, strokeValues).map { group, values in values.map { group[$0]!.count } }
        let length = strokeValues.count
        var breakdownStrokes: [Int] = []
        var breakdownCounts: [Int] = []
        var total = 0
        if strokeValues.allSatisfy({ !$0.isEmpty }) {
            let bounds = ConditionBounds(
                kakuValues: { Self.kakuValues(mei: $0, sei: seiStrokes, school: school) },
                strokeValues: strokeValues,
                conditions: query.conditions
            )
            // 深さごとの「途中までの格の値の増え方」。全部の位置を決めると、各格の値そのものになる
            var partials = [[Int]](repeating: [Int](repeating: 0, count: bounds.itemCount), count: length + 1)
            var current = [Int](repeating: 0, count: length)
            func visit(_ index: Int, _ count: Int) throws {
                if index == length {
                    // 内訳 1 つの件数だけで上限を超える場合も、ここで止める
                    guard count <= Self.maxTotal else { throw SearchError.tooManyResults }
                    breakdownStrokes.append(contentsOf: current)
                    breakdownCounts.append(count)
                    // 上限を超えたら、残りをたどらずにすぐやめる
                    total += count
                    guard total <= Self.maxTotal else { throw SearchError.tooManyResults }
                    return
                }
                let partial = partials[index]
                for (k, value) in strokeValues[index].enumerated() {
                    guard bounds.extend(partial, at: index, with: value, into: &partials[index + 1]) else {
                        continue
                    }
                    current[index] = value
                    let (product, overflow) = count.multipliedReportingOverflow(by: counts[index][k])
                    try visit(index + 1, overflow ? Self.maxTotal + 1 : min(product, Self.maxTotal + 1))
                }
            }
            try visit(0, 1)
        }
        self.length = length
        self.seiStrokes = seiStrokes
        self.breakdownStrokes = breakdownStrokes
        self.breakdownCounts = breakdownCounts
        self.total = total
    }

    /// 先頭から offset 件目（0 始まり）から、最大 limit 件の候補を返す。
    func page(offset: Int, limit: Int) -> [String] {
        candidates(offset: offset, limit: limit).map(\.name)
    }

    /// page と同じ範囲の候補を、各字の画数と一緒に返す。
    func candidates(offset: Int, limit: Int) -> [Candidate] {
        guard offset >= 0, limit > 0 else { return [] }
        var result: [Candidate] = []
        var index = offset
        for (i, count) in breakdownCounts.enumerated() {
            if index >= count {
                index -= count
                continue
            }
            let strokes = Array(breakdownStrokes[(i * length)..<((i + 1) * length)])
            let lists = (0..<length).map { candidates[$0][strokes[$0]]! }
            while index < count && result.count < limit {
                result.append(Candidate(name: Self.combination(lists, at: index), strokes: strokes))
                index += 1
            }
            if result.count >= limit { break }
            index = 0
        }
        return result
    }

    // MARK: - 内部

    /// 名の各位置の画数から、条件にできる格の値を求める。姓なしなら地格（総画数）だけ。
    private static func kakuValues(mei: [Int], sei: [Int]?, school: any KakuSchool) -> [KakuKind: Int] {
        guard let sei else {
            return [.chikaku: school.nameOnlyTotal(mei: mei)]
        }
        let kaku = school.kaku(sei: sei, mei: mei)
        return Dictionary(uniqueKeysWithValues: KakuKind.allCases.map { ($0, kaku.value(of: $0)) })
    }

    /// 打ち切りの判定。姓と文字数を決めると、各格は名の各位置の画数の 1 次式になる（KakuSchool の約束）。
    /// すべての位置が最小の画数のときの値と、位置ごとの係数（画数を 1 増やしたときの変化）を求めておき、
    /// 決めていない位置の最小・最大から、各格が取りうる範囲を出す。
    /// 全部の位置を決めると範囲は 1 点になるので、最後の判定はそのまま「条件を満たすか」になる。
    private struct ConditionBounds {
        struct Item {
            let base: Int
            let coefficients: [Int]
            /// suffixLow[i]・suffixHigh[i]: 位置 i 以降を自由に選んだときの、値の増え方の最小・最大
            let suffixLow: [Int]
            let suffixHigh: [Int]
            let allowed: [Int]
        }

        let mins: [Int]
        let items: [Item]
        var itemCount: Int { items.count }

        init(kakuValues: ([Int]) -> [KakuKind: Int], strokeValues: [[Int]], conditions: [KakuKind: Set<Int>]) {
            let mins = strokeValues.map { $0.first! }
            let maxs = strokeValues.map { $0.last! }
            self.mins = mins
            let base = kakuValues(mins)
            items = conditions.sorted { $0.key.rawValue < $1.key.rawValue }.map { kind, allowed in
                let coefficients = (0..<mins.count).map { index -> Int in
                    var bumped = mins
                    bumped[index] += 1
                    return kakuValues(bumped)[kind]! - base[kind]!
                }
                var suffixLow = [Int](repeating: 0, count: mins.count + 1)
                var suffixHigh = [Int](repeating: 0, count: mins.count + 1)
                for index in stride(from: mins.count - 1, through: 0, by: -1) {
                    let span = coefficients[index] * (maxs[index] - mins[index])
                    suffixLow[index] = suffixLow[index + 1] + min(0, span)
                    suffixHigh[index] = suffixHigh[index + 1] + max(0, span)
                }
                return Item(
                    base: base[kind]!, coefficients: coefficients,
                    suffixLow: suffixLow, suffixHigh: suffixHigh, allowed: allowed.sorted()
                )
            }
        }

        /// 位置 index の画数を value にしたときの途中の値を next に書き、条件を満たす見込みがあれば true。
        func extend(_ partial: [Int], at index: Int, with value: Int, into next: inout [Int]) -> Bool {
            for (i, item) in items.enumerated() {
                let sum = partial[i] + item.coefficients[index] * (value - mins[index])
                next[i] = sum
                let low = item.base + sum + item.suffixLow[index + 1]
                let high = item.base + sum + item.suffixHigh[index + 1]
                // allowed は小さい順なので、low 以上の最初の値が high 以下かを二分探索で調べる
                var lower = 0, upper = item.allowed.count
                while lower < upper {
                    let middle = (lower + upper) / 2
                    if item.allowed[middle] < low { lower = middle + 1 } else { upper = middle }
                }
                if lower == item.allowed.count || item.allowed[lower] > high { return false }
            }
            return true
        }
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
