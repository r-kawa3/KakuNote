# data/ 漢字データベースの生成

アプリに同梱する漢字データベース（SQLite）を作るスクリプトです。iOS 版と Android 版の両方に、ここで作った同じファイルを同梱します。

## ファイル

| ファイル | 内容 |
|---|---|
| `build_db.py` | DB を作るスクリプト（Python 3.9 以上、標準ライブラリだけで動く） |
| `schema.sql` | DB のテーブル定義。各列の意味もここに書いてある |
| `overrides.csv` | 流派ごとの画数の補正（`school,char,strokes,note`） |
| `tests/` | `build_db.py` のテスト |
| `sources/` | 元データ（git の管理対象外） |
| `build/` | 生成した `kanji.sqlite`（git の管理対象外） |

## 作り方

1. 元データを `data/sources/` に置きます。

   - **Unihan**: <https://www.unicode.org/Public/UCD/latest/ucd/Unihan.zip> を展開し、`Unihan_IRGSources.txt` を置く
   - **KANJIDIC2**: <http://www.edrdg.org/kanjidic/kanjidic2.xml.gz> を置く（展開しなくてよい）

2. リポジトリ直下で実行します。

   ```bash
   python3 data/build_db.py
   ```

   `data/build/kanji.sqlite` ができます。

3. テストは次のコマンドで実行します。

   ```bash
   python3 -m unittest discover -s data/tests
   ```

## データの中身

- **対象の字**: KANJIDIC2 に載っている 13,108 字（JIS X 0208 / 0212 / 0213）。名前に使えない字も入れてあるのは、姓に使われる字を「調べる」画面で出すためです。
- **名前に使えるか**（`name_ok`）: 常用漢字 2,136 字と人名用漢字 863 字（KANJIDIC2 の grade で判定）。
- **画数は 2 種類**:
  - `modern_strokes`: 現代の日本の字形の画数（KANJIDIC2）。例: 海 9、福 13
  - `kangxi_strokes`: 部首を康熙字典の元の形で数えた画数。Unihan の `kRSUnicode`（部首番号と残りの画数）から計算します。例: 海 11（水 4 + 7）、福 14（示 5 + 9）
- **読み**: 音読み・訓読み・名乗り。ひらがなにした形（`kana`）と、送り仮名を除いた形（`stem`）も入れてあります。
- **異体字**（`variant`）: 例: 桜 ⇔ 櫻、浜 ⇔ 濱・濵
- **別の数え方**（`alt_stroke`）: KANJIDIC2 に載っている、数え間違えやすい画数

## 注意点（仕様書で決めること）

- `kangxi_strokes` は**その文字コードの字形**で数えています。新字体を旧字体に置き換えて数える流派（例: 桜を櫻の 21 画で数える）に対応するには、`variant` を使ってどの字を旧字体とみなすかを決める必要があります。
- 漢数字（四・五・九など）を数の値で数える流派があります。たとえば `kangxi_strokes` では四が 5 画、九が 2 画です。このような違いは `overrides.csv` に書きます。
- KANJIDIC2 にない字があります（例: 髙、𠮷）。姓でよく使われる字なので、Unihan から追加するかどうかを検討します。
- 名前に使えるひらがな・カタカナは、まだ入っていません。

## ライセンス（2026-10-18 時点の確認。アプリを公開する前に必ず確認し直す）

法律の専門家の判断ではなく、各配布元の文章を読んだまとめです。

**KANJIDIC2**（EDRDG、CC BY-SA 4.0）<https://www.edrdg.org/edrdg/licence.html>
- 商用利用もできます。
- アプリの中に「このアプリについて」「出典」など、メニューから開ける別の画面を用意し、KANJIDIC2 を使っていることと出典を表示する必要があります。起動画面に出すだけでは不十分です。
- ライセンスと説明へのリンクも示します。
- 加工したデータを配布するときは、同じか互換性のあるライセンスで配布します（継承）。同梱する DB もこれに当たると考えられます。アプリのコードを公開する必要はありません。
- データを定期的に更新する手順を用意する必要があります。

**Unihan**（Unicode License）<https://www.unicode.org/license.txt>
- 商用利用・加工・配布ができます。
- 著作権表示と許諾の文章を、配布物かそのドキュメントに含める必要があります。
