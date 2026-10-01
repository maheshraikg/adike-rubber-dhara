# Setup guide — step by step

Everything here is free. No credit card is asked for at any step. Total time: about one hour.
You need: a Google account, this GitHub repository, and an Android phone. A computer helps but the
steps also work from a phone browser (use "Desktop site" for the Firebase console).

Keep a notes file open: several steps give you a value to copy into GitHub later.

---

## A. Firebase (≈ 15 min)

**A1. Create the project**
1. Open <https://console.firebase.google.com> → **Create a project**.
2. Name: `adike-rubber-dhara` → Continue.
3. Google Analytics: **turn off** → Create project.
4. The plan badge must say **Spark** (free). Never click *Upgrade*.

**A2. Create the database**
1. Left menu → **Build → Firestore Database → Create database**.
2. Location: **asia-south1 (Mumbai)** → Next.
3. Choose **Start in production mode** → Create.

**A3. Security rules**
1. Firestore Database → **Rules** tab.
2. Delete everything in the editor. Paste the whole content of
   [`firestore.rules`](../firestore.rules) from this repo.
3. Click **Publish**.

**A4. One index**
1. Firestore Database → **Indexes** tab → **Create index** (Composite).
2. Collection ID: `submissions`
3. Field 1: `partnerUid` — Ascending. Field 2: `createdAt` — Descending. Query scope: Collection.
4. Create. (It builds in a few minutes.)

**A5. Sign-in methods**
1. **Build → Authentication → Get started → Sign-in method**.
2. **Anonymous** → Enable → Save.
3. **Google** → Enable → pick your support email → Save.
4. Authentication → **Settings → Authorized domains → Add domain** → `maheshraikg.github.io` → Add.

**A6. Register the web app (for the admin console)**
1. Project Overview (home) → **</>** (Web) icon. Nickname `admin` → Register app
   (do not tick Firebase Hosting).
2. You see a `firebaseConfig` block. Copy these four values into your notes:
   - `apiKey` → will be **ADIKE_FIREBASE_WEB_API_KEY**
   - `projectId` → **ADIKE_FIREBASE_PROJECT_ID**
   - `messagingSenderId` → **ADIKE_FIREBASE_SENDER_ID**
   - `appId` (looks like `1:123…:web:abc…`) → **ADIKE_FIREBASE_WEB_APP_ID**
3. Continue to console.

**A7. Register the Android app**
1. Project Overview → **Add app → Android** icon.
2. Package name: `com.adikedhara.app` → App nickname `Adike Dhara` → leave SHA-1 empty for now → Register.
3. **Download google-services.json**. Do not add it to the repo. Open it with any text viewer and copy:
   - `"mobilesdk_app_id"` (looks like `1:123…:android:abc…`) → **ADIKE_FIREBASE_ANDROID_APP_ID**
   - `"current_key"` under `api_key` → **ADIKE_FIREBASE_API_KEY**
4. Skip the remaining wizard steps (Next → Next → Continue to console).

**A8. Service-account key (lets the robot write alerts and review items)**
1. ⚙ **Project settings → Service accounts** tab → **Generate new private key** → Generate key.
2. A `.json` file downloads. This one **is secret**: never share it or commit it. You will paste its
   whole content into GitHub in step C1.

---

## B. Free API keys (≈ 5 min)

**B1. data.gov.in** (official mandi prices) — *optional*
Without your own key the robot uses data.gov.in's public sample key (shown on every data.gov.in
dataset page; 10 rows per request, so it pages through). Your own key is faster and has higher
limits; add it when the login works:
1. <https://data.gov.in> → **Login / Sign up** (email + OTP to your email).
2. After login: your name (top right) → **My Account** → **Generate Key** (API key). Copy it → **DATA_GOV_IN_KEY**.

**B2. Gemini** (optional: reads rate photos and pages, writes the evening summary)
1. <https://aistudio.google.com/apikey> → sign in → **Create API key** → *Create API key in new project*.
2. Copy it → **GEMINI_API_KEY**. No billing is needed for the free tier.
   Without this key, official API prices still work; photos/pages wait and the summary uses a template.

