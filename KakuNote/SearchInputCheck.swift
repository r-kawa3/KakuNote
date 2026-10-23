//
//  SearchInputCheck.swift
//  KakuNote
//

import Foundation

/// 「探す」の入力を、「この条件で探す」を押す前に確かめた結果。
///
/// 入力の不足（総画数がない、条件が足りないマスがある）に加えて、探さなくてもわかる誤り
/// （読みにひらがな以外がある、固定の字が 1 文字でない・画数がわからない、姓に画数がわからない字がある）も見る。
/// 候補が多すぎるかどうかは、探してみないとわからないので見ない（押したあとの一覧で知らせる）。
enum SearchInputCheck: Equatable {
    case ready(SearchQuery)
    case problem(String)

    /// 押せないときの理由。押せるなら nil
    var problem: String? {
        if case .problem(let message) = self { return message }
        return nil
    }

    /// 姓ありのとき、折りたたみの中で条件にできる格
    static let otherKakuKinds: [KakuKind] = [.jinkaku, .chikaku, .gaikaku]

    /// - Parameters:
    ///   - sei: 検索に使う姓。姓なしなら nil
    ///   - positions: 文字数ぶんのマスの入力
    ///   - data: 漢字データ。まだ読み込んでいなければ nil（そのときは入力の不足だけを見る）
    static func make(
        sei: String?,
        totalText: String,
        otherKakuTexts: [KakuKind: String],
        positions: [PositionInput],
        reading: String,
        avoid: [String],
        use: [String],
        readingPrefix: Bool,
        data: KanjiData?
    ) -> SearchInputCheck {
        var conditions: [KakuKind: Set<Int>] = [:]
        let totals = TopView.parseNumbers(totalText)
        if !totals.isEmpty {
            conditions[sei != nil ? .soukaku : .chikaku] = Set(totals)
        }
        if sei != nil {
            for kind in otherKakuKinds {
                let values = TopView.parseNumbers(otherKakuTexts[kind] ?? "")
                if !values.isEmpty { conditions[kind] = Set(values) }
            }
        }
        guard !conditions.isEmpty else {
            return .problem(sei != nil ? "総格か、ほかの格の画数を入力してください" : "総画数を入力してください")
        }
        var positionConditions: [PositionCondition] = []
        for (index, input) in positions.enumerated() {
            guard let condition = input.condition else {
                return .problem("\(index + 1)文字目の条件を入力してください")
            }
            positionConditions.append(condition)
        }
        let trimmedReading = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = SearchQuery(
            sei: sei, positions: positionConditions, conditions: conditions,
            avoid: avoid, use: use,
            reading: trimmedReading.isEmpty ? nil : trimmedReading,
            readingPrefix: readingPrefix
        )

        // 探さなくてもわかる誤り
        do {
            _ = try Reading.normalize(reading)
        } catch {
            return .problem(ResultPresenter.message(for: error))
        }
        guard let data else { return .ready(query) }
        if let sei {
            do {
                _ = try data.strokes(of: TextPreprocessor.characters(from: sei))
            } catch let error as UnknownStrokeError {
                return .problem(ResultPresenter.message(for: SearchError.unknownStrokes(error.chars)))
            } catch let error as InputError {
                return .problem(ResultPresenter.message(for: SearchError.invalidInput(error)))
            } catch {
                return .problem(ResultPresenter.message(for: error))
            }
        }
        for (index, condition) in positionConditions.enumerated() {
            guard case .fixed(let text) = condition else { continue }
            do {
                let chars = try TextPreprocessor.characters(from: text)
                guard chars.count == 1 else {
                    return .problem(ResultPresenter.message(for: SearchError.fixedNotSingleChar(position: index + 1)))
                }
                _ = try data.strokes(of: chars)
            } catch let error as UnknownStrokeError {
                return .problem(ResultPresenter.message(for: SearchError.unknownStrokes(error.chars)))
            } catch let error as InputError {
                return .problem(ResultPresenter.message(for: SearchError.invalidInput(error)))
            } catch {
                return .problem(ResultPresenter.message(for: error))
            }
        }
        return .ready(query)
    }
}
