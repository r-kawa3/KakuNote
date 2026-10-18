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

class ResultRouter: ResultRouterInput {

    // 依存関係を組み立てて、Viewを返すクラスメソッド（ビルダー）
    static func assembleModules(query: SearchQuery) -> some View {
        let interactor = ResultInteractor(query: query)
        let router = ResultRouter()

        let presenter = ResultPresenter(
            interactor: interactor,
            router: router
        )

        interactor.output = presenter

        // PresenterをViewに注入して返す
        return ResultView(presenter: presenter)
    }
}