---

## C. GitHub settings (≈ 10 min)

Open <https://github.com/maheshraikg/adike-rubber-dhara> → **Settings** → left menu
**Secrets and variables → Actions**.

**C1. Secrets** (tab *Secrets* → **New repository secret**, one at a time)

| Name | Value |
|---|---|
| `DATA_GOV_IN_KEY` | from B1 (optional; the public sample key is used without it) |
| `GEMINI_API_KEY` | from B2 (skip if you have none) |
| `FIREBASE_SERVICE_ACCOUNT` | open the JSON file from A8, copy **all** of it, paste |

**C2. Variables** (tab *Variables* → **New repository variable**)

| Name | Value |
|---|---|
| `ADIKE_FIREBASE_PROJECT_ID` | A6 `projectId` |
| `ADIKE_FIREBASE_SENDER_ID` | A6 `messagingSenderId` |
| `ADIKE_FIREBASE_WEB_API_KEY` | A6 `apiKey` |
| `ADIKE_FIREBASE_WEB_APP_ID` | A6 `appId` |
| `ADIKE_FIREBASE_API_KEY` | A7 `current_key` |
| `ADIKE_FIREBASE_ANDROID_APP_ID` | A7 `mobilesdk_app_id` |

These Firebase values are public identifiers (they end up inside every app), which is why they are
variables and not secrets. Access is protected by the rules from A3.

**C3. Let workflows publish**
Settings → **Actions → General** → *Workflow permissions* → **Read and write permissions** → Save.

---

## D. First prices (≈ 10 min)

**D1. Probe the sources** — tab **Actions** → *Adike – probe sources* → **Run workflow** → Run.
When it finishes (green tick), open it → job *probe* → step *Run python -m tools.probe_sources* →
copy the log and send it to Claude. It tells us the exact data.gov.in filter format and which
official pages can be switched on.

**D2. Collect** — Actions → *Adike – collect prices* → **Run workflow** → Run. Wait for the green
tick (2–3 min). This creates the `gh-pages` branch.

**D3. Turn on GitHub Pages** — Settings → **Pages** → Source: *Deploy from a branch* →
Branch: `gh-pages`, folder `/ (root)` → Save. After 1–2 minutes open
<https://maheshraikg.github.io/adike-rubber-dhara/data/latest.json>. You should see JSON text.
If `rows` is empty, data.gov.in had no rows yet for today or the key is wrong: check the D2 log.

From now on collection runs by itself every day at **11:30** and **17:30** IST.

---

## E. The app (≈ 15 min)

**E1. Signing key (recommended, once)**
The APK must always be signed with the same key, or phones refuse updates.
- Easy way: ask Claude "make my signing key". You receive `adike-release.jks`, its password, and the
  SHA fingerprints.
- Own way (a computer with Java): `keytool -genkey -v -keystore adike-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias adike`

Then add four more **secrets** (C1 screen):

| Name | Value |
|---|---|
| `ADIKE_KEYSTORE_BASE64` | the .jks file as base64 (`base64 -w0 adike-release.jks`) |
| `ADIKE_KEYSTORE_PASSWORD` | keystore password |
| `ADIKE_KEY_ALIAS` | `adike` |
| `ADIKE_KEY_PASSWORD` | key password (same as keystore password if you pressed Enter) |

Keep the .jks file and password safe (e.g. Google Drive). Losing it means users must uninstall to update.

**E2. SHA fingerprints → Firebase** (needed for Google sign-in on the phone)
Firebase ⚙ Project settings → General → your Android app → **Add fingerprint** → paste SHA-1 → Save,
then add SHA-256 the same way. Get them with
`keytool -list -v -keystore adike-release.jks -alias adike` (or from Claude in E1).

**E3. Build the APK** — Actions → *Adike – release APK + admin web* → **Run workflow**.
Wait for the green tick (≈ 8 min). Open the run → **Artifacts** → `adike-dhara-release-apk` →
download the zip → inside is `app-release.apk`.
The same run also publishes the admin console.

