-- KakuNote 同梱用の漢字データベース（読み取り専用）
-- build_db.py が生成する。iOS と Android の両方に同じファイルを同梱する。
-- ユーザーデータ（お気に入りなど）はこのファイルに入れず、別の DB に持つ。

PRAGMA user_version = 1;

-- 生成元データのバージョンなど
CREATE TABLE meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- 漢字 1 文字につき 1 行。KANJIDIC2 に載っている字（JIS X 0208/0212/0213）をすべて入れる。
-- 名前に使えない字も入れるのは、姓に使われる字の画数を「調べる」画面で出すため。
CREATE TABLE kanji (
    char           TEXT PRIMARY KEY,
    codepoint      INTEGER NOT NULL UNIQUE,
    -- 康熙字典の部首番号（Unihan kRSUnicode の 1 つ目）
    radical        INTEGER,
    -- 部首を康熙字典の元の形で数えた画数（例: 氵は水として 4 画）。
    -- 計算方法: 部首の元の画数 + kRSUnicode の残りの画数。
    -- この文字コードの字形で数えるので、新字体（例: 桜）を旧字体（櫻）に置き換えた画数ではない。
    kangxi_strokes INTEGER,
    -- 現代の日本の字形での画数（KANJIDIC2 の最初の stroke_count）
    modern_strokes INTEGER,
    -- 'joyo'（常用漢字）、'jinmei'（人名用漢字）、それ以外は NULL
    category       TEXT CHECK (category IN ('joyo', 'jinmei')),
    -- KANJIDIC2 の grade（1〜6: 教育漢字, 8: その他の常用漢字, 9/10: 人名用漢字）
    grade          INTEGER,
    -- 子の名前に使える字なら 1（常用漢字・人名用漢字）
    name_ok        INTEGER NOT NULL CHECK (name_ok IN (0, 1)),
    -- 英語の意味。複数あるときは "; " でつなぐ
    meanings_en    TEXT
);

CREATE INDEX kanji_by_kangxi ON kanji (name_ok, kangxi_strokes);
CREATE INDEX kanji_by_modern ON kanji (name_ok, modern_strokes);

-- 読み。1 つの字に複数ある。
CREATE TABLE reading (
    char  TEXT    NOT NULL REFERENCES kanji (char),
    -- 'on'（音読み）, 'kun'（訓読み）, 'nanori'（名乗り。名前で使われる読み）
    type  TEXT    NOT NULL CHECK (type IN ('on', 'kun', 'nanori')),
    -- KANJIDIC2 の表記そのまま（例: "かけ.る", "ヨウ", "-び"）
    raw   TEXT    NOT NULL,
    -- ひらがなにして、記号（. と -）を取り除いたもの（例: "かける", "よう", "び"）
    kana  TEXT    NOT NULL,
    -- 送り仮名を除いた部分をひらがなにしたもの（例: "かけ"）。送り仮名がなければ kana と同じ
    stem  TEXT    NOT NULL,
    -- KANJIDIC2 に載っている順番（0 から）
    ord   INTEGER NOT NULL,
    PRIMARY KEY (char, type, ord)
);

CREATE INDEX reading_by_kana ON reading (kana);
CREATE INDEX reading_by_stem ON reading (stem);

-- KANJIDIC2 に載っている、現代の画数の別の数え方（数え間違えやすいもの）。
-- 「調べる」画面で複数の数え方を併記するために使う。
CREATE TABLE alt_stroke (
    char    TEXT    NOT NULL REFERENCES kanji (char),
    strokes INTEGER NOT NULL,
    PRIMARY KEY (char, strokes)
);

-- KANJIDIC2 に載っている異体字（例: 桜 → 櫻）。
-- 旧字体の画数で数える流派に対応するときの材料。どれを旧字体とみなすかは仕様書で決める。
CREATE TABLE variant (
    char    TEXT NOT NULL REFERENCES kanji (char),
    variant TEXT NOT NULL REFERENCES kanji (char),
    PRIMARY KEY (char, variant)
);

-- 漢字以外で名前に使える字（ひらがな・カタカナ・長音記号・繰り返し記号）の画数。
-- non_kanji.csv から読み込む。
CREATE TABLE non_kanji (
    char       TEXT    PRIMARY KEY,
    -- 'hiragana', 'katakana', 'kanji'（「々」は漢字の位置に置く）
    script     TEXT    NOT NULL CHECK (script IN ('hiragana', 'katakana', 'kanji')),
    strokes    INTEGER NOT NULL,
    -- 名前の 1 文字目に置けるなら 1
    initial_ok INTEGER NOT NULL CHECK (initial_ok IN (0, 1)),
    -- 「探す」で自動の候補に入れるなら 1（固定する文字としてはいつでも使える）
    auto_ok    INTEGER NOT NULL CHECK (auto_ok IN (0, 1)),
    note       TEXT
);

-- 流派ごとの画数の補正。overrides.csv から読み込む。
CREATE TABLE override (
    school  TEXT    NOT NULL,
    char    TEXT    NOT NULL REFERENCES kanji (char),
    strokes INTEGER NOT NULL,
    note    TEXT,
    PRIMARY KEY (school, char)
);
