# Endpaper — App Store Listing Pack

**Date:** July 27, 2026 · **Rewritten 2026-08-26** for the 1.0.2
submission: reflection-first per the strategy directive (reflection is
the spine, permanence the supporting trait). Everything here pastes
straight into App Store Connect fields (character limits noted). Voice
rules: the site's register — quiet, direct, first person where it's the
maker speaking. No feature-matrix language, no exclamation points.
Accuracy rule: no scanning/import language anywhere — the feature ships
hidden in production builds.

---

## Name & subtitle

- **Name** (30 chars max): `Endpaper — Journal`
  (fallback if contested: `Endpaper: Just a Journal`)
- **Subtitle** (30 chars max): `A journal that reads you back`
  (29 chars. Alternates: `Write. It reads you back` ·
  `One quiet page a day`)

## Promotional text (170 chars, editable without review)

> You write. It reads you back. Weekly and monthly reflections built
> from your own words — no AI, no analysis, no one reading but you.

## Description (4000 chars max; ~1500 used)

> Endpaper is a journal in two acts: you write one quiet page a day,
> and it reads your writing back to you.
>
> No folders. No tags. No mood scores, streaks, or chatbots. The page
> is the product — and the reflections are the reward.
>
> IT READS YOU BACK
> Each week and month, Endpaper hands your writing back as a small deck
> of cards: the word that kept surfacing, the line you wrote large, the
> question you asked yourself, when you write and how much. Your own
> words, verbatim — never advice, never analysis, never AI. Whether
> you're in therapy, in a new chapter, or just trying to understand
> yourself, you arrive already knowing what's been on your mind.
>
> WRITE DAILY
> Open to today's page with the cursor ready. Write it — or say it:
> spoken notes are transcribed on your device and land on the page as
> their own section. What you write stays written — no edits, no
> deletions, like pen and paper. The point is to commit.
>
> WATCH IT ACCUMULATE
> Each day you write, a dot fills in. Months become constellations; a
> year becomes something you can hold.
>
> ONLY YOURS
> Your writing lives on your device and in your private iCloud. No
> account. No tracking, no ads. We count taps, never words — we can see
> that a page was written, never what it says. We couldn't read your
> journal if we wanted to — and we don't want to.
>
> WRITING IS FREE, FOREVER
> Every page, every day, free — no trial, no clock. Reflections are a
> membership: your first weekly reflection is on me; after that, $39.99
> a year for every week and every month read back — about the price of
> one good paper notebook.
>
> ---
>
> Privacy: endpaper.space/privacy.html
> Terms: endpaper.space/terms.html

## Keywords (100 chars max, comma-separated, no spaces)

