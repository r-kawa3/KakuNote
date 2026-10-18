//
//  LookupView.swift
//  KakuNote
//

import SwiftUI

/// 「調べる」画面: 姓名を入れると、各字の画数と五格が出る。
struct LookupView: View {
    @State var presenter: LookupPresenter

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("姓（例: 田中）", text: $presenter.sei)
                        .accessibilityIdentifier("lookup.sei")
                    TextField("名（例: 健太）", text: $presenter.mei)
                        .accessibilityIdentifier("lookup.mei")
                } footer: {
                    Text("姓を空にすると、名の総画数だけを出します。")
                }

                if presenter.isLoading {
                    ProgressView()
                } else if let message = presenter.errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("lookup.error")
                    }
                } else if let result = presenter.result {
                    LookupResultSections(result: result)
                }
            }
            .navigationTitle("調べる")
            .aboutButton()
            .onChange(of: presenter.sei) { presenter.inputDidChange() }
            .onChange(of: presenter.mei) { presenter.inputDidChange() }
            .onAppear { presenter.viewDidAppear() }
        }
    }

}

/// 「調べる」の結果（警告・各字の画数・五格）の表示。候補の詳細でも使う。
struct LookupResultSections: View {
    let result: LookupResult

    var body: some View {
        if !result.warnings.isEmpty {
            Section {
                ForEach(Array(result.warnings.enumerated()), id: \.offset) { _, warning in
                    Label(LookupPresenter.message(for: warning), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }

        if !result.sei.isEmpty {
            Section("姓") { charRows(result.sei) }
        }
        if !result.mei.isEmpty {
            Section("名") { charRows(result.mei) }
        }

        if let kaku = result.kaku {
            Section("五格") {
                kakuRow("天格", kaku.tenkaku, id: "tenkaku")
                kakuRow("人格", kaku.jinkaku, id: "jinkaku")
                kakuRow("地格", kaku.chikaku, id: "chikaku")
                kakuRow("外格", kaku.gaikaku, id: "gaikaku")
                kakuRow("総格", kaku.soukaku, id: "soukaku")
            }
        } else if let total = result.nameOnlyTotal {
            Section {
                kakuRow("総画数", total, id: "total")
            }
        }
    }

    private func charRows(_ chars: [LookupChar]) -> some View {
        ForEach(Array(chars.enumerated()), id: \.offset) { _, item in
            HStack {
                Text(item.char)
                    .font(.title2)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(item.strokes)画")
                    if !item.altStrokes.isEmpty {
                        Text("別の数え方: " + item.altStrokes.map { "\($0)画" }.joined(separator: "・"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func kakuRow(_ title: String, _ value: Int, id: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)画")
                .accessibilityIdentifier("lookup.kaku.\(id)")
        }
    }
}
