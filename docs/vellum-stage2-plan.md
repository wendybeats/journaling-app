# Vellum — Stage 2 Plan: Account & Recovery, Onboarding, Reminder

**Version:** 1.0
**Date:** July 7, 2026
**Owner:** Wendell Barton
**Scope:** Implementation plan for the three pre-launch features (sign-in/recovery, 3-screen tutorial, daily reminder). The Reflection layer (V2) is specced separately once its open questions are settled.

---

## 0. Guardrails

Everything below is measured against the PDP's governing constraints:

- The user's writing is the only full-contrast element; new surfaces must not compete with it.
- The default answer to "should we add a surface" is no (PDP §4.5).
- Whitespace, dots, and the three type registers are the entire visual vocabulary. Onboarding, sign-in, and notifications get **zero new visual language**.

### ⚠️ One decision gates this stage

The PDP's non-goals (§4.5) say **"no accounts, no login"**, and §2 stakes the positioning on *local-first, no server*. Feature 1 as requested (Apple **or Google** sign-in) requires an account system, and Google sign-in specifically requires a **custom backend** — Google identity cannot gate CloudKit. That's a real change to the privacy story, the App Store listing copy, and the engineering surface. Three paths:

| Path | What it is | Recovery story | Server? | Cost |
|---|---|---|---|---|
| **A — Apple-native (recommended)** | No sign-in screen at all. SwiftData + CloudKit private DB (already the PDP architecture). "Account" = the user's iCloud, like Apple Notes. | New phone + same Apple ID → notebook is just there | No | ~0 — it's the existing architecture |
| **B — Real accounts, Apple + Google** | AuthenticationServices + GoogleSignIn, entries synced to our backend (Supabase/Postgres w/ RLS or equivalent), client-side encryption | Sign in anywhere → notebook restores | **Yes** | Backend, sync engine, E2EE key management, account deletion flows, privacy-label changes |
| **C — Ship A, add B later** | A now; the account layer only if/when a non-Apple platform (web/Android) exists to justify Google identity | Same as A now | Later | Defers the cost until it buys reach |

**✅ DECIDED (July 8): Path A — Apple-native.** Recovery through the user's
own iCloud; no account system, no server, positioning intact.

Recommendation: **A (or C, same thing at this stage).** It delivers exactly the stated goal — "recover their notes if lost" — with zero new surfaces, zero server, and the privacy positioning intact. The "skip account" option in A becomes a single quiet toggle: iCloud sync on/off.

The rest of §1 specs the **UX shell that works for any path**, plus path-B technical notes so nothing is foreclosed. **Decide A/B/C before building §1; the data model depends on it.**

---

## 1. Sign-in & recovery

### 1.1 UX spec

One screen, appearing once — after the tutorial, before first landing on Today:

- **Title** (`type.display`): "Keep your notebook."
- **Subtitle** (`type.written`, 2 lines max): "Your writing stays in your private storage — no profile, no analytics, nothing read by anyone but you."
- **Actions**, stacked, `radius.control`, no icons except the platform-required marks:
  - *Path A:* single button — "Back up with iCloud" (turns on CloudKit sync; this is the default, pre-highlighted)
  - *Path B:* "Continue with Apple" (first — App Store guideline 4.8 requires SIWA wherever third-party login exists), then "Continue with Google"
- **Skip**, quiet mono meta link below the buttons — "Continue without an account →" — with a one-line consequence in `type.metaSmall`: `SAVED ON THIS DEVICE ONLY`.
- No modal, no interstitials, no "are you sure." The skip path is a first-class citizen, not a shame gate.

### 1.2 Rules

- **Skippers can upgrade later.** Settings row: "Back up your notebook." On upgrade, the local corpus is adopted wholesale (entries carry stable UUIDs — no duplication risk).
- **Sign-out** (path B) asks one clear question: keep the local copy on this device, or remove it. Two buttons, no default trickery.
- **Account deletion** (path B): full in-app deletion of account + server data (App Store requirement). Path A needs nothing — data lives in the user's own iCloud.
- Sign-in state never changes the writing experience. No banner, no avatar, no cloud icon. Sync status appears only in Settings and only as a mono meta line (`SYNCED · 9:41 AM`).

### 1.3 Technical notes

**Path A:** `NSPersistentCloudKitContainer` / SwiftData `.cloudKitDatabase(.private)`. Recovery is inherent to the Apple ID. "Skip" = container configured local-only; upgrading re-initializes with the CloudKit option and migrates the store. Edge cases: iCloud storage full (surface one quiet meta warning in Settings, never on the page), account restrictions (managed devices), airplane-mode writes (CloudKit queues natively).

**Path B (if chosen):**
- Auth: `AuthenticationServices` (SIWA) + GoogleSignIn SDK; tokens exchanged for a backend session (Supabase Auth handles both providers natively).
- Storage: Postgres, one `entries` table (id UUID, user_id, day_key, at, last_at, text, updated_at), row-level security by user_id.
- Encryption: client-side AES-GCM before upload; key stored in iCloud Keychain (synced) so recovery works without a password. Document the tradeoff: Keychain escrow means Apple-ecosystem recovery; a user-held passphrase would be stronger but makes "recover if lost" fail for exactly the people it's meant to protect. Recommend Keychain escrow.
- Sync: per-entry last-write-wins on `updated_at`; the 30-minute merge window must compare `lastAt` *after* pulling remote state, or two devices writing in the same window will fork the section. Offline queue with replay.
- RevenueCat: set its app-user-id to the account id at sign-in so purchases follow the account.

### 1.4 Definition of done