`journal,diary,journaling,reflection,private,writing,daily,notebook,voice,minimal,mindful,therapy`
(96 chars. Don't repeat "Endpaper" — the name field already indexes.)

## What's New — 1.0.4 (the free model; paste this one)

> Writing is free, forever.
>
> — Every page, every day, free — no trial. Reflections are now a
>   membership, and your first weekly reflection is on me.
> — Your first week: a question worth answering each day, and a
>   countdown to your first reflection — whatever day you start.
> — A glimpse: when a word keeps coming back, it lights up on the page.
>   Tap it.
> — A finished week or month announces itself. The deck opens when
>   you're ready — tap either side to move through it.
> — Share a line, or a month of dots, as a card.
> — The page types the way handwriting settles: the first word large,
>   the first line medium, the rest body. Lists, too.
> — Anonymous usage counts — taps, never words — so I can see what's
>   working. Off in Settings.

## What's New — 1.0.3 (shipped; kept for the version history)

Only what's new since the live version's notes (which already announced
voice, handwriting capture, file import, recaps, and dictation
language). Import lines from the old notes roll into version history on
release; keep import out of ALL current fields.

> Your writing, read back better.
>
> — Recaps, redesigned: your week arrives as a small deck of cards, your
> month as a slower sequence — every line drawn from your own words.
> — A new introduction, built in the same card language.
> — Choose your theme in Settings: light, dark, or match your device.
> — Spoken notes now handle pauses gracefully — long takes no longer
> repeat words.
> — Refinements and small fixes throughout.

## Screenshot shot list (6.9" + 6.5" required; capture from simulator, light AND dark variants)

| # | Screen | Caption (overlay, display register) |
|---|---|---|
| 1 | Today with a written page | "Open. Write. Close." |
| 2 | Notebook with drop caps | "A record, not a feed." |
| 3 | Calendar year (one-piece matrix, well seeded) | "Each dot, a day." |
| 4 | Monthly recap topic slide ("boat") | "Your words, read back." |
| 5 | Wrapped numbers slide | "A year you can hold." |
| 6 | Onboarding "This is Endpaper." | "No edits. No deletions. That's the point." |

Caption frames: bone background, screenshot in a device frame, caption
set in Instrument Sans Medium above — same system as the site hero.

## App Review notes (paste into the Review Notes field)

> Endpaper is a private journaling app with no account system — the
> reviewer can write immediately after the onboarding sequence, with no
> purchase. Writing is free. Reflections (a weekly and a monthly
> read-back of the user's own words, computed on device) are the
> auto-renewing membership: $39.99/year with a 7-day free introductory
> offer. The first weekly reflection is free; the purchase is offered at
> the end of that first reflection, when a later locked reflection is
> tapped, and in Settings → Membership (with Restore Purchases). A
> reflection needs several days of writing to exist, so the reviewer may
> not reach one during review — every other surface is available at once.
>
> There is deliberately no way to edit or delete a committed entry —
> permanence is the product's core rule, disclosed during onboarding
> (screen 2) and in the Terms (§3). The full notebook can be exported
> as plain text from Settings at any time.
>
> Data: writing is stored on device and, if the user enables it, in
> their own iCloud private database — it is never transmitted to us.
> The app records anonymous product-interaction events (e.g. "a page
> was written", "a reflection was opened") via PostHog (US), not linked
> to the user, not used for tracking, no identifiers, switchable off in
> Settings. Notifications are local only and requested only after an
> explicit in-app yes.

App Privacy (App Store Connect) — UPDATE BEFORE SUBMITTING 1.0.4:
Data Not Collected → **Data Not Linked to You: Product Interaction**,
purpose Analytics, "not used to track you". The privacy manifest in
the bundle (PrivacyInfo.xcprivacy) declares the same; a mismatch is a
review rejection.

## Category & rating

- Primary: **Lifestyle** · Secondary: **Productivity**
- Age rating: 4+ (questionnaire: all "none")

## v3 screenshot set (2026-08-21) — lockups, not captions

Rendered by `tools/content/render-appstore-v3.mjs` through
`appstore/compose-v3.html`, in the reflections-deck grammar: one
statement per canvas, three registers, the layout changing shape shot to
shot, the dot punctuating twice across six. The product appears as an
element in a composition — a card face, a cropped device, a fanned deck
— rather than a rectangle with a headline above it.

| # | Slug | Layout | Theme | Claim |
|---|---|---|---|---|
| 1 | reads-you-back | statement + cropped dot + angled device | light | The journal that reads you back. |
| 2 | you-write-it-reads | ghost → ink split, type only | dark | You write. / It reads you back. |
| 3 | kept-surfacing | one reflection card, tilted | light | Your week, in your own words. |
| 4 | say-it-out-loud | voice card: rose seismograph + transcript | dark | Some days you'd rather say it. |
| 5 | next-session | kicker chip + question card | light | Know what to bring to your next session. |
| 6 | your-week-handed-back | three cards fanned with depth | dark | Your week, handed back. |
| 7 | sealed-at-midnight | statement + device bleeding off | dark | Sealed at midnight. Yours for good. |

Seven shots (ASC allows up to 10 per size). Themes alternate
L-D-L-D-L-D-D and no two neighbours share a layout.

Sizes: 1320×2868, 1290×2796, 1284×2778 (iPhone-only app — no iPad set
required). Upload with the 1.0.2 submission; screenshots for a live app
only change with a version.

Notes for future edits: card faces are HTML in the compositor, not
captures, so copy changes are text edits. `--card-face`/`--card-ink`
flip with the page theme so a card always opposes its ground. Cyrillic
is NOT available in the bundled faces — Russian-localized screenshots
need a Cyrillic companion serif first (see priorities doc).
