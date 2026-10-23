//
//  SettingsView.swift
//  KakuNote
//

import SwiftUI

/// 設定画面: 姓の登録、使いたい字、避けたい字、読みの頭の部分、「このアプリについて」。
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var data: KanjiData?

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

                CharListSection(
                    list: .use, title: "使いたい字", prompt: "例：陽", identifier: "settings.use", data: data,
                    footer: "どれか 1 字以上が名前のどこかに入っている候補だけを出します。名前に使える字だけを登録できます。避けたい字にも入っている字は、使いたい字を優先します。"
                )
                CharListSection(
                    list: .avoid, title: "避けたい字", prompt: "例：乙", identifier: "settings.avoid", data: data,
                    footer: "自由・画数指定の位置の候補から外します。自分で固定した字は外しません。漢字・ひらがな・カタカナを、何文字でもまとめて入れられます。"
                )

                Section {
                    Toggle("読みの頭の部分も使う", isOn: $settings.readingPrefix)
                        .tint(Wa.accent)
                        .accessibilityIdentifier("settings.readingPrefix")
                } header: {
                    Text("読み")
                } footer: {
                    Text("「探す」で読みを入れたとき、字の読みの先頭の部分も認めます（例：心「こころ」→「こ」で、心春を「こはる」）。小さい字（ゃ・ゅ・ょ など）の手前では区切りません。候補が大きく増えます。")
                }
                .waRow()

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
                } footer: {
                    Text("KakuNote バージョン \(Attribution.appVersion)")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .accessibilityIdentifier("settings.version")
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

/// 設定で登録する字の並び（使いたい字・避けたい字）の欄: 入力して「追加」、登録した字はチップで並び、押すと外れる。
private struct CharListSection: View {
    let list: CharList
    let title: String
    let prompt: String
    /// UI テスト用の識別子の頭（例: settings.avoid）
    let identifier: String
    let data: KanjiData?
    let footer: String

    @Environment(AppSettings.self) private var settings
    @State private var input = ""
    @State private var message: String?

    var body: some View {
        Section {
            HStack(spacing: 10) {
                TextField("", text: $input, prompt: Text(prompt).foregroundStyle(Wa.placeholder))
                    .font(Wa.mincho(20))
                    .submitLabel(.done)
                    .onSubmit(add)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier("\(identifier).input")
                // 押せることがわかるように、藍の地のボタンにする。何も入れていないときは押せない（iOS が自動で薄くする）
                let enabled = data != nil && !input.trimmingCharacters(in: .whitespaces).isEmpty
                Button(action: add) {
                    Text("追加")
                        .font(Wa.gothic(.subheadline, weight: .bold))
                        .foregroundStyle(Wa.onAccent)
                        .padding(.horizontal, 14)
                        .frame(minWidth: 64, minHeight: 36)
                        .background(Wa.accent, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.borderless)
                .disabled(!enabled)
                .accessibilityIdentifier("\(identifier).add")
            }
            .frame(minHeight: 44)
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Wa.seal)
                    .accessibilityIdentifier("\(identifier).error")
            }
            let chars = settings.chars(list)
            if !chars.isEmpty {
                ChipFlow(spacing: 8) {
                    // 正準等価な字が同じ id にならないよう、コードポイントの並びで区別する
                    ForEach(chars, id: \.codePoints) { char in
                        Button {
                            settings.removeChar(char, from: list)
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
                        .accessibilityIdentifier("\(identifier).remove.\(char)")
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
        .waRow()
    }

    private func add() {
        guard let data, !input.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        message = settings.addChars(input, to: list, data: data)
        if message == nil {
            input = ""
        }
    }
}
