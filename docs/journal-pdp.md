# Product Definition Plan — Endpaper

**Version:** 0.4 — Named; Stage 0 tokens drafted
**Date:** July 5, 2026
**Owner:** Wendell Barton
**Status:** Living document

---

## 1. Thesis

A journaling app reduced to its absolute essence: open it, write or speak, close it. No folders, no tags, no prompts, no gamified noise. The product is a quiet, beautiful log of your thinking over time.

The bet: journaling apps fail not because they lack features, but because they have too many. Day One, Journey, and Apple Journal all accumulate prompts, media types, templates, and social-adjacent features. The opportunity is radical restraint executed with editorial-grade craft — a product where the writing surface itself is the entire experience.

Because the feature set is deliberately tiny, **the bar shifts entirely to execution quality**: typography, motion, sound, latency, and the emotional feel of the daily ritual. This is a craft product. Mediocre polish means the product has no reason to exist.

## 2. Product Principles

1. **One thing well.** Capture a thought, log it by day. Everything else is a candidate for deletion.
2. **The blank page is the home screen.** Opening the app should land you ready to write within one second. Zero navigation to reach the core action.
3. **Editorial, not app-like.** The visual language borrows from print and long-form publishing, not from iOS component defaults.
4. **Private by design.** Local-first, iCloud-synced, no accounts, no server. Privacy is a feature statement, not a compliance footnote.
5. **The archive earns its beauty over time.** The more you write, the more valuable and visually satisfying the log becomes. Retention comes from accumulation, not notifications.
6. **AI serves reflection, never generation.** (V2) The AI reads your writing back to you; it never writes for you.

## 3. Target User & Positioning

- **Primary:** People who want a journaling habit but bounce off feature-heavy apps. Values design, minimalism, privacy. Overlaps heavily with the audience for apps like (Not Boring), Bear, iA Writer, and Stoic.
- **Positioning:** *The journal that is just a journal.* Anti-feature marketing — the App Store listing should read like a manifesto for less.
- **This product is simultaneously:** a personal daily tool, a shippable monetized product, and a portfolio-grade craft showcase. These three goals are aligned as long as restraint holds: the personal-tool lens keeps it honest, the craft lens keeps it differentiated, and the product lens keeps decisions accountable to strangers, not just the founder.

## 4. Core Experience (V1)

### 4.1 The loop

1. Open app → today's page, cursor ready (or one tap from it).
2. Write, or hold/tap to speak. Voice is transcribed on-device into text — **voice is an input method, not a content type.** The log is text, always.
3. Entry saves automatically. No save button, no confirmation.
4. Over time, a chronological archive accumulates, organized by day.

### 4.2 Entry model

- **The day is the organizing unit; writing is unlimited.** You can write as many times as you want, whenever you want. Entries within a day are grouped under that day's page (timestamped, visually subtle).
- **Habit layer:** the day-based structure supports a light habit signal — e.g., a streak or a "days written" visualization. This must stay quiet and editorial (think: a run of filled dots or a dense calendar spread, not Duolingo). Exact treatment is a design decision, but the principle is: *the record itself is the reward.*

### 4.3 Voice capture

