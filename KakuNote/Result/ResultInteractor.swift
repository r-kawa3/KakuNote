//
//  ResultInteractor.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/19.
//

import Foundation

protocol ResultInteractorInput: AnyObject {
    func fetchKanjis(withStrokeCount strokeCount: Int)
}

protocol ResultInteractorOutput: AnyObject {
    func didFetchKanjis(_ kanjis: [KanjiModel])
    func didFailToFetch(with error: Error)
}

class ResultInteractor: ResultInteractorInput {
    weak var output: ResultInteractorOutput?
    
    func fetchKanjis(withStrokeCount strokeCount: Int) {
        // 同梱 DB の初回の読み込みはバックグラウンドで行う
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = KanjiData.bundled.map { data in
                data.nameKanji(withStrokes: strokeCount).map { KanjiModel(kanji: $0) }
            }
            DispatchQueue.main.async {
                switch result {
                case .success(let kanjis):
                    self?.output?.didFetchKanjis(kanjis)
                case .failure(let error):
                    self?.output?.didFailToFetch(with: error)
                }
            }
        }
    }
}
