//
//  SettingsView.swift
//  KakuNote
//

import SwiftUI

/// 設定画面: 姓の登録、避けたい字、「このアプリについて」。
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var data: KanjiData?
    /// 避けたい字の入力欄
    @State private var avoidInput = ""
    @State private var avoidMessage: String?

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text("姓")
                            .font(Wa.gothic(.subheadline, weight: .bold))
                        TextField("", text: $settings.sei, prompt: Text("例：田中").foregroundStyle(Wa.placeholder))
                            .font(Wa.mincho(20))
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                            .accessibilityLabel("姓")
                            .accessibilityIdentifier("settings.sei")
                    }
                    .frame(minHeight: 44)
                    seiStatus
                } header: {
                    Text("姓")
                } footer: {
                    Text("登録した姓は「探す」と「調べる」で使います。空にすると、名前だけで探します。")
                }
                .waRow()

                avoidSection

                if let message = settings.errorMessage {
                    Text(message)
                        .foregroundStyle(Wa.seal)
                        .waRow()
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Text("このアプリについて")
                    }
                    .accessibilityIdentifier("settings.about")
                }
                .waRow()
            }
            .waScreen()
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                        .accessibilityIdentifier("settings.close")
                }
            }
            .task {
                data = await Task.detached { try? KanjiData.bundled.get() }.value
            }
        }
    }

    // MARK: - 避けたい字

    private var avoidSection: some View {
        Section {
            HStack(spacing: 10) {
                TextField("", text: $avoidInput, prompt: Text("例：乙").foregroundStyle(Wa.placeholder))
                    .font(Wa.mincho(20))
                    .submitLabel(.done)
                    .onSubmit(addAvoid)
                    .accessibilityLabel("避けたい字")
                    .accessibilityIdentifier("settings.avoid.input")
                Button("追加", action: addAvoid)
                    .font(Wa.gothic(.subheadline, weight: .bold))
                    .foregroundStyle(Wa.accent)
                    .buttonStyle(.borderless)
                    .disabled(data == nil || avoidInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("settings.avoid.add")
            }
            .frame(minHeight: 44)
            if let avoidMessage {
                Text(avoidMessage)
                    .font(.footnote)
                    .foregroundStyle(Wa.seal)
                    .accessibilityIdentifier("settings.avoid.error")
            }
            if !settings.avoidChars.isEmpty {
                ChipFlow(spacing: 8) {
                    // 正準等価な字が同じ id にならないよう、コードポイントの並びで区別する
                    ForEach(settings.avoidChars, id: \.codePoints) { char in
                        Button {
                            settings.removeAvoidChar(char)
                        } label: {
                            HStack(spacing: 4) {
                                Text(char)
                                    .font(Wa.mincho(18, bold: true))
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Wa.secondaryText)
                            }
                            .padding(.horizontal, 10)
                            .frame(minHeight: 36)
                            .background(Wa.surfaceMuted, in: Capsule())
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Wa.ink)
                        .accessibilityLabel("「\(char)」を外す")
                        .accessibilityIdentifier("settings.avoid.remove.\(char)")
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("避けたい字")
        } footer: {
            Text("自由・画数指定の位置の候補から外します。自分で固定した字は外しません。漢字・ひらがな・カタカナを、何文字でもまとめて入れられます。")
        }
        .waRow()
    }

    private func addAvoid() {
        guard let data, !avoidInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        avoidMessage = settings.addAvoidChars(avoidInput, data: data)
        if avoidMessage == nil {
            avoidInput = ""
        }
    }

    /// 登録した姓の天格。画数がわからない字があれば、それと分かるように出す。
    @ViewBuilder
    private var seiStatus: some View {
        if let sei = settings.registeredSei, let data {
            switch SeiCheck.tenkaku(of: sei, data: data) {
            case .success(let value):
                HStack {
                    Text("天格")
                        .foregroundStyle(Wa.secondaryText)
                    Spacer()
                    Text("\(value)画")
                        .font(Wa.mincho(17, bold: true))
                        .accessibilityIdentifier("settings.tenkaku")
                }
            case .failure(let message):
                Label(message.text, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Wa.seal)
                    .accessibilityIdentifier("settings.sei.error")
            }
        }
    }
}
