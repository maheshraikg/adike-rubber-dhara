"""data.gov.in (AGMARKNET) mandi price API. Deterministic parsing, no AI."""
from __future__ import annotations

from typing import Any, Iterable

from .. import config
from ..models import RawRow
from ..util import Fetcher, log_event, parse_number

SOURCE_ID = "datagov_mandi"


def _get(rec: dict, *names: str) -> Any:
    """Case/format-insensitive field lookup (daily resource uses snake_case,
    the historical resource uses e.g. 'Min_x0020_Price')."""
    low = {k.lower().replace("_x0020_", "_"): v for k, v in rec.items()}
    for n in names:
        if n in low:
            return low[n]
    return None


def parse_records(records: Iterable[dict], crop: str, collected_time: str) -> list[RawRow]:
    rows: list[RawRow] = []
    for rec in records:
        market = _get(rec, "market")
        variety = _get(rec, "variety")
        grade = _get(rec, "grade")
        if grade and str(grade).strip().upper() not in ("FAQ", "NON-FAQ", "LOCAL", ""):
            variety = f"{variety} {grade}".strip() if variety else grade
        rows.append(RawRow(
            sourceId=SOURCE_ID, crop=crop, market_raw=market, variety_raw=variety,
            min=parse_number(_get(rec, "min_price")), max=parse_number(_get(rec, "max_price")),
            modal=parse_number(_get(rec, "modal_price")), unit_raw=None,
            date_raw=_get(rec, "arrival_date"), confidence=None, via="api",
            time=collected_time[11:16],
            sourceUrl=config.DATAGOV_BASE + config.DATAGOV_DAILY_RESOURCE,
            rawExcerpt=str({k: rec.get(k) for k in list(rec)[:12]}),
        ))
    return rows


def build_params(api_key: str, state: str, commodity: str, offset: int,
                 keyword_filters: bool, limit: int = config.DATAGOV_PAGE_LIMIT) -> dict:
    suffix = ".keyword" if keyword_filters else ""
    return {
        "api-key": api_key, "format": "json", "limit": limit, "offset": offset,
        f"filters[state{suffix}]": state, f"filters[commodity{suffix}]": commodity,
    }


def fetch_query(fetcher: Fetcher, api_key: str, state: str, commodity: str,
                resource: str = config.DATAGOV_DAILY_RESOURCE) -> list[dict]:
    """Fetch all pages. Tries `filters[x.keyword]` first, then plain `filters[x]`
    (both forms are seen in the wild; see docs/DATA_SOURCES.md)."""
    url = config.DATAGOV_BASE + resource
    for keyword in (True, False):
        out: list[dict] = []
        for page in range(config.DATAGOV_MAX_PAGES):
            params = build_params(api_key, state, commodity, page * config.DATAGOV_PAGE_LIMIT, keyword)
            data = fetcher.get(SOURCE_ID, url, params=params, check_robots=False).json()
            recs = data.get("records") or []
            out.extend(recs)
            total = int(data.get("total") or 0)
            if len(recs) < config.DATAGOV_PAGE_LIMIT or len(out) >= total:
                break
        if out:
            log_event("datagov.fetched", state=state, commodity=commodity, rows=len(out), keyword=keyword)
            return out
    return []


def collect(fetcher: Fetcher, api_key: str, collected_time: str) -> tuple[list[RawRow], dict]:
    rows: list[RawRow] = []
    raw_dump: dict = {}
    for q in config.DATAGOV_QUERIES:
        recs = fetch_query(fetcher, api_key, q["state"], q["commodity"])
        raw_dump[f"{q['state']}|{q['commodity']}"] = recs
        rows.extend(parse_records(recs, q["crop"], collected_time))
    return rows, raw_dump
