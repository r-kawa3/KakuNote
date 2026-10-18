//
//  LookupRouter.swift
//  KakuNote
//

import SwiftUI

protocol LookupRouterInput: AnyObject {
}

class LookupRouter: LookupRouterInput {

    // 依存関係を組み立てて、View を返す
    static func assembleModules() -> some View {
        let interactor = LookupInteractor()
        let router = LookupRouter()
        let presenter = LookupPresenter(interactor: interactor, router: router)
        interactor.output = presenter
        return LookupView(presenter: presenter)
    }
}
