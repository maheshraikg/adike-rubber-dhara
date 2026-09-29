# Partner onboarding (co-operative societies, traders)

1. **Agreement.** Get written consent (email/WhatsApp is fine) that their daily rates may be shown in
   the app with their name. Record it (date, person) in your notes.
2. **Partner signs in.** In the app: *ಇನ್ನಷ್ಟು → ಪಾಲುದಾರ ವಿಭಾಗ / Partner mode → Sign in with Google*
   → fill *Apply to become a partner* (name, business phone, address). Google sign-in is free and
   unlimited (no SMS OTP).
3. **Admin approves.** Admin console → *Partners* → open the application → set:
   - `sourceId` (lowercase, e.g. `puttur_krishi_sangha`) — unique, never reuse;
   - type **partner** 🔵 (co-operative) or **trader** 🟡;
   - `marketId` (default market, e.g. `puttur`), `name_kn`, `timings`, `lat`/`lon` (for the map link);
   - **Approved** on.
4. **Next pipeline run** (or run *Adike – collect prices* manually) sets the custom claims
   `{partner: true, sourceId}` and publishes the partner in `sources.json` with its public profile.
5. The partner **signs out and in again**, then can submit rates as text, e.g.
   `ಪುತ್ತೂರು 29/09 ಹೊಸ ಚಾಲಿ 42000-46000 ಸರಾಸರಿ 45000 (ರೂ/ಕ್ವಿಂಟಾಲ್)`,
   or a photo of the rate board. Status shows *Waiting → Processed/Failed*.
6. **Review.** Rows that fail a rule (e.g. > 10% from the official rate) go to the review queue; the
   admin sees the partner's text next to the extracted values.

Manual alternative for step 3–4: `python -m tools.set_claim --email society@gmail.com --partner --source-id puttur_krishi_sangha`.

**Trust score** (shown in Settings → Data sources): average of agreement with official rates
(within 10%) and on-time rate (rates for today). New partners start at 50%.

**Removing a partner:** set Approved off, then
`python -m tools.set_claim --email … --clear`.
