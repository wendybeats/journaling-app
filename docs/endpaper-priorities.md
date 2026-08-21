# Priorities — reconciled board

*2026-08-20 · Wendell's running list merged with the session tracker.
Build-focused; marketing ops live in tools/content/hooks.md.*

## P0

| Item | Status |
|---|---|
| Fix or cut upload feature | **DECIDED 2026-08-20: hidden in production** (build 12) — the Upload pill shows only in DEBUG/TestFlight (`AppEnv.demoControls`); all code ships dormant. Mitigations (pre-note + review sheet) stay built for when it returns. "More advanced AI" parked until on-device multimodal exists. |
| Ensure payment system works | Recipe documented (QA checklist §payment). Needs: his tier-1 pass (local StoreKit config) + one sandbox-tester run before submitting; friend's-device production sight-check post-release. |
| Record content | On him — founder reflections script delivered + beat-mapped; W34 pack waiting on his footage. |
| Global strategy: reflection over permanence | **NEW directive — biggest item on the board.** Reflection becomes the messaging spine; permanence becomes the supporting trait. Touches: hooks.md pillars, onboarding tutorial (P1), ASC screenshots + listing (P1), site hero, founder video (already reflections-first). Recap redesign (shipped) is the product-side proof. Needs one coherent messaging pass, not piecemeal edits. |

**Russia / unpayable storefronts (decided 2026-08-21, build 13):** Apple
takes no payments in RU, so the paywall could only ever lock that
audience out for revenue that cannot exist. Endpaper is free on
unpayable storefronts (`TrialGate.unpayableStorefronts`), with honest
copy at onboarding. Reverts automatically if Apple restores payments.
Growth note: the RU cohort can download, rate, and review — but App
Store ratings display per storefront, so RU reviews build the RU
listing, not the US one.

Also P0-adjacent, missing from the list:
- **CloudKit Production schema** — verify CD_Entry (and the new `origin`
  field's schema) is deployed to Production before 1.0.2 ships; a
  SwiftData model change that only exists in Development breaks sync for
  App Store users.
- **1.0.2 archive + submit** (build 10) — the vehicle for half of P1.
- **Xcode Cloud Default workflow deletion** (ASC click, still pending —
  the failure emails continue until it's gone).

## P1

| Item | Status |
|---|---|
| Remove "seed demo" | **Already true for App Store users** — gated by `AppEnv.demoControls` (DEBUG + TestFlight only); production builds never show it. What he sees is the TestFlight affordance. Recommendation: keep it through recap QA (it's the only fast way to exercise weekly/monthly arrivals), then drop TestFlight from the gate if it still grates. |
| Onboarding tutorial: reflections-focused | NEW. Folds into the reflection-first messaging pass. Current tutorial teaches permanence + sealed-at-midnight; rewrite around "you write, it reads you back." |
| Redesign ASC screenshots | **Compositor already built** (v2: value-first headlines, kickers, tilted devices, dots). Needs: reflection-first copy update + his arrangement call + render at 3 sizes → upload WITH the 1.0.2 submission (screenshots only change with a version). |
| Re-write listing info | Partial — docs/appstore.md + endpaper-store-listing.md exist; need accuracy pass (voice capture, scan/import now real features) + reflection-first reframe. Same submission window. |

## P2 (animation & delight batch — post-1.0.2)

- First-open-of-day welcome moment
- Face ID lock screen: dot-expansion animation (reuse the dive motif from insight v4)
- Home → archive transition upgrade
- WrittenScale: 2 tiers instead of 3 visible styles — engine change;
  touches the JS parity engine + expected.json, not just Swift
- More styles: callouts, quotes
- Themes — **flag: scope conflict** with the single bone/char identity;
  needs a design decision before any code
- Share writing/quote as stylized IG-post cards — extends the existing
  share-card system; pairs naturally with the quote-motion brand look

## Already shipped this cycle (for the record)

Voice-as-sections card (waveform, dB fix), photo/file import + review
sheet, capture markers + rose token, weekly five-beat deck, monthly
re-paced sequence, PromptBeat choreography, payment-testing recipe,
recaps yearly parked for December.
