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

    var body: some View {
        Group {
            if presenter.isLoading {
                ProgressView()
            } else if let message = presenter.errorMessage {
                ContentUnavailableView(
                    "検索できませんでした",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            } else if presenter.total == 0 {
                ContentUnavailableView(
                    "該当する名前がありません",
                    systemImage: "magnifyingglass",
                    description: Text("条件を変えてみてください。")
                )
            } else if let total = presenter.total {
                List {
                    Group {
                        Section {
                            ForEach(Array(presenter.names.enumerated()), id: \.offset) { index, name in
                                HStack {
                                    NavigationLink {
                                        ResultRouter.detailView(sei: presenter.sei, mei: name)
                                    } label: {
                                        Text(name)
                                            .font(Wa.mincho(26, bold: true, relativeTo: .title2))
                                            .padding(.vertical, 4)
                                    }
                                    FavoriteButton(sei: presenter.sei, mei: name, query: presenter.query)
                                }
                                .onAppear { presenter.rowDidAppear(at: index) }
                            }
                        } header: {
                            Text("\(total)件")
                                .accessibilityIdentifier("result.total")
                        }
                    }
                    .waRow()
                }
                .listStyle(.plain)
                .accessibilityIdentifier("result.list")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .waScreen()
        .navigationTitle("検索結果")
        .navigationBarTitleDisplayMode(.inline)
        // 画面イベントをPresenterにそのまま丸投げ
        .onAppear {
            presenter.viewDidAppear()
        }
    }
}
