# KakuNote（iOS）

名前の画数（五格）を調べたり、画数の条件に合う名前を探したりする iOS アプリです。

同じアプリの Android 版は [KakuNote-Android](https://github.com/r-kawa3/KakuNote-Android) です。iOS 版と Android 版は、`testcases/` の同じテストケースを使っています。

## できること

| タブ | 内容 |
|---|---|
| 調べる | 姓と名を入力すると、1 文字ずつの画数と五格（天格・人格・地格・外格・総格）を出す |
| 探す | 名の文字数・各文字の条件（この字にする／何画の字にする／自由）・格の条件などから、合う名前を決まった順番で一覧にする。読み・使いたい字・避けたい字でも絞り込める |
| お気に入り | 気に入った名前を保存する |

設定画面と、漢字データの出典を示す「このアプリについて」もあります。

## 技術

- Swift・SwiftUI（iOS 26.5 以上）
- 画面は View・Presenter・Interactor・Router の構成（`Lookup/`・`Result/`）
- 画数の計算と名前の検索: `Logic/`
- 漢字データ: SQLite（`Resources/kanji.sqlite`）。SQLite3 の C API で読む
- お気に入り: 漢字データとは別の SQLite ファイル（`favorites.sqlite`）に保存
- 漢字データベースの生成: Python（標準ライブラリのみ）。`data/build_db.py`
- テスト: XCTest（ユニットテスト・UI テスト）、Python の unittest

## ビルドとテスト

必要なもの: Xcode 27.1

```bash
# ユニットテストだけ（すぐ終わる）
xcodebuild test -project KakuNote.xcodeproj -scheme KakuNote -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:KakuNoteTests

# UI テストも含めて全部（シミュレータで画面を操作するので時間がかかる）
xcodebuild test -project KakuNote.xcodeproj -scheme KakuNote -destination 'platform=iOS Simulator,name=iPhone 17'

# 漢字データベースを作るスクリプトのテスト
python3 -m unittest discover -s data/tests
```

アプリは `KakuNote.xcodeproj` を Xcode で開いて実行できます。実機で動かす場合は、Signing & Capabilities で自分の Team を選んでください。

### 漢字データベースを作り直す

元データ（KANJIDIC2）はリポジトリに含めていません。作り直すときだけ、`data/sources/` に置いてから実行します。

```bash
mkdir -p data/sources
curl -o data/sources/kanjidic2.xml.gz http://www.edrdg.org/kanjidic/kanjidic2.xml.gz
python3 data/build_db.py
```

## ディレクトリ構成

```
KakuNote/
  Logic/        画数の計算・名前の検索など（画面から独立）
  Lookup/       「調べる」画面
  Result/       「探す」の結果画面
  Favorites/    お気に入り
  Settings/     設定
  About/        このアプリについて（漢字データの出典）
  Design/       色や部品
  Resources/    同梱する漢字データベース（kanji.sqlite）
KakuNoteTests/  ユニットテスト
KakuNoteUITests/ UI テスト
data/           漢字データベースを作るスクリプト・補正用 CSV・テスト
testcases/      iOS 版と Android 版で共通のテストケース
```

## ライセンス

- **ソースコード**: [MIT License](LICENSE)
- **漢字データ**（`KakuNote/Resources/kanji.sqlite` と、`data/` で作るデータ）: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)

漢字の画数・読み・常用漢字と人名用漢字の区別には、Electronic Dictionary Research and Development Group（[EDRDG](https://www.edrdg.org/)）の [KANJIDIC2](https://www.edrdg.org/wiki/index.php/KANJIDIC_Project) を使っています。KANJIDIC2 は EDRDG の財産で、[同グループのライセンス](https://www.edrdg.org/edrdg/licence.html)に従って使っています。このリポジトリの漢字データは KANJIDIC2 をもとに作ったもので、同じ CC BY-SA 4.0 のもとで提供します。
