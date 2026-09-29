"""Build the static JSON published on GitHub Pages.

site_dir layout (the gh-pages branch):
  data/latest.json               today's rates + AI/template summary
  data/history/{crop}/{mid}.json last HISTORY_DAYS days per source|variety
  data/markets.json, sources.json, varieties.json
  data/state.json                pipeline state (content hashes, source stats)
  raw/{date}/{sourceId}.{ext}    audit snapshots
"""
from __future__ import annotations

import shutil
from datetime import date, timedelta
from pathlib import Path

from . import config
from .models import PriceRow
from .util import read_json, write_json_if_changed

LatestKey = tuple[str, str, str, str]  # sourceId, marketId, crop, variety


def num(v: float | None) -> float | int | None:
    """Compact numbers: 52500.0 -> 52500 (smaller JSON, same value)."""
    if v is None:
        return None
    return int(v) if float(v).is_integer() else round(float(v), 2)


def row_to_json(r: PriceRow, varieties: dict[str, dict]) -> dict:
    v = varieties.get(r.variety, {})
    return {
        "crop": r.crop, "variety": r.variety,
        "varietyLabel_kn": v.get("kn", r.variety), "varietyLabel_en": v.get("en", r.variety),
        "marketId": r.marketId, "sourceId": r.sourceId, "trust": r.trust,
        "min": num(r.min), "max": num(r.max), "modal": num(r.modal), "unit": r.unit,
        "date": r.date, "time": r.time, "change": None, "changePct": None,
    }


def _key(d: dict) -> LatestKey:
    return (d["sourceId"], d["marketId"], d["crop"], d["variety"])


class Publisher:
    def __init__(self, site_dir: Path, config_dir: Path, today: date):
        self.site = site_dir
        self.data = site_dir / "data"
        self.config_dir = config_dir
        self.today = today
        self.varieties = {v["id"]: v for v in read_json(config_dir / "varieties.json", [])}
        self.prev_latest = read_json(self.data / "latest.json", {}) or {}
        self.state = read_json(self.data / "state.json", {}) or {}
        self._history_cache: dict[tuple[str, str], dict] = {}
        self.changed_files: list[str] = []

    # ---------- lookups used by validation ----------
    def history(self, crop: str, market: str) -> dict:
        k = (crop, market)
        if k not in self._history_cache:
            h = read_json(self.data / "history" / crop / f"{market}.json", None)
            self._history_cache[k] = h or {"crop": crop, "marketId": market, "series": {}}
        return self._history_cache[k]

    def last_modal_before(self, sk: LatestKey, before: str) -> float | None:
        source, market, crop, variety = sk
        series = self.history(crop, market)["series"].get(f"{source}|{variety}", [])
        prev = [p for p in series if p[0] < before and p[3] is not None]
        return prev[-1][3] if prev else None

    def official_modal(self, row: PriceRow, fresh_official: dict[tuple, float]) -> float | None:
        k = (row.date, row.marketId, row.crop, row.variety)
        if k in fresh_official:
            return fresh_official[k]
        for d in self.prev_latest.get("rows", []):
            if d["trust"] == "official" and (d["date"], d["marketId"], d["crop"], d["variety"]) == k:
                return d["modal"]
        return None

    # ---------- writing ----------
    def _write(self, path: Path, obj) -> None:
        if write_json_if_changed(path, obj):
            self.changed_files.append(str(path.relative_to(self.site)))

    def append_history(self, rows: list[PriceRow]) -> None:
        cutoff = (self.today - timedelta(days=config.HISTORY_DAYS)).isoformat()
        touched: set[tuple[str, str]] = set()
        for r in rows:
            h = self.history(r.crop, r.marketId)
            s = h["series"].setdefault(f"{r.sourceId}|{r.variety}", [])
            entry = [r.date, num(r.min), num(r.max), num(r.modal)]
            s[:] = [p for p in s if p[0] != r.date] + [entry]
            touched.add((r.crop, r.marketId))
        for crop, market in touched:
            h = self.history(crop, market)
            for k in list(h["series"]):
                h["series"][k] = sorted([p for p in h["series"][k] if p[0] >= cutoff])
                if not h["series"][k]:
                    del h["series"][k]
            self._write(self.data / "history" / crop / f"{market}.json", h)

    def build_latest(self, rows: list[PriceRow], summary: dict | None, updated_at: str) -> dict:
        merged: dict[LatestKey, dict] = {}
        min_date = (self.today - timedelta(days=config.LATEST_MAX_AGE_DAYS)).isoformat()
        for d in self.prev_latest.get("rows", []):
            if d["date"] >= min_date:
                merged[_key(d)] = d
        for r in rows:
            d = row_to_json(r, self.varieties)
            k = _key(d)
            if k not in merged or merged[k]["date"] <= d["date"]:
                merged[k] = d
        out_rows = []
        for k, d in merged.items():
            prev = self.last_modal_before(k, d["date"])
            if prev and d["modal"] is not None:
                d["change"] = num(d["modal"] - prev)
                d["changePct"] = round((d["modal"] - prev) / prev * 100, 2)
            else:
                d["change"] = d["changePct"] = None
            out_rows.append(d)
        out_rows.sort(key=lambda d: (d["crop"], d["marketId"], config.TRUST_ORDER[d["trust"]], d["variety"]))
        latest = {"updatedAt": updated_at, "rows": out_rows,
                  "summary": summary if summary is not None else self.prev_latest.get("summary")}
        if self.prev_latest.get("sample") and not rows:
            latest["sample"] = True
        return latest

    def publish(self, rows: list[PriceRow], summary: dict | None, updated_at: str,
                sources_out: list[dict]) -> bool:
        self.append_history(rows)
        latest = self.build_latest(rows, summary, updated_at)
        # Only bump updatedAt when content changed, so ETags stay stable.
        prev_cmp = {k: v for k, v in self.prev_latest.items() if k != "updatedAt"}
        new_cmp = {k: v for k, v in latest.items() if k != "updatedAt"}
        if prev_cmp != new_cmp or not self.prev_latest:
            self._write(self.data / "latest.json", latest)
        for name in ("markets.json", "varieties.json"):
            self._write(self.data / name, read_json(self.config_dir / name, []))
        self._write(self.data / "sources.json", sources_out)
        self._write(self.data / "state.json", self.state)
        return bool(self.changed_files)

    # ---------- raw snapshots ----------
    def save_raw(self, source_id: str, ext: str, content: str) -> str:
        p = self.site / "raw" / self.today.isoformat() / f"{source_id}.{ext}"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
        return str(p.relative_to(self.site))


