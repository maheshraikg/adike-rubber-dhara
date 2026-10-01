"""Rubber Board public page -> deterministic rows (no AI)."""
from pathlib import Path

from adike_pipeline.normalize import normalize
from adike_pipeline.sources import rubberboard

HTML = (Path(__file__).parent / "fixtures" / "rubberboard_public.html").read_text()
URL = "https://rubberboard.gov.in/public"
T = "2026-10-01T11:30"


def parse(html=HTML):
    return rubberboard.parse_text(rubberboard.page_text(html), T, URL)


def test_rupee_column_per_market_tab():
    got = {(r.market_raw, r.variety_raw): r.modal for r in parse()}
    assert got == {
        ("kottayam", "RSS-4"): 28000.0, ("kottayam", "RSS-5"): 27400.0,
        ("kottayam", "ISNR-20"): 26300.0, ("kottayam", "Latex (60% DRC)"): 20395.0,
        ("kochi", "RSS-4"): 28000.0, ("kochi", "RSS-5"): 27400.0,
    }  # dollar column ignored; Agartala skipped (not one of our markets)
    r = parse()[0]
    assert r.unit_raw == "₹/100kg" and r.via == "api" and r.min is None and r.max is None
    assert r.date_raw == "30-09-2026" and r.note is None


def test_english_layout():
    html = (HTML.replace("देशी बाज़ार", "Domestic market").replace("को प्रति 100 कि.ग्रा.", "per 100 Kg")
            .replace("कोट्टयम", "Kottayam").replace("कोच्ची", "Kochi").replace("अगरतला", "Agartala")
            .replace("इंडियन रुपये", "Indian Rupees").replace("अमरीकी डॉलर", "US Dollar"))
    rows = parse(html)
    assert len(rows) == 6 and {r.market_raw for r in rows} == {"kottayam", "kochi"}


def test_no_printed_date_uses_collection_day():
    rows = parse(HTML.replace("<span>30-09-2026</span>", ""))
    assert rows and all(r.date_raw == "2026-10-01" and r.note == "dated by collection day" for r in rows)


def test_unrecognised_page_gives_no_rows():
    assert parse("<p>Welcome to Rubber Board. RSS4 news</p>") == []
    # figures without the per-100-kg header are not guessed at
    assert parse(HTML.replace("प्रति 100 कि.ग्रा.", "")) == []
    # a tab without its table: positions would no longer match markets
    assert parse(HTML.replace("<li>अगरतला</li>", "<li>अगरतला</li><li>Kochi</li>")) == []


def test_rows_normalize_to_rupees_per_kg(normalizer):
    out = {}
    for raw in parse():
        row, flags = normalize(raw, normalizer, "official", T)
        assert flags == []
        out[(row.marketId, row.variety)] = (row.modal, row.date)
    assert out[("kottayam", "rss4")] == (280.0, "2026-09-30")
    assert out[("kottayam", "latex60")] == (203.95, "2026-09-30")
    assert set(out) == {("kottayam", "rss4"), ("kottayam", "rss5"), ("kottayam", "isnr20"),
                        ("kottayam", "latex60"), ("kochi", "rss4"), ("kochi", "rss5")}
