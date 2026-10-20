//
//  TopView.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/13.
//

import SwiftUI

/// 「探す」画面: 総画数（姓を使うなら総格）を一番上に大きく置き、名の文字数・名前の形（位置ごとの条件）を
/// 指定して、名前の候補を探す。姓は設定画面で登録したものを使う。「この条件で探す」ボタンは画面の下に固定する。
struct TopView: View {
    @Environment(AppSettings.self) private var settings
    /// 登録した姓を使うか（一番上のカードの「姓を使う」）
    @State private var usesSei = true
    @State private var length = 2
    @State private var positions: [PositionInput] = Array(repeating: PositionInput(), count: NameSearch.maxLength)
    /// 名前の形で選んでいるマス（0 から）
    @State private var selectedIndex = 0
    /// 一番上のカードの入力。姓なしなら総画数（地格）、姓ありなら総格
    @State private var totalText = ""
    /// 姓ありのときの、ほかの格（人格・地格・外格）の入力
    @State private var otherKakuTexts: [KakuKind: String] = [:]
    @State private var showsOtherKaku = false
    @State private var query: SearchQuery?
    @State private var formError: String?
    @State private var data: KanjiData?
    /// いま入力している欄（キーボードの上の「,」「完了」に使う）
    @FocusState private var focusedField: Field?

    /// 入力欄の種類
    enum Field: Hashable {
        case total
        case kaku(KakuKind)
        case fixed
        case strokes
    }

    /// 姓ありのとき、折りたたみの中で条件にできる格（天格は姓だけで決まるので表示だけ）
    private static let otherKakuKinds: [(kind: KakuKind, title: String, note: String)] = [
        (.jinkaku, "人格", "姓の末尾＋名の先頭"),
        (.chikaku, "地格", "名の合計"),
        (.gaikaku, "外格", "総格−人格"),
    ]

    /// 検索に使う姓。登録がない・「姓を使う」がオフなら nil
    private var sei: String? {
        usesSei ? settings.registeredSei : nil
    }

