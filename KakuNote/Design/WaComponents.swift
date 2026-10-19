//
//  WaComponents.swift
//  KakuNote
//

import SwiftUI

/// 画面の上部の見出し: 朱の印 + 明朝体の題名、右に「設定」の丸いボタン。
/// この見出しを使う画面では、ナビゲーションバーを隠す。
struct WaHeader: View {
    /// 印の漢字 1 字（探す「名」、調べる「画」、お気に入り「好」）
    let seal: String
    let title: String

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                SealMark(character: seal)
                Text(title)
                    .font(Wa.mincho(26, bold: true, relativeTo: .title))
                    .tracking(1.5)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            SettingsCircleButton()
        }
        .frame(minHeight: Wa.Metrics.minTapSize)
    }
}

/// 設定画面を開く丸いボタン（歯車）。
struct SettingsCircleButton: View {
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Wa.ink)
                .frame(width: Wa.Metrics.minTapSize, height: Wa.Metrics.minTapSize)
                .background(Wa.surface, in: Circle())
                .overlay(Circle().stroke(Wa.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("設定")
        .accessibilityIdentifier("settings.open")
        .sheet(isPresented: $isPresented) {
            SettingsView()
        }
    }
}

/// チェックボックス。押すたびにオン・オフが替わる。色は置く面に合わせて渡す。
struct WaCheckbox: View {
    let title: String
    @Binding var isOn: Bool
    var color: Color = Wa.ink
    let identifier: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 17))
                Text(title)
                    .font(Wa.gothic(.footnote, weight: .bold))
            }
            .foregroundStyle(color)
            .frame(minHeight: Wa.Metrics.minTapSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "オン" : "オフ")
        .accessibilityAddTraits(.isToggle)
        .accessibilityIdentifier(identifier)
    }
}

extension View {
    /// カードの面: 面の色、細い枠線、角丸。
    func waCard(cornerRadius: CGFloat = Wa.Metrics.cornerRadius) -> some View {
        self
            .background(Wa.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Wa.border, lineWidth: 1))
    }

    /// 小さな見出し（「文字数」「名前の形」など）の文字。
    func waSectionLabel() -> some View {
        self
            .font(Wa.gothic(.footnote, weight: .bold))
            .tracking(1)
            .foregroundStyle(Wa.ink)
    }
}
