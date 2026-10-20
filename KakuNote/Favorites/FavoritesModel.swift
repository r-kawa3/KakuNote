//
//  FavoritesModel.swift
//  KakuNote
//

import Foundation
import Observation

/// 画面が共有するお気に入りの状態。「探す」の一覧と「お気に入り」タブの両方から使う。
@Observable
final class FavoritesModel {

    private(set) var items: [Favorite] = []
    var errorMessage: String?

    private let store: FavoriteStore?
    /// 保存済みの姓・名。String の Set は正準等価な字を同じとみなすので、コードポイントの並びで持つ
    private var keys: Set<Key> = []

    private struct Key: Hashable {
        let sei: [UInt32]
        let mei: [UInt32]

        init(sei: String?, mei: String) {
            self.sei = (sei ?? "").unicodeScalars.map(\.value)
            self.mei = mei.unicodeScalars.map(\.value)
        }
    }

    init(store: FavoriteStore?) {
        self.store = store
        if store == nil {
            errorMessage = "お気に入りを保存するファイルを開けませんでした"
        }
        reload()
    }

    /// アプリが使うお気に入り。UI テストでは、起動時の環境変数で保存先を切り替える。
    static func makeDefault() -> FavoritesModel {
        let environment = ProcessInfo.processInfo.environment
        let url: URL?
        if let name = environment["KAKUNOTE_FAVORITES_FILE"] {
            url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            if environment["KAKUNOTE_FAVORITES_RESET"] == "1", let url {
                try? FileManager.default.removeItem(at: url)
            }
        } else {
            url = try? FavoriteStore.defaultURL()
        }
        return FavoritesModel(store: url.flatMap { try? FavoriteStore(url: $0) })
    }

    func isFavorite(sei: String?, mei: String) -> Bool {
        keys.contains(Key(sei: sei, mei: mei))
    }

    /// 保存済みなら削除し、まだなら保存する。
    func toggle(sei: String?, mei: String, query: SearchQuery?) {
        guard let store else { return }
        do {
            if isFavorite(sei: sei, mei: mei) {
                try store.remove(sei: sei, mei: mei)
            } else {
                try store.add(sei: sei, mei: mei, query: query)
            }
        } catch {
            errorMessage = "お気に入りを保存できませんでした"
        }
        reload()
    }

    func remove(_ favorite: Favorite) {
        guard let store else { return }
        do {
            try store.remove(sei: favorite.sei, mei: favorite.mei)
        } catch {
            errorMessage = "お気に入りを削除できませんでした"
        }
        reload()
    }

    private func reload() {
        guard let store else { return }
        do {
            items = try store.all()
        } catch {
            errorMessage = "お気に入りを読み込めませんでした"
        }
        keys = Set(items.map { Key(sei: $0.sei, mei: $0.mei) })
    }
}

/// 探したときの条件を、お気に入りの一覧に出す短い文にする。
enum ConditionSummary {

    static func text(for query: SearchQuery) -> String {
        var parts = ["\(query.positions.count)文字"]
        if let reading = query.reading?.trimmingCharacters(in: .whitespacesAndNewlines), !reading.isEmpty {
            parts.append("読み「\(reading)」")
        }
        for (index, position) in query.positions.enumerated() {
            if case .fixed(let char) = position {
                parts.append("\(index + 1)文字目「\(char)」")
            }
        }
        let kinds: [(KakuKind, String)] = query.sei == nil
            ? [(.chikaku, "総画数")]
            : [(.jinkaku, "人格"), (.chikaku, "地格"), (.soukaku, "総格"), (.gaikaku, "外格")]
        for (kind, title) in kinds {
            if let values = query.conditions[kind], !values.isEmpty {
                parts.append("\(title) " + values.sorted().map(String.init).joined(separator: ", "))
            }
        }
        return parts.joined(separator: "・")
    }
}
