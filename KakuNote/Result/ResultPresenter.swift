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
}

@Observable // SwiftUIのViewが検知できるようにする
class ResultPresenter: ResultPresenterInput, ResultInteractorOutput {
    
    // Viewが観察するプロパティ（@Observableなので自動で検知される）
    var kanjis: [KanjiModel] = []
    var isLoading = false
    
    private let interactor: ResultInteractorInput
    private let router: ResultRouterInput
    private let strokeCount: Int
    
    init(interactor: ResultInteractorInput, router: ResultRouterInput, strokeCount: Int) {
        self.interactor = interactor
        self.router = router
        self.strokeCount = strokeCount
    }
    
    // MARK: - View Input
    func viewDidAppear() {
        isLoading = true
        interactor.fetchKanjis(withStrokeCount: strokeCount)
    }
    
    // MARK: - Interactor Output
    func didFetchKanjis(_ kanjis: [KanjiModel]) {
        self.kanjis = kanjis
        self.isLoading = false
    }
    
    func didFailToFetch(with error: Error) {
        self.isLoading = false
        print("エラーが発生しました: \(error)")
    }
}
