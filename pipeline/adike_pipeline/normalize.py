"""Map raw market/variety names to ids, convert units, parse dates."""
from __future__ import annotations

import re
from datetime import date

from . import config
from .models import PriceRow, RawRow
from .util import kn_digits_to_ascii, parse_date


def _clean(s: str | None) -> str:
    if not s:
        return ""
    s = kn_digits_to_ascii(s).lower().strip()
    s = re.sub(r"\s+", " ", s)
    return s


def slug(s: str | None) -> str:
    s = _clean(s)
    s = re.sub(r"[^0-9a-zಀ-೿]+", "_", s).strip("_")
    return s or "unknown"


class Normalizer:
    def __init__(self, markets: list[dict], varieties: list[dict],
                 extra_aliases: dict | None = None):
        self.markets = {m["id"]: m for m in markets}
        self.varieties = {v["id"]: v for v in varieties}
        self.market_alias: dict[str, str] = {}
        for m in markets:
            for a in [m["id"], m["en"], m["kn"], *m.get("aliases", [])]:
                self.market_alias[_clean(a)] = m["id"]
        self.variety_alias: dict[tuple[str, str], str] = {}
        for v in varieties:
            for a in [v["id"], v["en"], v["kn"], *v.get("aliases", [])]:
                self.variety_alias[(v["crop"], _clean(a))] = v["id"]
        extra = extra_aliases or {}
        for alias, mid in (extra.get("markets") or {}).items():
            self.market_alias[_clean(alias)] = mid
        for crop, amap in (extra.get("varieties") or {}).items():
            for alias, vid in amap.items():
                self.variety_alias[(crop, _clean(alias))] = vid

    def market_id(self, raw: str | None) -> str | None:
        c = _clean(raw)
        if not c:
            return None
        if c in self.market_alias:
            return self.market_alias[c]
        # "Puttur APMC", "Shimoga(Theerthahalli)" style: try tokens / bracket content
        for part in re.split(r"[()/,\-]| apmc| market| mandi", c):
            p = part.strip()
            if p in self.market_alias:
                return self.market_alias[p]
        return None

    def variety_id(self, crop: str, raw: str | None) -> str | None:
        c = _clean(raw)
        if not c:
            return None
        if (crop, c) in self.variety_alias:
            return self.variety_alias[(crop, c)]
        c2 = re.sub(r"[()\[\]]", " ", c)
        c2 = re.sub(r"\s+", " ", c2).strip()
        return self.variety_alias.get((crop, c2))


def unit_factor(crop: str, unit_raw: str | None) -> tuple[float, bool]:
    """Factor to convert a value in unit_raw to the canonical unit for the crop.

    Returns (factor, known). Arecanut canonical ₹/quintal, rubber canonical ₹/kg.
    """
    u = _clean(unit_raw).replace(" ", "")
    if not u:
        return 1.0, False
    per_kg = bool(re.search(r"(/|per)(1)?kg$|/kilo|perkilo|ಕೆಜಿ$|ಕಿಲೋ", u)) and "100" not in u
    per_100kg = bool(re.search(r"100kg|quintal|qtl|ಕ್ವಿಂಟಾಲ್|ಕ್ವಿಂ", u))
    if crop == "arecanut":
        if per_kg:
            return 100.0, True
        if per_100kg:
            return 1.0, True
    elif crop == "rubber":
        if per_100kg:
            return 0.01, True
        if per_kg:
            return 1.0, True
    return 1.0, False


def normalize(raw: RawRow, norm: Normalizer, trust: str, collected_time: str,
              default_crop: str | None = None, default_market: str | None = None
              ) -> tuple[PriceRow | None, list[str]]:
    """Returns (row, flags). row is None when the row is unusable (no crop / no numbers / no date)."""
    flags: list[str] = []
    crop = (raw.crop or default_crop or "").lower()
    if crop and crop not in ("arecanut", "rubber"):
        return None, ["unknown_crop"]  # another commodity (pepper, …)
    if not crop:
        # infer from an unambiguous variety name (e.g. "RSS-4" -> rubber)
        hits = {c for c in ("arecanut", "rubber") if norm.variety_id(c, raw.variety_raw)}
        if len(hits) != 1:
            return None, ["unknown_crop"]
        crop = hits.pop()
    if raw.min is None and raw.max is None and raw.modal is None:
        return None, ["no_values"]

    market = norm.market_id(raw.market_raw)
    if market is None:
        if raw.market_raw:
            flags.append("unknown_market")
            market = slug(raw.market_raw)
        elif default_market:
            market = default_market
        else:
            flags.append("unknown_market")
            market = "unknown"

    variety = norm.variety_id(crop, raw.variety_raw)
    if variety is None:
        flags.append("unknown_variety")
        variety = slug(raw.variety_raw)

    if raw.via == "api":
        factor, known = (0.01 if crop == "rubber" else 1.0), True  # data.gov.in is ₹/quintal
        if raw.unit_raw:
            factor, known = unit_factor(crop, raw.unit_raw)
    else:
        factor, known = unit_factor(crop, raw.unit_raw)
        if not known:
            flags.append("unit_unknown")

    def conv(v: float | None) -> float | None:
        return None if v is None else round(v * factor, 2)

    d = parse_date(raw.date_raw)
    if d is None:
        flags.append("date_missing")
        d = date.fromisoformat(collected_time[:10]) if len(collected_time) >= 10 else None
        if d is None:
            return None, flags
    row = PriceRow(crop=crop, variety=variety, marketId=market, sourceId=raw.sourceId,
                   trust=trust, min=conv(raw.min), max=conv(raw.max), modal=conv(raw.modal),
                   unit=config.CANONICAL_UNIT[crop], date=d.isoformat(),
                   time=raw.time or collected_time[11:16], confidence=raw.confidence)
    return row, flags
