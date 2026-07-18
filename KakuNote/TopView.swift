//
//  TopView.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/13.
//

import SwiftUI

struct TopView: View {
    @State private var numberText: String = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("調べたい漢字の画数を入力してください")
                    .font(.headline)
                    .padding(.bottom, 4)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("数字を入力", text: $numberText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: numberText) { oldValue, newValue in
                            // keep only digits
                            var filtered = newValue.filter { $0.isNumber }
                            // limit to 3 characters
                            if filtered.count > 3 {
                                filtered = String(filtered.prefix(3))
                            }
                            if filtered != newValue {
                                numberText = filtered
                            }
                        }
                    Text("画")
                }
                NavigationLink(destination: ResultRouter.assembleModules(strokeCount: Int(numberText) ?? 0)) {
                    Text("実行")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 12)
            }
            .padding()
        }
    }
}

#Preview {
    TopView()
}
