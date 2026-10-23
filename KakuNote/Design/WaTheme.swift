//
//  WaTheme.swift
//  KakuNote
//

import SwiftUI
import UIKit

/// 和のデザインの定数（色・文字・寸法）。値はデザインの見本「KakuNote 探す画面（和の雰囲気）」から。
///
/// 生成り色の背景、墨色の文字、藍色のアクセント。朱色は印鑑風の小さな差し色だけに使う。
/// 漢字と見出しは明朝体、本文はゴシック。ダークモードでも、いつもこの明るい色の組で見せる。
enum Wa {

    /// 色の値（0xRRGGBB）。テストで読みやすさ（コントラスト比）を確かめるために、数値でも持つ
    nonisolated enum Hex {
        /// 背景（生成り）
        static let background: UInt32 = 0xF3ECDC
        /// カードや入力欄の面
        static let surface: UInt32 = 0xFBF7EC
        /// タブバー・押せない面
        static let surfaceMuted: UInt32 = 0xEDE5D1
        /// 枠線
        static let border: UInt32 = 0xD8CDB6
        /// カードの中の区切り線
        static let divider: UInt32 = 0xE4DAC4
        /// 文字（墨）
        static let ink: UInt32 = 0x2A2723
        /// 補足の文字
        static let secondaryText: UInt32 = 0x6B6455
        /// 入力欄の例文。入力した文字と見間違えないように、薄くしている
        static let placeholder: UInt32 = 0xB3AA96
        /// 点線の枠（未入力のマス）
        static let dashed: UInt32 = 0xA89C82
        /// アクセント（藍）
        static let accent: UInt32 = 0x1F4E6B
        /// 藍や朱の上の文字
        static let onAccent: UInt32 = 0xFBF7EC
        /// 藍の上の薄い文字
        static let onAccentFaint: UInt32 = 0xE6DFCB
        /// 差し色（朱）
        static let seal: UInt32 = 0xC4452C
    }

    static let background = Color(hex: Hex.background)
    static let surface = Color(hex: Hex.surface)
    static let surfaceMuted = Color(hex: Hex.surfaceMuted)
    static let border = Color(hex: Hex.border)
    static let divider = Color(hex: Hex.divider)
    static let ink = Color(hex: Hex.ink)
    static let secondaryText = Color(hex: Hex.secondaryText)
    static let placeholder = Color(hex: Hex.placeholder)
    static let dashed = Color(hex: Hex.dashed)
    static let accent = Color(hex: Hex.accent)
    static let onAccent = Color(hex: Hex.onAccent)
    static let onAccentFaint = Color(hex: Hex.onAccentFaint)
    static let seal = Color(hex: Hex.seal)

    /// フォント名。どちらも iOS に入っているので、アプリには入れない
    nonisolated enum FontName {
        static let minchoRegular = "HiraMinProN-W3"
        static let minchoBold = "HiraMinProN-W6"
    }

    /// 漢字と見出しの明朝体。文字の大きさの設定に合わせて大きくなる
    static func mincho(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(bold ? FontName.minchoBold : FontName.minchoRegular, size: size, relativeTo: style)
    }

    /// 本文のゴシック（日本語ではヒラギノ角ゴになる iOS の標準の文字）
    static func gothic(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .system(style, weight: weight)
    }

    /// 寸法
    enum Metrics {
        /// 画面の左右の余白
        static let screenPadding: CGFloat = 22
        /// カードの角丸
        static let cornerRadius: CGFloat = 12
        /// 大きなカードの角丸
        static let largeCornerRadius: CGFloat = 16
        /// 名前のマスの大きさと角丸
        static let cellSize: CGFloat = 64
        static let cellCornerRadius: CGFloat = 8
        /// 押せる部分の最小の大きさ
        static let minTapSize: CGFloat = 44
        /// 下の大きなボタンの高さ
        static let primaryButtonHeight: CGFloat = 56
        /// 見出し横の印（朱の四角）の大きさ
        static let sealSize: CGFloat = 28
    }

    /// タブバーを、標準のまま色だけ合わせる。アプリの起動時に 1 回呼ぶ。
    /// ナビゲーションバーは標準のまま（背景が透けて生成り色になる）。見た目を上書きすると、
    /// iOS 26 では大きな見出しが出なくなるので触らない
    static func applyBarAppearance() {
        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.backgroundColor = UIColor(hex: Hex.surfaceMuted)
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = UIColor(hex: Hex.secondaryText)
            item.normal.titleTextAttributes = [.foregroundColor: UIColor(hex: Hex.secondaryText)]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}

// MARK: - 画面に当てる飾り

extension View {
    /// 画面全体を和の背景（生成り色）と墨色の文字にする。Form・List の標準の背景は隠す
    func waScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Wa.background)
            .foregroundStyle(Wa.ink)
    }

    /// Form・List の行を、カードの面の色にする
    func waRow() -> some View {
        listRowBackground(Wa.surface)
    }
}

/// 見出しの横に置く、朱の四角に白抜きの漢字 1 字の印。
struct SealMark: View {
    let character: String

    var body: some View {
        Text(character)
            .font(Wa.mincho(16, bold: true))
            .foregroundStyle(Wa.onAccent)
            .frame(width: Wa.Metrics.sealSize, height: Wa.Metrics.sealSize)
            .background(Wa.seal, in: RoundedRectangle(cornerRadius: 3))
            .accessibilityHidden(true)
    }
}

// MARK: - 色の値から作る

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
