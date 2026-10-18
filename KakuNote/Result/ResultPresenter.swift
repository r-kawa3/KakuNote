//
//  ResultPresenter.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/19.
//

import Foundation
import Observation

protocol ResultPresenterInput: AnyObject {
    func viewDidAppear()
    func rowDidAppear(at index: Int)
}

@Observable // SwiftUIのViewが検知できるようにする
class ResultPresenter: ResultPresenterInput, ResultInteractorOutput {

    /// 1 回に作る候補の数
    static let pageSize = 50

    // Viewが観察するプロパティ（@Observableなので自動で検知される）
    var names: [String] = []
    var total: Int?
    var isLoading = false
    var errorMessage: String?
    /// 検索の条件（お気に入りに一緒に保存する）
    let query: SearchQuery
    /// 検索した姓（候補の詳細で使う）。nil なら姓なし
    var sei: String? { query.sei }

    private let interactor: ResultInteractorInput
    private let router: ResultRouterInput

    init(interactor: ResultInteractorInput, router: ResultRouterInput, query: SearchQuery) {
        self.interactor = interactor
        self.router = router
        self.query = query
    }

    // MARK: - View Input
    func viewDidAppear() {
        guard total == nil && !isLoading else { return }
        isLoading = true
        interactor.startSearch()
    }

    /// 一覧の最後の行が表示されたら、続きを作る。
    func rowDidAppear(at index: Int) {
        guard let total, index == names.count - 1, names.count < total else { return }
        interactor.loadPage(offset: names.count, limit: Self.pageSize)
    }

    // MARK: - Interactor Output
    func didStartSearch(total: Int) {
        self.total = total
        isLoading = false
        interactor.loadPage(offset: 0, limit: Self.pageSize)
    }

    func didLoadPage(_ names: [String], offset: Int) {
        guard offset == self.names.count else { return }
        self.names.append(contentsOf: names)
    }

    func didFailToSearch(with error: Error) {
        isLoading = false
        errorMessage = Self.message(for: error)
    }

    // MARK: - 表示用の文言
    static func message(for error: Error) -> String {
        switch error as? SearchError {
        case .unknownStrokes(let chars):
            return "画数がわからない字があります: " + chars.map { "「\($0)」" }.joined(separator: "、")
        case .fixedNotSingleChar(let position):
            return "\(position)文字目に固定する字は 1 文字にしてください"
        case .invalidInput:
            return "入力に使えない文字（途中の空白など）があります"
        case .tooManyResults:
            return "候補が多すぎます。総画数を絞るか、文字を固定してください"
        case .invalidLength, .noCondition, .invalidCondition:
            return "検索の条件が正しくありません"
        case nil:
            return "漢字データを読み込めませんでした"
        }
    }
}
