"""KakuNote 同梱用の漢字データベースを作る。

使い方（リポジトリ直下から）:
    python3 data/build_db.py

元データ（data/sources/ に置く）:
    Unihan_IRGSources.txt  Unicode の Unihan データベース（部首と画数）
                           https://www.unicode.org/Public/UCD/latest/ucd/Unihan.zip を展開したもの
    kanjidic2.xml.gz       EDRDG の KANJIDIC2（現代の画数、読み、常用・人名用の区別）
                           http://www.edrdg.org/kanjidic/kanjidic2.xml.gz

出力: data/build/kanji.sqlite
テスト: python3 -m unittest discover -s data/tests

標準ライブラリだけで動く（Python 3.9 以上）。
"""

from __future__ import annotations

import argparse
import csv
import gzip
import re
import sqlite3
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

DATA_DIR = Path(__file__).resolve().parent

# 康熙字典の部首 214 個それぞれの画数（部首の元の形で数える）。
# (最初の部首番号, 最後の部首番号, 画数)
_RADICAL_STROKE_RANGES = [
    (1, 6, 1),
    (7, 29, 2),
    (30, 60, 3),
    (61, 94, 4),
    (95, 117, 5),
    (118, 146, 6),
    (147, 166, 7),
    (167, 175, 8),
    (176, 186, 9),
    (187, 194, 10),
    (195, 200, 11),
    (201, 204, 12),
    (205, 208, 13),
    (209, 210, 14),
    (211, 211, 15),
    (212, 213, 16),
    (214, 214, 17),
]

RADICAL_STROKES: Dict[int, int] = {
    number: strokes
    for first, last, strokes in _RADICAL_STROKE_RANGES
    for number in range(first, last + 1)
}

# KANJIDIC2 の grade → category
_JOYO_GRADES = {1, 2, 3, 4, 5, 6, 8}
_JINMEI_GRADES = {9, 10}

# 例: "85.7", "120'.3", "61.-1"
_RS_PATTERN = re.compile(r"^(\d+)'*\.(-?\d+)$")


def parse_rs_unicode(value: str) -> Optional[Tuple[int, int]]:
    """kRSUnicode の値から (部首番号, 残りの画数) を返す。値が複数あるときは 1 つ目を使う。"""
    first = value.split()[0] if value.split() else ""
    match = _RS_PATTERN.match(first)
    if not match:
        return None
    return int(match.group(1)), int(match.group(2))


def kangxi_strokes(radical: int, residual: int) -> int:
    """部首を康熙字典の元の形で数えた画数。"""
    return RADICAL_STROKES[radical] + residual


def to_hiragana(text: str) -> str:
    """カタカナをひらがなにする（長音記号などはそのまま）。"""
    return "".join(
        chr(ord(ch) - 0x60) if "ァ" <= ch <= "ヶ" else ch for ch in text
    )


def normalize_reading(raw: str) -> Tuple[str, str]:
    """KANJIDIC2 の読みから (kana, stem) を作る。

    kana: ひらがなにして "." と "-" を除いたもの（"かけ.る" → "かける"）
    stem: 送り仮名（"." より後ろ）を除いたもの（"かけ.る" → "かけ"）
    """
    hira = to_hiragana(raw).replace("-", "")
    kana = hira.replace(".", "")
    stem = hira.split(".")[0]
    return kana, stem


def load_unihan_radicals(path: Path) -> Tuple[Dict[str, Tuple[int, int]], Optional[str]]:
    """Unihan_IRGSources.txt から {字: (部首番号, 残りの画数)} と Unicode のバージョンを読む。"""
    radicals: Dict[str, Tuple[int, int]] = {}
    version: Optional[str] = None
    with path.open(encoding="utf-8") as f:
        for line in f:
            if line.startswith("#"):
                found = re.match(r"#\s*Unicode Version\s+(\S+)", line)
                if found:
                    version = found.group(1)
                continue
            columns = line.rstrip("\n").split("\t")
            if len(columns) != 3 or columns[1] != "kRSUnicode":
                continue
            parsed = parse_rs_unicode(columns[2])
            if parsed is None:
                continue
            char = chr(int(columns[0][2:], 16))
            radicals[char] = parsed
    return radicals, version


@dataclass
class KanjidicEntry:
    char: str
    grade: Optional[int]
    strokes: List[int]
    readings: List[Tuple[str, str]]  # (type, raw)
    meanings_en: List[str]
    variant_codes: List[Tuple[str, str]]  # (var_type, value)


