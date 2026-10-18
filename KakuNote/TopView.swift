//
//  TopView.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/13.
//

import SwiftUI

/// 「探す」画面: 姓（省略可）・名の文字数・位置ごとの条件・格の条件を指定して、名前の候補を探す。
struct TopView: View {
    @State private var seiText = ""
    @State private var length = 2
    @State private var positions: [PositionInput] = Array(repeating: PositionInput(), count: 4)
    /// 格ごとの条件の入力。姓なしのときは地格の欄を「総画数」として使う
    @State private var conditionTexts: [KakuKind: String] = [:]
    @State private var query: SearchQuery?
    @State private var formError: String?
    @State private var data: KanjiData?

    /// 姓ありのときに条件にできる格（天格は姓だけで決まるので表示だけ）
    private static let seiConditionKinds: [(KakuKind, String)] = [
        (.jinkaku, "人格"), (.chikaku, "地格"), (.soukaku, "総格"), (.gaikaku, "外格"),
    ]

    private var hasSei: Bool {
        !seiText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("姓（省略できます）", text: $seiText)
                        .accessibilityIdentifier("search.sei")
                    if hasSei {
                        tenkakuRow
                    }
                } footer: {
                    Text("姓を入れると、人格・地格・総格・外格を条件にできます。")
                }

                Section {
                    Picker("名の文字数", selection: $length) {
                        ForEach(1...4, id: \.self) { Text("\($0)文字").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("search.length")
                }

                ForEach(0..<length, id: \.self) { index in
                    Section("\(index + 1)文字目") {
                        PositionEditor(input: $positions[index], index: index)
                    }
                }

                Section {
                    if hasSei {
                        ForEach(Self.seiConditionKinds, id: \.0) { kind, title in
                            conditionField(title, kind: kind, identifier: "search.kaku.\(kind.rawValue)")
                        }
                    } else {
                        conditionField("総画数", kind: .chikaku, identifier: "search.total")
                    }
                } footer: {
                    Text(hasSei
                         ? "条件にしたい格だけを入れます。複数の画数は「,」で区切ります。"
                         : "複数の画数は「,」で区切ります。")
                }

                if let formError {
                    Section {
                        Text(formError)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("search.formError")
                    }
                }

                Section {
                    Button("実行") { submit() }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("search.submit")
                }
            }
            .navigationTitle("探す")
            .aboutButton()
            .navigationDestination(item: $query) { query in
                ResultRouter.assembleModules(query: query)
            }
            .task {
                // 天格の表示に使う。同梱 DB の初回の読み込みはバックグラウンドで行う
                data = await Task.detached { try? KanjiData.bundled.get() }.value
            }
        }
    }

    @ViewBuilder
    private var tenkakuRow: some View {
        if let data {
            switch Self.tenkaku(of: seiText, data: data) {
            case .success(let value):
                HStack {
                    Text("天格")
                    Spacer()
                    Text("\(value)画")
                        .accessibilityIdentifier("search.tenkaku")
                }
            case .failure(let message):
                Text(message.text)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("search.tenkaku.error")
            }
        }
    }

    private func conditionField(_ title: String, kind: KakuKind, identifier: String) -> some View {
        HStack {
            Text(title)
            TextField("例: 24 または 24, 31", text: Binding(
                get: { conditionTexts[kind] ?? "" },
                set: { conditionTexts[kind] = $0 }
            ))
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.trailing)
            .accessibilityIdentifier(identifier)
        }
    }

    private func submit() {
        var conditions: [KakuKind: Set<Int>] = [:]
        let kinds = hasSei ? Self.seiConditionKinds.map(\.0) : [.chikaku]
        for kind in kinds {
            let values = Self.parseNumbers(conditionTexts[kind] ?? "")
            if !values.isEmpty { conditions[kind] = Set(values) }
        }
        guard !conditions.isEmpty else {
            formError = hasSei ? "条件にしたい格の画数を、1 つ以上入力してください" : "総画数を入力してください"
            return
        }
        var positionConditions: [PositionCondition] = []
        for index in 0..<length {
            guard let condition = positions[index].condition else {
                formError = "\(index + 1)文字目の条件を入力してください"
                return
            }
            positionConditions.append(condition)
        }
        formError = nil
        query = SearchQuery(sei: hasSei ? seiText : nil, positions: positionConditions, conditions: conditions)
    }

    /// 姓の天格。入力に問題があれば、表示する文言を返す。
    static func tenkaku(of sei: String, data: KanjiData) -> Result<Int, TenkakuMessage> {
        do {
            return .success(try data.strokes(of: TextPreprocessor.characters(from: sei)).reduce(0, +))
        } catch let error as UnknownStrokeError {
            return .failure(TenkakuMessage("画数がわからない字があります: " + error.chars.map { "「\($0)」" }.joined(separator: "、")))
        } catch {
            return .failure(TenkakuMessage("姓に使えない文字（途中の空白など）があります"))
        }
    }

    /// 「24, 31」「24、31」「24 31」のような入力から、正の整数を取り出す。
    static func parseNumbers(_ text: String) -> [Int] {
        text
            .split(whereSeparator: { ",、， ".contains($0) })
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 }
    }
}

struct TenkakuMessage: Error {
    let text: String
    init(_ text: String) { self.text = text }
}

/// 1 つの位置の入力欄の状態。
struct PositionInput: Equatable {
    enum Kind: String, CaseIterable {
        case free = "自由"
        case strokes = "画数指定"
        case fixed = "固定"
    }

    var kind: Kind = .free
    var script: ScriptFilter = .kanji
    var strokesText = ""
    var fixedText = ""

    var condition: PositionCondition? {
        switch kind {
        case .free:
            return .free(script)
        case .strokes:
            guard let strokes = Int(strokesText), strokes > 0 else { return nil }
            return .strokes(strokes, script)
        case .fixed:
            let text = fixedText.trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : .fixed(text)
        }
    }
}

private struct PositionEditor: View {
    @Binding var input: PositionInput
    let index: Int

    var body: some View {
        Picker("条件", selection: $input.kind) {
            ForEach(PositionInput.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("search.position\(index + 1).kind")

        switch input.kind {
        case .fixed:
            TextField("この字にする（例: 陽）", text: $input.fixedText)
                .accessibilityIdentifier("search.position\(index + 1).fixed")
        case .strokes, .free:
            Picker("文字の種類", selection: $input.script) {
                Text("漢字").tag(ScriptFilter.kanji)
                Text("ひらがな").tag(ScriptFilter.hiragana)
                Text("カタカナ").tag(ScriptFilter.katakana)
                Text("どれでも").tag(ScriptFilter.any)
            }
            .accessibilityIdentifier("search.position\(index + 1).script")
            if input.kind == .strokes {
                HStack {
                    Text("画数")
                    TextField("例: 12", text: $input.strokesText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("search.position\(index + 1).strokes")
                }
            }
        }
    }
}

#Preview {
    TopView()
}
