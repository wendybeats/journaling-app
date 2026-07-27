# Endpaper — TestFlight Runbook

**Date:** July 27, 2026
**Precondition:** Apple Developer Program enrollment complete (D1).
Work top to bottom; each step's output feeds the next. Repo is
build-ready: icon, launch screen, entitlements, StoreKit config, and the
privacy/terms URLs are all in place.

---

## 1. Identifiers & capabilities (developer.apple.com → Certificates, IDs & Profiles)

1. **App ID**: register `com.wendellbarton.endpaper` (explicit, not wildcard).
2. Enable capability **iCloud**, and create/assign the container
   `iCloud.com.wendellbarton.endpaper` (must match the entitlements file
   exactly).
3. Nothing else — no push (reminders are local), no App Groups.

## 2. App Store Connect record

1. My Apps → **+ New App**: platform iOS, name **Endpaper** (if the bare
   name is contested, fallback listing name "Endpaper — Journal"),
   primary language English (U.S.), bundle `com.wendellbarton.endpaper`,
   SKU `endpaper-ios`.
2. App Information → category **Lifestyle** (secondary: Health & Fitness
   or Productivity — decide at listing pass), age rating questionnaire
   (all "no" → 4+).
3. **App Privacy** → Data Collection: **"Data Not Collected."** (True by
   architecture; the label is the marketing moment.)
4. URLs: privacy `https://endpaper.space/privacy.html`, support
   `https://endpaper.space/` (both live).

## 3. Paid apps prerequisites (blocks the subscription, not the beta)

- **Agreements, Tax, and Banking** → sign the Paid Applications
  agreement, add bank + tax forms. Processing can take days — start it
  the same day as enrollment.

## 4. Subscription product

1. App → Monetization → Subscriptions → create group **Endpaper**.
2. Auto-renewable subscription: reference name **Endpaper Yearly**,
   product ID **`com.wendellbarton.endpaper.yearly`** (must match
   `TrialGate.yearlyID` exactly), duration 1 year, price **$39.99**
   (decided July 27: annual-only, no monthly).
3. **Introductory offer**: Free, 7 days, one per Apple ID.
4. Localization: display name "Endpaper Yearly", description "Every page,
   every reflection."
5. **Code change after the product is live in sandbox:** delete the
   local trial-stamp fallback in `TrialGate.startTrial()` (the
   `guard let product else` branch) — from then on StoreKit is the only
   trial. Session note: ask Claude; it's a 5-line removal.

## 5. CloudKit production schema

1. Run the app once on device with iCloud backup on (dev environment
   creates the schema from the `Entry` model).
2. [CloudKit Console](https://icloud.developer.apple.com) → container →
   **Deploy Schema Changes** dev → **Production**. (Without this,
   TestFlight builds sync nothing — TestFlight uses the production
   environment.)

## 6. Archive & upload

1. Xcode: select **Endpaper** scheme, destination **Any iOS Device
   (arm64)**.
2. Bump if re-uploading: `CURRENT_PROJECT_VERSION` in `ios/project.yml`
   (build number must be unique per upload) → `xcodegen`.
3. Product → **Archive** → Organizer → **Distribute App** → App Store
   Connect → Upload (automatic signing).
4. Wait for processing (~15 min); the build appears under TestFlight.
5. Export compliance is pre-answered (`ITSAppUsesNonExemptEncryption:
   false` ships in the Info.plist) — no per-build questionnaire.

## 7. TestFlight

1. **Internal testing** (no review): create group "Core", add your own
   Apple ID + any ASC users → build is installable within minutes.
   Install via the TestFlight app on the phone.
2. **External testing** (friends): create group "Friends", add the build,
   fill Beta App Description + feedback email (hello@endpaper.space) →
   submit for **beta review** (usually <24 h; needs the privacy URL —
   live). Then invite by email or public link (cap it — 20 is plenty).
3. Beta builds expire in 90 days; upload fresh builds as fixes land
   (internal group updates without re-review; external re-review is
   usually instant for iterative builds).

## 8. What to verify on the first TestFlight install

- Sandbox subscription: trial starts through StoreKit (not the local
  stamp), Manage Subscription shows it, restore works
- iCloud sync in production environment (two devices)
- The icon, launch screen (bone/char), and display name
- Reminder permission + delivery on a device that never saw a dev build

## Known-remaining before *public* release (not beta blockers)

- Pricing pass (final price on the product)
- Store listing assets: screenshots (light+dark), description in the
  product's voice, keywords
- Formal trademark screen on "Endpaper"
- Grandfathering decision for beta testers (default: 1-year promo codes)
- Swap the site's drawn App Store badge for Apple's official asset +
  real store URL
