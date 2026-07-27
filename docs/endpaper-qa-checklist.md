# Endpaper — QA Checklist (pre-TestFlight)

**Date:** July 25, 2026
**Build:** `ios/` at current head; run on a real device where possible
(Face ID, notifications, and iCloud behave differently in the simulator).
Work top to bottom — the early sections set up state the later ones use.
`Seed demo` / `Clear` live in the Archive footer (debug builds only).

Legend: ☐ pass · ✗ fail (paste details in the session) · ~ known limitation

---

## 1. Fresh install & onboarding

- [ ] Delete the app if installed → clean install → launches to tutorial slide 1 ("Attention is a practice."), not Today
- [ ] Tap anywhere advances slides 1→2→3; slide 2 plays the dot-fill cascade once
- [ ] Progress dots track the current page (filled dot moves)
- [ ] "Skip" on any tutorial slide jumps straight to the account moment
- [ ] Slide 4 "Go forth." → Begin or tap-anywhere advances (July 25: every tutorial slide advances on tap)
- [ ] Account moment: "Back up with iCloud" and "Continue without an account →" both advance to the trial moment; note which you chose for §8
- [ ] Trial moment "A week, on me." → "Start my free week" lands on **Today with the keyboard up and cursor ready** (the ten-second test: fresh install → writable in <10s of user time)
- [ ] Kill the app, relaunch → straight to Today. Onboarding never re-appears on its own
- [ ] Settings → "Show the introduction again" → replays all six slides; finishing changes **nothing** (same account mode, same trial date — check Settings sync line unchanged)

## 2. Today & the writing loop

- [ ] Cursor is focused on open; placeholder reads "Write. This page is yours." when the day is empty
- [ ] Type a line, wait 5 s idle → it commits: appears above as a time-stamped section, faint "SAVED h:mm" acknowledgment appears then fades
- [ ] Type a line, background the app → committed on return
- [ ] Type a line, navigate to Archive and back → committed
- [ ] Two commits within 30 min → **one** section, two paragraphs (session merge)
- [ ] Committed text has no edit affordance anywhere — long-press, swipe, tap do nothing destructive
- [ ] Meta row counts entries and reading minutes correctly after several commits
- [ ] Type but don't commit, kill the app → relaunch → draft text is still in the field
- [ ] (If testable) leave an uncommitted draft overnight → next day it has auto-committed to *yesterday's* page and today is blank
- [ ] Empty/whitespace-only text never commits

## 3. Archive — Notebook

- [ ] Seed demo → Notebook shows ~9 months of days, newest first
- [ ] Every day's first paragraph opens with the two-line drop cap, cap flush with the text
- [ ] Crumbs are plain mono words (no iOS pill/glass anywhere): ← TODAY, SETTINGS, tabs row
- [ ] Scrolling a year of entries stays smooth (watch for hitches from LazyVStack)

## 4. Archive — Calendar (dynamic register, July 27)

- [ ] **Thin notebook** (Clear → write on 1–2 days in one month): the calendar lands on ONE big month — no year view, no back crumb, nothing daunting
- [ ] **Seeded notebook** (2+ months): lands on the year breakdown — mini matrices per month, stacked year sections for multi-year data
- [ ] Tap a written month → its mini matrix **morphs** into the big month grid (one continuous motion, not a jump)
- [ ] Month register: large tappable dots (~34px, today 40 + ring), each written day showing a **faint entry count on the dot**
- [ ] Tap a written day → that day's read-only page; ← BACK returns; ← YEAR morphs back to the year view
- [ ] Unwritten months don't navigate (except the current month)
- [ ] The whole journey year → month → day → back reads smooth, no jarring swaps

## 5. Archive — Find

- [ ] Field is centered and huge before typing
- [ ] Type "boat" → results grouped by day, matches underlined, day stamps correct
- [ ] Tapping a result opens that day's page
- [ ] One-character queries return nothing (2-char minimum); gibberish shows "NOTHING FOUND."

## 6. Reflections (the big one — after Seed demo, return to Today)

- [ ] **Consent card** appears on Today: "Reflections – Your Week" (it never appears before a recap could exist — verify by Clear → no card on empty data)
- [ ] "No thanks" → card gone, never returns (relaunch to confirm); Seed demo resets it
- [ ] Re-seed → "Yes, reflect" → the **weekly reflection** arrives as a two-screen sequence (July 25): the week in numbers (wrapped-style big stats), then the words — topic large, verbatim quotes with weekday stamps, Continue (no closing question — removed July 27)
- [ ] Close it → next visit to Today, the **monthly recap** arrives (monthly wins, weekly first only right after consent — per the flow, one arrival per visit)
- [ ] Recap sequence: circles intro → month grid draws itself (month label beneath) → the numbers, wrapped-style stacked → "Recurring ideas" intertitle → topics with 2 quotes each → "Your Word" → "Challenges" (only if difficulty quotes exist) → "Reflect & start anew" + CONTINUE
- [ ] Countdown bar shrinks; **tap anywhere continues on every slide** (timed or held, July 27); **hold ≥250 ms pauses** (bar freezes), release resumes
- [ ] Dismissed reflections rest as condensed on-color cards at period boundaries in the Notebook; tapping one reopens the full moment with identical content (no re-roll)
- [ ] Calendar year row shows "Your year →" (consent = yes) → **wrapped**: year matrix draws itself → big numbers → five threads → most-discussed reveal with first-ever mention → "See you on the page."
- [ ] Wrapped outro: "Save your year" opens the share sheet with the dots image — **verify the image contains dots and counts only, zero writing**
- [ ] Honesty checks: Clear → write 2 short entries on one day → no consent card, no reflections (thresholds hold)
- [ ] **⌘U in Xcode** — the parity suite (`EndpaperTests`): all four tests pass, or paste failures verbatim into the session

