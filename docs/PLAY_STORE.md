# Google Play listing (optional route)

Play needs a one-time USD 25 developer registration. The free route (share the APK) needs none of this.

## App name
- kn: ಅಡಿಕೆ–ರಬ್ಬರ್ ಧಾರಣೆ
- en: Adike–Rubber Dhara: Arecanut & Rubber Rates

## Short description (≤ 80 chars)
- kn: ಕರಾವಳಿ–ಮಲೆನಾಡಿನ ದಿನದ ಅಡಿಕೆ, ರಬ್ಬರ್ ಧಾರಣೆ — ಅಧಿಕೃತ ಮೂಲದೊಂದಿಗೆ
- en: Daily arecanut & rubber prices for coastal and Malnad Karnataka, with sources

## Full description
**kn**

ಅಡಿಕೆ ಮತ್ತು ರಬ್ಬರ್ ಬೆಳೆಗಾರರಿಗೆ ಒಂದೇ ಆ್ಯಪ್‌ನಲ್ಲಿ ದಿನದ ಧಾರಣೆ.
• ಎಪಿಎಂಸಿ (ಅಧಿಕೃತ), ಸಹಕಾರ ಸಂಘಗಳು ಮತ್ತು ರಬ್ಬರ್ ಸೊಸೈಟಿಗಳ ಧಾರಣೆ — ಪ್ರತಿಯೊಂದಕ್ಕೂ ಮೂಲ, ಸಮಯ ಮತ್ತು ಗುರುತು (🟢 ಅಧಿಕೃತ / 🔵 ಪಾಲುದಾರ / 🟡 ವ್ಯಾಪಾರಿ)
• ಕನಿಷ್ಠ, ಗರಿಷ್ಠ ಮತ್ತು ಸರಾಸರಿ (ಮೋಡಲ್) ಧಾರಣೆ — ಸದಾ ಸರಿಯಾದ ಕ್ರಮದಲ್ಲಿ
• 7 ದಿನ / 1 ತಿಂಗಳು / 6 ತಿಂಗಳು / 1 ವರ್ಷದ ಚಾರ್ಟ್ ಮತ್ತು ಕಳೆದ ವರ್ಷದೊಂದಿಗೆ ಹೋಲಿಕೆ
• ಬೆಲೆ ಎಚ್ಚರಿಕೆ: ನಿಮ್ಮ ಮಿತಿ ದಾಟಿದಾಗ ಅಧಿಸೂಚನೆ
• ಮಾರಾಟ ಲೆಕ್ಕ (ಕಮಿಷನ್, ಹಮಾಲಿ, ಸಾಗಣೆ ಕಡಿತ) ಮತ್ತು ಮಾರಾಟ ದಾಖಲೆ (ಫೋನ್‌ನಲ್ಲೇ)
• ಅಡಿಕೆ ಒಣಗಿಸಲು 3 ದಿನದ ಹವಾಮಾನ ಸೂಚನೆ
• WhatsApp ನಲ್ಲಿ ಧಾರಣೆ ಕಾರ್ಡ್ ಹಂಚಿಕೆ
• ಲಾಗಿನ್ ಬೇಕಿಲ್ಲ, ಆಫ್‌ಲೈನ್‌ನಲ್ಲೂ ಕೊನೆಯ ಧಾರಣೆ ಲಭ್ಯ
ಧಾರಣೆ ಸೂಚಕ ಮಾತ್ರ; ಮಾರಾಟದ ಮೊದಲು ಖರೀದಿದಾರರೊಂದಿಗೆ ಖಚಿತಪಡಿಸಿ.

**en**

Daily arecanut and rubber prices in one app, Kannada first.
• APMC (official), co-operative and rubber-society rates — every price shows its source, time and a trust badge
• Min, max and modal price, always consistent
• Charts for 7 days to 1 year, with same-period-last-year comparison
• Price alerts when a rate crosses your level
• Sale calculator (commission, hamali, transport) and an on-device sales diary
• 3-day drying-weather outlook (MET Norway data)
• Share a rate card on WhatsApp
• No login needed; works offline with the last rates
Rates are indicative only; confirm with the buyer before selling.

Category: Business (or Tools). Content rating: Everyone. Contact email: your address.

## Data safety answers
- **Data collected:** none that identifies a person.
  - *Device or other IDs*: Firebase anonymous user id + FCM token — collected **only** if the user
    creates a price alert or reports a wrong rate; purpose: app functionality (sending the alert);
    not shared; users can delete an alert (removes the token record).
  - Partners (optional, Google sign-in): email address and business name/phone they submit —
    purpose: account management / app functionality.
- **Not collected:** location (weather uses the chosen market's coordinates, no GPS), contacts,
  photos of farmers (partner rate-board photos are processed and deleted), financial info
  (the sales diary never leaves the phone).
- Data encrypted in transit: yes (HTTPS). Deletion: users can delete alerts in the app; partners can
  request deletion by email.
- Third parties: Google Firebase (Auth, Firestore, FCM), GitHub Pages (static files), MET Norway
  (weather request with rounded coordinates, no user id).

## Privacy policy (host on GitHub Pages)
Published by the collect workflow from `pages/privacy.html` at `https://maheshraikg.github.io/<repo>/privacy.html`; link it in the listing.
