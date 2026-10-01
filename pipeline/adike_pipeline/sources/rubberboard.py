"""Rubber Board (rubberboard.gov.in/public) daily domestic rubber prices.

The public page carries a small "Indian Rupees ₹" box with the Board's daily
Kottayam rates in ₹/kg:  RSS4 291.70  RSS5 285.45  ISNR20 274.00  Latex(60%) 212.50
Deterministic parsing, no AI. Only the figures printed on the page are used.
"""
from __future__ import annotations

import re
from typing import Optional

from ..models import RawRow
from ..util import Fetcher, log_event, parse_date
from .web import html_to_text

SOURCE_ID = "rubberboard_daily"

# grade label as printed -> name the normalizer knows (data/varieties.json aliases)
_GRADE_RX = re.compile(
    r"\b(?P<grade>RSS\s*-?\s*[45]|ISNR\s*-?\s*20|Latex\s*\(?\s*60\s*%?\s*(?:DRC)?\s*\)?)"
    r"\s*[:\-–]?\s*(?:₹|Rs\.?)?\s*(?P<value>\d{2,4}(?:,\d{3})*(?:\.\d{1,2})?)\b",
    re.I,
)
_RUPEE_RX = re.compile(r"₹|indian\s+rupees?|rupees|रुपये|ರೂಪಾಯಿ", re.I)
_DATE_RX = re.compile(r"\b(\d{1,2}[./-]\d{1,2}[./-]\d{4}|\d{4}-\d{2}-\d{2}|\d{1,2}[ -][A-Za-z]{3}[ -]\d{4})\b")


def _grade_name(g: str) -> str:
    g = re.sub(r"\s+", "", g).upper()
    if g.startswith("RSS"):
        return "RSS-" + g[-1]
    if g.startswith("ISNR"):
        return "ISNR-20"
    return "Latex (60% DRC)"


def _page_date(text: str, start: int, end: int) -> Optional[str]:
    """A date printed next to the rate box (within ~300 characters), if any."""
    window = text[max(0, start - 300): end + 300]
    for m in _DATE_RX.finditer(window):
        if parse_date(m.group(1)):
            return m.group(1)
    return None


def parse_text(text: str, collected_time: str, url: str) -> list[RawRow]:
    """Rows for the first RSS-4/RSS-5/ISNR-20/Latex figures after the rupee marker.

    Later boxes on the page (international prices in other currencies) are ignored
    because only the first occurrence of each grade after "₹" is taken.
    """
    m = _RUPEE_RX.search(text)
    if not m:
        return []
    body = text[m.start():]
    found: dict[str, tuple[float, int, int]] = {}
    for g in _GRADE_RX.finditer(body):
        name = _grade_name(g.group("grade"))
        if name in found:
            continue
        found[name] = (float(g.group("value").replace(",", "")), g.start(), g.end())
        if len(found) == 4:
            break
    if not found:
        return []
    start = min(s for _, s, _ in found.values()) + m.start()
    end = max(e for _, _, e in found.values()) + m.start()
    page_date = _page_date(text, start, end)
    excerpt = text[max(0, start - 120): end + 120]
    rows = []
    for name, (value, _, _) in found.items():
        rows.append(RawRow(
            sourceId=SOURCE_ID, crop="rubber", market_raw="Kottayam", variety_raw=name,
            modal=value, unit_raw="₹/kg",
            # The box shows the current day's rates; when it prints no date the
            # collection day (IST) is used and noted on the row.
            date_raw=page_date or collected_time[:10],
            note=None if page_date else "dated by collection day",
            via="api", time=collected_time[11:16], sourceUrl=url, rawExcerpt=excerpt,
        ))
    return rows


def collect(fetcher: Fetcher, source: dict, collected_time: str) -> tuple[list[RawRow], str]:
    url = source["url"]
    r = fetcher.get(SOURCE_ID, url)
    text = html_to_text(r.text)
    rows = parse_text(text, collected_time, url)
    log_event("rubberboard.parsed", rows=len(rows), dated=bool(rows and rows[0].note is None))
    return rows, text
