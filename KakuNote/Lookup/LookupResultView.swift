//
//  LookupResultView.swift
//  KakuNote
//

import SwiftUI

/// 「調べる」の結果: 警告 → 文字ごとの画数のマス → 総格（名だけなら総画数）の大きなカード →
/// 天格・人格・地格・外格の 2×2 のカード → 流派の注記。候補の詳細でも使う。
struct LookupResultView: View {
    let result: LookupResult

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !result.warnings.isEmpty {
                warnings
            }
            charCells
            if let kaku = result.kaku {
                BigKakuCard(title: "総格", value: kaku.soukaku, note: "姓名すべての合計", identifier: "lookup.kaku.soukaku")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    KakuCard(title: "天格", note: "姓の合計", value: kaku.tenkaku, identifier: "lookup.kaku.tenkaku")
                    KakuCard(title: "人格", note: "姓の末尾＋名の先頭", value: kaku.jinkaku, identifier: "lookup.kaku.jinkaku")
                    KakuCard(title: "地格", note: "名の合計", value: kaku.chikaku, identifier: "lookup.kaku.chikaku")
                    KakuCard(title: "外格", note: gaikakuNote, value: kaku.gaikaku, identifier: "lookup.kaku.gaikaku")
                }
            } else if let total = result.nameOnlyTotal {
                BigKakuCard(title: "総画数", value: total, note: "名の合計", identifier: "lookup.kaku.total")
            }
            Text("画数の数え方は、流派によって異なる場合があります。")
                .font(.caption2)
                .foregroundStyle(Wa.secondaryText)
                .padding(.horizontal, 4)
        }
    }

    /// 一字姓・一字名のときは、外格にその字の画数を足す（新字体式）
    private var gaikakuNote: String {
        switch (result.sei.count == 1, result.mei.count == 1) {
        case (true, true): return "総格−人格＋姓と名の字"
        case (true, false): return "総格−人格＋姓の字"
        case (false, true): return "総格−人格＋名の字"
        case (false, false): return "総格−人格"
        }
    }

    private var warnings: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(result.warnings.enumerated()), id: \.offset) { _, warning in
                Label(LookupPresenter.message(for: warning), systemImage: "exclamationmark.triangle.fill")
                    .font(Wa.gothic(.subheadline))
                    .foregroundStyle(Wa.seal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .waCard()
    }

    private var charCells: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("文字ごとの画数").waSectionLabel()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Array(result.sei.enumerated()), id: \.offset) { _, item in
                        CharCell(item: item, isMei: false)
                    }
                    if !result.sei.isEmpty && !result.mei.isEmpty {
                        Rectangle()
                            .fill(Wa.dashed.opacity(0.7))
                            .frame(width: 1, height: Wa.Metrics.cellSize)
                            .padding(.horizontal, 6)
                            .accessibilityHidden(true)
                    }
                    ForEach(Array(result.mei.enumerated()), id: \.offset) { _, item in
                        CharCell(item: item, isMei: true)
                    }
                }
                .padding(2)
            }
        }
    }
}

/// 1 文字のマスと、その下の画数。名の字は藍の枠で目立たせる。
private struct CharCell: View {
    let item: LookupChar
    let isMei: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(item.char)
                .font(Wa.mincho(34, bold: true))
                .foregroundStyle(Wa.ink)
                .frame(width: Wa.Metrics.cellSize, height: Wa.Metrics.cellSize)
                .background(Wa.surface, in: RoundedRectangle(cornerRadius: Wa.Metrics.cellCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Wa.Metrics.cellCornerRadius)
                        .strokeBorder(isMei ? Wa.accent : Wa.border, lineWidth: isMei ? 2 : 1)
                )
            Text("\(item.strokes)画")
                .font(Wa.gothic(.footnote, weight: .bold))
                .foregroundStyle(Wa.accent)
            if !item.altStrokes.isEmpty {
                Text("別 " + item.altStrokes.map { "\($0)画" }.joined(separator: "・"))
                    .font(.caption2)
                    .foregroundStyle(Wa.secondaryText)
            }
        }
        .frame(minWidth: Wa.Metrics.cellSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = "\(isMei ? "名" : "姓")の字 \(item.char)、\(item.strokes)画"
        if !item.altStrokes.isEmpty {
            text += "、別の数え方 " + item.altStrokes.map { "\($0)画" }.joined(separator: "・")
        }
        return text
    }
}

/// 藍の大きなカード（総格、名だけなら総画数）。
private struct BigKakuCard: View {
    let title: String
    let value: Int
    let note: String
    let identifier: String

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Wa.gothic(.footnote, weight: .bold))
                    .tracking(2)
                (Text("\(value)").font(Wa.mincho(56, bold: true, relativeTo: .largeTitle))
                    + Text("画").font(Wa.mincho(22, bold: true)).foregroundStyle(Wa.onAccentFaint))
                    .accessibilityIdentifier(identifier)
            }
            Spacer()
            Text(note)
                .font(.caption)
                .foregroundStyle(Wa.onAccentFaint)
                .padding(.bottom, 8)
        }
        .foregroundStyle(Wa.onAccent)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(Wa.accent, in: RoundedRectangle(cornerRadius: Wa.Metrics.largeCornerRadius))
    }
}

/// 2×2 に並べる格のカード。
private struct KakuCard: View {
    let title: String
    let note: String
    let value: Int
    let identifier: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Wa.gothic(.subheadline, weight: .bold))
                    .tracking(1)
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(Wa.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            (Text("\(value)").font(Wa.mincho(28, bold: true, relativeTo: .title2))
                + Text("画").font(Wa.mincho(14)).foregroundStyle(Wa.secondaryText))
                .accessibilityIdentifier(identifier)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .waCard()
    }
}
