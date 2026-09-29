# Data sources

Only official sites and partners who gave permission. Polite fetching: User-Agent
`AdikeRubberDhara/1.0 (+repo; contact email)`, ≤ 3 requests per source per run, robots.txt respected,
AI skipped when the page hash is unchanged. Configure in `data/sources.json`.

> **Verification status.** The build sandbox could not reach data.gov.in, rubberboard.gov.in,
> agmarknet.gov.in, krishimaratavahini.kar.nic.in or api.met.no, so URLs and filter syntax below are
> from public documentation and **not yet verified**. Run **Actions → Adike – probe sources** and paste
> the output under "Probe results". HTML sources stay `"enabled": false` until confirmed.

## 1. data.gov.in — AGMARKNET mandi prices (official, API, no AI)
- Resource (current daily prices): `9ef84268-d588-465a-a308-a864a43d0070`
- Request:
  `https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070?api-key=KEY&format=json&limit=1000&offset=N&filters[state.keyword]=Karnataka&filters[commodity.keyword]=Arecanut(Betelnut/Supari)`
- The collector tries `filters[x.keyword]` first and falls back to `filters[x]` when nothing comes
  back (both forms are reported in the wild).
- Queries: Karnataka + `Arecanut(Betelnut/Supari)`; Kerala + `Rubber`; Karnataka + `Rubber`.
- Fields: state, district, market, commodity, variety, grade, arrival_date (dd/mm/yyyy), min_price,
  max_price, modal_price — prices in ₹/quintal (rubber converted to ₹/kg).
- Historical (backfill) resource: `35985678-0d79-46b4-9ed6-6f13308a1d24` (variety-wise daily prices;
  capitalised field names like `Min_x0020_Price` are handled). Date filter name to verify:
  `filters[Arrival_Date]=dd/mm/yyyy` (override with `tools/backfill.py --date-filter`).

## 2. Rubber Board daily prices (official, HTML → AI) — `rubberboard_daily`
- Candidate URL: `https://rubberboard.gov.in/public` (daily RSS-4/RSS-5/ISNR-20/Latex, Kottayam &
  Kochi). Confirm the exact page with the probe; set `url` and `"enabled": true`.
  If the rates are in a PDF linked from the page, add `"pdfLinkPattern": "<regex>"`.

## 3. Agmarknet 2.0 date-wise report (official, fallback) — `agmarknet_report`
- `https://agmarknet.gov.in/` → date-wise price report for Arecanut / Karnataka. Confirm URL. Only
  needed when the API is down.

## 4. Krishi Marata Vahini (Karnataka APMC) — `krishimaratavahini`
- `https://krishimaratavahini.kar.nic.in/` → daily arrivals & prices report. Confirm URL.

## 5. Co-operatives (CAMPCO, TSS Sirsi, MAMCOS) — partner, need permission
- Websites are listed but **disabled** with `"permissionConfirmed": false`. Enable only with written
  permission. The easiest route is partner submissions from the app (see PARTNER_ONBOARDING.md).

## 6. Partner submissions (Firestore `submissions`)
Text or a photo (JPEG ≤ 1024 px, ≤ 300 KB) from a signed-in partner with the `partner` claim. The
photo is removed after extraction; the extracted text is kept in `raw/` and on the submission.

## 7. MET Norway Locationforecast (weather, in the app)
`https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=12.76&lon=75.20` — User-Agent with
app name + contact email (required), lat/lon rounded to 2 decimals, cached until `Expires`,
attribution "Weather data: MET Norway" (CC BY 4.0). Free for commercial use per their terms.

## Probe results
_(paste output of the “Adike – probe sources” workflow here)_