- Recording UI is a single gesture from the writing surface.
- Transcription happens **on-device** (Apple's Speech framework / SpeechAnalyzer, or WhisperKit if quality demands it — spike required, see §9).
- Transcribed text drops into the day's page as a normal entry, editable like typed text.
- Raw audio is discarded after transcription (v1 default). Keeping audio adds storage, sync weight, and UI complexity for marginal value against the "log of your writing" thesis.

### 4.4 The archive

- Reverse-chronological scroll of days. Typography-led: date as an editorial heading, entries as body text.
- A zoomed-out view (month/year) that makes accumulation visible and satisfying.
- Search: simple full-text, v1 if cheap, v1.1 if not.

### 4.5 Explicit non-goals (V1)

- No tags, folders, notebooks, or categories
- No photos, videos, or attachments
- No prompts, templates, or "daily questions"
- No mood tracking, weather, location stamps
- No sharing, export-to-social, collaboration
- No accounts, no login
- No push notification spam (at most one optional, user-scheduled daily reminder)

## 5. Design Direction

**The synthesis:** thedot.space's structure and abstraction language, dressed in the wendellbarton.com editorial type system. Bureaucratic minimalism meets literary warmth — the dot grid gives the product its identity and habit mechanic; the serif writing surface gives it its soul.

### 5.1 References

- **Structure & abstraction — thedot.space ("Department of Time"):** the dot-matrix life visualization, extreme monochrome restraint, hairline rules under headings, generous negative space, understated system-style UI chrome.
- **Type & tone — wendellbarton.com editorial (e.g., /writing/convergence):** high-contrast display serif for titles, readable serif for body/writing, bone/lighter-bone sectioning for surfaces (cards, callouts), muted uppercase monospace meta rows, drop caps in reading contexts, subtle geometric line/shape abstraction.

### 5.2 The dot grid is the habit system

Each dot = a day. Filled dot = a day you wrote; today is emphasized (larger/marked). This resolves the "quiet, editorial habit signal" requirement (§4.2) directly — **the accumulating grid replaces streaks, badges, and counters entirely.** Views: a month grid on/near the today screen, and a zoomed-out year (or multi-year) matrix in the archive that becomes genuinely beautiful with density. The dot grid is also the product's marketing identity — App Store screenshots, icon territory, the whole visual signature.

### 5.3 System spec (refined against the today-screen concept)

- **Palette:** bone `#E8E6E1` base, lighter bone `#EFEDE8` for raised sections/cards, ink `#1A1A1A` for body/writing and filled dots, muted graphite `#4A4843` for grotesk headers, muted gray `#A9A6A0` for metadata and unfilled dots, hairline gray `#C9C6BF` for rules and dividers. No accent color. Dark mode inverts to near-black charcoal with bone type (per the "Measure moments" treatment).
- **Type system (three registers — contrast encodes hierarchy):**
  1. *Grotesk, muted (`#4A4843`)* — day headings, screen titles, structural chrome. Candidates: Neue Haas Grotesk, Söhne, ABC Diatype (final choice TBD in Figma). Softer than ink so structure recedes.
  2. *Body serif, full ink (`#1A1A1A`)* — the writing surface; user words are always set in the reading serif at `line-height: 1.8`. **The user's writing is the only element at full contrast on the page.** Writing in the app should feel like writing in a well-set book.
  3. *Monospace, uppercase, tracked-out (`0.14em`), faint (`#A9A6A0`)* — all metadata: `JULY 5, 2026 · 3 ENTRIES · 4 MIN`, timestamps, grid labels.
- **The hierarchy principle:** softest for chrome (grotesk), darkest for what you wrote (serif), faintest for metadata (mono). This is the spine of the whole system.
- **Vertical rhythm:** generous — roughly double the default spacing between entries (~34px), day rule with ~22px above / ~34px below, screen top padding ~44px. Whitespace is a primary material, not leftover space.
- **Abstraction language:** dots and hairline lines only. Thin rules under headings, dot matrices for time, occasional faint geometric line work. No icons where a word or a dot will do.
- **Reading view:** the archive borrows editorial article conventions — drop caps optional per day, callout blocks in inverted ink for any future AI reflections (the dark quote-card treatment from the editorial site maps perfectly to v2 reflection cards).
- **Motion & feel:** sparse but precise — today↔archive transition, the voice-recording state (a live dot/waveform in the abstraction language), and the entry-save moment are the three places motion earns its keep.

### 5.4 Differentiation note

thedot.space contributes structure, not features — its time-blocking/insights machinery is explicitly out of scope. This product borrows the *visual philosophy* (dots as days, monochrome, space) and rejects the dashboard density. Where Department of Time quantifies life, this product simply records it.

### 5.5 Design implementation plan

The path from the approved today-screen concept to a buildable design system. Sequenced so each stage unblocks the next.

**Stage 0 — Foundations (design tokens)**
Lock the primitives before drawing any more screens. Deliverable: a token sheet (Figma variables) covering the full palette, the three type registers with their weights and sizes, spacing scale, corner radii, and the two dot states (filled/unfilled) plus the "today" emphasis. Resolve the grotesk choice here by setting Neue Haas Grotesk, Söhne, and ABC Diatype against the serif body and picking the pairing that feels most editorial. Both light and dark mode defined at token level from the start.

**Stage 1 — Core screens (the four that define the product)**
1. *Today* — the approved concept, productionized: empty state (no entries yet), single-entry, multi-entry states.
2. *Write / capture* — the focused writing surface (serif, cursor, minimal chrome) and the voice-capture state (live dot/waveform, transcribing → text).
3. *Archive (month)* — reverse-chronological scroll of day pages; the reading experience of past entries.
4. *Archive (year/matrix)* — the zoomed-out dot grid that becomes beautiful with density; the retention payoff.

**Stage 2 — States, edges, and system moments**
Empty states for a brand-new user, the one optional daily reminder, Face ID lock screen, settings (deliberately sparse), sync/offline indicators, and the entry-save micro-moment. This is where restraint is tested — resist adding surfaces.

**Stage 3 — Motion spec**
Define the three motion moments (today↔archive transition, voice-record state, entry-save) with timing and easing. Keep the vocabulary tiny and consistent; motion should feel like the dots settling, not like an app animating.

**Stage 4 — Prototype + personal dogfood**
Clickable Figma prototype of the core loop, then the real bar: the founder writes in a TestFlight build every morning. Design decisions get validated against daily use, not review sessions.

**Stage 5 — Handoff + marketing surface**
Developer handoff spec (tokens → SwiftUI, per LifeOS conventions) and the App Store visual identity — the dot grid is the hero of every screenshot, and the icon lives in the dot language.

**Governing constraints across all stages:**
- The user's writing is the only full-contrast element; if a new element competes with it, the element is wrong.
- Every screen must justify its existence against §4.5 (non-goals). The default answer to "should we add a surface" is no.
- Whitespace is a material with a budget — spend it generously and deliberately.
- Design in both modes simultaneously; dark mode is not a post-process.

## 6. Technical Architecture (V1)

- **Platform:** Native iOS, SwiftUI
- **Minimum target:** iOS 17+ (aligns with existing conventions; Observation framework, modern SwiftUI APIs)
- **Pattern:** MVVM with Observation (consistent with LifeOS codebase conventions)
- **Persistence:** SwiftData with CloudKit sync — local-first, private database, no custom backend
- **Transcription:** on-device (Speech framework baseline; WhisperKit as quality fallback — decide via spike)
- **Security:** optional Face ID lock on launch; data never leaves the Apple private ecosystem
- **Monetization plumbing:** RevenueCat (consistent with LifeOS), even if pricing is decided later — wire it early, it's painful to retrofit

## 7. V2 Preview — The Reflection Layer

Not in scope for v1, but v1 architecture must not foreclose it.

- **Concept:** AI reads your accumulated writing and surfaces patterns: "Last month you wrote a lot about X." Monthly/weekly reflections, theme tracking over time, gentle mirrors — never advice, never generated journal content.
- **The privacy tension is the central design problem.** Local-first + no-server is a headline feature; server-side AI contradicts it. Options, in order of preference:
  1. On-device models (Apple Foundation Models / on-device inference) — private, but capability-limited
  2. Explicit opt-in cloud analysis with clear consent moments (e.g., Claude API), framed as a premium feature
  3. Hybrid: on-device for lightweight signals, opt-in cloud for deep reflections
- V1 obligation: clean, well-structured entry data (plain text, day-keyed, timestamped) so the corpus is analysis-ready.

## 8. Business & Constraints

- **Monetization:** ✅ **Decided (July 8, 2026): paid subscription with a 7-day free trial, hard paywall, no freemium.** The trial moment ("A week on me." — personal, first-person comms) sits at the end of onboarding; nothing works without starting the trial. Price points are placeholders ($29.99/yr in the prototype) until the pre-submission pricing pass. The subscription carries the reflections' ongoing AI cost.
- **⚠️ Non-compete check (do this early):** the Mode contractor non-compete has been treated as covering consumer apps in the fractional-positioning context. Before investing serious hours, confirm whether it restricts *building and shipping your own consumer app* or only *client work* in the category. This is a 30-minute contract read that de-risks the whole project.
- **Solo build:** scope must fit nights/weekends alongside Mode, Doss, and the portfolio build. V1 as specced is deliberately shippable by one person; scope creep is the primary schedule risk.
- **App Store:** journaling category is crowded; differentiation is design + privacy + restraint, which must come through in screenshots and listing copy.

## 9. Open Questions & Next Steps

| # | Item | Owner | Notes |
|---|------|-------|-------|
| 1 | ~~Product name~~ | ✅ **Endpaper** (decided July 24, after two research rounds — see launch plan §2; formerly working title "Vellum") | Registrar check on endpaper.com/.app + formal trademark screen before TestFlight |
| 2 | ~~Upload design references~~ | ✅ Done | thedot.space + editorial site — synthesized in §5 |
| 3 | Non-compete contract read | Wendell | Deferred (July 8) — do before serious iOS investment |
| 4 | ~~Transcription spike~~ | Fast follow | Voice capture moved out of launch scope (July 8); spike happens with the v1.1 fast follow |
| 5 | ~~Habit visualization concept~~ | ✅ Resolved | Dot grid — each dot a day, filled = written (§5.2) |
| 6 | ~~Monetization model~~ | ✅ Decided | 7-day trial → paid subscription, no freemium (July 8); price points at submission |
| 7 | Search in v1 vs v1.1 | Build | Cost-driven decision |

## 10. Definition of Done (V1)

V1 ships when:
- Cold open → writable in under 1 second on target hardware
- Text capture feels effortless (voice capture is a v1.1 fast follow; the prototype's design for it stands)
- iCloud sync is invisible and reliable across two devices
- The archive is genuinely pleasurable to scroll after 30 days of real personal use
- **The founder uses it every day and would keep using it if no one else ever downloaded it**

That last criterion is the real one. Personal daily use is both the QA process and the proof of thesis.
