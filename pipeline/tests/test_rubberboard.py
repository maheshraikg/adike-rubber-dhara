"""Rubber Board public page -> deterministic rows (no AI)."""
from pathlib import Path

from adike_pipeline.normalize import normalize
from adike_pipeline.sources import rubberboard
from adike_pipeline.sources.web import html_to_text

HTML = (Path(__file__).parent / "fixtures" / "rubberboard_public.html").read_text()
URL = "https://rubberboard.gov.in/public"


def test_parses_inr_box_only():
    rows = rubberboard.parse_text(html_to_text(HTML), "2026-09-29T11:30", URL)
    got = {r.variety_raw: r.modal for r in rows}
    assert got == {"RSS-4": 291.70, "RSS-5": 285.45, "ISNR-20": 274.00, "Latex (60% DRC)": 212.50}
    r = rows[0]
    assert r.market_raw == "Kottayam" and r.unit_raw == "₹/kg" and r.via == "api"
    assert r.date_raw == "2026-09-29" and r.note == "dated by collection day"
    assert r.min is None and r.max is None  # only the single printed figure is used


def test_uses_printed_date_when_present():
    html = HTML.replace("Daily Rubber Prices", "Daily Rubber Prices as on 28-09-2026")
    rows = rubberboard.parse_text(html_to_text(html), "2026-09-29T11:30", URL)
    assert rows and all(r.date_raw == "28-09-2026" and r.note is None for r in rows)


def test_no_rupee_box_gives_no_rows():
    assert rubberboard.parse_text("Welcome to Rubber Board. RSS4 news", "2026-09-29T11:30", URL) == []


def test_rows_normalize_to_known_ids(normalizer):
    rows = rubberboard.parse_text(html_to_text(HTML), "2026-09-29T11:30", URL)
    out = {}
    for raw in rows:
        row, flags = normalize(raw, normalizer, "official", "2026-09-29T11:30")
        assert flags == []
        out[row.variety] = (row.marketId, row.modal, row.unit)
    assert out["rss4"] == ("kottayam", 291.70, out["rss4"][2])
    assert set(out) == {"rss4", "rss5", "isnr20", "latex60"}
