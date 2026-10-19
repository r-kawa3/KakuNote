//
//  FavoritesView.swift
//  KakuNote
//

import SwiftUI

/// 「お気に入り」タブ: 保存した名前と五格を並べて見比べる。
struct FavoritesView: View {
    @Environment(FavoritesModel.self) private var favorites
    /// タップしたお気に入り（詳細の画面を出す）
    @State private var selected: Favorite?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                WaHeader(seal: "好", title: "お気に入り")
                    .padding(.horizontal, Wa.Metrics.screenPadding)
                    .padding(.top, 8)
                if favorites.items.isEmpty {
                    EmptyFavorites(errorMessage: favorites.errorMessage)
                } else {
                    list
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .waScreen()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selected) { favorite in
                CandidateDetailView(sei: favorite.sei, mei: favorite.mei)
            }
        }
    }

    private var list: some View {
        List {
            Text("\(favorites.items.count)件")
                .font(Wa.gothic(.footnote, weight: .bold))
                .foregroundStyle(Wa.secondaryText)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: Wa.Metrics.screenPadding, bottom: 0, trailing: Wa.Metrics.screenPadding))
            ForEach(favorites.items) { favorite in
                Button {
                    selected = favorite
                } label: {
                    FavoriteCard(favorite: favorite)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: Wa.Metrics.screenPadding, bottom: 5, trailing: Wa.Metrics.screenPadding))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        favorites.remove(favorite)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("favorites.list")
    }
}

/// お気に入りがないときの画面: 点線の枠のハート、説明、「探しにいく」。
private struct EmptyFavorites: View {
    let errorMessage: String?
    @Environment(\.openSearchTab) private var openSearchTab

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "heart")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Wa.dashed)
                .frame(width: 120, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: Wa.Metrics.cornerRadius)
                        .strokeBorder(Wa.dashed, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                )
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("お気に入りはまだありません")
                    .font(Wa.mincho(22, bold: true, relativeTo: .title3))
                    .tracking(1)
                Text(errorMessage ?? "「探す」の候補の一覧で、\nハートを押すと保存できます。")
                    .font(Wa.gothic(.footnote))
                    .foregroundStyle(Wa.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            Button {
                openSearchTab()
            } label: {
                Text("探しにいく")
                    .font(Wa.gothic(.subheadline, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Wa.accent)
                    .padding(.horizontal, 28)
                    .frame(minHeight: 48)
                    .overlay(RoundedRectangle(cornerRadius: Wa.Metrics.cornerRadius).stroke(Wa.accent, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("favorites.goSearch")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}

/// お気に入りの 1 枚: 明朝の大きな名前、五格（同じ並び・同じ幅）、探したときの条件。
private struct FavoriteCard: View {
    let favorite: Favorite

    private var fullName: String {
        [favorite.sei, favorite.mei].compactMap { $0 }.joined(separator: " ")
    }

    private var result: LookupResult? {
        try? NameLookup.lookup(
            sei: favorite.sei ?? "", mei: favorite.mei, data: KanjiData.bundled.get(), school: ShinjitaiSchool()
        )
    }

    /// 見比べやすいよう、五格は同じ並び・同じ幅で出す
    private var values: [(String, Int)] {
        guard let result else { return [] }
        if let kaku = result.kaku {
            return [("天格", kaku.tenkaku), ("人格", kaku.jinkaku), ("地格", kaku.chikaku),
                    ("外格", kaku.gaikaku), ("総格", kaku.soukaku)]
        }
        return result.nameOnlyTotal.map { [("総画数", $0)] } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(fullName)
                    .font(Wa.mincho(28, bold: true, relativeTo: .title))
                    .foregroundStyle(Wa.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Wa.dashed)
            }
            HStack(spacing: 0) {
                ForEach(values, id: \.0) { title, value in
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.caption2)
                            .foregroundStyle(Wa.secondaryText)
                        Text("\(value)")
                            .font(Wa.mincho(20, bold: true, relativeTo: .headline))
                            .monospacedDigit()
                            .foregroundStyle(title == "総格" || title == "総画数" ? Wa.accent : Wa.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
            }
            .background(Wa.background, in: RoundedRectangle(cornerRadius: Wa.Metrics.cellCornerRadius))
            if let query = favorite.query {
                Text(ConditionSummary.text(for: query))
                    .font(.caption)
                    .foregroundStyle(Wa.secondaryText)
            }
        }
        .padding(16)
        .waCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [fullName]
        parts += values.map { "\($0.0) \($0.1)画" }
        if let query = favorite.query {
            parts.append(ConditionSummary.text(for: query))
        }
        return parts.joined(separator: "、")
    }
}

/// 候補をお気に入りに保存・削除するハートのボタン。
struct FavoriteButton: View {
    @Environment(FavoritesModel.self) private var favorites
    let sei: String?
    let mei: String
    let query: SearchQuery?

    var body: some View {
        let saved = favorites.isFavorite(sei: sei, mei: mei)
        Button {
            favorites.toggle(sei: sei, mei: mei, query: query)
        } label: {
            Image(systemName: saved ? "heart.fill" : "heart")
                .font(.system(size: 22))
                .foregroundStyle(saved ? Wa.seal : Wa.secondaryText)
                .frame(width: Wa.Metrics.minTapSize, height: Wa.Metrics.minTapSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(saved ? "お気に入りから外す" : "お気に入りに追加")
        .accessibilityValue(saved ? "保存済み" : "")
        .accessibilityIdentifier("favorite.toggle.\(mei)")
    }
}
