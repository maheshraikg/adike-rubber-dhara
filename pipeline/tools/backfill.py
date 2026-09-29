"""One-time backfill of ~12 months of history from data.gov.in into history files.

    DATA_GOV_IN_KEY=... python -m tools.backfill --site ../../site --config ../data --days 365

Uses the historical variety-wise resource (config.DATAGOV_HISTORY_RESOURCE), one
request per commodity+state per day with a delay (rate limited). Rows are
validated with the same rules except the date-age and daily-change checks;
anything flagged is skipped (history must only contain clean rows).
Verify the resource id + date filter with tools/probe_sources.py first.
"""
from __future__ import annotations

import argparse
import os
import time
from datetime import date, timedelta
from pathlib import Path

from adike_pipeline import config
from adike_pipeline.normalize import Normalizer, normalize
from adike_pipeline.publish import Publisher
from adike_pipeline.sources import datagov
from adike_pipeline.util import Fetcher, log_event, now_ist, read_json
from adike_pipeline.validation import merged_config, sanity_ok, validate


def raise_missing() -> str:
    raise SystemExit("DATA_GOV_IN_KEY not set")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--site", default="../../site")
    ap.add_argument("--config", default="../data")
    ap.add_argument("--days", type=int, default=365)
    ap.add_argument("--delay", type=float, default=1.5, help="seconds between requests")
    ap.add_argument("--date-filter", default="filters[Arrival_Date]",
                    help="query param for the date (verify with probe)")
    a = ap.parse_args()
    key = os.environ.get("DATA_GOV_IN_KEY") or raise_missing()
    now = now_ist()
    site, cfgdir = Path(a.site), Path(a.config)
    pub = Publisher(site, cfgdir, now.date())
    norm = Normalizer(read_json(cfgdir / "markets.json", []), read_json(cfgdir / "varieties.json", []))
    cfg = merged_config({})
    fetcher = Fetcher(max_per_source=10 ** 6)
    url = config.DATAGOV_BASE + config.DATAGOV_HISTORY_RESOURCE
    total = 0
    for back in range(a.days, 0, -1):
        day = now.date() - timedelta(days=back)
        batch = []
        for q in config.DATAGOV_QUERIES:
            params = {"api-key": key, "format": "json", "limit": 1000, "offset": 0,
                      "filters[State]": q["state"], "filters[Commodity]": q["commodity"],
                      a.date_filter: day.strftime("%d/%m/%Y")}
            try:
                data = fetcher.get("backfill", url, params=params, check_robots=False).json()
            except Exception as e:  # noqa: BLE001
                log_event("backfill.error", day=str(day), q=q["commodity"], error=str(e)[:200])
                continue
            finally:
                time.sleep(a.delay)
            for raw in datagov.parse_records(data.get("records") or [], q["crop"], f"{day}T17:30"):
                row, flags = normalize(raw, norm, "official", f"{day}T17:30")
                if row is None or flags:
                    continue
                row, vflags = validate(row, cfg, date.fromisoformat(row.date))
                vflags = [f for f in vflags if f not in ("stale_date",)]
                if not vflags and sanity_ok(row):
                    batch.append(row)
        pub.append_history(batch)
        total += len(batch)
        log_event("backfill.day", day=str(day), rows=len(batch))
    print(f"backfilled {total} rows; files changed: {len(pub.changed_files)}")


if __name__ == "__main__":
    main()
