//
//  AppSettings.swift
//  KakuNote
//

import Foundation
import Observation

/// 設定画面で決める値。端末の中（Application Support の settings.json）に保存する。
/// 同梱の漢字 DB とは別のファイルなので、DB を差し替えても消えない。
nonisolated struct SettingsValues: Codable, Equatable, Sendable {
    /// 登録した姓。空なら登録なし
    var sei = ""
    /// 避けたい字（登録した順）。String の Set は正準等価な字を同じとみなすので、配列で持つ
    var avoidChars: [String] = []

    init(sei: String = "", avoidChars: [String] = []) {
        self.sei = sei
        self.avoidChars = avoidChars
    }

    // 項目を足しても古いファイルを読めるように、ない項目は初期値にする
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sei = try container.decodeIfPresent(String.self, forKey: .sei) ?? ""
        avoidChars = try container.decodeIfPresent([String].self, forKey: .avoidChars) ?? []
    }
}

/// 設定のファイルの読み書き。
nonisolated struct SettingsStore: Sendable {
    let url: URL

    /// アプリが使う保存先。
    static func defaultURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return directory.appendingPathComponent("settings.json")
    }

    /// 保存した設定。ファイルがない・読めないときは初期値。
    func load() -> SettingsValues {
        guard let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode(SettingsValues.self, from: data) else {
            return SettingsValues()
        }
        return values
    }

    func save(_ values: SettingsValues) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(values).write(to: url, options: .atomic)
    }
}

/// 画面が共有する設定。変えるとすぐに保存する。
@Observable
final class AppSettings {

    /// 登録した姓（入力のまま）
    var sei: String {
        didSet { save() }
    }
    /// 避けたい字。すべての検索で、自動の候補から外す
    private(set) var avoidChars: [String] {
        didSet { save() }
    }
    var errorMessage: String?

    private let store: SettingsStore?

    init(store: SettingsStore?) {
        self.store = store
        let values = store?.load() ?? SettingsValues()
        sei = values.sei
        avoidChars = values.avoidChars
    }

    /// 登録した姓。前後の空白を除いて空なら nil
    var registeredSei: String? {
        let trimmed = sei.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// アプリが使う設定。UI テストでは、起動時の環境変数で保存先を切り替える。
    static func makeDefault() -> AppSettings {
        let environment = ProcessInfo.processInfo.environment
        let url: URL?
        if let name = environment["KAKUNOTE_SETTINGS_FILE"] {
            url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            if environment["KAKUNOTE_SETTINGS_RESET"] == "1", let url {
                try? FileManager.default.removeItem(at: url)
            }
        } else {
            url = try? SettingsStore.defaultURL()
        }
        return AppSettings(store: url.map { SettingsStore(url: $0) })
    }

    /// 入力した字（何文字でもよい）を、避けたい字に足す。足せない字があれば、知らせる文言を返して何も足さない。
    @discardableResult
    func addAvoidChars(_ text: String, data: KanjiData) -> String? {
        let chars: [String]
        do {
            chars = try TextPreprocessor.characters(from: text)
        } catch {
            return "字だけを入れてください（途中の空白などは使えません）"
        }
        let unknown = chars.filter { data.info($0) == nil }
        if !unknown.isEmpty {
            return unknown.map { "「\($0)」" }.joined(separator: "、") + "は登録できません。漢字・ひらがな・カタカナを入れてください"
        }
        var added = avoidChars
        for char in chars where !added.contains(where: { Self.sameChar($0, char) }) {
            added.append(char)
        }
        avoidChars = added
        return nil
    }

    func removeAvoidChar(_ char: String) {
        avoidChars.removeAll { Self.sameChar($0, char) }
    }

    /// 正準等価な字（海 U+6D77 と U+FA45 など）を別の字として比べる
    private static func sameChar(_ lhs: String, _ rhs: String) -> Bool {
        lhs.codePoints == rhs.codePoints
    }

    private func save() {
        guard let store else { return }
        do {
            try store.save(SettingsValues(sei: sei, avoidChars: avoidChars))
            errorMessage = nil
        } catch {
            errorMessage = "設定を保存できませんでした"
        }
    }
}

/// 姓の天格。画数がわからない字などがあれば、表示する文言を返す。
enum SeiCheck {
    static func tenkaku(of sei: String, data: KanjiData) -> Result<Int, SeiMessage> {
        do {
            return .success(try data.strokes(of: TextPreprocessor.characters(from: sei)).reduce(0, +))
        } catch let error as UnknownStrokeError {
            return .failure(SeiMessage("画数がわからない字があります: " + error.chars.map { "「\($0)」" }.joined(separator: "、")))
        } catch {
            return .failure(SeiMessage("姓に使えない文字（途中の空白など）があります"))
        }
    }
}

struct SeiMessage: Error {
    let text: String
    init(_ text: String) { self.text = text }
}

extension String {
    /// コードポイントの並び。String の == と違い、正準等価な字を別のものとして区別できる
    nonisolated var codePoints: [UInt32] { unicodeScalars.map(\.value) }
}
