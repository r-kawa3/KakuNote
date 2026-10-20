//
//  ReadingFilter.swift
//  KakuNote
//

import Foundation

/// 読みでの絞り込み（仕様書 search.md「読み」）。
///
/// 読みは、ひらがなのコードポイントの並びで扱う。名の読み r を、位置ごとの空でない連続した部分に分けて、
/// どれか 1 つの分け方で全部の位置の字がその部分を担えれば、その組み合わせを残す。
nonisolated enum Reading {

    /// 読みの長さの上限（「どこまで割り振れるか」を 64 ビットの集合で持つため）
    static let maxLength = 30
    /// 「ー」
    static let longVowel: UInt32 = 0x30FC

    /// 入力を、比べる形（ひらがなのコードポイントの並び）にする。前後の空白を除いて空なら nil（絞り込まない）。
    static func normalize(_ text: String) throws -> [UInt32]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let reading = trimmed.unicodeScalars.map { hiragana($0.value) }
        guard reading.count <= maxLength,
              reading.allSatisfy({ (0x3041...0x309F).contains($0) || $0 == longVowel }) else {
            throw SearchError.invalidReading
        }
        return reading
    }

    /// カタカナ（ァ〜ヶ、ヽヾ）をひらがなに直す。「ー」やひらがなのないカタカナはそのまま。
    static func hiragana(_ code: UInt32) -> UInt32 {
        (0x30A1...0x30F6).contains(code) || code == 0x30FD || code == 0x30FE ? code - 0x60 : code
    }

    /// 連濁: 1 文字目の替え方（か〜こ → が〜ご、さ〜そ → ざ〜ぞ、た〜と → だ〜ど、は〜ほ → ば〜ぼ・ぱ〜ぽ）
    static let rendaku: [UInt32: [UInt32]] = {
        var table: [UInt32: [UInt32]] = [:]
        for (plain, voiced) in zip("かきくけこさしすせそたちつてと".unicodeScalars, "がぎぐげござじずぜぞだぢづでど".unicodeScalars) {
            table[plain.value] = [voiced.value]
        }
        for ((plain, voiced), semi) in zip(zip("はひふへほ".unicodeScalars, "ばびぶべぼ".unicodeScalars), "ぱぴぷぺぽ".unicodeScalars) {
            table[plain.value] = [voiced.value, semi.value]
        }
        return table
    }()
}

/// 1 回の検索での、読みの割り振りの表。
///
/// 字の読みの集合（連濁なし）に番号（setID）を付け、「読みの s 文字目から始めて、どこまで担えるか」を
/// 64 ビットの集合で持つ。同じ読みの集合の字は、同じように割り振れるので、まとめて扱える。
nonisolated struct ReadingTable: Sendable {
    /// 名の読み（ひらがなのコードポイント）
    let reading: [UInt32]
    /// spans[setID * 2 + (連濁ありなら 1)][s]: 読みの s 文字目から始めたときに、担い終われる位置の集合
    private(set) var spans: [[UInt64]] = []
    private var setIDs: [Set<[UInt32]>: Int] = [:]

    /// 々 を表すキー（直前の字の読みを使う）
    static let odoriji = -1

    init(reading: [UInt32]) {
        self.reading = reading
    }

    /// 位置 position（0 始まり）の字 info のキー。々 は odoriji。どこも担えない字は nil（候補から外す）。
    mutating func key(for info: CharInfo, position: Int, data: KanjiData) -> Int? {
        let scalar = info.char.unicodeScalars.first!
        if scalar == "々" {
            return position == 0 ? nil : Self.odoriji
        }
        let readings: Set<[UInt32]>
        if info.script == .kanji {
            readings = Set((data.readings[scalar] ?? []).map { $0.unicodeScalars.map(\.value) })
        } else {
            readings = [[Reading.hiragana(scalar.value)]]
        }
        let id = setID(for: readings)
        // 連濁は、位置 2 以降の漢字だけ
        let key = id * 2 + (position > 0 && info.script == .kanji ? 1 : 0)
        return spans[key].contains { $0 != 0 } ? key : nil
    }

    private mutating func setID(for readings: Set<[UInt32]>) -> Int {
        if let id = setIDs[readings] { return id }
        let id = setIDs.count
        setIDs[readings] = id
        let voiced = Set(readings.flatMap { y -> [[UInt32]] in
            guard let first = y.first, let replacements = Reading.rendaku[first] else { return [] }
            return replacements.map { [$0] + y.dropFirst() }
        }).union(readings)
        spans.append(makeSpans(readings))
        spans.append(makeSpans(voiced))
        return id
    }

    private func makeSpans(_ readings: Set<[UInt32]>) -> [UInt64] {
        let m = reading.count
        return (0..<m).map { start in
            var ends: UInt64 = 0
            for y in readings where !y.isEmpty && start + y.count <= m && reading[start..<(start + y.count)].elementsEqual(y) {
                ends |= 1 << UInt64(start + y.count)
            }
            return ends
        }
    }

    /// 位置ごとに数えていくときの状態: ここまでで割り振り終われる位置の集合、使いたい字がもう入っているか、
    /// 直前の 々 でない字の読みの setID（覚えなくてよいときは -1）。
    struct Path: Hashable, Sendable {
        var ends: UInt64
        var satisfied: Bool
        var base: Int

        static func start(needsUse: Bool) -> Path {
            Path(ends: 1, satisfied: !needsUse, base: -1)
        }
    }

    /// 位置 position（0 始まり）に、キー key の字を置いたあとの状態。割り振れなくなれば nil。
    /// remaining はそのあとに残る位置の数（残りの位置にも 1 文字以上ずつ要るので、割り振り終わる位置を絞る）。
    /// keepBase が false なら、直前の字の読みを覚えない（この先に 々 がないとき）。
    func step(_ path: Path, key: Int, used: Bool, remaining: Int, keepBase: Bool) -> Path? {
        let base: Int
        let spanKey: Int
        if key == Self.odoriji {
            guard path.base >= 0 else { return nil }
            base = path.base
            // 々 は漢字なので、連濁を認める（位置 1 の 々 は、はじめから外している）
            spanKey = path.base * 2 + 1
        } else {
            base = key >> 1
            spanKey = key
        }
        let limit = reading.count - remaining
        guard limit > 0 else { return nil }
        let ends = advance(path.ends, key: spanKey) & ((UInt64(2) << UInt64(limit)) - 1)
        guard ends != 0 else { return nil }
        return Path(ends: ends, satisfied: path.satisfied || used, base: keepBase ? base : -1)
    }

    /// 最後の位置まで置いたあと、条件に合っているか。
    func accepts(_ path: Path) -> Bool {
        path.satisfied && path.ends & (1 << UInt64(reading.count)) != 0
    }

    /// 割り振れる位置の集合 S から、キー key の字を置いたあとの集合。
    private func advance(_ state: UInt64, key: Int) -> UInt64 {
        var next: UInt64 = 0
        var rest = state
        let table = spans[key]
        while rest != 0 {
            let start = rest.trailingZeroBitCount
            rest &= rest - 1
            if start < table.count { next |= table[start] }
        }
        return next
    }
}

