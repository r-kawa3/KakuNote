//
//  KakuNoteApp.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/13.
//

import SwiftUI

/// 下のタブ。
enum AppTab: Hashable {
    case search
    case lookup
    case favorites
}

extension EnvironmentValues {
    /// 「探す」タブに移る（お気に入りが空のときの「探しにいく」などで使う）
    @Entry var openSearchTab: () -> Void = {}
}

@main
struct KakuNoteApp: App {
    // お気に入りは「探す」の一覧と「お気に入り」タブで共有する
    @State private var favorites = FavoritesModel.makeDefault()
    // 設定（登録した姓など）は全部の画面で共有する
    @State private var settings = AppSettings.makeDefault()
    @State private var selectedTab: AppTab = .search

    init() {
        Wa.applyBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                Tab("探す", systemImage: "magnifyingglass", value: AppTab.search) {
                    TopView()
                }
                Tab("調べる", systemImage: "character.book.closed", value: AppTab.lookup) {
                    LookupRouter.assembleModules()
                }
                Tab("お気に入り", systemImage: "heart", value: AppTab.favorites) {
                    FavoritesView()
                }
            }
            .environment(favorites)
            .environment(settings)
            .environment(\.openSearchTab) { selectedTab = .search }
            .tint(Wa.accent)
            // ダークモードでも、いつも明るい和の色で見せる
            .preferredColorScheme(.light)
        }
    }
}
