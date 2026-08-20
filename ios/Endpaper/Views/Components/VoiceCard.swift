// The recording card — the 1.0.2 voice-capture surface, ported from the
// approved prototype. Rises from the page foot when REC starts: grabber,
// "Spoken · Aug 18", a mono timer, the vintage seismograph waveform in
// the capture rose, the live transcript, and the stop button. The
// waveform is the user's actual voice (mic RMS), flat through silence,
// spiking through speech, scrolling past a playhead at the right edge.

import SwiftUI

struct VoiceCard: View {
    @ObservedObject var voice: VoiceCapture
    var onStop: () -> Void

    // The trace: per-sample jitter and sign are fixed at push time so the
    // drawing holds still as it scrolls (same rule as the prototype).
    private struct Sample {
        let a: CGFloat   // amplitude 0…1
        let j: CGFloat   // per-sample height jitter
        let s: CGFloat   // +1 / -1, alternating around the baseline
    }
    @State private var samples: [Sample] = []
    @State private var count = 0
    private let feed = Timer.publish(every: 0.022, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Tokens.Line.rule)
                .frame(width: 42, height: 5)
                .padding(.top, 14)

            Text("Spoken · \(DayFormat.shortDay(Date()))")
                .font(.custom(EndpaperFont.heading, size: 18).weight(.semibold))
                .foregroundStyle(Tokens.Text.written)
                .padding(.top, 16)

            TimelineView(.periodic(from: .now, by: 0.03)) { _ in
                Text(elapsed)
                    .font(.custom(EndpaperFont.meta, size: 13))
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Text.meta)
            }
            .padding(.top, 5)

            // The waveform block owns the slack space, so the trace sits
            // dead-center between the title group and the stop button.
            // The wave bleeds edge-to-edge of the card; the transcript is
            // the inset one (QA 8-20: it was exactly backwards).
            VStack(spacing: 16) {
                wave
                    .frame(height: 130)
                if !voice.transcript.isEmpty {
                    Text(voice.transcript)
                        .font(.custom(EndpaperFont.body, size: 15).italic())
                        .foregroundStyle(Tokens.Text.heading)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, Tokens.Space.screenX)
                }
            }
            .frame(maxHeight: .infinity)

            Button(action: onStop) {
                ZStack {
                    Circle()
                        .fill(Tokens.Surface.page)
                        .overlay(Circle().strokeBorder(Tokens.Line.rule, lineWidth: 1))
                        .frame(width: 68, height: 68)
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Tokens.Accent.capture)
                        .frame(width: 24, height: 24)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop recording")
            .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Tokens.Surface.raised)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Tokens.Line.rule, lineWidth: 1)
                )
        )
        .padding(.horizontal, Tokens.Space.sm)
        .onReceive(feed) { _ in push(CGFloat(voice.level)) }
    }

    private var wave: some View {
        Canvas { ctx, size in
            let mid = size.height / 2
            let step: CGFloat = 3
            let maxSamples = Int(size.width / step)
            let visible = samples.suffix(maxSamples)
            var path = Path()
            var x = size.width - CGFloat(visible.count) * step
            for (i, s) in visible.enumerated() {
                // level is dB-normalized 0…1: room tone sits ≈0.1–0.15,
                // speech ≈0.4–0.8. Below the floor draws the flat baseline.
                let amp = s.a < 0.18 ? 0 : min(1, (s.a - 0.18) * 2.0)
                let y = mid - s.s * amp * s.j * (mid - 4)
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
                x += step
            }
            ctx.stroke(path, with: .color(Tokens.Accent.capture),
                       style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
            // playhead tick at the writing edge
            ctx.fill(Path(CGRect(x: size.width - 1.5, y: mid - 12, width: 1.5, height: 24)),
                     with: .color(Tokens.Accent.capture))
        }
    }

    private func push(_ level: CGFloat) {
        count += 1
        // mostly mid-height, with the occasional near-full spike
        let j: CGFloat = .random(in: 0...1) < 0.18
            ? .random(in: 0.9...1.0)
            : .random(in: 0.45...0.85)
        samples.append(Sample(a: level, j: j, s: count.isMultiple(of: 2) ? 1 : -1))
        if samples.count > 400 { samples.removeFirst(samples.count - 400) }
    }

    private var elapsed: String {
        guard let start = voice.startedAt else { return "00:00.00" }
        let t = Date().timeIntervalSince(start)
        let m = Int(t) / 60, s = Int(t) % 60, c = Int(t * 100) % 100
        return String(format: "%02d:%02d.%02d", m, s, c)
    }
}
