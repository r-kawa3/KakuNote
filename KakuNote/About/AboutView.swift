//
//  AboutView.swift
//  KakuNote
//

import SwiftUI

/// 「このアプリについて」画面: 漢字データの出典・ライセンス・バージョンを表示する。
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sources: [Attribution.Source] = []

    var body: some View {
        NavigationStack {
            List {
                Group {
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                        .accessibilityIdentifier("about.close")
                }
            }
            .task {
                let meta = await Task.detached { (try? KanjiData.bundled.get())?.meta ?? [:] }.value
                sources = Attribution.sources(meta: meta)
            }
        }
    }
}

extension View {
    /// ナビゲーションバーの右上に「このアプリについて」を開くボタンを付ける。
    func aboutButton() -> some View {
        modifier(AboutButtonModifier())
    }
}

private struct AboutButtonModifier: ViewModifier {
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("このアプリについて")
                    .accessibilityIdentifier("about.open")
                }
            }
            .sheet(isPresented: $isPresented) {
                AboutView()
            }
    }
}
