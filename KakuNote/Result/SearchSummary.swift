//
//  SearchSummary.swift
//  KakuNote
//

import Foundation

/// 候補の一覧の上に並べる、検索の条件のチップ。
nonisolated enum SearchSummary {

    struct Chip: Equatable, Sendable {
        let text: String
        /// 格の条件（藍で塗る）なら true、それ以外（枠だけ）は false
        let isPrimary: Bool
    }

    static func chips(for query: SearchQuery) -> [Chip] {
        var chips: [Chip] = []
        let kinds: [(KakuKind, String)] = query.sei == nil
            ? [(.chikaku, "総画数")]
            : [(.jinkaku, "人格"), (.chikaku, "地格"), (.soukaku, "総格"), (.gaikaku, "外格")]
        for (kind, title) in kinds {
            if let values = query.conditions[kind], !values.isEmpty {
                chips.append(Chip(text: "\(title) " + values.sorted().map(String.init).joined(separator: "・") + "画", isPrimary: true))
            }
        }
        if let sei = query.sei {
            chips.append(Chip(text: "姓「\(sei)」", isPrimary: false))
        }
        chips.append(Chip(text: "\(query.positions.count)文字", isPrimary: false))
        for (index, position) in query.positions.enumerated() {
            let label = "\(index + 1)文字目"
            switch position {
            case .fixed(let char):
                chips.append(Chip(text: "\(label)「\(char)」固定", isPrimary: false))
            case .strokes(let strokes, let script):
                let scriptText = script == .kanji ? "" : "・" + scriptName(script)
                chips.append(Chip(text: "\(label) \(strokes)画\(scriptText)", isPrimary: false))
            case .free(let script):
                // 自由・漢字は初期値なので、チップにしない
                if script != .kanji {
                    chips.append(Chip(text: "\(label) \(scriptName(script))", isPrimary: false))
                }
            }
        }
        if !query.use.isEmpty {
            chips.append(Chip(text: "使いたい字: " + query.use.joined(separator: "・"), isPrimary: false))
        }
        if !query.avoid.isEmpty {
            chips.append(Chip(text: "避けたい字 \(query.avoid.count)字を除外", isPrimary: false))
        }
        return chips
    }

    static func scriptName(_ script: ScriptFilter) -> String {
        switch script {
        case .kanji: return "漢字"
        case .hiragana: return "ひらがな"
        case .katakana: return "カタカナ"
        case .any: return "どれでも"
        }
    }
}

/// 候補の一覧の 1 行。
nonisolated struct ResultRow: Hashable, Sendable {
    let name: String
    /// 名の各字の画数の内訳（例: 「12 + 8 = 20画」、1 文字なら「12画」）
    let breakdown: String
    /// 姓ありの検索で、条件にした格の値（例: 「人格 15・総格 24」）。姓なしなら nil
    let kakuNote: String?

    static func make(
        candidate: NameSearch.Candidate, seiStrokes: [Int]?, conditions: [KakuKind: Set<Int>], school: any KakuSchool
    ) -> ResultRow {
        let total = candidate.strokes.reduce(0, +)
        let breakdown = candidate.strokes.count == 1
            ? "\(total)画"
            : candidate.strokes.map(String.init).joined(separator: " + ") + " = \(total)画"

        var kakuNote: String?
        if let seiStrokes {
            let kaku = school.kaku(sei: seiStrokes, mei: candidate.strokes)
            let kinds: [(KakuKind, String)] = [(.jinkaku, "人格"), (.chikaku, "地格"), (.soukaku, "総格"), (.gaikaku, "外格")]
            kakuNote = kinds
                .filter { conditions[$0.0] != nil }
                .map { "\($0.1) \(kaku.value(of: $0.0))" }
                .joined(separator: "・")
        }
        return ResultRow(name: candidate.name, breakdown: breakdown, kakuNote: kakuNote)
    }
}