    private var hasSei: Bool { sei != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    WaHeader(seal: "名", title: "名前を探す")
                    totalCard
                    if hasSei {
                        otherKakuSection
                    }
                    lengthSection
                    nameShapeSection
                }
                .padding(.horizontal, Wa.Metrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if acceptsSeparator {
                        Button {
                            insertSeparator()
                        } label: {
                            Text("，区切り")
                                .font(Wa.gothic(.subheadline, weight: .bold))
                        }
                        .accessibilityLabel("区切りの「,」を入れる")
                        .accessibilityIdentifier("keyboard.comma")
                    }
                    Spacer()
                    Button("完了") {
                        focusedField = nil
                    }
                    .font(Wa.gothic(.subheadline, weight: .bold))
                    .accessibilityIdentifier("keyboard.done")
                }
            }
            .waScreen()
            .safeAreaInset(edge: .bottom) { submitBar }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $query) { query in
                ResultRouter.assembleModules(query: query)
            }
            .onChange(of: length) {
                selectedIndex = min(selectedIndex, length - 1)
            }
            .task {
                // 天格の表示に使う。同梱 DB の初回の読み込みはバックグラウンドで行う
                data = await Task.detached { try? KanjiData.bundled.get() }.value
            }
        }
    }

    // MARK: - 総画数（総格）のカード

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(hasSei ? "総格" : "総画数")
                    .font(Wa.gothic(.footnote, weight: .bold))
                    .tracking(2)
                Spacer()
                Text("複数は「,」で区切ります")
                    .font(.caption2)
                    .foregroundStyle(Wa.onAccentFaint)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("", text: $totalText, prompt: Text("20").foregroundStyle(Wa.onAccent.opacity(0.4)))
                    .font(Wa.mincho(64, bold: true, relativeTo: .largeTitle))
                    // 数字専用のキーボード（かな変換を通らない）。区切りはキーボードの上の「,」で入れる
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .total)
                    .tint(Wa.onAccent)
                    .accessibilityLabel(hasSei ? "総格" : "総画数")
                    .accessibilityIdentifier("search.total")
                Text("画")
                    .font(Wa.mincho(24))
                    .foregroundStyle(Wa.onAccentFaint)
            }
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Wa.onAccent.opacity(0.4)).frame(height: 1)
            }
            if let registered = settings.registeredSei {
                seiRow(registered)
                    .padding(.top, 6)
            }
        }
        .foregroundStyle(Wa.onAccent)
        .padding(EdgeInsets(top: 16, leading: 22, bottom: 14, trailing: 22))
        .background(Wa.accent, in: RoundedRectangle(cornerRadius: Wa.Metrics.largeCornerRadius))
    }

    /// 登録した姓の行: 「姓「田中」・天格 9画」と「姓を使う」。
    private func seiRow(_ registered: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("姓「\(registered)」")
                        .font(Wa.gothic(.footnote, weight: .bold))
                        .accessibilityIdentifier("search.sei")
                    if usesSei {
                        tenkakuText(registered)
                    }
                }
                .opacity(usesSei ? 1 : 0.6)
                if usesSei, let data, case .failure(let message) = SeiCheck.tenkaku(of: registered, data: data) {
                    Text(message.text)
                        .font(.footnote)
                        .accessibilityIdentifier("search.tenkaku.error")
                }
            }
            Spacer(minLength: 4)
            WaCheckbox(title: "姓を使う", isOn: $usesSei, color: Wa.onAccent, identifier: "search.useSei")
        }
    }

    @ViewBuilder
    private func tenkakuText(_ registered: String) -> some View {
        if let data, case .success(let value) = SeiCheck.tenkaku(of: registered, data: data) {
            HStack(spacing: 4) {
                Text("・天格")
                    .font(Wa.gothic(.footnote, weight: .bold))
                Text("\(value)画")
                    .font(Wa.mincho(17, bold: true))
                    .accessibilityIdentifier("search.tenkaku")
            }
        }
    }

    // MARK: - ほかの格（姓ありのとき）

    private var otherKakuSection: some View {
        DisclosureGroup(isExpanded: $showsOtherKaku) {
            VStack(spacing: 0) {
                ForEach(Self.otherKakuKinds, id: \.kind) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.title)
                                .font(Wa.gothic(.subheadline, weight: .bold))
                            Text(item.note)
                                .font(.caption2)
                                .foregroundStyle(Wa.secondaryText)
                        }
                        TextField("", text: Binding(
                            get: { otherKakuTexts[item.kind] ?? "" },
                            set: { otherKakuTexts[item.kind] = $0 }
                        ), prompt: Text("例: 15").foregroundStyle(Wa.placeholder))
                        .font(Wa.mincho(20, bold: true))
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .kaku(item.kind))
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel(item.title)
                        .accessibilityIdentifier("search.kaku.\(item.kind.rawValue)")
                        Text("画")
                            .foregroundStyle(Wa.secondaryText)
                    }
                    .frame(minHeight: 52)
                    if item.kind != Self.otherKakuKinds.last?.kind {
                        Divider().overlay(Wa.divider)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Text("ほかの格も条件にする（人格・地格・外格）")
                .font(Wa.gothic(.subheadline))
                .foregroundStyle(Wa.ink)
        }
        .tint(Wa.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .waCard()
    }

    // MARK: - 文字数

    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("文字数").waSectionLabel()
                Spacer()
                Text("1〜\(NameSearch.maxLength)文字")
                    .font(.caption2)
                    .foregroundStyle(Wa.secondaryText)
            }
            LengthStepper(length: $length, range: 1...NameSearch.maxLength)
        }
    }

    // MARK: - 名前の形

    private var nameShapeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("名前の形").waSectionLabel()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<length, id: \.self) { index in
                        NameCell(input: positions[index], index: index, isSelected: index == selectedIndex) {
                            selectedIndex = index
                        }
                    }
                }
                .padding(2)
            }
            KindTabs(kind: $positions[selectedIndex].kind)
            PositionDetail(input: $positions[selectedIndex], focusedField: $focusedField)
        }
    }

    // MARK: - 「この条件で探す」

    private var submitBar: some View {
        VStack(spacing: 6) {
            if let formError {
                Text(formError)
                    .font(.footnote)
                    .foregroundStyle(Wa.seal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("search.formError")
            }
            Button(action: submit) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    Text("この条件で探す")
                        .tracking(3)
                }
                .font(Wa.gothic(.headline, weight: .bold))
                .foregroundStyle(Wa.onAccent)
                .frame(maxWidth: .infinity, minHeight: Wa.Metrics.primaryButtonHeight)
                .background(Wa.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("search.submit")
        }
        .padding(.horizontal, Wa.Metrics.screenPadding)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Wa.background)
    }

    /// いまの欄が、複数の値（「,」区切り）を受け付けるか
    private var acceptsSeparator: Bool {
        switch focusedField {
        case .total, .kaku: return true
        default: return false
        }
    }

    /// いまの欄の末尾に区切りの「,」を足す（空のとき・すでに区切りで終わるときは足さない）
    private func insertSeparator() {
        func appended(_ text: String) -> String {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard let last = trimmed.last, !",、，".contains(last) else { return trimmed }
            return trimmed + ","
        }
        switch focusedField {
        case .total:
            totalText = appended(totalText)
        case .kaku(let kind):
            otherKakuTexts[kind] = appended(otherKakuTexts[kind] ?? "")
        default:
            break
        }
    }

    private func submit() {
        focusedField = nil
        var conditions: [KakuKind: Set<Int>] = [:]
        let totals = Self.parseNumbers(totalText)
        if !totals.isEmpty {
            conditions[hasSei ? .soukaku : .chikaku] = Set(totals)
        }
        if hasSei {
            for item in Self.otherKakuKinds {
                let values = Self.parseNumbers(otherKakuTexts[item.kind] ?? "")
                if !values.isEmpty { conditions[item.kind] = Set(values) }
            }
        }
        guard !conditions.isEmpty else {
            formError = hasSei ? "総格か、ほかの格の画数を入力してください" : "総画数を入力してください"
            return
        }
        var positionConditions: [PositionCondition] = []
        for index in 0..<length {
            guard let condition = positions[index].condition else {
                selectedIndex = index
                formError = "\(index + 1)文字目の条件を入力してください"
                return
            }
            positionConditions.append(condition)
        }
        formError = nil
        query = SearchQuery(sei: sei, positions: positionConditions, conditions: conditions, avoid: settings.avoidChars)
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

        var identifier: String {
            switch self {
            case .free: return "free"
            case .strokes: return "strokes"
            case .fixed: return "fixed"
            }
        }
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

// MARK: - 部品

/// 名の文字数の「− n文字 +」。範囲の外には動かない。
private struct LengthStepper: View {
    @Binding var length: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            stepButton(systemImage: "minus", filled: false, label: "文字数を減らす", identifier: "search.length.minus") {
                length = max(range.lowerBound, length - 1)
            }
            .disabled(length <= range.lowerBound)

            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(length)")
                    .font(Wa.mincho(30, bold: true, relativeTo: .title))
                    .monospacedDigit()
                Text("文字")
                    .font(Wa.gothic(.callout))
                    .foregroundStyle(Wa.secondaryText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(length)文字")
            .accessibilityIdentifier("search.length.value")
            Spacer()

            stepButton(systemImage: "plus", filled: true, label: "文字数を増やす", identifier: "search.length.plus") {
                length = min(range.upperBound, length + 1)
            }
            .disabled(length >= range.upperBound)
        }
        .padding(4)
        .waCard()
    }

    private func stepButton(
        systemImage: String, filled: Bool, label: String, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(filled ? Wa.onAccent : Wa.ink)
                .frame(width: Wa.Metrics.minTapSize, height: Wa.Metrics.minTapSize)
                .background(filled ? Wa.accent : Wa.surfaceMuted, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

/// 名前の形の 1 マス。固定は実線の枠にその字、自由は点線の枠に「自由」、画数指定は「n画」。
private struct NameCell: View {
    let input: PositionInput
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    private var text: String {
        switch input.kind {
        case .free:
            return "自由"
        case .strokes:
            return Int(input.strokesText).map { "\($0)画" } ?? "画数"
        case .fixed:
            let fixed = input.fixedText.trimmingCharacters(in: .whitespaces)
            return fixed.isEmpty ? "固定" : fixed
        }
    }

    private var hasFixedChar: Bool {
        input.kind == .fixed && !input.fixedText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(text)
                    .font(hasFixedChar ? Wa.mincho(36, bold: true) : Wa.gothic(.subheadline))
                    .tracking(hasFixedChar ? 0 : 1)
                    .foregroundStyle(input.kind == .free ? Wa.secondaryText : Wa.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: Wa.Metrics.cellSize, height: Wa.Metrics.cellSize)
                    .background(
                        input.kind == .free ? Color.clear : Wa.surface,
                        in: RoundedRectangle(cornerRadius: Wa.Metrics.cellCornerRadius)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Wa.Metrics.cellCornerRadius)
                            .strokeBorder(
                                isSelected ? Wa.accent : (input.kind == .free ? Wa.dashed : Wa.border),
                                style: StrokeStyle(lineWidth: isSelected ? 2 : 1.5, dash: input.kind == .free ? [5, 4] : [])
                            )
                    )
                Text("\(index + 1)文字目")
                    .font(.caption2.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Wa.accent : Wa.secondaryText)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(index + 1)文字目 \(text)")
        .accessibilityValue(isSelected ? "選択中" : "")
        .accessibilityIdentifier("search.cell.\(index + 1)")
    }
}

/// 選んだマスの「自由／画数指定／固定」。選んでいるものに藍の下線を引く。
private struct KindTabs: View {
    @Binding var kind: PositionInput.Kind

    var body: some View {
        HStack(spacing: 20) {
            ForEach(PositionInput.Kind.allCases, id: \.self) { item in
                Button {
                    kind = item
                } label: {
                    Text(item.rawValue)
                        .font(Wa.gothic(.subheadline, weight: kind == item ? .bold : .regular))
                        .foregroundStyle(kind == item ? Wa.accent : Wa.secondaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 2)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(kind == item ? Wa.accent : .clear)
                                .frame(height: 2)
                        }
                        .frame(minHeight: Wa.Metrics.minTapSize)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(kind == item ? .isSelected : [])
                .accessibilityIdentifier("search.kind.\(item.identifier)")
            }
        }
    }
}

/// 選んだマスの入力: 固定する字、画数、文字の種類。
private struct PositionDetail: View {
    @Binding var input: PositionInput
    var focusedField: FocusState<TopView.Field?>.Binding

    var body: some View {
        VStack(spacing: 10) {
            switch input.kind {
            case .fixed:
                row(title: "固定する字") {
                    TextField("", text: $input.fixedText, prompt: Text("例: 陽").foregroundStyle(Wa.placeholder))
                        .font(Wa.mincho(24, bold: true))
                        .multilineTextAlignment(.trailing)
                        .focused(focusedField, equals: .fixed)
                        .accessibilityLabel("固定する字")
                        .accessibilityIdentifier("search.fixed")
                }
            case .strokes:
                row(title: "画数") {
                    HStack(spacing: 4) {
                        TextField("", text: $input.strokesText, prompt: Text("例: 12").foregroundStyle(Wa.placeholder))
                            .font(Wa.mincho(22, bold: true))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused(focusedField, equals: .strokes)
                            .accessibilityLabel("画数")
                            .accessibilityIdentifier("search.strokes")
                        Text("画")
                            .foregroundStyle(Wa.secondaryText)
                    }
                }
                scriptRow
            case .free:
                scriptRow
            }
        }
    }

    private var scriptRow: some View {
        row(title: "文字の種類") {
            Picker("文字の種類", selection: $input.script) {
                Text("漢字").tag(ScriptFilter.kanji)
                Text("ひらがな").tag(ScriptFilter.hiragana)
                Text("カタカナ").tag(ScriptFilter.katakana)
                Text("どれでも").tag(ScriptFilter.any)
            }
            .pickerStyle(.menu)
            .tint(Wa.accent)
            .accessibilityIdentifier("search.script")
        }
    }

    private func row<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(Wa.gothic(.subheadline))
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .waCard(cornerRadius: 10)
    }
}

#Preview {
    TopView()
        .environment(AppSettings(store: nil))
}
