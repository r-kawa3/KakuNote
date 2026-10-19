//
//  CandidateDetailView.swift
//  KakuNote
//

import SwiftUI

/// 候補の詳細: 「調べる」と同じ表示（各字の画数・警告・五格）を出す。
struct CandidateDetailView: View {
    let sei: String?
    let mei: String

    var body: some View {
        Form {
            Group {
                switch lookup() {
                case .success(let result):
                    LookupResultSections(result: result)
                case .failure(let error):
                    Text(LookupPresenter.message(for: error))
                        .foregroundStyle(.red)
                }
            }
            .waRow()
        }
        .waScreen()
        .navigationTitle(((sei ?? "") + " " + mei).trimmingCharacters(in: .whitespaces))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lookup() -> Result<LookupResult, Error> {
        // 一覧が出ている時点で同梱 DB は読み込み済みなので、その場で計算する
        Result {
            try NameLookup.lookup(sei: sei ?? "", mei: mei, data: KanjiData.bundled.get(), school: ShinjitaiSchool())
        }
    }
}
