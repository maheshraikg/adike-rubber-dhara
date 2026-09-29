"""Pure validation rules. No I/O. Every rule is unit-tested in tests/test_validation.py.

The validator never invents a value: it may swap min/max (and flags it), but a
missing modal stays missing and is flagged.
"""
from __future__ import annotations

from datetime import date

from . import config
from .models import PriceRow


def merged_config(cfg: dict | None) -> dict:
    out = {k: (dict(v) if isinstance(v, dict) else v) for k, v in config.DEFAULT_VALIDATION.items()}
    for k, v in (cfg or {}).items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k].update(v)
        else:
            out[k] = v
    return out


def price_range(crop: str, cfg: dict) -> tuple[float, float]:
    if crop == "arecanut":
        return float(cfg["arecanut"]["minQtl"]), float(cfg["arecanut"]["maxQtl"])
    return float(cfg["rubber"]["minKg"]), float(cfg["rubber"]["maxKg"])


def pct_diff(a: float, b: float) -> float:
    if b == 0:
        return float("inf")
    return abs(a - b) / abs(b) * 100.0


def validate(row: PriceRow, cfg: dict, today: date,
             last_published_modal: float | None = None,
             official_modal: float | None = None) -> tuple[PriceRow, list[str]]:
    """Return a (possibly min/max-swapped) copy of row and the list of flags.

    last_published_modal: last published modal for the same source/market/crop/variety
        on an earlier date (for the daily-change rule).
    official_modal: modal from an official source for the same date/market/crop/variety
        (only used when row is not official).
    """
    cfg = merged_config(cfg)
    flags: list[str] = []
    r = row.model_copy()

    if r.min is not None and r.max is not None and r.min > r.max:
        r.min, r.max = r.max, r.min
        flags.append("min_max_swapped")

    if r.modal is None:
        flags.append("modal_missing")
    else:
        if (r.min is not None and r.modal < r.min) or (r.max is not None and r.modal > r.max):
            flags.append("modal_out_of_range")

    lo, hi = price_range(r.crop, cfg)
    for v in (r.min, r.max, r.modal):
        if v is not None and not (lo <= v <= hi):
            flags.append("out_of_range")
            break

    if r.modal is not None and last_published_modal:
        if pct_diff(r.modal, last_published_modal) > float(cfg["maxDailyChangePct"]):
            flags.append("big_change")

    if r.trust != "official" and r.modal is not None and official_modal:
        if pct_diff(r.modal, official_modal) > float(cfg["maxCrossSourceDiffPct"]):
            flags.append("cross_source_diff")

    d = date.fromisoformat(r.date)
    if d > today:
        flags.append("future_date")
    elif (today - d).days > config.MAX_DATE_AGE_DAYS:
        flags.append("stale_date")

    if r.confidence is not None and r.confidence < float(cfg.get("minAiConfidence", 0.8)):
        flags.append("low_confidence")

    return r, flags


def sanity_ok(row: PriceRow) -> bool:
    """Final invariant for anything we publish: min ≤ modal ≤ max where present."""
    vals = [v for v in (row.min, row.modal, row.max) if v is not None]
    return vals == sorted(vals) and row.modal is not None