@dataclass
class Kanjidic:
    database_version: Optional[str]
    date_of_creation: Optional[str]
    entries: List[KanjidicEntry] = field(default_factory=list)
    # 文字コード（"jis208:1-61-15" や "ucs:6afb"）→ 字
    code_to_char: Dict[str, str] = field(default_factory=dict)


_READING_TYPES = {"ja_on": "on", "ja_kun": "kun"}


def parse_kanjidic(source) -> Kanjidic:
    """KANJIDIC2 の XML（パスかファイルオブジェクト）を読む。"""
    root = ET.parse(source).getroot()
    header = root.find("header")
    kanjidic = Kanjidic(
        database_version=header.findtext("database_version") if header is not None else None,
        date_of_creation=header.findtext("date_of_creation") if header is not None else None,
    )
    for ch in root.iter("character"):
        char = ch.findtext("literal")
        if not char:
            continue
        for cp in ch.findall("codepoint/cp_value"):
            kanjidic.code_to_char[f"{cp.get('cp_type')}:{cp.text.lower()}"] = char

        grade_text = ch.findtext("misc/grade")
        readings: List[Tuple[str, str]] = []
        meanings: List[str] = []
        rm = ch.find("reading_meaning")
        if rm is not None:
            for group in rm.findall("rmgroup"):
                for r in group.findall("reading"):
                    kind = _READING_TYPES.get(r.get("r_type", ""))
                    if kind and r.text:
                        readings.append((kind, r.text))
                for m in group.findall("meaning"):
                    if m.get("m_lang") is None and m.text:
                        meanings.append(m.text)
            for n in rm.findall("nanori"):
                if n.text:
                    readings.append(("nanori", n.text))

        kanjidic.entries.append(
            KanjidicEntry(
                char=char,
                grade=int(grade_text) if grade_text else None,
                strokes=[int(s.text) for s in ch.findall("misc/stroke_count") if s.text],
                readings=readings,
                meanings_en=meanings,
                variant_codes=[
                    (v.get("var_type", ""), v.text)
                    for v in ch.findall("misc/variant")
                    if v.text
                ],
            )
        )
    return kanjidic


def load_overrides(path: Path) -> List[Tuple[str, str, int, Optional[str]]]:
    """overrides.csv（school,char,strokes,note）を読む。"""
    rows = []
    with path.open(encoding="utf-8", newline="") as f:
        for line_no, row in enumerate(csv.DictReader(f), start=2):
            try:
                rows.append((row["school"], row["char"], int(row["strokes"]), row.get("note") or None))
            except (KeyError, ValueError) as e:
                raise ValueError(f"{path}:{line_no}: 読めない行です: {row}") from e
    return rows


NonKanjiRow = Tuple[str, str, int, int, int, Optional[str]]


def load_non_kanji(path: Path) -> List[NonKanjiRow]:
    """non_kanji.csv（char,script,strokes,initial_ok,auto_ok,note）を読む。"""
    rows = []
    with path.open(encoding="utf-8", newline="") as f:
        for line_no, row in enumerate(csv.DictReader(f), start=2):
            try:
                rows.append(
                    (
                        row["char"],
                        row["script"],
                        int(row["strokes"]),
                        int(row["initial_ok"]),
                        int(row["auto_ok"]),
                        row.get("note") or None,
                    )
                )
            except (KeyError, ValueError) as e:
                raise ValueError(f"{path}:{line_no}: 読めない行です: {row}") from e
    return rows


def category_for(grade: Optional[int]) -> Optional[str]:
    if grade in _JOYO_GRADES:
        return "joyo"
    if grade in _JINMEI_GRADES:
        return "jinmei"
    return None


