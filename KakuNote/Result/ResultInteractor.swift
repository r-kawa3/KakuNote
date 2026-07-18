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
        guard let url = Bundle.main.url(forResource: "strokes", withExtension: "json") else {
            output?.didFailToFetch(with: NSError(domain: "FileNotFound", code: 404))
            return
        }
        
        // 実際のデータ処理をバックグラウンドで行う（巨大なJSON対策）
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let data = try Data(contentsOf: url)
                let allKanjis = try JSONDecoder().decode([String: Int].self, from: data)
                
                let filtered = allKanjis.filter { $0.value == strokeCount }
                                        .map { KanjiModel(kanji: $0.key) }
                                        .sorted { $0.kanji < $1.kanji }
                
                DispatchQueue.main.async {
                    self?.output?.didFetchKanjis(filtered)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.output?.didFailToFetch(with: error)
                }
            }
        }
    }
}
