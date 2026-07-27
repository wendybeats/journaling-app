// Dot choreography — the reusable Stage system, extracted from the
// calendar (docs/endpaper-calendar-choreography.md). Use it anywhere dots
// should reorganize themselves between two layouts: travelers fly from
// explicit start to explicit end coordinates, chaff scatters radially and
// dissolves, every dot on its own deterministic delay.
//
// The protocol that makes it flash-proof — follow all four steps:
//   1. Compute every dot's start AND end coordinates from the same layout
//      math your resting views use (never measure one side, guess the other).
//   2. Mount `DotStage` with `fly == false` — its first frame must be
//      pixel-identical to the outgoing resting view. Swap the resting views
//      *under* the stage (no withAnimation; the stage hides the cut).
//   3. Flip `fly = true` on the next runloop tick; per-dot animations carry
//      position, size, and opacity.
//   4. After `Choreo.total`, unmount the stage — its last frame must be
//      pixel-identical to the incoming resting view.
//
// Respect Reduce Motion at the call site: skip the stage, crossfade.

import SwiftUI

/// One dot's flight plan.
struct ChoreoDot: Identifiable {
    let id: String
    let from: CGPoint
    let to: CGPoint
    let fromSize: CGFloat
    let toSize: CGFloat
    let toOpacity: Double
    let filled: Bool
    let duration: Double
    let delay: Double
}

/// Choreography constants and math — one place for taste passes.
enum Choreo {
    static let travel: Double = 0.42     // traveler flight
    static let chaff: Double = 0.30      // scatter + dissolve
    static let stagger: Double = 0.14    // max per-dot delay
    static let total: Double = 0.64      // stage lifetime

    /// Deterministic per-dot delay in [0, stagger) — same seed, same beat.
    static func delay(_ seed: Int) -> Double {
        Double((seed * 131) % 89) / 89 * stagger
    }

    /// Radial scatter target: away from `center`, 90–160pt, with a
    /// deterministic angular jitter so the field doesn't ray out evenly.
    static func scatter(seed: Int, from: CGPoint, center: CGPoint) -> CGPoint {
        var dx = from.x - center.x, dy = from.y - center.y
        let len = max(1, hypot(dx, dy))
        dx /= len; dy /= len
        let jitter = (Double((seed * 53) % 41) / 41 - 0.5) * 0.9
        let rx = dx * cos(jitter) - dy * sin(jitter)
        let ry = dx * sin(jitter) + dy * cos(jitter)
        let dist = 90 + CGFloat((seed * 37) % 71)
        return CGPoint(x: from.x + rx * dist, y: from.y + ry * dist)
    }

    /// The house curve at an arbitrary duration, with a per-dot delay.
    static func curve(_ duration: Double, delay: Double) -> Animation {
        .timingCurve(0.22, 0.61, 0.36, 1, duration: duration).delay(delay)
    }
}

/// The stage itself: page-colored (hides the register swap beneath),
/// swallows touches mid-flight, renders every dot at explicit coordinates.
struct DotStage: View {
    let dots: [ChoreoDot]
    let fly: Bool

    var body: some View {
        ZStack {
            Tokens.Surface.page.ignoresSafeArea()
            ForEach(dots) { d in
                Circle()
                    .fill(d.filled ? Tokens.Dot.filled : Tokens.Dot.empty)
                    .frame(width: fly ? d.toSize : d.fromSize,
                           height: fly ? d.toSize : d.fromSize)
                    .position(fly ? d.to : d.from)
                    .opacity(fly ? d.toOpacity : 1)
                    .animation(Choreo.curve(d.duration, delay: d.delay), value: fly)
            }
        }
        .contentShape(Rectangle())
    }
}
