# -*- coding: utf-8 -*-
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def col_letter(cell_ref: str) -> str:
    return "".join(c for c in cell_ref if c.isalpha())


def load_shared(z: zipfile.ZipFile) -> list[str]:
    shared: list[str] = []
    if "xl/sharedStrings.xml" not in z.namelist():
        return shared
    ss = ET.fromstring(z.read("xl/sharedStrings.xml"))
    for si in ss.findall("m:si", NS):
        texts: list[str] = []
        for t in si.iter("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t"):
            if t.text:
                texts.append(t.text)
        shared.append("".join(texts))
    return shared


def cell_value(c, shared: list[str]) -> str:
    t = c.get("t")
    v = c.find("m:v", NS)
    is_elem = c.find("m:is", NS)
    if t == "s" and v is not None and v.text:
        return shared[int(v.text)]
    if v is not None and v.text:
        return v.text
    if is_elem is not None:
        ts = [
            x.text or ""
            for x in is_elem.iter(
                "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t"
            )
        ]
        return "".join(ts)
    return ""


def main() -> None:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else r"D:\WDP301-SE1824-SU26.xlsx")
    with zipfile.ZipFile(path) as z:
        wb = ET.fromstring(z.read("xl/workbook.xml"))
        sheets = [sh.get("name") for sh in wb.findall(".//m:sheet", NS)]
        print("FILE:", path)
        print("SHEETS:", sheets)
        shared = load_shared(z)
        root = ET.fromstring(z.read("xl/worksheets/sheet1.xml"))
        rows = root.findall(".//m:sheetData/m:row", NS)
        print("TOTAL_ROWS:", len(rows))
        print()
        keys = list("ABCDEFGHIJKLM")
        for row in rows[:15]:
            r_idx = row.get("r")
            by_col: dict[str, str] = {}
            for c in row.findall("m:c", NS):
                ref = c.get("r", "")
                by_col[col_letter(ref)] = cell_value(c, shared)
            parts = [f"{k}={by_col.get(k, '')[:70]}" for k in keys if by_col.get(k, "")]
            print(f"Row{r_idx}:", " | ".join(parts))
        print()
        # sample data rows 4-8
        print("--- Sample topic rows (4-7) ---")
        for row in rows[3:7]:
            r_idx = row.get("r")
            by_col = {}
            for c in row.findall("m:c", NS):
                ref = c.get("r", "")
                by_col[col_letter(ref)] = cell_value(c, shared)
            code = by_col.get("B", "")
            name = by_col.get("C", "")
            submitter = by_col.get("D", "")
            print(f"  #{by_col.get('A','')} | {code} | {name[:80]} | by {submitter}")


if __name__ == "__main__":
    main()
