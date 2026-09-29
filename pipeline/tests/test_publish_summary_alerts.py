from datetime import date, timedelta

from adike_pipeline.alerts import best_row, evaluate, maybe_send_summary, should_fire
from adike_pipeline.models import PriceRow
from adike_pipeline.publish import Publisher, prune_raw, trust_score, update_source_stats
from adike_pipeline.store import MemoryStore
from adike_pipeline.summary import build_summary, inr

TODAY = date(2026, 9, 29)


def pr(d, modal, **kw):
    base = dict(crop="arecanut", variety="rashi", marketId="shivamogga", sourceId="datagov_mandi",
                trust="official", min=modal - 1000, max=modal + 1000, modal=modal, unit="INR/quintal",
                date=d, time="11:30")
    base.update(kw)
    return PriceRow(**base)


def test_history_append_dedupe_trim_and_change(tmp_path, config_dir):
    p = Publisher(tmp_path, config_dir, TODAY)
    old = (TODAY - timedelta(days=500)).isoformat()
    p.append_history([pr(old, 40000), pr("2026-09-28", 50000), pr("2026-09-28", 50500)])
    s = p.history("arecanut", "shivamogga")["series"]["datagov_mandi|rashi"]
    assert s == [["2026-09-28", 49500, 51500, 50500]]  # old trimmed, same date replaced
    today = pr("2026-09-29", 52525)
    assert p.publish([today], None, "2026-09-29T11:30", [])
    latest = p.build_latest([], None, "x")
    row = latest["rows"][0] if latest["rows"] else None
    p2 = Publisher(tmp_path, config_dir, TODAY)
    row = p2.prev_latest["rows"][0]
    assert row["modal"] == 52525 and row["change"] == 2025 and row["changePct"] == 4.01
    assert row["varietyLabel_kn"] == "ರಾಶಿ"
    # re-publishing identical data changes nothing (ETag stays)
    p3 = Publisher(tmp_path, config_dir, TODAY)
    assert not p3.publish([today], None, "2026-09-29T17:30", [])


def test_latest_drops_rows_older_than_7_days(tmp_path, config_dir):
    p = Publisher(tmp_path, config_dir, TODAY)
    p.publish([pr("2026-09-10", 50000)], None, "t", [])
    p2 = Publisher(tmp_path, config_dir, TODAY)
    assert p2.build_latest([], None, "t")["rows"] == []


def test_prune_raw(tmp_path):
    (tmp_path / "raw" / "2026-05-01").mkdir(parents=True)
    (tmp_path / "raw" / "2026-09-01").mkdir(parents=True)
    assert prune_raw(tmp_path, TODAY) == ["2026-05-01"]
    assert (tmp_path / "raw" / "2026-09-01").exists()


def test_trust_scores():
    state = {}
    assert trust_score(None, "partner") == 0.5
    for _ in range(4):
        update_source_stats(state, "p", True, True, [True, True])
    update_source_stats(state, "p", False, None, [False])
    st = state["sources"]["p"]
    assert st["failStreak"] == 1
    assert trust_score(st, "partner") == round((8 / 9 + 1) / 2, 2)
    assert trust_score({"runs": 10, "okRuns": 9}, "official") == 0.9


def test_inr_format():
    assert inr(123456) == "₹1,23,456"
    assert inr(52500) == "₹52,500"
    assert inr(190.5) == "₹190.50"
    assert inr(12345678) == "₹1,23,45,678"


def test_template_summary_without_ai():
    rows = [dict(crop="arecanut", variety="rashi", varietyLabel_kn="ರಾಶಿ", varietyLabel_en="Rashi",
                 marketId="shivamogga", trust="official", modal=52500, date="2026-09-29", changePct=1.2),
            dict(crop="rubber", variety="rss4", varietyLabel_kn="ಆರ್‌ಎಸ್‌ಎಸ್-4", varietyLabel_en="RSS-4",
                 marketId="kottayam", trust="official", modal=190, date="2026-09-29", changePct=None)]
    s = build_summary(rows, "2026-09-29", {"shivamogga": {"kn": "ಶಿವಮೊಗ್ಗ", "en": "Shivamogga"}}, None, "t")
    assert s["source"] == "template" and s["evening"]
    assert "₹52,500" in s["en"] and "Shivamogga" in s["en"] and "▲1.2%" in s["kn"]
    assert "RSS-4" in s["en"]


def latest_rows():
    return [dict(crop="arecanut", variety="rashi", marketId="shivamogga", trust="official",
                 modal=52500, date="2026-09-29"),
            dict(crop="arecanut", variety="rashi", marketId="shivamogga", trust="partner",
                 modal=53000, date="2026-09-29")]


def test_best_row_prefers_official_and_fire_rules():
    r = best_row(latest_rows(), "arecanut", "rashi", "shivamogga")
    assert r["trust"] == "official"
    assert should_fire({"condition": "above", "value": 52000}, r, "2026-09-29")
    assert not should_fire({"condition": "below", "value": 52000}, r, "2026-09-29")
    assert not should_fire({"condition": "above", "value": 52000, "lastFiredDate": "2026-09-29"}, r, "2026-09-29")


def test_evaluate_fires_once_and_deactivates_bad_tokens():
    store = MemoryStore({
        "alerts/a1": {"active": True, "crop": "arecanut", "variety": "rashi", "marketId": "shivamogga",
                      "condition": "above", "value": 50000, "fcmToken": "good", "uid": "u1"},
        "alerts/a2": {"active": True, "crop": "arecanut", "variety": "rashi", "marketId": "shivamogga",
                      "condition": "above", "value": 50000, "fcmToken": "dead", "uid": "u2"},
        "alerts/a3": {"active": False, "crop": "arecanut", "variety": "rashi", "marketId": "shivamogga",
                      "condition": "above", "value": 1, "fcmToken": "x", "uid": "u3"},
    })
    sent = []

    def send(m):
        sent.append(m)
        return "UNREGISTERED" if m.get("token") == "dead" else None
    res = evaluate(store, {"rows": latest_rows()}, send, "2026-09-29", {}, {})
    assert res == {"fired": 1, "skipped": 0, "deactivated": 1}
    assert store.docs["alerts/a1"]["lastFiredDate"] == "2026-09-29"
    assert store.docs["alerts/a2"]["active"] is False
    res = evaluate(store, {"rows": latest_rows()}, send, "2026-09-29", {}, {})
    assert res["fired"] == 0


def test_summary_sent_once_per_day():
    store = MemoryStore()
    latest = {"summary": {"date": "2026-09-29", "evening": True, "kn": "ಸಾಲು1\nಸಾಲು2", "en": "x"}}
    sent = []
    assert maybe_send_summary(store, latest, lambda m: sent.append(m), "2026-09-29")
    assert not maybe_send_summary(store, latest, lambda m: sent.append(m), "2026-09-29")
    assert sent[0]["topic"] == "daily_summary" and sent[0]["body"] == "ಸಾಲು1"
