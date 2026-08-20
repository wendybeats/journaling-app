// The slide-sequence machinery — Swift twin of js/views/sequence.js.
// Timed slides on the inverted surface with the reverse countdown bar;
// tap skips, touch-and-hold (250 ms) pauses, release resumes. Slides with
// no duration (outros) wait for an explicit button.

import SwiftUI

struct SequenceSlide: Identifiable {
    let id = UUID()
    var duration: TimeInterval?     // nil = holds until a button acts
    var content: AnyView

    init<V: View>(duration: TimeInterval?, @ViewBuilder content: () -> V) {
        self.duration = duration
        self.content = AnyView(content())
    }
}

struct SlideSequenceView: View {
    let slides: [SequenceSlide]
    var onDone: () -> Void

    @State private var index = 0
    @State private var progress: Double = 1     // 1 → 0, the reverse countdown
    @State private var paused = false
    @State private var pressBegan: Date? = nil
    @State private var runner: Task<Void, Never>? = nil

    var body: some View {
        let slide = slides[min(index, slides.count - 1)]

        ZStack(alignment: .top) {
            Tokens.Surface.inverted.ignoresSafeArea()

            slide.content
                .id(slide.id)                  // re-mounts per slide (restarts its animations)
                .transition(.opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if slide.duration != nil {
                // The reverse countdown bar, shrinking from full width.
                GeometryReader { geo in
                    Rectangle()
                        .fill(Tokens.Text.onInverted.opacity(0.35))
                        .frame(width: geo.size.width * progress, height: 2)
                }
                .frame(height: 2)
                .padding(.horizontal, Tokens.Space.screenX)
                .padding(.top, Tokens.Space.sm)
            }
        }
        .animation(Tokens.Motion.base, value: index)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if pressBegan == nil {
                        pressBegan = Date()
                        // Held past 250 ms → pause until release.
                        Task {
                            try? await Task.sleep(for: .milliseconds(250))
                            if pressBegan != nil { paused = true }
                        }
                    }
                }
                .onEnded { _ in
                    let quick = pressBegan.map { Date().timeIntervalSince($0) < 0.25 } ?? false
                    pressBegan = nil
                    paused = false
                    if quick { advance() }   // tap continues on every slide, timed or held
                }
        )
        .onAppear { run() }
        .onDisappear { runner?.cancel() }
    }

    private func advance() {
        runner?.cancel()
        if index + 1 < slides.count {
            index += 1
            run()
        } else {
            onDone()
        }
    }

    private func run() {
        runner?.cancel()
        progress = 1
        guard let duration = slides[min(index, slides.count - 1)].duration else { return }
        runner = Task {
            var elapsed: TimeInterval = 0
            let tick: TimeInterval = 1.0 / 30
            while !Task.isCancelled && elapsed < duration {
                try? await Task.sleep(for: .seconds(tick))
                if !paused { elapsed += tick }
                progress = max(0, 1 - elapsed / duration)
            }
            if !Task.isCancelled { advance() }
        }
    }
}

// MARK: - Shared sequence furniture

/// Decorative intertitle — huge italic serif, faint, sized to the width.
struct Intertitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("Newsreader", size: 120).italic())
            .foregroundStyle(Tokens.Text.onInverted.opacity(0.35))
            .lineLimit(1)
            .minimumScaleFactor(0.05)
            .padding(.horizontal, 40)
    }
}

/// One big number with its mono label beneath — the stats register.
/// The wrapped's hierarchy (44pt, generous air) is the family standard.
struct SequenceStat: View {
    let value: String
    let label: String
    var size: CGFloat = 44

    var body: some View {
        VStack(spacing: Tokens.Space.xs) {
            Text(value)
                .font(.custom(EndpaperFont.heading, size: size).weight(.medium))
                .foregroundStyle(Tokens.Text.onInverted)
            Text(label)
                .font(.custom(EndpaperFont.meta, size: 10))
                .tracking(10 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
        }
    }
}

/// A big number that counts up to its value — the stats register with a
/// pulse. Ease-out over ~0.9s so the last digits land softly; the final
/// frame always shows the exact value. Reduce Motion: static.
struct CounterStat: View {
    let value: Int
    let label: String
    var size: CGFloat = 100

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            Text(shown.formatted())
                .font(.custom(EndpaperFont.meta, size: size))
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(Tokens.Text.onInverted)
            Text(label)
                .font(.custom(EndpaperFont.meta, size: 10))
                .tracking(10 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
        }
        .padding(.horizontal, Tokens.Space.screenX)
        .task {
            if reduceMotion || value <= 0 {
                shown = value
                return
            }
            let steps = 28
            for i in 1...steps {
                let t = Double(i) / Double(steps)
                let eased = 1 - pow(1 - t, 3)          // ease-out cubic
                shown = Int((Double(value) * eased).rounded())
                try? await Task.sleep(for: .milliseconds(32))
            }
            shown = value
        }
    }
}

/// A pull-quote with its day stamp, on the inverted surface.
struct SequenceQuote: View {
    let quote: RQuote
    var stampAsDate = false

    var body: some View {
        VStack(spacing: Tokens.Space.xs) {
            Text("“\(quote.text.trimmingCharacters(in: CharacterSet(charactersIn: ".?!")))”")
                .font(.custom("Newsreader", size: 19).italic())
                .foregroundStyle(Tokens.Text.onInverted.opacity(0.9))
                .multilineTextAlignment(.center)
            Text(stampAsDate
                 ? DayFormat.dayMetaDate(DayFormat.date(fromKey: quote.day))
                 : DayFormat.weekdayName(DayFormat.date(fromKey: quote.day)))
                .font(.custom(EndpaperFont.meta, size: 10))
                .tracking(10 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Text.onInverted.opacity(0.5))
        }
    }
}
