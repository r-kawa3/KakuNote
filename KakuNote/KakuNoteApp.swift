//
//  KakuNoteApp.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/13.
//

import SwiftUI

@main
struct KakuNoteApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("探す", systemImage: "magnifyingglass") {
                    TopView()
                }
                Tab("調べる", systemImage: "character.book.closed") {
                    LookupRouter.assembleModules()
                }
            }
        }
    }
}
