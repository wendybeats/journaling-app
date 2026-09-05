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
- [ ] Tap a written month → **each dot flies** from its mini-matrix spot to its month-grid spot, growing 5→34px, staggered like magnetic pulls (July 28 rebuild — per-dot matching)
- [ ] Month register: large tappable dots (~34px, today 40 + ring), each written day showing a **faint entry count on the dot**
- [ ] Month register is a **scrollable list of the year's months**, landing on the tapped month with neighbors above/below
- [ ] Tap a written day → that day's read-only page; ← BACK returns; ← YEAR flies the dots back into the year view
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

## 12. Capture (1.0.2): voice card, photo, file import

Voice — the card, not the draft:

- [ ] Type a line → REC → keyboard slides down, card rises, waveform moves
      with your voice (flat in silence, spikes in speech), timer runs
- [ ] Speak → pause 3s → speak → stop: the committed section contains ALL
      words; the typed draft above is untouched
- [ ] Stop with zero words: no empty section, card just dismisses
- [ ] Background the app mid-take: what was said so far commits as a section
- [ ] Committed section meta reads "9:41 PM · SPOKEN" (rose marker);
      same-day edit works and the marker persists; next day it locks
- [ ] Two takes in a row → two separate sections (no session merge);
      typing after a take starts a fresh typed section
- [ ] Long take (>1 min): recognizer may file its final early — words to
      that point survive; stop still commits (known edge, note behavior)
- [ ] Deny mic or speech permission → no card, no crash; re-ask flow sane

Import — UPLOAD pill:

- [ ] UPLOAD → menu: Take a photo / From your photos / Choose a file
- [ ] Photograph a handwritten page → words land as one flowing section
      (paragraphs joined, not one line per photographed line), meta
      "· SCANNED"
- [ ] Multi-page scan in one camera session → one section, pages joined
- [ ] Photo-library image of writing → same path
- [ ] .txt and .md files → text lands (md markup stripped: #, **, links,
      bullets), meta "· IMPORTED"
- [ ] Text-layer PDF → paragraphs land clean; scanned PDF → OCR fallback
      reads the pages
- [ ] .doc/.docx → quiet message: "Word files can't be opened here —
      export as PDF or text first." — no crash
- [ ] "reading your writing…" shows while OCR runs; failure messages show
      in the same quiet register and fade
- [ ] Device B (iCloud): origin markers sync; a pre-1.0.2 client shows
      captured sections as plain text without crashing

---

## 13. Recaps (1.0.2): weekly deck + monthly sequence

Seed a demo notebook (or write across several days) with consent = yes,
then force the arrivals (Settings demo tools / fresh week boundary):

- [ ] Weekly arrives as a swipeable deck; every beat opens with the
      prompt flash → slide-up → metric reveal; pager dots visible in
      BOTH light and dark mode
- [ ] Beats without evidence are absent (no session times → no
      shape/sitting; no "?" sentence → no question; nothing written
      large → no big-line beat) — never an empty page
- [ ] Big-line beat shows the line at display size; question beat is
      verbatim, with its weekday
- [ ] Monthly: dot opener (cropped circle, left-set type) → grid →
      three FAST number slides → opened/closed split → turn (ghost →
      ink; replaces Your Word when present) → topics → people → rhythm
      bars → spoken (rose) → challenges → outro
- [ ] Insufficient month still gets the quiet variant, no new slides
- [ ] Old archived reflections (pre-1.0.2) reopen from the Notebook
      without crashing (new fields decode as absent)
- [ ] Reduce Motion: prompts sit at rest, metrics appear without travel
- [ ] Tap-to-advance/hold-to-pause still work on the monthly sequence

Round 2 (2026-08-20, build 11):

- [ ] Weekly opens with the ring opener ("Your week."), monthly with the
      filled-disc opener — siblings, not twins
- [ ] Weekly shape beat: the seven dots draw in one by one
- [ ] Weekly numbers are separate beats and COUNT UP (days, then words);
      monthly's three number slides count up too
- [ ] Weekly closes: challenge quote (when one exists) → "See you on the
      page." + Continue