- [ ] Path decision recorded here (A / B / C)
- [ ] Fresh install → tutorial → account screen → Today, cursor ready, under 10 seconds of user time
- [ ] Skip path works and is remembered; upgrade path adopts local corpus without duplicates
- [ ] Delete/sign-out flows exist (B) or are n/a (A)
- [ ] Two-device test: write on one, appears on the other; same-window writes merge, not fork

---

## 2. Tutorial — three screens

### 2.1 Content (draft copy — final pass in situ)

Four full-bleed pages (ceiling raised July 8 to teach permanence and the
reflection layer), swipe or tap to advance, mono `SKIP` top-right. Progress indicator: **three Vellum dots**, the current page's dot filled — the habit metaphor, taught silently before a word about it is read.

1. **Why** — display heading: "Attention is a practice."
   Body (serif, ≤3 sentences): "A few honest lines a day change how the day sits with you. Not therapy, not productivity — just noticing, kept somewhere quiet."
2. **What** — display heading: "This is Vellum."
   Body: "Open it, write or speak, close it. What you write stays written — no edits, no deletions; the point is to commit. Each day you write, a dot fills in."
   Visual: a live month grid, a handful of dots filling one by one (`motion.fast` cascade).
3. **Reflections** — display heading: "It reads back."
   Body: "Each week, month, and year, Vellum can reflect your writing back to you — the topics and words you returned to most. Optional, always skippable, only ever yours."
   Visual: the reflections circle motif (ring + near-opaque disc).
4. **Go** — display heading: "Go forth."
   Body: one line — "Today's page is ready."
   CTA (the only button): **"Begin"** → lands on Today, cursor focused, keyboard up.

### 2.2 Rules

- Shows exactly once (`onboarded` flag). Replayable from Settings ("Show the introduction again") — never re-triggered otherwise.
- Sequence on first launch: tutorial → account screen (§1) → Today.
- No feature tour, no permission requests, no tips. Three screens is a ceiling, not a target.
- Respect Reduce Motion: dot-fill cascade becomes a static filled grid.

### 2.3 Implementation

- iOS: `TabView(.page)` with custom dot indicator (system indicator is the wrong dots); copy as constants, not localized files, until localization is real.
- Web prototype: buildable now as an overlay in the existing system (~1 session). Worth doing — it's the first thing every user sees and should be judged visually like the rest.

### 2.4 Definition of done

- [ ] All three screens render in both modes, both text sizes (Dynamic Type XL check)
- [ ] Dot-fill moment lands (and degrades under Reduce Motion)
- [ ] Fresh-install path lands on Today with cursor ready
- [ ] Replay entry point in Settings

---

## 3. Daily reminder

### 3.1 Product rules

- **Local notifications only.** No server, no push infrastructure, nothing leaves the device. (This also survives an A/B/C account decision unchanged.)
- **At most one per day**, morning, default **8:00**, user-adjustable in Settings.
- **Off until offered, offered once.** The system permission dialog is never the first touch:
  1. Trigger: the user has written on ≥2 distinct days (they've felt the value) — not first launch.
  2. In-app pre-prompt, in-system: a quiet card on Today after a save — "Want a nudge each morning? One line, once a day." / mono actions: `YES, 8:00 AM` · `NO THANKS`.
  3. Only a yes opens the system dialog. A no is remembered and never re-asked; the Settings row remains for changed minds.
- **Suppress when already written:** if today's page has an entry before reminder time, today's notification is cancelled. The reminder is a doorway, not a scoreboard.
- **Copy pool** (rotate, one line, no title, no emoji, never streak language):
  - "The page is ready."
  - "A few lines, before the day gets loud."
  - "Nothing fancy. Just today."
  - "Yesterday had edges. Write one down."
- Tapping it opens Today, cursor ready.

### 3.2 Implementation

- iOS: `UNUserNotificationCenter`, repeating `UNCalendarNotificationTrigger` at the chosen time. On every entry commit and on foreground: if today's entry exists, `removePendingNotificationRequests` for today and re-arm tomorrow's. Copy rotation seeded by day-of-year (deterministic, testable).
- Settings surface (this stage's only settings additions): "One reminder, each morning" toggle + time — plus §1's backup row and §2's replay row. Still deliberately sparse.
- Web prototype: document-only (browser notifications don't map to the iOS choreography and would test nothing real). The pre-prompt card *is* worth prototyping visually.

### 3.3 Definition of done

- [ ] Permission never requested before the pre-prompt yes
- [ ] Reminder fires at chosen time; suppressed on days already written
- [ ] Time change and toggle-off take effect immediately
- [ ] Notification deep-links to Today writable
- [ ] Reinstall doesn't resurrect a declined prompt (flag persisted in the store, not UserDefaults, if path A/B syncs it)

---

## 4. Sequencing & estimates

Order of build (after the A/B/C decision):

| # | Work | Depends on | Estimate (nights) |
|---|---|---|---|
| 1 | A/B/C decision + data-model consequences | — | decision only |
| 2 | Tutorial (web prototype, then SwiftUI) | — | 1 + 2 |
| 3 | Reminder pre-prompt card + logic | — | 1 + 2 |
| 4 | Account/backup screen + flows | #1 | A: 2 · B: 8–12 |
| 5 | Settings additions (3 rows) | #3, #4 | 1 |

Path B's 8–12 nights are mostly invisible work (backend, encryption, sync edge cases, deletion) — worth stating plainly since solo-build schedule risk is the PDP's named top risk.

---

## 5. Open items

| # | Item | Owner |
|---|---|---|
| 1 | ~~Path A / B / C~~ | ✅ **Path A** (July 8) |
| 2 | Final tutorial copy pass | Wendell + build |
| 3 | Reminder default time — 8:00 assumed | Wendell |
| 4 | Do tutorial + account screens ship in the web prototype first? (Recommended: yes, they're cheap and visual) | Wendell |