/// 位置ごとの字を、同じように数えられるもの（読みのキーと、使いたい字かどうかが同じ）にまとめる。
nonisolated struct ReadingClass: Sendable {
    let key: Int
    let used: Bool
    let count: Int128

    static func group(keys: [Int], used: [Bool]) -> [ReadingClass] {
        var counts: [[Int]: Int128] = [:]
        var order: [[Int]] = []
        for (key, isUsed) in zip(keys, used) {
            let id = [key, isUsed ? 1 : 0]
            if counts[id] == nil { order.append(id) }
            counts[id, default: 0] += 1
        }
        return order.map { ReadingClass(key: $0[0], used: $0[1] == 1, count: counts[$0]!) }
    }
}

/// 1 つの内訳の中で、読み（と使いたい字）の条件に合う組み合わせの n 番目を求める。
/// 「この先で条件に合う組み合わせの数」を状態ごとに覚えておく（仕様書 search.md「数え方（実装の例）」）。
nonisolated struct ReadingCounter {
    /// 位置ごとの字のキー（ReadingTable.key）と、使いたい字かどうか
    let keys: [[Int]]
    let used: [[Bool]]
    let table: ReadingTable
    let needsUse: Bool

    /// 位置 i より後ろに 々 があるか（なければ、直前の字の読みを覚えなくてよい）
    private let keepsBase: [Bool]
    private let classes: [[ReadingClass]]
    private var memo: [Memo: Int128] = [:]

    private struct Memo: Hashable {
        let index: Int
        let path: ReadingTable.Path
    }

    init(keys: [[Int]], used: [[Bool]], table: ReadingTable, needsUse: Bool) {
        self.keys = keys
        self.used = used
        self.table = table
        self.needsUse = needsUse
        keepsBase = keys.indices.map { i in keys[(i + 1)...].contains { $0.contains(ReadingTable.odoriji) } }
        classes = keys.indices.map { ReadingClass.group(keys: keys[$0], used: used[$0]) }
    }

    /// 条件に合う組み合わせの数。
    mutating func total() -> Int128 {
        count(0, .start(needsUse: needsUse))
    }

    /// 条件に合う組み合わせのうち n 番目（0 始まり）の、位置ごとの字の番号。
    mutating func nth(_ n: Int128) -> [Int] {
        var n = n
        var path = ReadingTable.Path.start(needsUse: needsUse)
        var picks: [Int] = []
        for i in keys.indices {
            for (k, key) in keys[i].enumerated() {
                guard let next = step(i, path, key: key, used: used[i][k]) else { continue }
                let rest = count(i + 1, next)
                if n < rest {
                    picks.append(k)
                    path = next
                    break
                }
                n -= rest
            }
        }
        return picks
    }

    private func step(_ index: Int, _ path: ReadingTable.Path, key: Int, used: Bool) -> ReadingTable.Path? {
        table.step(path, key: key, used: used, remaining: keys.count - index - 1, keepBase: keepsBase[index])
    }

    private mutating func count(_ index: Int, _ path: ReadingTable.Path) -> Int128 {
        if index == keys.count {
            return table.accepts(path) ? 1 : 0
        }
        let memoKey = Memo(index: index, path: path)
        if let cached = memo[memoKey] { return cached }
        var total: Int128 = 0
        for item in classes[index] {
            guard let next = step(index, path, key: item.key, used: item.used) else { continue }
            total += item.count * count(index + 1, next)
        }
        memo[memoKey] = total
        return total
    }
}
