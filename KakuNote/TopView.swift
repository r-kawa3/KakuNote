//
//  TopView.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/13.
//

import SwiftUI

/// 「探す」画面: 名の文字数・位置ごとの条件・総画数を指定して、名前の候補を探す。
struct TopView: View {
    @State private var length = 2
    @State private var positions: [PositionInput] = Array(repeating: PositionInput(), count: 4)
    @State private var totalText = ""
    @State private var query: SearchQuery?
    @State private var formError: String?

    var body: some View {
        NavigationStack {
            Form {
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
                    HStack {
                        Text("総画数")
                        TextField("例: 24 または 24, 31", text: $totalText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("search.total")
                    }
                } footer: {
                    Text("複数の画数は「,」で区切ります。")
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
            .navigationDestination(item: $query) { query in
                ResultRouter.assembleModules(query: query)
            }
        }
    }

    private func submit() {
        let totals = Self.parseNumbers(totalText)
        guard !totals.isEmpty else {
            formError = "総画数を入力してください"
            return
        }
        var conditions: [PositionCondition] = []
        for index in 0..<length {
            guard let condition = positions[index].condition else {
                formError = "\(index + 1)文字目の条件を入力してください"
                return
            }
            conditions.append(condition)
        }
        formError = nil
        query = SearchQuery(sei: nil, positions: conditions, conditions: [.chikaku: Set(totals)])
    }

    /// 「24, 31」「24、31」「24 31」のような入力から、正の整数を取り出す。
    static func parseNumbers(_ text: String) -> [Int] {
        text
            .split(whereSeparator: { ",、， ".contains($0) })
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 }
    }
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
