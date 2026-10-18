//
//  LookupInteractor.swift
//  KakuNote
//

import Foundation

protocol LookupInteractorInput: AnyObject {
    func prepare()
    func lookup(sei: String, mei: String)
}

protocol LookupInteractorOutput: AnyObject {
    func didPrepare()
    func didLookup(_ result: LookupResult?)
    func didFailToLookup(with error: Error)
}

class LookupInteractor: LookupInteractorInput {
    weak var output: LookupInteractorOutput?

    private let school: any KakuSchool
    private var data: KanjiData?

    init(school: any KakuSchool = ShinjitaiSchool()) {
        self.school = school
    }

    func prepare() {
        // 同梱 DB の初回の読み込みはバックグラウンドで行う
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = KanjiData.bundled
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self?.data = data
                    self?.output?.didPrepare()
                case .failure(let error):
                    self?.output?.didFailToLookup(with: error)
                }
            }
        }
    }

    func lookup(sei: String, mei: String) {
        guard let data else { return }
        if sei.trimmingCharacters(in: .whitespaces).isEmpty && mei.trimmingCharacters(in: .whitespaces).isEmpty {
            output?.didLookup(nil)
            return
        }
        // 読み込んだあとの計算は軽いので、入力のたびにその場で行う
        do {
            output?.didLookup(try NameLookup.lookup(sei: sei, mei: mei, data: data, school: school))
        } catch {
            output?.didFailToLookup(with: error)
        }
    }
}
