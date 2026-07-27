# Vellum — Launch Plan: From Prototype to the App Store

**Version:** 1.0
**Date:** July 24, 2026
**Owner:** Wendell Barton
**Scope:** Everything between today's state (web prototype complete; SwiftUI
port round 1 building and running) and a public App Store release, via a
TestFlight beta.

---

## 0. Decisions recorded July 24

| Question | Decision |
|---|---|
| Launch pricing | **Keep the July 8 model: 7-day free trial → $29.99/yr, hard paywall, no freemium.** Monetization ships at launch, not V2. Price stays placeholder until the pre-submission pricing pass. |
| Reflections at launch | **On-device deterministic only** — the engine the web prototype already proves (weekly / monthly / wrapped, quote-first, honest thresholds). Claude-written narrative is post-launch (R5), and with it the only backend the product would ever need. |
| Backend | **None.** CloudKit private DB is Apple-hosted; notifications are local; reflections are on-device. There is no server, no account system, no analytics service. This is a launch *feature* — the privacy label reads "Data Not Collected." |
| First milestone | **TestFlight beta**, then public launch. Store assets and review prep trail the beta instead of blocking it. |
| Name | ✅ **Endpaper** (decided July 24 after the §2 workshop; formerly working title "Vellum"). Rename pass through code and docs done the same day — bundle ID `com.wendellbarton.endpaper`, container `iCloud.com.wendellbarton.endpaper`. Remaining: registrar check + formal trademark screen before TestFlight. |

Explicitly **V2 / not now:** voice-to-text (v1.1 fast follow, already
decided), photo-of-handwriting-to-text, cloud AI reflections (R5).

---

## 1. Workstream A — Finish the product (code)

In dependency order. "Nights" = solo-build estimate, consistent with the
Stage 2 plan's units.

| # | Work | Detail | Nights |
|---|---|---|---|
| A1 | **Reflections port** | `js/reflect.js` → `Reflect.swift` (pure logic, ports mechanically; unit-test against the same seed corpus so JS and Swift agree). Consent card, weekly inverted modal, archived cards at period boundaries, monthly recap sequence, yearly wrapped + share image. The prototype is the spec. | 4–5 |
| A2 | **Settings** | The sparse screen the Stage 2 plan already defines: reminder toggle + time, "Back up your notebook" (iCloud on/off + sync status meta line), "Show the introduction again," export (A3), licenses/about. | 2 |
| A3 | **Export** | "Your writing is yours" needs a door: one button producing a plain-text/Markdown archive of the whole notebook via the share sheet. Cheap, and the single biggest trust signal in Settings. | 1 |
| A4 | **Paywall wiring** | Real product in App Store Connect, `TrialGate` pointed at it, the trial-expiry gate (hard paywall screen when neither trial nor subscription is live), restore flow, sandbox testing. The StoreKit 2 scaffold from port round 1 is most of this. | 2 |
| A5 | **CloudKit hardening** | ◐ Status surface built (quiet meta line in Settings via ubiquityIdentityToken — signed-out/absent states degrade politely). Remaining: two-device sync test on real hardware (write on one, appears on other; same-window sessions merge, not fork), production schema deploy. | 2 |
| A6 | **QA pass** | ◐ Code side built July 24: VoiceOver labels (dots speak — "July 5, written"; drop caps read whole; year matrices defer to their month card; tutorial dots announce page), Reduce Motion already degrades the sequences. Remaining (on-device): Dynamic Type XL check, dark mode sweep, keyboard/scroll edge cases, fresh-install path. | 2–3 |
| A7 | **Face ID lock** | ✅ Built July 24: Settings toggle, lock on background, LocalAuthentication with passcode fallback; stands aside if the device has no passcode. Privacy outranks commerce — the lock sits above the paywall. | 1 |
| A8 | **Calendar polish** *(noted July 25, from device QA — deliberate later pass)* | Restore the web prototype's FLIP-grade morph (year ↔ month transitions currently lack the smoothness); dot sizing that scales dynamically with how much the user has written. The week/month hybrid was removed and day taps wired in the meantime — month grid is now the single register. | 2–3 |

Not in scope: widgets, iPad/Mac layouts, localization (copy stays constants
until localization is real).

## 2. Workstream B — The name

Gates the bundle ID, the iCloud container, the App Store Connect record,
and the domain — so it lands **before TestFlight**, not before code.

