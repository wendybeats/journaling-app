# Endpaper — App Store Listing Pack

**Date:** July 27, 2026
**Status:** Draft for Wendell's edit pass. Everything here pastes straight
into App Store Connect fields (character limits noted). Voice rules: the
site's register — quiet, direct, first person where it's the maker
speaking. No feature-matrix language, no exclamation points.

---

## Name & subtitle

- **Name** (30 chars max): `Endpaper — Journal`
  (fallback if contested: `Endpaper: Just a Journal`)
- **Subtitle** (30 chars max): `The journal that's a journal`
  (alternates: `Write. Reflect. Know yourself` · `One quiet page a day`)

## Promotional text (170 chars, editable without review)

> What's really going on inside your head? Write one note each day and
> find out. No AI chatbot, no artificial conclusions. This is you.

## Description (4000 chars max; ~1400 used)

> Endpaper is a journal reduced to its essence: open it, write, close it.
>
> No folders. No tags. No prompts, templates, mood scores, or streaks.
> The page is the whole product — a quiet, beautiful log of your thinking
> over time.
>
> WRITE DAILY
> Open to today's page with the cursor ready. Write as many times a day
> as you like. What you write stays written — no edits, no deletions,
> like pen and paper. The point is to commit.
>
> WATCH IT ACCUMULATE
> Each day you write, a dot fills in. Months become constellations; a
> year becomes something you can hold. The record itself is the reward.
>
> REFLECT, IF YOU WISH
> Each week, month, and year, Endpaper can read your writing back to
> you — the topics you returned to, your own recurring words, verbatim.
> Never advice, never analysis, never a chatbot. Optional, always.
>
> ONLY YOURS
> Your writing lives on your device and in your private iCloud. No
> account. No analytics. No tracking. No server of ours anywhere. We
> couldn't read your journal if we wanted to — and we don't want to.
>
> A WEEK, ON ME
> Every page and every reflection, free for seven days. After that,
> Endpaper is $39.99 a year — about the price of one good paper notebook.
>
> ---
>
> Privacy: endpaper.space/privacy.html
> Terms: endpaper.space/terms.html

## Keywords (100 chars max, comma-separated, no spaces)

`journal,diary,journaling,minimal,private,writing,daily,notebook,reflection,mindful,quiet,gratitude`
(98 chars. Don't repeat "Endpaper" — the name field already indexes.)

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
> reviewer can use every feature immediately after the onboarding
> sequence. The subscription (7-day free trial → $39.99/year) starts
> from the final onboarding screen ("A week, on me.").
>
> There is deliberately no way to edit or delete a committed entry —
> permanence is the product's core rule, disclosed during onboarding
> (screen 2) and in the Terms (§3). The full notebook can be exported
> as plain text from Settings at any time.
>
> Data: nothing is collected. Writing is stored on device and, if the
> user enables it, in their own iCloud private database. No third-party
> SDKs, no analytics. Notifications are local only and requested only
> after an explicit in-app yes.

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
