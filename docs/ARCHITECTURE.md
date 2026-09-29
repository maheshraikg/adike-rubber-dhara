# Architecture

```
            ┌──────────── GitHub Actions (free, public repo) ─────────────┐
 cron 06:00 │ adike-collect.yml                                            │
 & 12:00 UTC│  pipeline/adike_pipeline/run.py                              │
            │   1 data.gov.in API ──► parse (no AI)                        │
            │   2 official pages/PDFs ─► text ─► Gemini structured output  │
            │   3 partner websites (permissionConfirmed only)              │
            │   4 Firestore submissions (partner text/photo) ─► Gemini     │
            │   5 normalise (maps, units, dates) ─► validate (pure rules)  │
            │   6 clean ─► publish     flagged ─► Firestore review/{key}   │
            │   7 apply admin decisions from review/*                      │
            │   8 evening: summary (Gemini or template)                    │
            │   9 commit JSON + raw snapshots to gh-pages                  │
            │ adike-alerts.yml (workflow_run) ─► FCM HTTP v1               │
            └──────────────────────────────────────────────────────────────┘
                     │ gh-pages                      │ Admin SDK
                     ▼                               ▼
   GitHub Pages CDN: data/*.json         Firestore (Spark): alerts, reports,
   (ETag, no Firestore reads)            submissions, review, config, runs, partners
                     │                               ▲
                     ▼                               │ rules (firestore.rules)
             Flutter app (Android) ───── anonymous / Google auth ── FCM topics
             Flutter web /admin (same code, admin claim)
```

## Design rules
- **AI never creates prices.** Gemini only reads numbers that are in the source text/photo
  (structured output via a pydantic `response_schema`). Values are then normalised and validated in
  plain Python. Anything unusual goes to a human (review queue).
- **Official API data needs no AI.** With `GEMINI_API_KEY` missing or `aiEnabled: false` the pipeline
  still publishes data.gov.in rows; AI sources are deferred to the next run.
- **The app never reads prices from Firestore**, only static JSON from GitHub Pages (cached, ETag).
- **Idempotent keys** `${date}_${sourceId}_${marketId}_${crop}_${variety}` for rows, review docs and
  history (same date replaces, never duplicates).
- **Swappable AI provider:** `ai/base.py:AIProvider` (extract + summarize, call budget). `GeminiProvider`
  handles 429 with exponential backoff and falls back to `GEMINI_FALLBACK_MODEL`. Model names are in
  `config.py` only.

## Published JSON (gh-pages)

`data/latest.json` (minified):
```json
{"updatedAt":"2026-09-29T17:30",
 "rows":[{"crop":"arecanut","variety":"rashi","varietyLabel_kn":"ರಾಶಿ","varietyLabel_en":"Rashi",
          "marketId":"shivamogga","sourceId":"datagov_mandi","trust":"official",
          "min":50000,"max":53500,"modal":52500,"unit":"INR/quintal",
          "date":"2026-09-29","time":"11:30","change":500,"changePct":0.96}],
 "summary":{"kn":"…","en":"…","date":"2026-09-29","source":"ai|template","evening":true}}
```
- Arecanut is always ₹/quintal, rubber always ₹/kg. `change` is vs the previous date for the same
  source+market+variety. Rows older than 7 days drop out of `latest.json` (still in history).
- `data/history/{crop}/{marketId}.json`: `{"series":{"<sourceId>|<variety>":[[date,min,max,modal],…]}}`,
  last 400 days.
- `data/sources.json` carries `score` (trust: agreement with official ± on-time rate) and partner
  `profile` (address, timings, phone, lat/lon for the free Google Maps link).
- `data/state.json`: page content hashes (skip AI when unchanged) and per-source stats (fail streaks).
- `raw/{date}/{sourceId}.{json|txt}`: audit snapshots, pruned after 90 days. Partner photos are **not**
  stored; only extracted text.

## Validation (pipeline/adike_pipeline/validation.py)
| Rule | Result |
|---|---|
| min > max | swap + flag `min_max_swapped` |
| modal missing | flag `modal_missing` (never invented) |
| modal outside [min, max] | flag `modal_out_of_range` |
| outside config range (arecanut 5,000–1,50,000 ₹/qtl; rubber 50–500 ₹/kg) | `out_of_range` |
| > 8% vs last published modal | `big_change` |
| partner/trader vs official > 10% (same date/market/variety) | `cross_source_diff` (both kept) |
| future date / > 3 days old | `future_date` / `stale_date` |
| AI confidence < 0.8 | `low_confidence` |
| unknown market / variety / unit | `unknown_market` / `unknown_variety` / `unit_unknown` |

No flag → published. Any flag → `review/{key}`; admin approves / edits / rejects; the next run applies it.
Decisions are remembered, so the same values re-extracted later are not queued again.

## Firestore (Spark quota)
`submissions`, `review`, `alerts`, `reports`, `partners`, `config/validation`, `config/aliases`,
`runs/{runId}`, `runs/_meta` (summary sent date). Security rules: see `firestore.rules`; tests in
`firestore-tests/` (emulator). The pipeline uses the Admin SDK and syncs custom claims for approved
partners (`partner: true, sourceId`). Admin claim: `pipeline/tools/set_claim.py`.

**Deviation from the brief (documented):** a Google-signed-in user may *create* their own
`partners/{uid}` application with `approved: false` and read it back; only admins can approve or edit.
This lets societies apply from the app without sharing their uid by other means.

## App
Flutter, Material 3 (seed #2E7D32, accent #8D6E63), Kannada default + English, all strings in
`lib/l10n/app_{kn,en}.arb`. Offline: every JSON is cached in SharedPreferences and shown with an
offline banner. Firebase is optional at build time: without the `--dart-define` Firebase values the
app still shows prices, charts, calculator, diary and weather; alerts/partner/admin say "not configured".