def build(
    out_path: Path,
    radicals: Dict[str, Tuple[int, int]],
    kanjidic: Kanjidic,
    overrides: Iterable[Tuple[str, str, int, Optional[str]]],
    unicode_version: Optional[str],
    non_kanji: Iterable[NonKanjiRow] = (),
    schema_path: Path = DATA_DIR / "schema.sql",
) -> Dict[str, int]:
    """DB を作り直す。件数のまとめを返す。"""
    if out_path.exists():
        out_path.unlink()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    entries = sorted(kanjidic.entries, key=lambda e: ord(e.char[0]) if len(e.char) == 1 else sys.maxsize)
    known = {e.char for e in entries}
    stats = {
        "kanji": 0,
        "name_ok": 0,
        "no_radical": 0,
        "reading": 0,
        "alt_stroke": 0,
        "variant": 0,
        "non_kanji": 0,
        "override": 0,
    }

    con = sqlite3.connect(str(out_path))
    try:
        con.executescript(schema_path.read_text(encoding="utf-8"))
        meta = {
            "schema_version": "1",
            "unicode_version": unicode_version or "",
            "kanjidic2_database_version": kanjidic.database_version or "",
            "kanjidic2_date_of_creation": kanjidic.date_of_creation or "",
        }
        con.executemany("INSERT INTO meta VALUES (?, ?)", sorted(meta.items()))

        for e in entries:
            if len(e.char) != 1:
                continue
            rs = radicals.get(e.char)
            if rs is None:
                stats["no_radical"] += 1
            category = category_for(e.grade)
            con.execute(
                "INSERT INTO kanji VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    e.char,
                    ord(e.char),
                    rs[0] if rs else None,
                    kangxi_strokes(*rs) if rs else None,
                    e.strokes[0] if e.strokes else None,
                    category,
                    e.grade,
                    1 if category else 0,
                    "; ".join(e.meanings_en) or None,
                ),
            )
            stats["kanji"] += 1
            stats["name_ok"] += 1 if category else 0

            counters: Dict[str, int] = {}
            for kind, raw in e.readings:
                ord_ = counters.get(kind, 0)
                counters[kind] = ord_ + 1
                kana, stem = normalize_reading(raw)
                con.execute("INSERT INTO reading VALUES (?, ?, ?, ?, ?, ?)", (e.char, kind, raw, kana, stem, ord_))
                stats["reading"] += 1

            for s in sorted(set(e.strokes[1:]) - {e.strokes[0]} if e.strokes else []):
                con.execute("INSERT INTO alt_stroke VALUES (?, ?)", (e.char, s))
                stats["alt_stroke"] += 1

            variants = set()
            for var_type, value in e.variant_codes:
                target = kanjidic.code_to_char.get(f"{var_type}:{value.lower()}")
                if target and target != e.char and target in known:
                    variants.add(target)
            for v in sorted(variants, key=ord):
                con.execute("INSERT INTO variant VALUES (?, ?)", (e.char, v))
                stats["variant"] += 1

        for row in sorted(non_kanji, key=lambda r: ord(r[0])):
            if row[0] in known:
                raise ValueError(f"non_kanji.csv: {row[0]} は KANJIDIC2 にもある字です")
            con.execute("INSERT INTO non_kanji VALUES (?, ?, ?, ?, ?, ?)", row)
            stats["non_kanji"] += 1

        for school, char, strokes, note in overrides:
            if char not in known:
                raise ValueError(f"overrides.csv: {char} は KANJIDIC2 にない字です")
            con.execute("INSERT INTO override VALUES (?, ?, ?, ?)", (school, char, strokes, note))
            stats["override"] += 1

        con.commit()
        con.execute("VACUUM")
    finally:
        con.close()
    return stats


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="KakuNote 同梱用の漢字データベースを作る")
    parser.add_argument("--unihan", type=Path, default=DATA_DIR / "sources" / "Unihan_IRGSources.txt")
    parser.add_argument("--kanjidic", type=Path, default=DATA_DIR / "sources" / "kanjidic2.xml.gz")
    parser.add_argument("--overrides", type=Path, default=DATA_DIR / "overrides.csv")
    parser.add_argument("--non-kanji", type=Path, default=DATA_DIR / "non_kanji.csv")
    parser.add_argument("--out", type=Path, default=DATA_DIR / "build" / "kanji.sqlite")
    args = parser.parse_args(argv)

    for path in (args.unihan, args.kanjidic, args.overrides, args.non_kanji):
        if not path.exists():
            print(f"エラー: {path} が見つかりません（build_db.py の先頭の説明を参照）", file=sys.stderr)
            return 1

    radicals, unicode_version = load_unihan_radicals(args.unihan)
    opener = gzip.open if args.kanjidic.suffix == ".gz" else open
    with opener(args.kanjidic, "rb") as f:
        kanjidic = parse_kanjidic(f)
    overrides = load_overrides(args.overrides)
    non_kanji = load_non_kanji(args.non_kanji)

    stats = build(args.out, radicals, kanjidic, overrides, unicode_version, non_kanji)
    print(f"保存先: {args.out}")
    print(f"Unicode {unicode_version} / KANJIDIC2 {kanjidic.database_version}")
    for key, value in stats.items():
        print(f"  {key}: {value}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
