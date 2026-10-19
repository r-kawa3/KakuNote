//
//  SettingsView.swift
//  KakuNote
//

import SwiftUI

/// 設定画面: 姓の登録と、「このアプリについて」。
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
