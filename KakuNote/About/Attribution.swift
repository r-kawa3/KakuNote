//
//  Attribution.swift
//  KakuNote
//

import Foundation

/// 漢字データの出典とライセンス（「このアプリについて」に表示する）。
///
/// KANJIDIC2 のライセンスでは、メニューから開ける別の画面に、使っていることと出典を表示し、
/// ライセンスへのリンクを示すことが求められている。Unihan は Unicode の著作権表示が必要。
/// アプリを公開する前に、各配布元の最新の条件を確かめ直すこと。
nonisolated enum Attribution {

    struct Link: Equatable, Sendable {
        let title: String
        let url: URL
    }

    struct Source: Equatable, Sendable {
        /// 表示名（画面の識別子にも使う）
        let name: String
        let description: String
        /// 同梱 DB に記録されているデータのバージョン
        let version: String
        let notice: String
        let links: [Link]
    }

    static func sources(meta: [String: String]) -> [Source] {
        [
            Source(
                name: "KANJIDIC2",
                description: "漢字の画数・読み・常用漢字と人名用漢字の区別に、Electronic Dictionary Research and Development Group（EDRDG）の KANJIDIC2 を使っています。",
                version: meta["kanjidic2_database_version"] ?? unknown,
                notice: "KANJIDIC2 は EDRDG の財産で、同グループのライセンスに従って使っています。このアプリの漢字データは KANJIDIC2 をもとに作ったもので、同じ CC BY-SA 4.0 のもとで提供します。",
                links: [
                    link("KANJIDIC プロジェクト", "https://www.edrdg.org/wiki/index.php/KANJIDIC_Project"),
                    link("EDRDG のライセンス", "https://www.edrdg.org/edrdg/licence.html"),
                    link("CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/"),
                ]
            ),
            Source(
                name: "Unihan",
                description: "漢字の部首の情報に、Unicode の Unihan データベースを使っています。",
                version: meta["unicode_version"].map { "Unicode \($0)" } ?? unknown,
                notice: "© 2025 Unicode®, Inc. Unicode and the Unicode Logo are registered trademarks of Unicode, Inc. in the U.S. and other countries.",
                links: [
                    link("Unicode License", "https://www.unicode.org/license.txt"),
                    link("Unicode の利用条件", "https://www.unicode.org/terms_of_use.html"),
                ]
            ),
        ]
    }

    private static let unknown = "不明"

    private static func link(_ title: String, _ url: String) -> Link {
        Link(title: title, url: URL(string: url)!)
    }
}
