//
//  AboutView.swift
//  KakuNote
//

import SwiftUI

/// 「このアプリについて」画面: 漢字データの出典・ライセンス・バージョンを表示する。設定画面から開く。
struct AboutView: View {
    @State private var sources: [Attribution.Source] = []

    var body: some View {
        List {
            Group {
                Section("KakuNote") {
                    HStack {
                        Text("アプリのバージョン")
                        Spacer()
                        Text(Attribution.appVersion)
                            .accessibilityIdentifier("about.app.version")
                    }
                }
                ForEach(sources, id: \.name) { source in
                    Section(source.name) {
                        Text(source.description)
                        HStack {
                            Text("データのバージョン")
                            Spacer()
                            Text(source.version)
                                .accessibilityIdentifier("about.\(source.name).version")
                        }
                        Text(source.notice)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(source.links, id: \.url) { link in
                            Link(link.title, destination: link.url)
                        }
                    }
                }
            }
            .waRow()
        }
        .waScreen()
        .navigationTitle("このアプリについて")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let meta = await Task.detached { (try? KanjiData.bundled.get())?.meta ?? [:] }.value
            sources = Attribution.sources(meta: meta)
        }
    }
}
