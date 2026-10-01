"""Rubber Board (rubberboard.gov.in/public) daily domestic rubber prices.

The public page has a "domestic market" box (English or Hindi, depending on the
site's language), dated and quoted per 100 kg, with one table per market tab:

    Domestic market 30-09-2026 per 100 Kg | Kottayam | Kochi | Agartala
    Grade | Indian Rupees ₹ | US Dollar $
    RSS4 | 28000.0 | 291.70
    RSS5 | 27400.0 | 285.45 ...
    Grade | Indian Rupees ₹ | US Dollar $        <- next tab (Kochi)
    ...

Only the rupee column is used (₹/100 kg; converted to ₹/kg by normalize).
Deterministic parsing, no AI. Only the figures printed on the page are used.
"""
from __future__ import annotations

import re

from bs4 import BeautifulSoup

from ..models import RawRow
from ..util import Fetcher, log_event, parse_date

SOURCE_ID = "rubberboard_daily"

_GRADE = r"RSS\s*-?\s*[1-5]|ISNR\s*-?\s*20|Latex\s*\(?\s*60\s*%?\s*(?:DRC)?\s*\)?"
_NUM = r"\d[\d,]*(?:\.\d+)?"
# grade line, rupee figure line, dollar figure line
_ROW_RX = re.compile(rf"^\s*(?P<grade>{_GRADE})\s*\n\s*(?P<inr>{_NUM})\s*\n\s*(?P<usd>{_NUM})\s*$",
                     re.I | re.M)
_DATE_RX = re.compile(r"\b(\d{1,2}[./-]\d{1,2}[./-]\d{4}|\d{4}-\d{2}-\d{2})\b")
_PER_100 = re.compile(r"100\s*(?:kg|कि|ಕೆ)", re.I)

# market tab labels as printed (en / hi / ml / kn) -> market id in data/markets.json.
# Tabs not listed here (e.g. Agartala) are skipped.
MARKET_TABS = {
    "kottayam": "kottayam", "कोट्टयम": "kottayam", "കോട്ടയം": "kottayam", "ಕೊಟ್ಟಾಯಂ": "kottayam",
    "kochi": "kochi", "cochin": "kochi", "कोच्ची": "kochi", "कोचीन": "kochi", "കൊച്ചി": "kochi",
    "ಕೊಚ್ಚಿ": "kochi",
}
_TAB_RX = re.compile(r"kottayam|kochi|cochin|agartala|कोट्टयम|कोच्ची|कोचीन|अगरतला|കോട്ടയം|കൊച്ചി|"
                     r"ಕೊಟ್ಟಾಯಂ|ಕೊಚ್ಚಿ", re.I)


def page_text(html: str) -> str:
    """Visible text in document order, one element per line (keeps header/footer
    blocks and table order, unlike web.html_to_text)."""
    soup = BeautifulSoup(html, "html.parser")
    for t in soup(["script", "style", "noscript"]):
        t.decompose()
    return re.sub(r"\n{3,}", "\n\n", soup.get_text("\n", strip=True))


def _grade_name(g: str) -> str:
    g = re.sub(r"\s+", "", g).upper()
    if g.startswith("RSS"):
        return "RSS-" + g[-1]
    if g.startswith("ISNR"):
        return "ISNR-20"
    return "Latex (60% DRC)"


def _num(s: str) -> float:
    return float(s.replace(",", ""))


def parse_text(text: str, collected_time: str, url: str) -> list[RawRow]:
    """One row per (market tab, grade), rupee column only.

    Tables follow the order of the market tabs printed above them; a table ends
    where a grade repeats. Returns [] when the box is not recognisable (no tab
    names, no per-100-kg header, or tab and table counts differ), so a page redesign never yields guesses.
    """
    rows_m = list(_ROW_RX.finditer(text))
    if not rows_m:
        return []
    head = text[max(0, rows_m[0].start() - 600): rows_m[0].start()]
    if not _PER_100.search(head):
        return []
    tabs = [t.group(0).lower() for t in _TAB_RX.finditer(head)]
    if not tabs:
        return []
    dates = [d.group(1) for d in _DATE_RX.finditer(head) if parse_date(d.group(1))]
    page_date = dates[-1] if dates else None  # the last date before the tables is the box's own

    tables: list[list[re.Match]] = [[]]
    for m in rows_m:
        names = {_grade_name(x.group("grade")) for x in tables[-1]}
        if _grade_name(m.group("grade")) in names:
            tables.append([])
        tables[-1].append(m)

    if len(tabs) != len(tables):
        # tabs and tables no longer line up: matching by position could put a
        # price under the wrong market, so read nothing
        log_event("rubberboard.layout_mismatch", tabs=len(tabs), tables=len(tables))
        return []
    out: list[RawRow] = []
    for tab, table in zip(tabs, tables, strict=True):
        market = MARKET_TABS.get(tab)
        if not market or not table:
            continue
        excerpt = text[table[0].start(): table[-1].end()].replace("\n", " | ")
        for m in table:
            out.append(RawRow(
                sourceId=SOURCE_ID, crop="rubber", market_raw=market,
                variety_raw=_grade_name(m.group("grade")), modal=_num(m.group("inr")),
                unit_raw="₹/100kg",
                # When the box prints no date the collection day (IST) is used and noted.
                date_raw=page_date or collected_time[:10],
                note=None if page_date else "dated by collection day",
                via="api", time=collected_time[11:16], sourceUrl=url,
                rawExcerpt=f"{tab}: {excerpt}"[:600],
            ))
    return out


def collect(fetcher: Fetcher, source: dict, collected_time: str) -> tuple[list[RawRow], str]:
    url = source["url"]
    r = fetcher.get(SOURCE_ID, url)
    text = page_text(r.text)
    rows = parse_text(text, collected_time, url)
    log_event("rubberboard.parsed", rows=len(rows), markets=sorted({r.market_raw for r in rows}),
              dated=bool(rows and rows[0].note is None))
    return rows, text
