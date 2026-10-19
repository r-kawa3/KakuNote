//
//  KakuNoteApp.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/13.
//

import SwiftUI

@main
struct KakuNoteApp: App {
    // お気に入りは「探す」の一覧と「お気に入り」タブで共有する
    @State private var favorites = FavoritesModel.makeDefault()

    init() {
        Wa.applyBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("探す", systemImage: "magnifyingglass") {
                    TopView()
                }
                Tab("調べる", systemImage: "character.book.closed") {
                    LookupRouter.assembleModules()
                }
                Tab("お気に入り", systemImage: "heart") {
                    FavoritesView()
                }
            }
            .environment(favorites)
            .tint(Wa.accent)
            // ダークモードでも、いつも明るい和の色で見せる
            .preferredColorScheme(.light)
        }
    }
}
