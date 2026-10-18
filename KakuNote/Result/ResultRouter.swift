//
//  ResultRouter.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/19.
//

import SwiftUI

protocol ResultRouterInput: AnyObject {
    // 他の画面へ遷移させる場合はここに定義（例: func navigateToDetail(kanji: String)）
}

extension ResultRouter {
    /// 候補の詳細（五格）の画面
    static func detailView(sei: String?, mei: String) -> some View {
        CandidateDetailView(sei: sei, mei: mei)
    }
}

class ResultRouter: ResultRouterInput {

    // 依存関係を組み立てて、Viewを返すクラスメソッド（ビルダー）
    static func assembleModules(query: SearchQuery) -> some View {
        let interactor = ResultInteractor(query: query)
        let router = ResultRouter()

        let presenter = ResultPresenter(
            interactor: interactor,
            router: router,
            query: query
        )

        interactor.output = presenter

        // PresenterをViewに注入して返す
        return ResultView(presenter: presenter)
    }
}
