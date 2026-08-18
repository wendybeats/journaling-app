# Voice as sections — 1.0.2 redesign plan

> **STATUS 2026-08-18: BUILT.** Shipped on the branch with one spec
> change: `Entry.spoken: Bool` became `Entry.origin: String` ("" typed /
> "spoken" / "scanned" / "imported") because photo-and-file import
> landed in the same release and shares the discrete-section commit
> path. The recording card follows the approved interactive prototype
> (rose seismograph waveform on live mic RMS, centered layout, mono
> timer, stop button). Same CloudKit-safe migration story — a String
> with a default instead of a Bool.

*2026-08-18 · from Wendell's QA: "anything that is voice recorded onto the
page remains in place… we could redesign the feature to be voice capture
and place it as a section (and subtly note it was voice). Honestly maybe
the better way."*

It is the better way. This doc is the spec.

## Why the current design keeps breaking

Dictation and the keyboard share one mutable string — the `@AppStorage`
draft — and voice writes to it with **replace** semantics
(`voice.onText = { draft = $0 }`). Every voice bug we've hit is the same
bug wearing different clothes:

1. **Pause erasure** — a ~2s silence makes on-device recognition open a
   fresh utterance; the transcription *resets* instead of extending, and
   the replacement stomps the earlier words.
2. **Return overwrite** — the keyboard edits the draft mid-take; the next
   partial result replaces the string and the typed/earlier text is gone.
3. (Earlier, fixed) type-then-record staleness, permission-flow races,
   commit-vs-final-callback races.

Two interim patches shipped 2026-08-18 (segment folding on utterance
reset; keyboard focus drops when REC starts). They make the current build
honest, but they're defenses around a shared-ownership design. The
redesign removes the shared ownership.

## The new model

**One writer per surface.** The keyboard owns the draft. Voice owns its
own transcript, in its own container, committed as its own section.

### Flow

1. Tap **REC** → keyboard stands down (already true). A **pending voice
   container** appears below the draft area: live transcript rendering in
   entry type as the words land. The draft is never touched — whatever
   was typed sits exactly where it was, above.
2. Tap **stop** → the take is over. The container holds through the
   recognizer's grace window (~1.5s, existing logic) so the final
   consolidated transcription can land, then the take **commits
   immediately** as a discrete `Entry` on the day — no trip through the
   draft, nothing left to overwrite.
3. The committed section renders like any other, with one quiet
   difference: the meta line carries a mono **"· spoken"** marker.
   Subtle — same register as the timestamp, not a badge.
4. Empty take (no recognized words) → container disappears, nothing
   commits.
5. Same-day revision applies to spoken sections exactly as typed ones
   (EntryStore.isEditable is day-based, not source-based). Editing a
   spoken section does *not* clear the marker — it recorded how the words
   arrived, not their final state.

### Model change

```swift
@Model final class Entry {
    // …existing…
    var spoken: Bool = false   // CloudKit-safe: default present
}
```

Additive with a default → lightweight SwiftData migration, and CloudKit
accepts it (every property already carries a default for exactly this
reason). Old clients ignore the field; old records read as `spoken =
false`. Deploy the updated schema to the CloudKit Production container
with the release.

### What each file does

- **VoiceCapture.swift** — *simplifies.* No external `base` provider at
  all: the capture owns its whole transcript. The utterance-reset folding
  stays (it's real recognizer behavior) but becomes purely internal —
  `transcript` = folded segments + live utterance, published as-is.
  `onText` delivers the transcript, not a replacement draft.
- **TodayView.swift** — REC pill starts a take → renders
  `voice.transcript` in the pending container; on stop-and-grace-close,
  calls a new `EntryStore.commit(_:spoken:in:)` and clears the take.
  The `onChange(of: draft)` voice guards, the draft-restore hazards, and
  the commit-path `voice.cancel()` draft interplay all disappear — commit
  of the *typed* draft no longer needs to know voice exists (if a take is
  live when the user navigates away, the take commits too, as its own
  section).
- **EntrySection** — renders the marker when `entry.spoken`.
- **EntryStore** — `commit` gains a `spoken:` flag (default false).

### Scope and release

Surface is four files plus the model — a contained 1.0.2 change, **build
9** (number must increase on every upload). The two interim fixes ride
whatever 1.0.1 becomes; this redesign should not be rushed into a build
that's already in review.

### QA for the new flow (add to checklist when built)

- [ ] Type a line → REC → speak → pause 3s → speak → stop: typed line
      untouched, spoken section contains *all* words, marker shows
- [ ] REC → tap into the draft and type while recording: both survive,
      in their own places
- [ ] REC → stop with zero words: no empty section
- [ ] REC → navigate away mid-take: take commits as a section
- [ ] Spoken section: same-day edit works, marker persists; next day,
      locked like everything else
- [ ] Device B (iCloud): spoken flag syncs; pre-update client shows the
      section as plain text without crashing
