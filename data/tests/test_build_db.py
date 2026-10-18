"""build_db.py のテスト。

実行（リポジトリ直下から）:
    python3 -m unittest discover -s data/tests
"""

import io
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import build_db  # noqa: E402

KANJIDIC_SAMPLE = """<?xml version="1.0" encoding="UTF-8"?>
<kanjidic2>
<header>
<file_version>4</file_version>
<database_version>2026-001</database_version>
<date_of_creation>2026-01-01</date_of_creation>
</header>
<character>
<literal>桜</literal>
<codepoint><cp_value cp_type="ucs">685c</cp_value><cp_value cp_type="jis208">1-24-89</cp_value></codepoint>
<radical><rad_value rad_type="classical">75</rad_value></radical>
<misc><grade>5</grade><stroke_count>10</stroke_count><variant var_type="jis208">1-61-15</variant></misc>
<reading_meaning>
<rmgroup>
<reading r_type="pinyin">ying1</reading>
<reading r_type="ja_on">オウ</reading>
<reading r_type="ja_kun">さくら</reading>
<meaning>cherry</meaning>
<meaning m_lang="fr">cerisier du Japon</meaning>
</rmgroup>
<nanori>さ</nanori>
</reading_meaning>
</character>
<character>
<literal>櫻</literal>
<codepoint><cp_value cp_type="ucs">6afb</cp_value><cp_value cp_type="jis208">1-61-15</cp_value></codepoint>
<radical><rad_value rad_type="classical">75</rad_value></radical>
<misc><grade>10</grade><stroke_count>21</stroke_count><variant var_type="jis208">1-24-89</variant></misc>
</character>
<character>
<literal>翔</literal>
<codepoint><cp_value cp_type="ucs">7fd4</cp_value></codepoint>
<radical><rad_value rad_type="classical">124</rad_value></radical>
<misc><grade>9</grade><stroke_count>12</stroke_count><stroke_count>11</stroke_count></misc>
<reading_meaning>
<rmgroup>
<reading r_type="ja_on">ショウ</reading>
<reading r_type="ja_kun">かけ.る</reading>
<reading r_type="ja_kun">と.ぶ</reading>
<meaning>soar</meaning>
</rmgroup>
</reading_meaning>
</character>
<character>
<literal>辻</literal>
<codepoint><cp_value cp_type="ucs">8fbb</cp_value></codepoint>
<radical><rad_value rad_type="classical">162</rad_value></radical>
<misc><stroke_count>5</stroke_count></misc>
</character>
</kanjidic2>
"""

UNIHAN_SAMPLE = """# Unihan_IRGSources.txt
# Unicode Version 17.0.0
U+685C\tkRSUnicode\t75.6
U+685C\tkTotalStrokes\t10
U+6AFB\tkRSUnicode\t75.17
U+7FD4\tkRSUnicode\t124.6
U+8FBB\tkRSUnicode\t162.2
"""


class RadicalStrokesTest(unittest.TestCase):
    def test_all_214_radicals_have_strokes(self):
        self.assertEqual(sorted(build_db.RADICAL_STROKES), list(range(1, 215)))

    def test_known_radicals(self):
        self.assertEqual(build_db.RADICAL_STROKES[1], 1)    # 一
        self.assertEqual(build_db.RADICAL_STROKES[61], 4)   # 心（忄）
        self.assertEqual(build_db.RADICAL_STROKES[85], 4)   # 水（氵）
        self.assertEqual(build_db.RADICAL_STROKES[140], 6)  # 艸（艹）
        self.assertEqual(build_db.RADICAL_STROKES[162], 7)  # 辵（辶）
        self.assertEqual(build_db.RADICAL_STROKES[163], 7)  # 邑（阝 右）
        self.assertEqual(build_db.RADICAL_STROKES[170], 8)  # 阜（阝 左）
        self.assertEqual(build_db.RADICAL_STROKES[214], 17)  # 龠


class ParseRsUnicodeTest(unittest.TestCase):
    def test_simple(self):
        self.assertEqual(build_db.parse_rs_unicode("85.7"), (85, 7))

    def test_simplified_radical_mark(self):
        self.assertEqual(build_db.parse_rs_unicode("120'.3"), (120, 3))

    def test_negative_residual(self):
        self.assertEqual(build_db.parse_rs_unicode("61.-1"), (61, -1))

    def test_uses_first_of_multiple_values(self):
        self.assertEqual(build_db.parse_rs_unicode("9.2 30.5"), (9, 2))

    def test_invalid(self):
        self.assertIsNone(build_db.parse_rs_unicode(""))
        self.assertIsNone(build_db.parse_rs_unicode("abc"))


class KangxiStrokesTest(unittest.TestCase):
    def test_well_known_examples(self):
        self.assertEqual(build_db.kangxi_strokes(85, 7), 11)   # 海
        self.assertEqual(build_db.kangxi_strokes(113, 9), 14)  # 福