def prune_raw(site_dir: Path, today: date, keep_days: int = config.RAW_KEEP_DAYS) -> list[str]:
    removed = []
    root = site_dir / "raw"
    if not root.exists():
        return removed
    cutoff = today - timedelta(days=keep_days)
    for d in root.iterdir():
        try:
            if d.is_dir() and date.fromisoformat(d.name) < cutoff:
                shutil.rmtree(d)
                removed.append(d.name)
        except ValueError:
            continue
    return removed


# ---------- trust scores ----------
def update_source_stats(state: dict, source_id: str, ok: bool, on_time: bool | None,
                        agreements: list[bool]) -> dict:
    st = state.setdefault("sources", {}).setdefault(source_id, {
        "runs": 0, "okRuns": 0, "onTime": 0, "onTimeTotal": 0,
        "agree": 0, "agreeTotal": 0, "failStreak": 0})
    st["runs"] += 1
    if ok:
        st["okRuns"] += 1
        st["failStreak"] = 0
    else:
        st["failStreak"] += 1
    if on_time is not None:
        st["onTimeTotal"] += 1
        st["onTime"] += int(on_time)
    st["agree"] += sum(agreements)
    st["agreeTotal"] += len(agreements)
    return st


def trust_score(st: dict | None, trust: str) -> float:
    """0..1. Official sources start at 1.0. Others: mean of agreement-with-official
    and on-time rate (unknown components count as 0.5)."""
    if trust == "official":
        base = 1.0 if not st or not st.get("runs") else st["okRuns"] / st["runs"]
        return round(max(0.5, base), 2)
    if not st:
        return 0.5
    agree = st["agree"] / st["agreeTotal"] if st.get("agreeTotal") else 0.5
    ontime = st["onTime"] / st["onTimeTotal"] if st.get("onTimeTotal") else 0.5
    return round((agree + ontime) / 2, 2)
