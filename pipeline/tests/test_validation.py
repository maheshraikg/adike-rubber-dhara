from datetime import date

from adike_pipeline.models import PriceRow
from adike_pipeline.validation import merged_config, sanity_ok, validate

TODAY = date(2026, 9, 29)


def row(**kw):
    base = dict(crop="arecanut", variety="rashi", marketId="shivamogga", sourceId="datagov_mandi",
                trust="official", min=50000, max=53500, modal=52500, unit="INR/quintal",
                date="2026-09-29", time="11:30")
    base.update(kw)
    return PriceRow(**base)


def test_clean_row_has_no_flags():
    r, flags = validate(row(), {}, TODAY)
    assert flags == []
    assert sanity_ok(r)


def test_min_max_swapped_and_flagged():
    r, flags = validate(row(min=57000, max=54000, modal=55500), {}, TODAY)
    assert (r.min, r.max) == (54000, 57000)
    assert "min_max_swapped" in flags
    assert "modal_out_of_range" not in flags


def test_modal_missing_is_flagged_not_invented():
    r, flags = validate(row(modal=None), {}, TODAY)
    assert r.modal is None
    assert "modal_missing" in flags
    assert not sanity_ok(r)


def test_modal_outside_min_max():
    _, flags = validate(row(modal=60000), {}, TODAY)
    assert "modal_out_of_range" in flags


def test_range_check_arecanut_and_rubber():
    _, flags = validate(row(min=400, max=600, modal=500), {}, TODAY)
    assert "out_of_range" in flags
    rub = row(crop="rubber", variety="rss4", unit="INR/kg", min=18000, max=19000, modal=18500)
    _, flags = validate(rub, {}, TODAY)
    assert "out_of_range" in flags
    rub_ok = row(crop="rubber", variety="rss4", unit="INR/kg", min=188, max=192, modal=190)
    assert validate(rub_ok, {}, TODAY)[1] == []


def test_range_uses_config_override():
    _, flags = validate(row(), {"arecanut": {"maxQtl": 50000}}, TODAY)
    assert "out_of_range" in flags


def test_big_daily_change():
    _, flags = validate(row(), {}, TODAY, last_published_modal=45000)  # +16.7%
    assert "big_change" in flags
    _, flags = validate(row(), {}, TODAY, last_published_modal=50000)  # +5%
    assert "big_change" not in flags


def test_cross_source_difference_only_for_non_official():
    partner = row(sourceId="campco", trust="partner", modal=52500)
    _, flags = validate(partner, {}, TODAY, official_modal=46000)
    assert "cross_source_diff" in flags
    _, flags = validate(partner, {}, TODAY, official_modal=51000)
    assert "cross_source_diff" not in flags
    _, flags = validate(row(), {}, TODAY, official_modal=46000)
    assert "cross_source_diff" not in flags


def test_dates():
    assert "future_date" in validate(row(date="2026-09-30"), {}, TODAY)[1]
    assert "stale_date" in validate(row(date="2026-09-25"), {}, TODAY)[1]
    assert validate(row(date="2026-09-26"), {}, TODAY)[1] == []


def test_low_ai_confidence():
    assert "low_confidence" in validate(row(confidence=0.6), {}, TODAY)[1]
    assert validate(row(confidence=0.95), {}, TODAY)[1] == []


def test_merged_config_keeps_defaults():
    c = merged_config({"arecanut": {"minQtl": 1}, "maxDailyChangePct": 5})
    assert c["arecanut"] == {"minQtl": 1, "maxQtl": 150000}
    assert c["maxDailyChangePct"] == 5
    assert c["maxCrossSourceDiffPct"] == 10