class NormalizeReadingTest(unittest.TestCase):
    def test_on_reading_becomes_hiragana(self):
        self.assertEqual(build_db.normalize_reading("ショウ"), ("しょう", "しょう"))

    def test_okurigana(self):
        self.assertEqual(build_db.normalize_reading("かけ.る"), ("かける", "かけ"))

    def test_prefix_suffix_marks(self):
        self.assertEqual(build_db.normalize_reading("-び"), ("び", "び"))
        self.assertEqual(build_db.normalize_reading("お-"), ("お", "お"))

    def test_long_vowel_mark_kept(self):
        self.assertEqual(build_db.normalize_reading("トー"), ("とー", "とー"))


class BuildTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        tmp = Path(self.tmp.name)
        unihan_path = tmp / "unihan.txt"
        unihan_path.write_text(UNIHAN_SAMPLE, encoding="utf-8")
        radicals, version = build_db.load_unihan_radicals(unihan_path)
        kanjidic = build_db.parse_kanjidic(io.BytesIO(KANJIDIC_SAMPLE.encode("utf-8")))
        self.out = tmp / "kanji.sqlite"
        self.stats = build_db.build(
            self.out,
            radicals,
            kanjidic,
            [("example", "辻", 6, "一点しんにょう")],
            version,
            [("さ", "hiragana", 3, 1, 1, None), ("ー", "katakana", 1, 0, 1, "長音記号")],
        )
        self.con = sqlite3.connect(str(self.out))

    def tearDown(self):
        self.con.close()
        self.tmp.cleanup()

    def query(self, sql, *params):
        return self.con.execute(sql, params).fetchall()

    def test_meta(self):
        meta = dict(self.query("SELECT key, value FROM meta"))
        self.assertEqual(meta["unicode_version"], "17.0.0")
        self.assertEqual(meta["kanjidic2_database_version"], "2026-001")

    def test_kanji_rows(self):
        rows = self.query(
            "SELECT char, radical, kangxi_strokes, modern_strokes, category, name_ok, meanings_en"
            " FROM kanji ORDER BY codepoint"
        )
        self.assertEqual(
            rows,
            [
                ("桜", 75, 10, 10, "joyo", 1, "cherry"),
                ("櫻", 75, 21, 21, "jinmei", 1, None),
                ("翔", 124, 12, 12, "jinmei", 1, "soar"),
                ("辻", 162, 9, 5, None, 0, None),
            ],
        )

    def test_readings(self):
        rows = self.query("SELECT type, raw, kana, stem FROM reading WHERE char = '翔' ORDER BY type, ord")
        self.assertEqual(
            rows,
            [
                ("kun", "かけ.る", "かける", "かけ"),
                ("kun", "と.ぶ", "とぶ", "と"),
                ("on", "ショウ", "しょう", "しょう"),
            ],
        )
        self.assertEqual(self.query("SELECT kana FROM reading WHERE char = '桜' AND type = 'nanori'"), [("さ",)])

    def test_alt_strokes(self):
        self.assertEqual(self.query("SELECT char, strokes FROM alt_stroke"), [("翔", 11)])

    def test_variants_both_directions(self):
        self.assertEqual(
            sorted(self.query("SELECT char, variant FROM variant")),
            [("桜", "櫻"), ("櫻", "桜")],
        )

    def test_override(self):
        self.assertEqual(self.query("SELECT school, char, strokes FROM override"), [("example", "辻", 6)])

    def test_non_kanji(self):
        self.assertEqual(
            self.query("SELECT char, script, strokes, initial_ok, auto_ok FROM non_kanji ORDER BY char"),
            [("さ", "hiragana", 3, 1, 1), ("ー", "katakana", 1, 0, 1)],
        )

    def test_non_kanji_that_is_also_kanji_fails(self):
        kanjidic = build_db.parse_kanjidic(io.BytesIO(KANJIDIC_SAMPLE.encode("utf-8")))
        with self.assertRaises(ValueError):
            build_db.build(
                Path(self.tmp.name) / "x.sqlite", {}, kanjidic, [], None, [("桜", "kanji", 10, 1, 1, None)]
            )

    def test_non_kanji_csv_in_repo(self):
        rows = build_db.load_non_kanji(build_db.DATA_DIR / "non_kanji.csv")
        by_char = {r[0]: r for r in rows}
        self.assertEqual(len(rows), 179)
        self.assertEqual(by_char["さ"][2], 3)
        self.assertEqual(by_char["が"][2], by_char["か"][2] + 2)  # 濁点は +2
        self.assertEqual(by_char["ぱ"][2], by_char["は"][2] + 1)  # 半濁点は +1
        self.assertEqual(by_char["々"][1:], ("kanji", 3, 0, 1, "繰り返し記号。いつも3画"))

    def test_override_with_unknown_char_fails(self):
        kanjidic = build_db.parse_kanjidic(io.BytesIO(KANJIDIC_SAMPLE.encode("utf-8")))
        with self.assertRaises(ValueError):
            build_db.build(Path(self.tmp.name) / "x.sqlite", {}, kanjidic, [("example", "龘", 1, None)], None)

    def test_stats(self):
        self.assertEqual(self.stats["kanji"], 4)
        self.assertEqual(self.stats["name_ok"], 3)
        self.assertEqual(self.stats["no_radical"], 0)


if __name__ == "__main__":
    unittest.main()
