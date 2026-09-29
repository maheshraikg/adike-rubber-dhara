"""One collection run. Invoked by .github/workflows/adike-collect.yml.

    python -m adike_pipeline.run --site ../../site --config ../data [--evening auto|yes|no]
"""
from __future__ import annotations

import argparse
import base64
import json
import os
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path
from typing import Optional

from .ai import AIProvider, AIUnavailable, make_provider
from .alerts import send_admin_alert
from .models import AIExtraction, PriceRow, RawRow
from .normalize import Normalizer, normalize
from .publish import Publisher, prune_raw, trust_score, update_source_stats
from .sources import datagov, web
from .store import Store, make_store, older_than, utcnow
from .summary import build_summary
from .util import Fetcher, log_event, now_ist, read_json
from .validation import merged_config, pct_diff, sanity_ok, validate


@dataclass
class Item:
    raw: RawRow
    source: dict


@dataclass
class SourceResult:
    ok: bool = True
    rows: int = 0
    error: Optional[str] = None
    note: Optional[str] = None


@dataclass
class RunResult:
    published: list[PriceRow] = field(default_factory=list)
    flagged: list[dict] = field(default_factory=list)
    sources: dict[str, SourceResult] = field(default_factory=dict)
    ai_calls: int = 0
    changed: bool = False
    changed_files: list[str] = field(default_factory=list)
    summary: Optional[dict] = None


def ai_rows_to_raw(ext: AIExtraction, source: dict, url: str, excerpt: str, t: str) -> list[RawRow]:
    out = []
    for r in ext.rows:
        out.append(RawRow(sourceId=source["id"], crop=r.crop, market_raw=r.market,
                          variety_raw=r.variety_raw, min=r.min, max=r.max, modal=r.modal,
                          unit_raw=r.unit, date_raw=r.date, confidence=r.confidence, note=r.note,
                          sourceUrl=url, rawExcerpt=excerpt[:1500], time=t, via="ai"))
    return out


def load_sources(config_dir: Path, store: Store) -> list[dict]:
    sources = read_json(config_dir / "sources.json", [])
    known = {s["id"] for s in sources}
    for _uid, p in store.approved_partners():
        sid = p.get("sourceId")
        if not sid or sid in known:
            continue
        known.add(sid)
        sources.append({
            "id": sid, "type": p.get("type", "partner") if p.get("type") in ("partner", "trader") else "partner",
            "kind": "submission", "enabled": True, "permissionConfirmed": True,
            "crops": p.get("crops", ["arecanut", "rubber"]),
            "name_en": p.get("name", sid), "name_kn": p.get("name_kn", p.get("name", sid)),
            "defaultMarketId": p.get("marketId"),
            "profile": {k: p[k] for k in ("address", "timings", "phone", "lat", "lon") if k in p},
        })
    return sources


def sync_partner_claims(store: Store) -> int:
    """Approved partners get {partner: true, sourceId}; admin claim is preserved."""
    n = 0
    for uid, p in store.approved_partners():
        try:
            claims = store.get_claims(uid)
        except Exception as e:  # noqa: BLE001 - user may not exist
            log_event("claims.error", uid=uid, error=str(e)[:200])
            continue
        want = dict(claims, partner=True, sourceId=p.get("sourceId"))
        if want != claims:
            store.set_claims(uid, want)
            n += 1
    return n


