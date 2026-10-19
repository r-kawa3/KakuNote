//
//  ResultInteractor.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/19.
//

import Foundation

protocol ResultInteractorInput: AnyObject {
    func startSearch()
    func loadPage(offset: Int, limit: Int)
}

protocol ResultInteractorOutput: AnyObject {
    func didStartSearch(total: Int)
    func didLoadPage(_ rows: [ResultRow], offset: Int)
    func didFailToSearch(with error: Error)
}

class ResultInteractor: ResultInteractorInput {
    weak var output: ResultInteractorOutput?

    private let query: SearchQuery
    private let school: any KakuSchool
    private var search: NameSearch?

    init(query: SearchQuery, school: any KakuSchool = ShinjitaiSchool()) {
        self.query = query
        self.school = school
    }

    func startSearch() {
        let query = query
        let school = school
        // DB の読み込みと内訳の列挙はバックグラウンドで行う（候補そのものはまだ作らない）
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                try NameSearch(query: query, data: KanjiData.bundled.get(), school: school)
            }
            DispatchQueue.main.async {
                switch result {
                case .success(let search):
                    self?.search = search
                    self?.output?.didStartSearch(total: search.total)
                case .failure(let error):
                    self?.output?.didFailToSearch(with: error)
                }
            }
        }
    }

    func loadPage(offset: Int, limit: Int) {
        // 1 ページ分の候補を作るのは軽いので、その場で行う
        guard let search else { return }
        let rows = search.candidates(offset: offset, limit: limit).map {
            ResultRow.make(candidate: $0, seiStrokes: search.seiStrokes, conditions: query.conditions, school: school)
        }
        output?.didLoadPage(rows, offset: offset)
    }
}