- [ ] Monthly order: opener → grid → numbers → opened/closed → one name
      kept appearing → rhythm → spoken → kept surfacing (topics) →
      challenges → your word / the turn (closer) → outro
- [ ] Topics, challenges, and the tone slide all open with the prompt
      choreography (no more intertitle cards)
- [ ] Writing bar: REC + UPLOAD left, Done right, no overlap on iPhone 15;
      bar present after Archive → seed → back (regression)
- [ ] Voice card: waveform touches both card edges; transcript has side
      padding
- [ ] Review sheet meta fits one line on iPhone 15 ("From your photo ·
      tap to edit or fix")

Round 3 — production candidate (2026-08-20, build 12):

- [ ] Type a line, record a voice note mid-draft, let the draft idle-commit:
      the typed section sorts ABOVE the spoken one (writing-start ordering)
- [ ] UPLOAD pill absent in an App Store/Release build; present on TestFlight
- [ ] Settings → Voice language: chips select; ru-RU actually transcribes
      Russian speech on device; "Match device" restores default; a language
      without on-device support falls back to the device recognizer (REC
      still works)
- [ ] Known limitation (accepted for now): the 180s idle commit delays
      iCloud sync by up to 3 minutes — an uncommitted draft has nothing to
      sync. Revisit if cross-device users complain.

## 14. Unpayable storefronts (build 13)

Apple processes no payments in Russia (since March 2022): no paid apps,
no IAP, no subscriptions, no offer codes. Endpaper stays open there
rather than showing a door nobody can walk through.

- [ ] With a Russian-storefront Apple ID: onboarding's trial slide reads
      "Endpaper is yours." / "Apple doesn't process payments in your
      region…", button says "Start writing", no price line, no Restore
- [ ] Writing works; day 8 (or with the trial stamp cleared) shows NO
      paywall — the notebook stays open
- [ ] With a US storefront: unchanged — trial slide, Apple sheet, price,
      paywall after the week
- [ ] Airplane mode on a payable storefront: paywall says "The App Store
      isn't reachable right now" instead of a silent dead button
- [ ] Simulator check: Xcode → scheme → Options → StoreKit → the
      `.storekit` config's Storefront setting can be switched to Russia
      to exercise the branch without a Russian Apple ID

## 15. Build 14 — transcript duplication + trial reinstall

Theme toggle (Settings → Theme):

- [ ] "System" follows the OS (flip iOS appearance → app re-themes)
- [ ] "Light" and "Dark" pin the app regardless of OS setting; survives
      relaunch
- [ ] Every surface obeys — Today, Archive, recap sequences, onboarding,
      the voice card, paywall — no half-themed screen
- [ ] Reflections' inverted (on-color) surfaces still read correctly
      under a pinned theme

Voice:

- [ ] Record a LONG take (60s+) with several 2–3s pauses, talking through
      them: no clause appears twice. (Build 13 re-delivered folded words
      after a pause and wrote them onto the page again.)
- [ ] Deliberately repeat a word twice in a row ("really, really tired") —
      it survives; the dedupe only trims runs of 2+ words
- [ ] Transcript arrives punctuated rather than as one run-on

Trial (the reinstall hole):

- [ ] Start the free week → delete the app → reinstall → onboarding does
      NOT hand out a second week; the original clock still applies
      (stamp is mirrored to iCloud key-value storage)
- [ ] Same, with the device offline at first run (the fallback path that
      grants the local week) — reinstall still can't re-trial
- [ ] Signed out of iCloud entirely: local week still works (a legit
      offline user isn't punished); note this is the accepted escape
      hatch — it costs the abuser the synced notebook
- [ ] A genuinely new Apple ID gets a normal new trial (expected)
- [ ] Xcode: the target has the iCloud key-value storage capability after
      `xcodegen` (entitlement `ubiquity-kvstore-identifier`)

## 16. Onboarding deck (reflections-first; revised per QA 2026-08-27)

Splash: one dot held center, expanded until its ink fills the screen,
faded to reveal the deck (the calendar dive motif). Then six beats on
the SYSTEM surface (not inverted): centered opener ("The journal that
reflects.") → "Each day" month grid above the title → "What did I say?"
("stressed") → "Who did I talk about?" ("Sam") → collage of overlapping
stat cards → "Today's page is ready." Then the unchanged account and
trial slides.

- [ ] Fresh install: splash dot holds ~0.7 s, expands to fill, fades
      into the opener; Reduce Motion skips the splash entirely
- [ ] Deck matches the app's theme (bone in light, char in dark) — no
      inverted surface anywhere in the tutorial
- [ ] Each PromptBeat plays the choreography: prompt flashes centered
      large in ink, holds ~1 s, slides up to its seat (muted), then the
      content rises
- [ ] "Each day" beat (revised 2026-09-05): one dot splits into the
      week row, then blooms into the 30-dot month (3 misses), the morph
      travelling outward from the week's center; grid sits ABOVE
      "Write each day, sealed at midnight."
- [ ] Deck pacing: prompt holds ~0.5 s (halved), opener is full-ink at
      54pt; copy — "stressed · 2 times this week · no analysis, no AI"
      and "Mom · Mentioned 3 times this week · Get to know yourself
      better through your writing" (no "a sample" anywhere)
- [ ] Collage beat: five cards (days counter, rhythm bars, rose voice
      waveform, words counter, "Enough.") land staggered, overlapping,
      tilted — all legible, none clipped off-screen on a small phone
      (test SE-class width)
- [ ] Tap anywhere advances every deck beat (but NOT during the splash);
      swipe left advances; swipe right goes back a beat; the pager dots
      (6) track position
- [ ] Skip (top right) jumps straight to the account slide from any beat
- [ ] Account and trial slides still require their buttons — tap-anywhere
      must NOT advance past them
- [ ] Trial slide unchanged: purchase sheet on "Start my free week",
      dismissing the sheet stays on the slide, Restore works, the
      TestFlight store-check line shows product state
- [ ] Replay from Settings ("Show the introduction again"): full deck
      plays, and finishing writes nothing — account mode, trial stamp,
      and onboarded flag all unchanged
- [ ] Reduce Motion on: no splash, every beat renders at rest (prompt
      seated, content visible, month grid pre-filled, collage laid out)
- [ ] VoiceOver: pager announces "Page n of 6"; Skip, Begin, and both
      account buttons are reachable and labeled

## 17. Build 18 (1.0.4) — the free model

Writing free forever; membership gates reflections. First weekly plays
free and closes on the offer. Daily-arrival splash + countdown line +
first-week ghost prompts carry the free user's week. Share cards v1.

Onboarding & model
- [ ] Fresh install: deck → account slide → straight onto the page — NO
      trial slide, no payment sheet anywhere in onboarding
- [ ] Closing beat carries the quiet membership line (no price, no button)
- [ ] Replay from Settings ends at the account slide and writes nothing

Daily arrival & countdown
- [ ] Onboarding day: no arrival splash (the deck was the moment)
- [ ] Next day's first open: countdown line held large → dot expands to
      fill → fades into Today; plays once per calendar day (background /
      foreground same day: no repeat)
- [ ] Countdown copy: n days away / arrives tomorrow / is ready (Sunday);
      consent=="no" shows the bare weekday instead
- [ ] Today: small "Reflection in n days" line under the date (hidden
      when reflections are declined)
- [ ] Reduce Motion: no splash at all

Ghost prompts (first week)
- [ ] Days 1–7: a charged italic question as the empty-page ghost;
      vanishes on first keystroke; gone once anything is committed today
- [ ] Day 8+: plain "Write." placeholder returns

Free weekly + offer
- [ ] Non-member's first weekly arrives and plays in full; its closing
      beat is the offer ("That was your week" → join / not now)
- [ ] "Not now" closes the deck; the card is archived as normal
- [ ] Second weekly for a non-member does NOT auto-present: quiet line
      "Your week is ready — join to read it →"; joining presents it
      immediately, unspoiled (it was never marked seen while locked)
- [ ] Monthly for a non-member: same locked line, never auto-presents
- [ ] Member (or unpayable storefront): weekly and monthly arrive as
      before, decks close on "See you on the page."
- [ ] Purchase from offer beat / Settings applies the ASC intro offer
      (first week free) and unlocks on the spot; Restore works
- [ ] Trial-stamp reinstall logic is moot for writing (never gated) —
      confirm a lapsed 1.0.2 user upgrading to 1.0.4 lands on the page,
      not a paywall

Share cards v1
- [ ] Long-press an entry → "Share as card": bone card, drop cap, day
      stamp, ENDPAPER.SPACE footer; long text scales, never clips
- [ ] Calendar → long-press a month name → "Share this month": char
      constellation card matches that month's dots
- [ ] Cards render identically in light and dark app themes (cards pin
      their own colors)

Round 2 (2026-09-05) — Today page + reflections flow:
- [ ] Heading: full "Saturday, September 5" on a blank day; cross-fades
      to "Sep 5" on the first typed characters and STAYS short for the
      rest of the day (committing keeps it short); no repeated small
      date line underneath — only "N entries · M min" once entries exist
- [ ] Countdown line carries the mini reflections mark (outlined +
      filled overlapping circles, meta tone) to its right
- [ ] Ghost prompt: comfortable line height on two-line questions
- [ ] Consent card: opting in presents NOTHING (new user has no week);
      it arms the weekly notification pair instead
- [ ] End of week: "Your week is ready." card rests on Today — tapping
      it opens the deck; nothing auto-presents on app open any more
- [ ] Non-member, free weekly spent: the same card reads "Join to read
      it →" and purchases inline
- [ ] Non-member monthly: card opens the full-screen recap-styled gate
      (inverted, cropped disc, "Your August recap is ready.") with
      Join / Not now; Not now returns with the card still resting;
      joining opens the real recap immediately
- [ ] Settings → Reflections toggled ON by a non-member: the inverted
      membership sheet rises; dismissing keeps reflections on (consent
      is never gated)
- [ ] Notifications (consent on, permission granted): Saturday 22:00
      "Know yourself: your weekly reflection arrives tomorrow." and
      Sunday 9:00 "What did you say? Your weekly reflection is here."
      — both repeat weekly; turning consent off cancels both

## Payment flow — reliable testing recipe (2026-08-18)

The confusing sightings post-launch were all environment artifacts, not
bugs: TestFlight builds hit the **sandbox** store, where trial
eligibility resets per sandbox account and canceled subs expire in
minutes — while a **production** sub canceled on a real account persists
to period end, and a production lapsed user is (correctly) never
re-offered the intro trial. Three tiers, in order of usefulness:

1. **Deterministic (daily driver): local StoreKit config.** Xcode scheme
   → Run → Options → StoreKit Configuration → `Endpaper.storekit`. Then
   Debug → StoreKit → Manage Transactions gives full control: delete the
   transaction to become a brand-new user, expire it to test the lapsed
   paywall, refund it, toggle intro-offer eligibility. Every path in
   section 9, on demand, no waiting.
   - [ ] New user: onboarding purchase sheet → trial starts only on a
         verified transaction (dismiss the sheet → still gated)
   - [ ] Expire the transaction → lapsed paywall appears → "Keep
         writing" re-subscribes and unlocks
   - [ ] Delete transaction + relaunch → clean new-user state again
2. **Realistic (before each submission): fresh ASC sandbox tester.**
   Users and Access → Sandbox Testers → new tester (any +tag email).
   On device: Settings → App Store → Sandbox Account. Delete/reinstall
   the app between runs for a clean slate. Sandbox clock: trial burns in
   minutes, so a full trial→convert→lapse cycle is a coffee break.
3. **Production truth (once, post-release): a friend's device** with an
   account that has never bought Endpaper — the one thing sandbox can't
   prove is the live ASC product configuration. One install, one
   purchase-sheet sighting ("1 week free, then $39.99/year"), refund via
   reportaproblem.apple.com if they don't want to keep it. Not a
   regression tool — config verification only.

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
