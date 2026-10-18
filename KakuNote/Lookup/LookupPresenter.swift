//
//  LookupPresenter.swift
//  KakuNote
//

import Foundation
import Observation

protocol LookupPresenterInput: AnyObject {
    func viewDidAppear()
    func inputDidChange()
}

@Observable
class LookupPresenter: LookupPresenterInput, LookupInteractorOutput {

    // View が入力・観察するプロパティ
    var sei = ""
    var mei = ""
    var result: LookupResult?
    var errorMessage: String?
    var isLoading = false

    private let interactor: LookupInteractorInput
    private let router: LookupRouterInput

    init(interactor: LookupInteractorInput, router: LookupRouterInput) {
        self.interactor = interactor
        self.router = router
    }

    // MARK: - View Input
    func viewDidAppear() {
        guard result == nil && !isLoading else { return }
        isLoading = true
        interactor.prepare()
    }

    func inputDidChange() {
        interactor.lookup(sei: sei, mei: mei)
    }

    // MARK: - Interactor Output
    func didPrepare() {
        isLoading = false
        interactor.lookup(sei: sei, mei: mei)
    }

    func didLookup(_ result: LookupResult?) {
        self.result = result
        errorMessage = nil
    }

    func didFailToLookup(with error: Error) {
        isLoading = false
        result = nil
        errorMessage = Self.message(for: error)
    }

    // MARK: - 表示用の文言
    static func message(for error: Error) -> String {
        switch error {
        case LookupError.unknownStrokes(let chars):
            return "画数がわからない字があります: " + chars.map { "「\($0)」" }.joined(separator: "、")
        case LookupError.invalidInput(let part, let inputError):
            let partName = part == .sei ? "姓" : "名"
            switch inputError {
            case .spaceInside:
                return "\(partName)の途中に空白があります"
            case .danglingSoundMark, .invalidSoundMark:
                return "\(partName)の濁点・半濁点の付け方が正しくありません"
            case .empty:
                return "\(partName)を入力してください"
            }
        default:
            return "漢字データを読み込めませんでした"
        }
    }

    static func message(for warning: NameWarning) -> String {
        switch warning {
        case .notNameChar(let char, let position):
            return "「\(char)」（名の\(position)文字目）は名前には使えません"
        case .notInitial(let char):
            return "「\(char)」は名の1文字目には使えません"
        }
    }
}
