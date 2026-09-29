from adike_pipeline.models import RawRow
from adike_pipeline.normalize import normalize, unit_factor
from adike_pipeline.util import parse_date, parse_number

T = "2026-09-29T11:30"


def raw(**kw):
    base = dict(sourceId="x", crop="arecanut", market_raw="Puttur", variety_raw="Rashi",
                min=50000, max=53000, modal=52000, date_raw="29/09/2026", via="ai", unit_raw="Rs/Quintal",
                confidence=0.95)
    base.update(kw)
    return RawRow(**base)


def test_unit_conversion_rubber_per_100kg_to_kg(normalizer):
    r, flags = normalize(raw(crop="rubber", variety_raw="RSS 4", unit_raw="Rs/100 kg",
                             min=18800, max=19200, modal=19000), normalizer, "official", T)
    assert (r.min, r.max, r.modal, r.unit) == (188, 192, 190, "INR/kg")
    assert r.variety == "rss4"
    assert flags == []


def test_unit_conversion_arecanut_per_kg_to_quintal(normalizer):
    r, _ = normalize(raw(unit_raw="₹/kg", min=500, max=530, modal=520), normalizer, "partner", T)
    assert (r.min, r.max, r.modal, r.unit) == (50000, 53000, 52000, "INR/quintal")


def test_unit_factor_table():
    assert unit_factor("rubber", "per quintal") == (0.01, True)
    assert unit_factor("rubber", "Rs/Kg") == (1.0, True)
    assert unit_factor("arecanut", "Rs./Qtl") == (1.0, True)
    assert unit_factor("arecanut", None) == (1.0, False)


def test_api_rows_are_per_quintal(normalizer):
    r, flags = normalize(raw(crop="rubber", variety_raw="RSS-4", unit_raw=None, via="api",
                             min=18800, max=19200, modal=19000, confidence=None), normalizer, "official", T)
    assert r.modal == 190 and flags == []


def test_unknown_variety_and_market_flagged(normalizer):
    r, flags = normalize(raw(market_raw="Mudigere", variety_raw="Super Gold"), normalizer, "official", T)
    assert "unknown_market" in flags and "unknown_variety" in flags
    assert r.marketId == "mudigere" and r.variety == "super_gold"


def test_aliases_and_kannada(normalizer):
    assert normalizer.market_id("Shimoga") == "shivamogga"
    assert normalizer.market_id("ಪುತ್ತೂರು") == "puttur"
    assert normalizer.market_id("Puttur APMC") == "puttur"
    assert normalizer.variety_id("arecanut", "ಹೊಸ ಚಾಲಿ") == "chali_new"
    assert normalizer.variety_id("arecanut", "New Variety") == "chali_new"
    assert parse_number("೫೨,೫೦೦") == 52500
    assert parse_number("₹ 52,500.00") == 52500
    assert parse_number("") is None
    assert str(parse_date("೨೯/೦೯/೨೦೨೬")) == "2026-09-29"


def test_unit_unknown_flag_for_ai_rows(normalizer):
    _, flags = normalize(raw(unit_raw=None), normalizer, "partner", T)
    assert "unit_unknown" in flags


def test_rows_without_values_or_crop_are_dropped(normalizer):
    assert normalize(raw(min=None, max=None, modal=None), normalizer, "official", T)[0] is None
    assert normalize(raw(crop="pepper"), normalizer, "official", T)[0] is None


def test_crop_inferred_from_variety(normalizer):
    r, _ = normalize(raw(crop=None, variety_raw="RSS-4", market_raw="Kottayam", unit_raw="Rs/kg",
                         min=188, max=192, modal=190), normalizer, "partner", T)
    assert r.crop == "rubber" and r.variety == "rss4"
    assert normalize(raw(crop=None, variety_raw="Mystery"), normalizer, "partner", T)[0] is None
