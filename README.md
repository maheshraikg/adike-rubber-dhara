# ಅಡಿಕೆ–ರಬ್ಬರ್ ಧಾರಣೆ · Adike–Rubber Dhara

A Kannada-first Android app (Flutter) with daily **arecanut (ಅಡಿಕೆ)** and **rubber (ರಬ್ಬರ್)**
prices for coastal and Malnad Karnataka. Rates are collected automatically twice a day from
official sources (data.gov.in / AGMARKNET, Rubber Board, …) and from partner co-operatives and
traders, validated, and published as static JSON on GitHub Pages.

**Everything runs on free tiers — no credit card:** GitHub Actions + GitHub Pages, Firebase Spark
(Auth, Firestore, Cloud Messaging only — no Cloud Functions / Storage), Gemini API free tier
(optional), data.gov.in API, MET Norway weather. See [docs/FREE_LIMITS.md](docs/FREE_LIMITS.md).

| | |
|---|---|
| Farmers | No login. Today's rates, 1-year charts, compare markets, price alerts, sale calculator, on-device sales diary, drying-weather forecast, WhatsApp share card. |
| Trust | Every price shows source, time and a badge: 🟢 ಅಧಿಕೃತ Official · 🔵 ಪಾಲುದಾರ Partner · 🟡 ವ್ಯಾಪಾರಿ Trader. min ≤ modal ≤ max always; modal is shown and never invented. |
| Partners | Google sign-in; submit today's rates as text or a photo of the rate board. |
| Admin | Review queue (raw text next to extracted values), partners, validation config, run log. Web console on GitHub Pages at `/admin`. |

## Layout

```
app/               Flutter app (Android + web admin)
pipeline/          Python collector (runs in GitHub Actions)
data/              markets.json, varieties.json, sources.json (hand-edited config)
firestore.rules, firestore.indexes.json, firebase.json, firestore-tests/
docs/              ARCHITECTURE, DATA_SOURCES, PARTNER_ONBOARDING, FREE_LIMITS, PLAY_STORE
.github/workflows/adike-*.yml   collect, alerts, tests, release, probe
```

Generated data lives on the **gh-pages** branch: `data/latest.json`, `data/history/{crop}/{market}.json`,
`data/{markets,sources,varieties}.json`, audit snapshots in `raw/{date}/`, and the admin console in `admin/`.

## Setup, step by step (all free)

### 1. Firebase (Spark plan — never add billing)
1. <https://console.firebase.google.com> → **Add project** → name `adike-rubber-dhara` → Analytics off.
   Stay on **Spark**. Do not click “Upgrade”.
2. **Build → Firestore Database → Create database** → production mode → region `asia-south1` (Mumbai).
3. **Build → Authentication → Get started** → Sign-in method → enable **Anonymous** and **Google**.
   Authentication → Settings → **Authorized domains** → add `maheshraikg.github.io`.
4. **Project settings → General → Your apps**:
   - Add **Android** app, package `com.adikedhara.app`. Add the SHA-1 of your signing key
     (`keytool -list -v -keystore adike-release.jks -alias adike`; for debug builds
     `keytool -list -v -keystore ~/.android/debug.keystore -storepass android`). Google sign-in needs it.
     You do **not** need to download `google-services.json`.
   - Add **Web** app (for the admin console).
   - Note: API key, project id, messaging sender id, Android app id, web app id, web API key.
5. **Project settings → Service accounts → Generate new private key** → keep the JSON safe
   (never commit it). The Admin SDK works on Spark.
6. Deploy rules + indexes (free):
   ```sh
   npm i -g firebase-tools && firebase login
   firebase deploy --only firestore:rules,firestore:indexes --project <project-id>
   ```

### 2. Gemini API key (optional; free tier, no card)
<https://aistudio.google.com/apikey> → **Create API key**. The pipeline works without it
(data.gov.in rows need no AI; pages/photos wait until AI is available; summary uses a template).

### 3. data.gov.in key (free)
<https://data.gov.in> → Sign up / Login → **My Account → Generate API Key**.

### 4. GitHub
1. Repository → **Settings → Secrets and variables → Actions → Secrets**:
   - `DATA_GOV_IN_KEY`, `GEMINI_API_KEY`, `FIREBASE_SERVICE_ACCOUNT` (paste the whole JSON).
   - Optional signing: `ADIKE_KEYSTORE_BASE64` (`base64 -w0 adike-release.jks`), `ADIKE_KEYSTORE_PASSWORD`,
     `ADIKE_KEY_ALIAS`, `ADIKE_KEY_PASSWORD`.
