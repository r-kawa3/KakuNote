//
//  TextPreprocessor.swift
//  KakuNote
//

import Foundation

/// 入力文字列が前処理の規則に合わないときのエラー。
nonisolated enum InputError: Error, Equatable {
    case empty
    case spaceInside
    case danglingSoundMark
    case invalidSoundMark(base: String)
}

/// 姓・名の入力文字列を、画数を数える前に 1 文字ずつに分ける（仕様書 strokes.md「入力文字列の前処理」）。
///
/// Unicode の正規化（NFC・NFKC）は全体にはかけない。互換漢字（例: 﨑）が統合漢字（崎）に
/// 置き換わり、画数や「名前に使えるか」が変わってしまうため。
/// 1 文字は Unicode のコードポイント 1 つ（Swift の Character ではない）。
nonisolated enum TextPreprocessor {

    private static let spaces: Set<Unicode.Scalar> = [" ", "\u{3000}", "\t"]
    private static let combiningSoundMarks: Set<Unicode.Scalar> = ["\u{3099}", "\u{309A}"]

    static func characters(from text: String) throws -> [String] {
        // 前後の空白を取り除く
        var scalars = Array(text.unicodeScalars)
        while let first = scalars.first, spaces.contains(first) { scalars.removeFirst() }
        while let last = scalars.last, spaces.contains(last) { scalars.removeLast() }

        // 1. 半角カタカナを全角にする（その部分だけ NFKC。半角の濁点は結合用の濁点になる）
        var widened: [Unicode.Scalar] = []
        var index = 0
        while index < scalars.count {
            guard isHalfwidthKatakana(scalars[index]) else {
                widened.append(scalars[index])
                index += 1
                continue
            }
            var end = index
            while end < scalars.count, isHalfwidthKatakana(scalars[end]) { end += 1 }
            var segment = String.UnicodeScalarView()
            segment.append(contentsOf: scalars[index..<end])
            widened.append(contentsOf: String(segment).precomposedStringWithCompatibilityMapping.unicodeScalars)
            index = end
        }

        // 2. 結合用の濁点・半濁点を直前の字と合成する
        var result: [String] = []
        for scalar in widened {
            if combiningSoundMarks.contains(scalar) {
                guard let base = result.popLast() else { throw InputError.danglingSoundMark }
                // NFC はこの 2 つのコードポイントだけにかける。合成できるのは、かなに濁点・半濁点を付けたときだけ
                let composed = (base + String(scalar)).precomposedStringWithCanonicalMapping
                guard composed.unicodeScalars.count == 1,
                      let value = composed.unicodeScalars.first?.value,
                      (0x3041...0x30FF).contains(value)
                else { throw InputError.invalidSoundMark(base: base) }
                result.append(composed)
            } else {
                result.append(String(scalar))
            }
        }

        // 3. 途中の空白はエラー
        if result.contains(where: { $0.unicodeScalars.count == 1 && spaces.contains($0.unicodeScalars.first!) }) {
            throw InputError.spaceInside
        }
        if result.isEmpty { throw InputError.empty }
        return result
    }

    private static func isHalfwidthKatakana(_ scalar: Unicode.Scalar) -> Bool {
        (0xFF61...0xFF9F).contains(scalar.value)
    }
}

extension String {
    /// コードポイントの並び。String の == と違い、正準等価な字を別のものとして区別できる
    nonisolated var codePoints: [UInt32] { unicodeScalars.map(\.value) }
}
