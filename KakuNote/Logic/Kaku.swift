//
//  Kaku.swift
//  KakuNote
//

import Foundation

/// 五格（仕様書 kaku.md）。
nonisolated struct Kaku: Equatable, Sendable {
    let tenkaku: Int
    let jinkaku: Int
    let chikaku: Int
    let soukaku: Int
    let gaikaku: Int
}

/// 流派。五格の計算方法を入れ替えられるようにする（最初の版は新字体式だけ）。
///
/// 約束: 姓と名の文字数を決めたとき、各格は名の各位置の画数の 1 次式であること
/// （検索の打ち切りが、この性質を使って格の取りうる範囲を求める）。
nonisolated protocol KakuSchool: Sendable {
    /// 姓と名の各字の画数から五格を求める。sei・mei はどちらも 1 文字以上。
    func kaku(sei: [Int], mei: [Int]) -> Kaku
    /// 姓なしのときの総画数（＝ 地格）。
    func nameOnlyTotal(mei: [Int]) -> Int
}

/// 新字体式: 霊数なし。一字姓・一字名のときは、外格にその字の画数を足す。
nonisolated struct ShinjitaiSchool: KakuSchool {

    func kaku(sei: [Int], mei: [Int]) -> Kaku {
        precondition(!sei.isEmpty && !mei.isEmpty, "姓と名の両方が必要です")
        let tenkaku = sei.reduce(0, +)
        let chikaku = mei.reduce(0, +)
        let jinkaku = sei[sei.count - 1] + mei[0]
        let soukaku = tenkaku + chikaku
        var gaikaku = soukaku - jinkaku
        if sei.count == 1 { gaikaku += sei[0] }
        if mei.count == 1 { gaikaku += mei[0] }
        return Kaku(tenkaku: tenkaku, jinkaku: jinkaku, chikaku: chikaku, soukaku: soukaku, gaikaku: gaikaku)
    }

    func nameOnlyTotal(mei: [Int]) -> Int {
        mei.reduce(0, +)
    }
}

/// 名についての警告（仕様書 strokes.md「名前に使える字」）。
nonisolated enum NameWarning: Equatable, Sendable {
    /// 名前に使えない字（position は 1 から数える）
    case notNameChar(char: String, position: Int)
    /// 名の 1 文字目に置けない字
    case notInitial(char: String)
}

extension KanjiData {

    /// 名の警告。画数がわからない字は、ここでは警告しない（別のエラーとして扱う）。
    nonisolated func meiWarnings(_ mei: [String]) -> [NameWarning] {
        var warnings: [NameWarning] = []
        for (index, char) in mei.enumerated() {
            guard let info = info(char) else { continue }
            if !info.nameOK {
                warnings.append(.notNameChar(char: char, position: index + 1))
            } else if index == 0 && !info.initialOK {
                warnings.append(.notInitial(char: char))
            }
        }
        return warnings
    }
}