**E4. Install on a phone** — send the APK to your phone (WhatsApp to yourself works) → tap it →
allow *Install unknown apps* for WhatsApp/Files when asked → Install.
First launch: choose your markets → the Today screen shows prices.

**E5. Make yourself admin**
1. Open <https://maheshraikg.github.io/adike-rubber-dhara/admin/> → **Sign in with Google**.
   It says "not an admin" — that is expected.
2. GitHub → Actions → *Adike – set user role* → Run workflow → email: your Gmail, role: `admin` → Run.
3. Back in the admin page: **Sign out**, then sign in again. You now see Review, Partners, Config, Runs, Reports.

---

## F. Every day

- **Automatic:** prices at 11:30 and 17:30 IST; alerts and the evening summary notification after
  the 17:30 run.
- **Review queue** (admin console → Review): rows that looked unusual (big change, missing modal,
  unknown market…). Approve, Edit + approve, or Reject. The next run publishes approved rows.
- **Add a co-operative/trader partner:** see [PARTNER_ONBOARDING.md](PARTNER_ONBOARDING.md)
  (they apply in the app → you approve in Partners and set a source id).
- **Run now:** admin console → Runs → *Run collection now*, or Actions → *Adike – collect prices*.
- **Share the app:** forward the APK on WhatsApp. For a new version, run E3 again and share the new APK
  (same signing key → it installs as an update).
- **Optional Play Store:** one-time USD 25; listing text is in [PLAY_STORE.md](PLAY_STORE.md).

---

## G. Arecanut mandi prices (data.gov.in)

data.gov.in refuses connections from GitHub's servers, so the robot cannot read it directly.

- **On phones (automatic):** the app reads data.gov.in itself (phones in India are not blocked)
  with the public sample key and shows rows marked *data.gov.in, live*. Nothing to set up.
- **For the robot (history, alerts, review queue): a free Cloudflare relay** (≈ 10 min, no card)
  1. <https://dash.cloudflare.com/sign-up> → sign up with email (Free plan).
  2. Account ID: Cloudflare home → **Workers & Pages** → right side *Account ID* → copy.
  3. API token: top-right profile → **My Profile → API Tokens → Create Token** →
     template **Edit Cloudflare Workers** → Continue → Create → copy the token.
  4. GitHub → Settings → Secrets and variables → Actions → **New repository secret**, three times:
     `CLOUDFLARE_ACCOUNT_ID` (step 2), `CLOUDFLARE_API_TOKEN` (step 3),
     `ADIKE_RELAY_TOKEN` (any long random text — it is a password between robot and relay).
  5. Actions → **Adike – deploy data.gov.in relay** → Run workflow. When green, open the run:
     it prints the relay URL (`https://adike-datagov-relay.<name>.workers.dev`) and whether
     data.gov.in answered.
  6. If it answered: Variables tab → **New repository variable** `ADIKE_RELAY_URL` = that URL.
     The next collection run uses it.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Collect run red at "Commit and push" | C3: set workflow permissions to *Read and write*. |
| `latest.json` 404 | D3 not done, or wait 2 minutes after the first collect run. |
| App says "Could not load rates" | Open the latest.json link in the phone browser. If it fails, fix D; the app retries on pull-down. |
| App says "Online services are not configured" | C2 variables missing when the APK was built. Add them and run E3 again. |
| Google sign-in fails on the phone | E2 fingerprints missing, or Google sign-in not enabled (A5). |
| Admin page: sign-in popup closes / error | A5 authorized domain `maheshraikg.github.io` missing. |
| "not an admin" after E5 | Sign out and in again; check the *set user role* run is green. |
| No notifications | Phone Settings → Apps → Adike Dhara → Notifications → allow. Alerts fire at most once a day, after a collection run. |
| Scheduled runs stopped | GitHub pauses schedules after 60 days without activity; the bot's data commits normally prevent this. Re-enable in Actions. |