1. **Criteria:** one word or two short ones; reads quiet and editorial, not
   techy; pronounceable; doesn't collide on the App Store in journaling or
   note-taking; a sane domain exists; no obvious trademark conflict in
   software (note: "Vellum" collides with the established Mac book-writing
   app at vellum.pub — assume it's out unless a search says otherwise).
2. **Process:** generate ~15 candidates in the product's register (paper,
   quiet, permanence: e.g. Quire, Flyleaf, Margin, Deckle, Foolscap,
   Octavo, Onionskin, Kept…) → App Store + domain + USPTO quick-check →
   shortlist of 3 → Wendell picks.

   **✅ Research run July 24 (18 candidates, web-verified).** Most of the
   register is taken: Foolscap (foolscap.app is nearly this exact product),
   Daybook, Commonplace, Kept, Folio, Flyleaf, Quire, Colophon,
   Marginalia — all have direct or near-direct App Store collisions in
   journaling/notes. Survivors, shortlisted:

   | | Case | Caveat |
   |---|---|---|
   | **Endpaper** | The quiet decorative leaf inside a hardcover — ornament that serves the book, exactly the design stance. No iOS app or notable software found with the name. | endpaper.com possibly parked (unverified); formal trademark search still needed |
   | **Pressed** | Strongest permanence metaphor (pressed flowers, letterpress — a mark that can't be unmade). One syllable, zero tech odor. No journaling/notes collision found — App Store "Pressed" is juice, dry cleaning, yoga. | pressed.com is Pressed Juicery (different class but owns search results); would live on pressed.app/.ink |
   | **Octavo** | Bookish, pronounceable, and octavo.com is openly for sale on BrandBucket — the ideal domain is actually buyable. | Octavo Reader + octavo.app (both reading apps) mean non-empty App Store search; lawyer should eye the overlap |

   **Round 2 (July 24, Wendell's candidates):** Tetradi (тетрадь — the
   ordinary Russian word for a school exercise book; register invisible to
   non-Russian speakers but conceptually perfect), Pica, Glossa.

   | | Verdict | Evidence |
   |---|---|---|
   | **Tetradi** | **Viable — the ownability pick.** No iOS app or notable software found on the exact string; tetradi.com looks like a for-sale landing page (likely buyable, unverified). "Tetrad" (no i) collides (CMU causal-inference tool) but the -i insulates it. Trade-off: the humble-notebook meaning is a private pleasure, not a market signal — to browsers it's an abstract coinage. | search round 2 |
   | Pica | Out — four exact-name iOS apps, the popular pica npm library, and the eating-disorder homonym owns general web search. | search round 2 |
   | Glossa | Out — multiple exact-name AI/language iOS apps, salon SaaS, and the linguistics journal; reads "language," not "paper." | search round 2 |

   **✅ Decided July 24: Endpaper.** Domain landscape checked by Wendell
   the same day: endpaper.com/.app/.ink all taken — notably endpaper.app
   is an AI book-writing service (same name, writing category; a trademark
   screen should look hard at it) and endpaper.ink is a fountain-pen ink
   brand. **Domain decided: `endpaper.space`** ($2, available, and echoes
   thedot.space — the PDP's structural design reference). App Store search
   for "Endpaper" remains empty, which is the collision that matters most
   for an iOS product. Runners-up stay on file in case the trademark
   screen forces a fallback: Tetradi (ownability pick), Octavo, Pressed.
   Remaining: register endpaper.space → formal trademark search.
3. **On decision:** bundle ID `com.wendellbarton.<name>`, iCloud container
   `iCloud.com.wendellbarton.<name>`, rename pass through code and docs.
   (Do this *before* any TestFlight build ships — migrating a CloudKit
   container after real data exists is painful.)

## 3. Workstream C — Legal & privacy

The no-backend architecture makes this unusually short:

1. **Privacy policy.** ✅ Drafted July 24 — `docs/legal/privacy-policy.md`.
   Truthfully minimal: writing stays on device and in the user's private
   iCloud; no accounts, no analytics, no tracking, no third-party SDKs;
   notifications are local; reflections computed on device; subscription
   handled by Apple. One page, in the product's voice.
2. **Terms of use.** ✅ Drafted July 24 — `docs/legal/terms.md`. Subscription
   terms (trial/renewal/cancel via Apple), the **permanence disclosure**
   (§3 — no edit/delete is a stated feature, not a defect), content
   ownership, not-therapy disclaimer, liability limits. Placeholders
   remaining: dates, final price, governing law.
3. **App Privacy label** in App Store Connect: **"Data Not Collected"** —
   worth designing the App Store listing around.
4. **Landing page.** One static page at **endpaper.space**: the pitch,
   support email (e.g. hello@endpaper.space), privacy policy, terms.
   Required (App Store wants support + privacy URLs); also where the name
   lives publicly. The web prototype's design system makes this an
   afternoon.

## 4. Workstream D — App Store plumbing

| # | Work | Notes |
|---|---|---|
| D1 | Apple Developer Program enrollment ($99/yr) | Prerequisite for everything below |
| D2 | App Store Connect record + signing | Bundle ID from §2; automatic signing |
| D3 | iCloud container + push-to-production schema | Container ID from §2 |
| D4 | Subscription product | Yearly auto-renewing, 7-day free introductory offer, subscription group; final price decided here (pricing pass) |
| D5 | App icon + launch screen | The dot is the obvious mark: one filled dot on bone. Launch screen = blank bone page |
| D5b | **Figma file** (built July 24) | [Endpaper design file](https://www.figma.com/design/ZvusVn4JRWLMMxuMpuljO2/) — Design System page (semantic color variables with Light/Dark modes, the three type-register text styles, palette/type/spacing/dot documentation) + App Walkthrough page (23 screen mocks: core loop, onboarding, paywall, cards, reflections, wrapped) + Cover. Website page reserved for the landing-page design. |
| D6 | Store assets | Screenshots (light+dark, the writing page and the dots), description in the product's voice, keywords; no video needed at launch |
| D7 | TestFlight | Internal testing first (no review), then external group (one-time beta review) for friends |
| D8 | App Review prep | Review notes explaining the trial/paywall and the no-account design; demo not needed (reviewer can write). Subscription apps get extra scrutiny: terms link, restore button, price clarity — all already in the trial moment |

## 5. Sequencing

```
now ─────────────────────────────────────────────► public launch

A1 Reflections port  ██████
B  Name workshop     ███ (decision gate ▼)
A2 Settings + A3 Export     ████
D1–D3 Accounts/ASC/iCloud      ██   (needs name)
A4 Paywall wiring + D4            ███
A5 CloudKit hardening              ██
C  Legal + landing page            ██
A6 QA + A7 Face ID                   ███
D7 ══ TESTFLIGHT BETA ══════════════════▼
   beta feedback loop, D5–D6 assets, pricing pass
D8 ══ SUBMIT ═══════════════════════════════════▼
```

Roughly: **~15–18 nights of build** to the TestFlight gate, then beta
duration is a choice (suggest 2–4 weeks with 10–20 testers), then
submission. The critical path is A1 (biggest single build) and B (gates
all of D).

## 6. Go-live checklist (definition of done)

- [ ] Name decided; bundle ID, container, domain, and all copy renamed
- [x] **Swift engine agrees with the JS engine** — ✅ July 27: parity suite
      passed 4/4 on device (19 signals, zero failures, zero tie divergences)
- [ ] Reflections: weekly/monthly/wrapped land on device, thresholds honest
      (on-device QA §6 still to finish)
- [ ] Settings complete; export produces a readable archive of real data
- [ ] Trial → paywall → subscribe → restore all pass in sandbox
- [ ] Two-device iCloud test passes; signed-out state degrades quietly
- [ ] Dynamic Type XL, VoiceOver, Reduce Motion, dark mode all pass
- [ ] Privacy policy + terms live at the domain; support email answered by a human
- [ ] App Privacy label: Data Not Collected
- [ ] TestFlight beta ran ≥2 weeks; blocking feedback resolved
- [ ] Pricing pass done (final price on the product, placeholder retired)
- [ ] Screenshots/description final; review notes written
- [ ] Submitted ✦

## 7. Open items

| # | Item | Default until decided |
|---|---|---|
| 1 | Beta testers who journal for weeks then hit the paywall at public launch — grandfather them? | Yes: 1-year promo code as a thank-you |
| 2 | Crash reporting | None (no third-party SDKs); rely on Apple's opt-in crash reports in Xcode Organizer |
| 3 | Export format | Markdown, one file per year, day-headed |
| 4 | Reminder default time | 8:00 AM (Stage 2 assumption stands) |
| 5 | Final price | $29.99/yr placeholder; decide at D4 with the pricing pass |