## 7. Reminder

- [ ] Clear → fresh state → the pre-prompt card is **absent** until you've written on 2 distinct days (commit today + seed or backdate)
- [ ] Card appears on Today *below the writing surface*, and never simultaneously with the consent card
- [ ] "No thanks" → gone forever (relaunch to confirm); the OS permission dialog **never appeared**
- [ ] Reset → "Yes, 8:00 AM" → the system dialog appears now, and only now
- [ ] Settings: toggle reflects the choice; time picker changes take effect (set reminder 2 min ahead, lock the phone, wait — it fires)
- [ ] Write something today, with the reminder set for later today → today's notification is skipped (re-aimed at tomorrow)
- [ ] Tapping the notification opens the app to Today, writable

## 8. Settings, iCloud, export, Face ID

- [ ] All five rows render in the registers; no system-blue anywhere
- [ ] Sync line is honest: iCloud mode + signed in → "SYNCED TO YOUR PRIVATE ICLOUD · APPLIES AT NEXT LAUNCH"; signed out of iCloud (Settings app) → the unavailable line; local mode → "SAVED ON THIS DEVICE ONLY"
- [ ] **Two-device test** (needs the iCloud capability on your team's app ID): iCloud mode on both, write on device A → appears on device B after a relaunch; write on both within the same 30-min window → sections merge, don't fork
- [ ] Export → share sheet → `notebook.md`: whole notebook, day-headed, oldest first, times stamped; open it in a text editor and spot-check against the Notebook
- [ ] Face ID toggle on → background the app → reopen → lock screen (one dot + ENDPAPER), Face ID sheet auto-prompts; success unlocks, cancel leaves the lock with UNLOCK to retry
- [ ] Lock sits **above** the paywall (if both apply, lock shows first)
- [ ] Device with no passcode: toggle on → app never hard-locks you out (gate stands aside)

## 9. Trial & paywall

- [ ] Debug check: trial stamp exists from onboarding (no App Store product yet — the local 7-day window applies)
- [ ] Simulate expiry: in Xcode, pause and set the stored `endpaper.trial.v1` date back 8 days (or temporarily shorten the window) → relaunch → paywall: "The week is over." — notebook inaccessible but **not** deleted
- [ ] Restore purchase on the paywall doesn't crash with no App Store record (quiet no-op)
- [ ] (With `Endpaper.storekit` set as the scheme's StoreKit configuration) "Start my free week" runs a sandbox purchase; "Keep writing" on the paywall completes and unlocks; Restore works

## 10. System integration

- [ ] **Dark mode**: flip mid-use — every screen re-themes at the token level (char/bone-type); check the inverted reflection surfaces still read correctly in dark
- [ ] **Reduce Motion** (Settings → Accessibility): onboarding dot-fill is static, recap/wrapped grids appear pre-drawn, sequences still advance
- [ ] **VoiceOver**: dots speak ("July 5, written, today"); month cards speak once ("July 2026, 21 days written"); drop-cap paragraphs read as whole sentences, not "S" + "anded…"; tutorial dots announce "Page 2 of 4"
- [ ] **Dynamic Type XL**: ~ *known limitation* — the registers are fixed-size this round (matching the token sheet). Verify nothing *breaks* (clipping, overlap); note reading comfort for a post-beta decision
- [ ] Interruptions: incoming call / control-center pull mid-writing → draft intact; mid-recap-sequence → sequence state sane on return
- [ ] Rotation is locked to portrait
- [ ] Low Power Mode: animations still complete (timers are Task-based)
- [ ] Airplane mode: everything works; iCloud writes queue and sync later (write offline, go online, check device B)

## 11. Lifecycle & edges

- [ ] Kill and relaunch at every screen — no crash, state sane
- [ ] Write at 11:58 PM, commit at 12:01 AM (or simulate) — entry lands on the day it was *committed*; no orphaned draft
- [ ] Timezone change (Settings → General → set a different zone) → day keys stay consistent; no duplicate or vanished days
- [ ] Delete app → reinstall → local mode: data gone (expected); iCloud mode: notebook returns after sync
- [ ] Seed → Clear → seed again: deterministic (same demo notebook every time)
- [ ] Leave the app running overnight → next open shows the new day's page

---

## After this list: the road to TestFlight

Everything left is **accounts and assets, not code**:

1. Apple Developer Program enrollment (D1)
2. App Store Connect record, bundle `com.wendellbarton.endpaper` (D2)
3. iCloud container on the team's app ID + deploy schema to production (D3)
4. Subscription product + 7-day intro offer in ASC (D4) — then delete the
   local trial-stamp fallback path
5. App icon + launch screen (D5 — one filled dot on bone)
6. Archive/upload the build → TestFlight internal testing (no review) →
   external group (one-time beta review; needs the privacy policy URL,
   which is live)

Fixes from this QA pass fold in before the upload. That's the whole gap.
