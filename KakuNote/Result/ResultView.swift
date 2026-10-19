//
//  ResultView.swift
//  KakuNote
//
//  Created by KAWA on 2026/07/19.
//

import SwiftUI

struct ResultView: View {
    // Presenterを保持（@Stateでライフサイクルを維持）
    @State var presenter: ResultPresenter
    /// タップした候補（詳細の画面を出す）
    @State private var selected: ResultRow?

    var body: some View {
        Group {
            if presenter.isLoading {
                ProgressView()
                    .tint(Wa.accent)
            } else if let message = presenter.errorMessage {
                ContentUnavailableView {
                    Label("検索できませんでした", systemImage: "exclamationmark.triangle")
                        .font(Wa.mincho(22, bold: true))
                } description: {
                    Text(message)
                        .foregroundStyle(Wa.secondaryText)
                }
            } else if presenter.total == 0 {
                ContentUnavailableView {
                    Label("該当する名前がありません", systemImage: "magnifyingglass")
                        .font(Wa.mincho(22, bold: true))
                } description: {
                    Text("条件を変えてみてください。")
                        .foregroundStyle(Wa.secondaryText)
                }
            } else if let total = presenter.total {
                list(total: total)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .waScreen()
        .navigationTitle("候補")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selected) { row in
            ResultRouter.detailView(sei: presenter.sei, mei: row.name)
        }
        // 画面イベントをPresenterにそのまま丸投げ
        .onAppear {
            presenter.viewDidAppear()
        }
    }

    private func list(total: Int) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ChipFlow(spacing: 8) {
                    ForEach(Array(presenter.chips.enumerated()), id: \.offset) { _, chip in
                        ConditionChip(chip: chip)
                    }
                }
                .padding(.bottom, 4)

                Text("\(total)件")
                    .font(Wa.gothic(.footnote, weight: .bold))
                    .foregroundStyle(Wa.secondaryText)
                    .accessibilityIdentifier("result.total")

                ForEach(Array(presenter.rows.enumerated()), id: \.offset) { index, row in
                    CandidateRow(row: row, sei: presenter.sei, query: presenter.query) {
                        selected = row
                    }
                    .onAppear { presenter.rowDidAppear(at: index) }
                }
            }
            .padding(.horizontal, Wa.Metrics.screenPadding)
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("result.list")
    }
}

/// 条件のチップ。格の条件は藍で塗り、それ以外は枠だけ。
private struct ConditionChip: View {
    let chip: SearchSummary.Chip

    var body: some View {
        Text(chip.text)
            .font(Wa.gothic(.caption, weight: chip.isPrimary ? .bold : .regular))
            .foregroundStyle(chip.isPrimary ? Wa.onAccent : Wa.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .background(chip.isPrimary ? Wa.accent : Wa.surface, in: Capsule())
            .overlay(Capsule().stroke(chip.isPrimary ? Color.clear : Wa.border, lineWidth: 1))
    }
}

/// 候補の 1 行: 明朝の大きな名前、画数の内訳、ハート。
private struct CandidateRow: View {
    let row: ResultRow
    let sei: String?
    let query: SearchQuery
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(row.name)
                        .font(Wa.mincho(32, bold: true, relativeTo: .title))
                        .foregroundStyle(Wa.ink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.breakdown)
                            .font(.caption)
                            .foregroundStyle(Wa.secondaryText)
                        if let note = row.kakuNote {
                            Text(note)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Wa.accent)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 18)
                .padding(.vertical, 10)
                .frame(minHeight: 68)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(row.name)
            .accessibilityValue([row.breakdown, row.kakuNote].compactMap { $0 }.joined(separator: "、"))

            FavoriteButton(sei: sei, mei: row.name, query: query)
                .padding(.trailing, 8)
        }
        .waCard()
    }
}

/// チップを横に並べ、入りきらなければ次の行に折り返す。
private struct ChipFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let last = rows.count - 1
            let needed = rows[last].indices.isEmpty ? size.width : rows[last].width + spacing + size.width
            if needed > width && !rows[last].indices.isEmpty {
                rows.append(Row())
            }
            let current = rows.count - 1
            rows[current].width = rows[current].indices.isEmpty ? size.width : rows[current].width + spacing + size.width
            rows[current].height = max(rows[current].height, size.height)
            rows[current].indices.append(index)
        }
        return rows
    }
}
