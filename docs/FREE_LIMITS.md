# Free services, limits and expected usage

All figures are the published free-tier limits as understood when this was written (Sept 2026).
**Providers change them — re-check the linked pages.** Items marked ⚠️ could not be verified from
the build environment.

| Service | Free limit | Our expected use (≈ 10,000 farmers) |
|---|---|---|
| **GitHub Actions** (public repo) | Unlimited minutes on standard runners. Scheduled workflows are disabled after 60 days without repository activity. | ~4 runs/day × 2–4 min. The bot's data commits count as activity. |
| **GitHub Pages** | Site ≤ 1 GB; soft bandwidth 100 GB/month; public repo on the Free plan. | `latest.json` ≈ 15 KB (≈ 3 KB gzip); history files 20–80 KB. ETag → most refreshes are 304. ≈ 10–25 GB/month. |
| **Firestore (Spark)** | 1 GiB stored, 50,000 reads/day, 20,000 writes/day, 20,000 deletes/day, 10 GiB/month egress. | Pipeline ≈ 300 reads + ≈ 60 writes per run. Alerts job reads each active alert once per run (5,000 alerts ≈ 10,000 reads/day). Farmers only read their own alerts. Prices never read from Firestore. |
| **Firebase Auth** | Anonymous and Google sign-in: no charge on Spark. ⚠️ If the project is upgraded to Identity Platform, 50,000 MAU free (anonymous users count). | Farmers only sign in anonymously when they create an alert or report. |
| **Cloud Messaging (FCM)** | Free, no message quota (topic fan-out is rate-limited). | ≤ 1 alert per alert per day + 1 summary/day to topic `daily_summary`. |
| **Gemini API free tier** ⚠️ | Roughly: gemini-2.5-flash ≈ 10 RPM / 250 requests per day; gemini-2.5-flash-lite ≈ 15 RPM / 1,000 per day (see ai.google.dev/gemini-api/docs/rate-limits). Free-tier prompts may be used by Google to improve products — we send only public price text and partner rate messages, never personal data. | ≤ 30 calls/run (`maxAiCallsPerRun`), usually < 10; skipped when page hash unchanged. |
| **data.gov.in API** ⚠️ | Free key; per-request `limit` up to 1000 records; throttling not publicly documented. | 3 queries × 1–2 pages per run. Backfill is rate-limited (1.5 s between requests). |
| **MET Norway** | Free (CC BY 4.0), commercial use allowed; must send identifying User-Agent, respect `Expires`, keep total traffic modest (< 20 req/s per application). | Only when a user opens the weather screen; cached until Expires; lat/lon rounded to 2 decimals. |
| **Google Maps** | Plain `https://www.google.com/maps/search/?api=1&query=lat,lon` link — no SDK, no key. | — |
| **Distribution** | Direct APK sharing: free. Google Play: optional one-time USD 25. | — |

## If limits get close
- Firestore reads from alerts: evaluate alerts only in the evening run (edit `adike-alerts.yml` to
  skip the morning run) or group alerts per user.
- Pages bandwidth: split `latest.json` per crop; history is fetched only on the detail screen.
- Gemini: lower `maxAiCallsPerRun`, switch `GEMINI_MODEL` to the lite model, or turn `aiEnabled` off.
- Growth beyond free tiers: Firebase Blaze + Cloud Functions, paid Gemini/Claude (provider is swappable).