2. **Variables** tab (public identifiers, not secrets): `ADIKE_FIREBASE_API_KEY`, `ADIKE_FIREBASE_WEB_API_KEY`,
   `ADIKE_FIREBASE_PROJECT_ID`, `ADIKE_FIREBASE_SENDER_ID`, `ADIKE_FIREBASE_ANDROID_APP_ID`,
   `ADIKE_FIREBASE_WEB_APP_ID`, `ADIKE_DATA_BASE_URL` (e.g. `https://maheshraikg.github.io/adike-rubber-dhara/`).
3. **Actions → Adike – probe sources → Run workflow**. Read the log; copy results into
   `docs/DATA_SOURCES.md`; set `"enabled": true` for official pages whose URL is confirmed.
4. **Actions → Adike – collect prices → Run workflow** (first run creates the `gh-pages` branch).
5. **Settings → Pages** → Source: *Deploy from a branch* → `gh-pages` / `(root)` → Save.
   Check `https://maheshraikg.github.io/<repo>/data/latest.json`.
6. Optional one-time history: run locally
   `cd pipeline && DATA_GOV_IN_KEY=… python -m tools.backfill --site ../../site --days 365`
   inside a checkout of `gh-pages` at `../../site`, then commit and push that branch.

### 5. Make yourself admin
1. Build/run the app (or open `/admin/` after step 6) and **sign in with Google** once.
2. ```sh
   cd pipeline && pip install -r requirements.txt
   export FIREBASE_SERVICE_ACCOUNT="$(cat ~/adike-service-account.json)"
   python -m tools.set_claim --email you@gmail.com --admin
   ```
3. Sign out and sign in again (claims refresh on sign-in).

### 6. Build the APK
- **In GitHub (recommended):** Actions → *Adike – release APK + admin web* → Run workflow. Download
  `adike-dhara-release-apk` from the run, or push a tag `adike-v1.0.0` to attach it to a release.
  The same workflow publishes the admin console to `gh-pages/admin`.
- **Locally:**
  ```sh
  keytool -genkey -v -keystore ~/adike-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias adike
  cat > app/android/key.properties <<'P'
  storeFile=/home/you/adike-release.jks
  storePassword=…
  keyAlias=adike
  keyPassword=…
  P
  cd app && flutter build apk --release \
    --dart-define=FIREBASE_API_KEY=… --dart-define=FIREBASE_PROJECT_ID=… \
    --dart-define=FIREBASE_SENDER_ID=… --dart-define=FIREBASE_ANDROID_APP_ID=… \
    --dart-define=DATA_BASE_URL=https://maheshraikg.github.io/adike-rubber-dhara/
  # → app/build/app/outputs/flutter-apk/app-release.apk
  ```
  Keep the keystore safe: updates must be signed with the same key.

### 7. Distribute
- **Free:** share the APK file on WhatsApp, or link the GitHub release asset from a website.
  Users must allow “Install unknown apps”. Updates: share the new APK (same signing key).
- **Google Play (optional, one-time USD 25):** create a developer account, build an app bundle
  (`flutter build appbundle --release …`), upload, fill the listing from
  [docs/PLAY_STORE.md](docs/PLAY_STORE.md) and the data-safety answers there. Play App Signing
  gives a new SHA-1 — add it in Firebase for Google sign-in.

## Local development

```sh
# pipeline
cd pipeline && python -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt
pytest && ruff check .
python -m tools.seed_sample --site ../../site-sample     # SAMPLE data for the app
# rules (needs Java + Node)
cd ../firestore-tests && npm ci && npx firebase emulators:exec --only firestore --project demo-adike --config ../firebase.json "npm test"
# app
cd ../app && flutter pub get && flutter analyze && flutter test
cd ../../site-sample && python -m http.server 8000 &   # serve sample data
cd ../adike-rubber-dhara/app && flutter run --dart-define=DATA_BASE_URL=http://10.0.2.2:8000/
```

## Roadmap
- WhatsApp partner messages (WhatsApp Cloud API has a free tier; needs Meta business verification).
- Home-screen widget with favourite rates.
- Pepper, cashew, coconut, coffee.
- Kannada voice query (“ಇಂದು ಪುತ್ತೂರು ಚಾಲಿ ಧಾರಣೆ?”) answered **only** from stored data.
- iOS build.
- Beyond free limits: Firebase Blaze + Cloud Functions, or a paid Gemini/Claude tier. The AI
  provider is one interface (`pipeline/adike_pipeline/ai/base.py` → `AIProvider`); add a class
  and return it from `ai/__init__.py:make_provider`.
