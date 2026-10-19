//
//  WaThemeTests.swift
//  KakuNoteTests
//

import XCTest
import UIKit
@testable import KakuNote

/// 和のデザインの定数（色・文字）を確かめる。
final class WaThemeTests: XCTestCase {

    /// 文字と背景の組み合わせが読める明るさの差（WCAG のコントラスト比）を持つ。
    func testTextContrast() {
        let pairs: [(String, UInt32, UInt32, Double)] = [
            ("墨 / 生成り", Wa.Hex.ink, Wa.Hex.background, 4.5),
            ("墨 / カードの面", Wa.Hex.ink, Wa.Hex.surface, 4.5),
            ("補足 / 生成り", Wa.Hex.secondaryText, Wa.Hex.background, 4.5),
            ("補足 / カードの面", Wa.Hex.secondaryText, Wa.Hex.surface, 4.5),
            ("藍の上の文字 / 藍", Wa.Hex.onAccent, Wa.Hex.accent, 4.5),
            ("藍 / 生成り", Wa.Hex.accent, Wa.Hex.background, 4.5),
            ("朱の上の文字 / 朱", Wa.Hex.onAccent, Wa.Hex.seal, 4.5),
            // 入力欄の例文は大きめの文字なので 3:1 でよい
            ("例文 / カードの面", Wa.Hex.placeholder, Wa.Hex.surface, 3.0),
        ]
        for (name, text, background, minimum) in pairs {
            XCTAssertGreaterThanOrEqual(Self.contrast(text, background), minimum, name)
        }
    }

    /// 明朝体（ヒラギノ明朝）は iOS に入っているので、アプリに入れなくても使える。
    func testMinchoFontsAreAvailable() {
        for name in [Wa.FontName.minchoRegular, Wa.FontName.minchoBold] {
            XCTAssertNotNil(UIFont(name: name, size: 17), name)
        }
    }

    // MARK: - コントラスト比

    private static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static func luminance(_ hex: UInt32) -> Double {
        func channel(_ value: UInt32) -> Double {
            let c = Double(value) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF) + 0.7152 * channel((hex >> 8) & 0xFF) + 0.0722 * channel(hex & 0xFF)
    }
}
