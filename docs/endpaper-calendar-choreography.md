# Calendar Choreography — Plan v2

**Date:** July 28, 2026
**Status:** Plan for sign-off. Supersedes the two matchedGeometryEffect
attempts (July 25, July 27).

## Why the current morph misfires

`matchedGeometryEffect` asks SwiftUI to *infer* a hero animation between
two different view trees. That inference breaks non-deterministically:
lazy grids build late, scroll offsets shift the source frame, and an
interrupted transaction falls back to a cut — which is why the same tap
is sometimes a smooth flight and sometimes a flash. More fundamentally,
the choreography we actually want (scatter-away, lone survivor, staggered
magnetic pulls) is not expressible in that API at all. Tuning cannot fix
an approach whose ceiling is too low.

## The principle: own the dots

Split responsibilities completely:

- **Resting views** — Year, Month, Day. Static, scrollable, zero
  animation duties. Each dot reports its frame (global coordinates) via a
  lightweight preference; that's their only extra job.
- **The Stage** — a full-screen overlay that exists *only during a
  transition*. On tap:
  1. Capture every visible dot's current position/size.
  2. Mount the stage with dots at exactly those coordinates —
     pixel-identical, so the mount is invisible.
  3. Animate each dot explicitly to its destination (or scatter it).
  4. Unmount, revealing the destination resting view — pre-scrolled so
     the handoff is again pixel-identical.

Same dots, stable identities, explicit coordinates at both ends. A flash
becomes structurally impossible rather than hopefully avoided.

## The three resting registers

1. **Year — one piece** (restores the original web layout): twelve rows,
   one per month, 31 dot columns, single-letter month gutter
   (`J F M A M J J A S O N D`), ~6px dots, the whole year reading as one
   object. Years stack; scrollable. Tapping a row opens that month.
   Dynamic-register rule unchanged: <1 month of data lands on Month.
2. **Month** — the grid centered in the viewport, 34/40 dots, faint
   per-day entry counts. Adjacent months reachable by vertical paging
   (snap per month) so the centered-formation moment survives scrolling.
3. **Day** — the existing read-only page.

## The choreography

**Year → Month.** The tapped month's ~30 dots are *travelers*: they fly
from their row positions into the centered month grid, growing 6→34px,
each departing on a deterministic per-dot delay (0–140ms). Every other
visible dot is *chaff*: it scatters along its own radial vector away from
the forming grid's center (80–160pt, deterministic pseudo-random),
shrinking slightly and fading to zero, staggered likewise. Labels and
chrome crossfade in the final third. Total leg ≈ 500ms.

**Month → Day.** The tapped day is the *survivor*. All other dots
scatter+fade; the survivor glides to screen center and grows a step;
holds a beat (~120ms); the Day page rises beneath it as it fades. The
lone-dot beat is the signature moment — one day, kept.

**Reverse legs mirror exactly**: day → month re-forms the grid from
scattered origins; month → year shrinks travelers back into their row as
the chaff flies home.

**Reduce Motion:** no stage — a 180ms crossfade between resting views.

## Implementation notes

- Stage = ZStack of ≤ ~450 `Circle`s with explicit `.position`, animated
  by one state flip with per-dot `.delay`. Stable ids, no
  insertion/removal mid-flight. If device profiling shows jank →
  fallback plan B: `Canvas` + `TimelineView` with hand-rolled easing
  (more code, unlimited control).
- Only *visible* dots animate (chaff capped to the viewport); offscreen
  dots simply aren't part of the shot.
- Scroll freezes during a leg; destination pre-scrolled via
  `scrollPosition` before unmount.
- All timings/distances live in one `Choreo` constants enum for taste
  passes.

## Build rounds (each shippable)

| Round | Contents | Judge on device |
|---|---|---|
| 1 | ✅ One-piece year resting view + dot-frame capture plumbing (no stage yet; transitions temporarily plain crossfade) | The year as one object; row taps |
| 2 | ✅ The Stage + Year ↔ Month legs (travelers + chaff, both directions) | The reorganize moment |
| 3 | ✅ Month ↔ Day legs (survivor beat) + timing/perf/Reduce Motion polish — day presented in-place above the pager so both legs own its arrival/departure | The whole journey |

## Taste decisions — ✅ decided July 28

1. Month register navigation: **vertical paging snap** — each month
   centered, preserving the formation moment.
2. Chaff behavior: **fade while scattering ~120pt** — quiet, stays in the
   room.
3. Leg duration: ~500ms baseline; tune after feel.

Round 1 build started same day.
