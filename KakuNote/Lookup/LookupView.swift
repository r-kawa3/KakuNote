//
//  LookupView.swift
//  KakuNote
//

import SwiftUI

/// 「調べる」画面: 姓名を入れると、各字の画数と五格が出る。
struct LookupView: View {
    @State var presenter: LookupPresenter
    @Environment(AppSettings.self) private var settings
    /// 設定に登録した姓を使うか（姓の欄の上のチェックボックス）
    @State private var usesRegisteredSei = true

    /// いま姓の欄に入れている、登録した姓。使わないなら nil
    private var appliedSei: String? {
        usesRegisteredSei ? settings.registeredSei : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    WaHeader(seal: "画", title: "画数を調べる")
                    inputCard

                    if presenter.isLoading {
                        ProgressView()
                            .tint(Wa.accent)
                            .frame(maxWidth: .infinity)
                    } else if let message = presenter.errorMessage {
                        Label(message, systemImage: "exclamationmark.circle.fill")
                            .font(Wa.gothic(.subheadline))
                            .foregroundStyle(Wa.seal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .waCard()
                            .accessibilityIdentifier("lookup.error")
                    } else if let result = presenter.result {
                        LookupResultView(result: result)
                    }
                }
                .padding(.horizontal, Wa.Metrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .waScreen()
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: presenter.sei) { presenter.inputDidChange() }
            .onChange(of: presenter.mei) { presenter.inputDidChange() }
            .onChange(of: appliedSei, initial: true) {
                if let appliedSei { presenter.sei = appliedSei }
            }
            .onAppear { presenter.viewDidAppear() }
        }
    }

    /// 姓・名の入力。1 つのカードに 2 行。
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if settings.registeredSei != nil {
                WaCheckbox(title: "登録した姓を使う", isOn: $usesRegisteredSei, color: Wa.accent, identifier: "lookup.useSei")
                    .padding(.horizontal, 4)
            }
            VStack(spacing: 0) {
                inputRow(label: "姓", text: $presenter.sei, prompt: "例：田中", identifier: "lookup.sei")
                    .disabled(appliedSei != nil)
                    .opacity(appliedSei != nil ? 0.7 : 1)
                Divider().overlay(Wa.divider)
                inputRow(label: "名", text: $presenter.mei, prompt: "例：健太", identifier: "lookup.mei")
            }
            .waCard()
            Text("姓を空にすると、名の総画数だけを出します。")
                .font(.caption)
                .foregroundStyle(Wa.secondaryText)
                .padding(.horizontal, 4)
        }
    }

    private func inputRow(label: String, text: Binding<String>, prompt: String, identifier: String) -> some View {
        HStack(spacing: 14) {
            Text(label)
                .font(Wa.gothic(.subheadline, weight: .bold))
                .tracking(1)
                .frame(width: 24, alignment: .leading)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Wa.placeholder))
                .font(Wa.mincho(20))
                .accessibilityLabel(label)
                .accessibilityIdentifier(identifier)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
    }
}
