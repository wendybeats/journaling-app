# Endpaper — Beta Round 2 Plan

**Date:** July 30, 2026
**Source:** Wendell's TestFlight feedback, written in Endpaper itself
(dictated — decoded: "Tex size" = text size, "a poll" = a pill).
Decisions below marked **assumption** were made without a check-in and can
be flipped with one line.

---

## The feedback, itemized

1. Committing is too abrupt — a thinking pause mid-sentence splits the
   thought into two sections ("maybe a longer pause or you can edit for
   1 minute?").
2. Text should be larger — "big text that sizes as you type so some
   insights look more designed, like a quote."
3. Photo capture — start work. Big.
4. Voice-to-text notes — start work. Big.
5. Copy / share a section.
6. The bar above the keyboard is white; it should match the page color.
7. The Done affordance should be a pill, not bare/circle.
8. (Week review: consent now arrives day one as of build 2 — no action.)

> **Status July 31:** Rounds A + B built together (build 3) at Wendell's
> direction. REC pill design per his markups: dot + REC in a pill, inline
> with Done, centered; extra line of air under the last written line.
> Round C (photo) remains.

## Round A — the page feels right (build 3, ~a day) ✅

**A1. Commit timing** — *assumption: long idle, no edit window.*
The idle timer goes 5 s → **3 minutes**; commit still fires immediately
on Done, navigating away, or backgrounding. A pause to think is no longer
an event. This keeps permanence pure — no "soft" sections that harden
later, no second state to explain. (Alternative if it still feels harsh
in practice: a 60-second settling window where the newest section stays
editable — more machinery, weakens the teach; deliberately not chosen.)

**A2. Big text that sizes as you type** — *assumption: it applies to both
writing and reading.*
- Writing: the surface starts at display scale (~30pt Newsreader) while
  the draft is short and steps down smoothly to the standard 17pt as it
  grows past a few lines — the web-era "the page meets your first words
  large" feel.
- Reading: committed sections short enough to be one thought (~≤100
  chars, single paragraph) render in a larger quote register (~24pt),
  so one-line insights sit on the page like pull quotes between longer
  sections.

**A3. Keyboard accessory** — the bar matches the page (bone / char in
dark), hairline rule on top, and **Done becomes a quiet pill** (mono
uppercase, 1px ink outline, transparent fill — the app-store-button
register, inverted).

**A4. Copy / share a section** — long-press any committed section →
system context menu: **Copy** (plain text) and **Share** (system sheet,
day-headed text). Read-only outbound; permanence untouched. Also works
on day pages in the archive.

## Round B — voice notes (shipped with build 3) ✅

*Assumption: a dedicated capture flow, not just keyboard dictation.*
A quiet mic affordance on the writing surface (mono register, no icon
soup): tap to start, tap to stop; on-device transcription via the Speech
framework (`requiresOnDeviceRecognition` — nothing leaves the phone,
privacy story intact); words stream into the draft as you speak, then
follow the normal commit rules. Mic + speech permission asks are deferred
until first use. V1 scope: transcription only — no audio is stored (no
schema change, no CloudKit redeploy, export stays clean text).

## Round C — photo capture (build 5, ~2 days)

*Assumption: photo-to-text OCR first, not inline images.*
A capture affordance opens the camera / photo picker; Live Text (Vision)
extracts the words; the text lands in the draft for a look-over before
commit. Handwritten pages, whiteboards, receipts, book passages — the
journal stays a text corpus (reflections, search, and export all keep
working on everything captured). Inline photos-on-the-page is a real
product direction but a different one — model + CloudKit schema change,
rendering, export format — deferred until OCR proves out.

## Sequencing

A (page feel) → B (voice) → C (photo). A ships alone — it's the daily
feel and should reach testers fast. B before C because dictated notes
compound daily; photo capture is occasional.

## Flip-able decisions (say the word)

| # | Assumed | Alternative |
|---|---|---|
| A1 | 3-min idle, hard commit | 60 s edit-grace window |
| A2 | Quote register also for committed short sections | Writing surface only |
| B | Custom on-device capture flow | Keyboard dictation is enough |
| C | OCR-to-text first | Inline photos on the page |