class Runner:
    def __init__(self, site: Path, config_dir: Path, store: Store, store_real: bool,
                 ai: Optional[AIProvider], now: datetime, evening: bool,
                 fetcher: Optional[Fetcher] = None, api_fetcher: Optional[Fetcher] = None,
                 datagov_key: str = "", admin_alert=send_admin_alert):
        self.site, self.config_dir = site, config_dir
        self.store, self.store_real = store, store_real
        self.now = now
        self.today: date = now.date()
        self.tstamp = now.strftime("%Y-%m-%dT%H:%M")
        self.evening = evening
        self.cfg = merged_config(store.validation_config())
        self.ai = ai if ai is not None else make_provider(self.cfg)
        self.fetcher = fetcher or Fetcher()
        self.api_fetcher = api_fetcher or Fetcher(max_per_source=40)
        self.datagov_key = datagov_key
        self.admin_alert = admin_alert
        self.publisher = Publisher(site, config_dir, self.today)
        self.normalizer = Normalizer(read_json(config_dir / "markets.json", []),
                                     read_json(config_dir / "varieties.json", []), store.aliases())
        self.res = RunResult()

    # ---------------- collection ----------------
    def collect_datagov(self, src: dict) -> list[Item]:
        if not self.datagov_key:
            self.res.sources[src["id"]] = SourceResult(ok=False, error="DATA_GOV_IN_KEY not set")
            return []
        try:
            rows, dump = datagov.collect(self.api_fetcher, self.datagov_key, self.tstamp)
            self.publisher.save_raw(src["id"], "json", json.dumps(dump, ensure_ascii=False))
            self.res.sources[src["id"]] = SourceResult(rows=len(rows))
            return [Item(r, src) for r in rows]
        except Exception as e:  # noqa: BLE001
            self.res.sources[src["id"]] = SourceResult(ok=False, error=str(e)[:300])
            return []

    def collect_web(self, src: dict) -> list[Item]:
        sid = src["id"]
        hashes = self.publisher.state.setdefault("hashes", {})
        try:
            page = web.fetch_source_text(self.fetcher, src)
        except Exception as e:  # noqa: BLE001
            self.res.sources[sid] = SourceResult(ok=False, error=str(e)[:300])
            return []
        self.publisher.save_raw(sid, "txt", f"URL: {page.url}\n\n{page.text}")
        if hashes.get(sid) == page.hash:
            self.res.sources[sid] = SourceResult(note="unchanged; AI skipped")
            return []
        try:
            ext = self.ai.extract(text=page.text, hint=f"Source: {src.get('name_en')}; crops: {src.get('crops')}")
        except AIUnavailable as e:
            self.res.sources[sid] = SourceResult(ok=True, note=f"deferred: {e}")
            return []
        hashes[sid] = page.hash
        raws = ai_rows_to_raw(ext, src, page.url, page.text, self.tstamp[11:16])
        self.res.sources[sid] = SourceResult(rows=len(raws))
        return [Item(r, src) for r in raws]

    def collect_submissions(self, by_id: dict[str, dict]) -> list[Item]:
        items: list[Item] = []
        if not self.store_real:
            return items
        for sub_id, sub in self.store.new_submissions():
            src = by_id.get(sub.get("sourceId"))
            if src is None:
                self.store.set_doc(f"submissions/{sub_id}", {"status": "failed", "error": "unknown sourceId",
                                                               "imageB64": None}, merge=True)
                continue
            try:
                img = base64.b64decode(sub["imageB64"]) if sub.get("imageB64") else None
                ext = self.ai.extract(text=sub.get("text"), image=img,
                                      hint=f"Rate message from partner {src.get('name_en')}; "
                                           f"default market {src.get('defaultMarketId')}")
            except AIUnavailable as e:
                log_event("submission.deferred", id=sub_id, error=str(e))
                break  # AI is down/over budget: keep the rest for the next run
            except Exception as e:  # noqa: BLE001
                self.store.set_doc(f"submissions/{sub_id}", {"status": "failed", "error": str(e)[:300],
                                                               "imageB64": None}, merge=True)
                continue
            excerpt = (sub.get("text") or "") + ("\n" + ext.transcript if ext.transcript else "")
            self.publisher.save_raw(f"{src['id']}_submission_{sub_id}", "txt", excerpt)
            raws = ai_rows_to_raw(ext, src, f"submission:{sub_id}", excerpt, self.tstamp[11:16])
            items.extend(Item(r, src) for r in raws)
            # Photos are not kept after processing, only the extracted text.
            self.store.set_doc(f"submissions/{sub_id}", {
                "status": "processed", "imageB64": None, "extractedText": excerpt[:5000],
                "rows": len(raws), "processedAt": utcnow()}, merge=True)
            r = self.res.sources.setdefault(src["id"], SourceResult())
            r.rows += len(raws)
        return items

    # ---------------- validation / review ----------------
    def process(self, items: list[Item]) -> None:
        rows: dict[str, tuple[PriceRow, list[str], Item]] = {}
        for it in items:
            trust = it.source.get("type", "official")
            row, flags = normalize(it.raw, self.normalizer, trust, self.tstamp,
                                   default_crop=(it.source.get("crops") or [None])[0]
                                   if len(it.source.get("crops") or []) == 1 else None,
                                   default_market=it.source.get("defaultMarketId"))
            if row is None:
                continue
            rows[row.key] = (row, flags, it)  # idempotent key: last wins

        fresh_official = {(r.date, r.marketId, r.crop, r.variety): r.modal
                          for r, f, _ in rows.values() if r.trust == "official" and r.modal and not f}
        self.agreements: dict[str, list[bool]] = {}
        to_review: list[tuple[PriceRow, list[str], Item]] = []
        for row, nflags, it in rows.values():
            last = self.publisher.last_modal_before(row.series_key, row.date)
            official = None if row.trust == "official" else self.publisher.official_modal(row, fresh_official)
            vrow, vflags = validate(row, self.cfg, self.today, last, official)
            if official and vrow.modal is not None:
                self.agreements.setdefault(row.sourceId, []).append(
                    pct_diff(vrow.modal, official) <= float(self.cfg["maxCrossSourceDiffPct"]))
            flags = nflags + vflags
            if not flags and sanity_ok(vrow):
                self.res.published.append(vrow)
            else:
                to_review.append((vrow, flags or ["sanity"], it))
        self.handle_review(to_review)

    def handle_review(self, flagged: list[tuple[PriceRow, list[str], Item]]) -> None:
        existing = dict(self.store.review_docs()) if self.store_real else {}
        # 1) apply admin decisions made since the last run
        for key, doc in existing.items():
            if doc.get("status") == "applied":
                if older_than(doc.get("appliedAt"), 7):
                    self.store.delete_doc(f"review/{key}")
                continue
            dec = doc.get("decision")
            if dec in ("approve", "edit"):
                data = doc.get("editedRow") if dec == "edit" and doc.get("editedRow") else doc.get("row")
                try:
                    row = PriceRow.model_validate(data)
                    if row.min is not None and row.max is not None and row.min > row.max:
                        row.min, row.max = row.max, row.min
                    if sanity_ok(row):
                        self.res.published.append(row)
                except Exception as e:  # noqa: BLE001
                    log_event("review.bad_row", key=key, error=str(e)[:200])
            if dec in ("approve", "edit", "reject"):
                self.store.set_doc(f"review/{key}", {"status": "applied", "appliedAt": utcnow()}, merge=True)
                doc["status"] = "applied"
        # 2) new flagged rows
        for row, flags, it in flagged:
            item = {"key": row.key, "row": row.model_dump(), "flags": flags}
            self.res.flagged.append(item)
            if not self.store_real:
                continue
            doc = existing.get(row.key)
            if doc and doc.get("decision") and doc.get("row") == row.model_dump():
                continue  # admin already decided on these exact values
            payload = {"row": row.model_dump(), "flags": flags,
                       "rawExcerpt": (it.raw.rawExcerpt or "")[:1500],
                       "sourceUrl": it.raw.sourceUrl, "status": "pending",
                       "decision": None, "editedRow": None,
                       "createdAt": (doc or {}).get("createdAt") or utcnow(), "updatedAt": utcnow()}
            self.store.set_doc(f"review/{row.key}", payload)

    # ---------------- main ----------------
    def run(self) -> RunResult:
        if self.store_real:
            sync_partner_claims(self.store)
        sources = load_sources(self.config_dir, self.store)
        by_id = {s["id"]: s for s in sources}
        items: list[Item] = []
        for s in sources:
            if not s.get("enabled"):
                continue
            if s["type"] != "official" and not s.get("permissionConfirmed"):
                continue
            if s["kind"] == "api" and s["id"] == datagov.SOURCE_ID:
                items += self.collect_datagov(s)
            elif s["kind"] in ("html", "pdf"):
                items += self.collect_web(s)
        items += self.collect_submissions(by_id)
        self.process(items)

        summary = None
        if self.evening:
            prelim = self.publisher.build_latest(self.res.published, None, self.tstamp)
            markets = {m["id"]: m for m in read_json(self.config_dir / "markets.json", [])}
            summary = build_summary(prelim["rows"], self.today.isoformat(), markets,
                                    self.ai if self.cfg.get("aiEnabled", True) else None, self.tstamp)
            self.res.summary = summary

        # trust stats
        state = self.publisher.state
        for sid, sr in self.res.sources.items():
            on_time = None
            if by_id.get(sid, {}).get("type") != "official" and sr.rows:
                on_time = any(r.sourceId == sid and r.date == self.today.isoformat() for r in self.res.published)
            st = update_source_stats(state, sid, sr.ok, on_time, getattr(self, "agreements", {}).get(sid, []))
            if st["failStreak"] == 2:
                try:
                    self.admin_alert("Source failing", f"{sid} failed 2 runs in a row: {sr.error}")
                except Exception as e:  # noqa: BLE001
                    log_event("admin_alert.error", error=str(e)[:200])
        sources_out = []
        for s in sources:
            pub = {k: v for k, v in s.items() if k not in ("note",)}
            pub["score"] = trust_score(state.get("sources", {}).get(s["id"]), s["type"])
            sources_out.append(pub)

        self.res.changed = self.publisher.publish(self.res.published, summary, self.tstamp, sources_out)
        self.res.changed_files = list(self.publisher.changed_files)
        prune_raw(self.site, self.today)
        self.res.ai_calls = self.ai.calls
        self.write_run_log()
        return self.res

    def write_run_log(self) -> None:
        run_id = self.now.strftime("%Y%m%d-%H%M")
        doc = {"startedAt": self.tstamp, "evening": self.evening,
               "sources": {k: vars(v) for k, v in self.res.sources.items()},
               "aiCalls": self.ai.calls, "aiProvider": self.ai.name,
               "flagged": len(self.res.flagged), "published": len(self.res.published),
               "changedFiles": self.publisher.changed_files[:50]}
        log_event("run.done", runId=run_id, **{k: v for k, v in doc.items() if k != "changedFiles"})
        if self.store_real:
            self.store.set_doc(f"runs/{run_id}", doc)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--site", default="../site", help="checkout of the gh-pages branch")
    ap.add_argument("--config", default="../data", help="repo data/ dir with markets/sources/varieties")
    ap.add_argument("--evening", default="auto", choices=["auto", "yes", "no"])
    a = ap.parse_args()
    now = now_ist()
    evening = a.evening == "yes" or (a.evening == "auto" and now.hour >= 15)
    store, real = make_store()
    if not real:
        log_event("run.offline_mode", reason="FIREBASE_SERVICE_ACCOUNT not set; review queue disabled")
    runner = Runner(Path(a.site), Path(a.config), store, real, None, now, evening,
                    datagov_key=os.environ.get("DATA_GOV_IN_KEY", "").strip(),
                    admin_alert=send_admin_alert if real else (lambda *x: None))
    res = runner.run()
    gh_out = os.environ.get("GITHUB_OUTPUT")
    if gh_out:
        with open(gh_out, "a") as f:
            f.write(f"changed={'true' if res.changed else 'false'}\n")


if __name__ == "__main__":
    main()
