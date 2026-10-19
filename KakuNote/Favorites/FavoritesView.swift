//
//  FavoritesView.swift
//  KakuNote
//

import SwiftUI

/// 「お気に入り」タブ: 保存した名前と五格を並べて見比べる。
struct FavoritesView: View {
    @Environment(FavoritesModel.self) private var favorites

    var body: some View {
        NavigationStack {
            Group {
                if favorites.items.isEmpty {
                    ContentUnavailableView(
                        "お気に入りはまだありません",
                        systemImage: "heart",
                        description: Text(favorites.errorMessage ?? "「探す」の一覧で、ハートのボタンを押すと保存できます。")
                    )
                } else {
                    List {
                        Group {
                            ForEach(favorites.items) { favorite in
                                NavigationLink {
                                    CandidateDetailView(sei: favorite.sei, mei: favorite.mei)
                                } label: {
                                    FavoriteRow(favorite: favorite)
                                }
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    favorites.remove(favorites.items[index])
                                }
                            }
                        }
                        .waRow()
                    }
                    .accessibilityIdentifier("favorites.list")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .waScreen()
            .navigationTitle("お気に入り")
            .aboutButton()
        }
    }
}

/// お気に入りの 1 行: 名前・五格・探したときの条件。
private struct FavoriteRow: View {
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
        VStack(alignment: .leading, spacing: 6) {
            Text(fullName)
                .font(Wa.mincho(26, bold: true, relativeTo: .title2))
            HStack(spacing: 12) {
                ForEach(values, id: \.0) { title, value in
                    VStack {
                        Text(title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(value)")
                            .font(.headline)
                            .monospacedDigit()
                    }
                    .frame(minWidth: 36)
                }
            }
            if let query = favorite.query {
                Text(ConditionSummary.text(for: query))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
