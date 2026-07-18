//
//  ResultView.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/19.
//

import SwiftUI

struct ResultView: View {
    // Presenterを保持（@Stateでライフサイクルを維持）
    @State var presenter: ResultPresenter
    let strokeCount: Int

    var body: some View {
        VStack(spacing: 16) {
            Text("検索結果")
                .font(.title2)
                .bold()
            
            Text("入力された画数: \(strokeCount)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if presenter.isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if presenter.kanjis.isEmpty {
                ContentUnavailableView(
                    "該当する漢字がありません",
                    systemImage: "magnifyingglass",
                    description: Text("\(strokeCount)画の漢字は見つかりませんでした。")
                )
            } else {
                List(presenter.kanjis) { item in
                    HStack {
                        Text(item.kanji)
                            .font(.title)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .padding()
        .navigationTitle("結果")
        .navigationBarTitleDisplayMode(.inline)
        // 画面イベントをPresenterにそのまま丸投げ
        .onAppear {
            presenter.viewDidAppear()
        }
    }
}

