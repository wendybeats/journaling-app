// The monthly recap — the full-screen slide sequence on the inverted
// surface, ported from js/views/recap.js: circles intro → stats with the
// month grid drawing itself → "Recurring ideas" topics → "Your Word" tone →
// "Challenges" → "Reflect & start anew". Slides with nothing honest to show
// remove themselves; an insufficient month gets the quiet variant.

import SwiftUI

struct RecapView: View {
    let signal: MonthlySignal
    var writtenDays: Set<Int>   // day-of-month numbers, for the grid drawing
    var onDone: () -> Void

    var body: some View {
        SlideSequenceView(slides: slides, onDone: onDone)
    }

    private var monthTitle: String {
        "\(DayFormat.monthName(signal.month)) \(String(signal.year))"
    }

    private var slides: [SequenceSlide] {
        var s: [SequenceSlide] = []

        // 1 — circles + title
        s.append(SequenceSlide(duration: 4.5) {
            VStack(spacing: Tokens.Space.lg) {
                RecapCircles()
                Text("Reflections — Your month")
                    .font(.custom(EndpaperFont.heading, size: 22).weight(.medium))
                    .foregroundStyle(Tokens.Text.onInverted)
                Text(monthTitle)
                    .font(.custom(EndpaperFont.meta, size: 11))
                    .tracking(11 * 0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
            }
        })

        // 2 — the month grid draws itself, then the row of three
        s.append(SequenceSlide(duration: 5.0) {
            RecapStatsSlide(signal: signal, writtenDays: writtenDays)
        })

        if signal.sufficient {
            // 3 — recurring ideas
            if !signal.topics.isEmpty {
                s.append(SequenceSlide(duration: 2.2) { Intertitle(text: "Recurring ideas") })
                for topic in signal.topics {
                    // Two quotes need reading time — slower than the stat slides.
                    s.append(SequenceSlide(duration: 5.5) { RecapTopicSlide(topic: topic) })
                }
            }
            // 4 — the tone, in the user's own word
            if let tone = signal.tone {
                s.append(SequenceSlide(duration: 2.2) { Intertitle(text: "Your Word") })
                s.append(SequenceSlide(duration: 4.5) {
                    VStack(spacing: Tokens.Space.md) {
                        Text("“\(tone.word)”")
                            .font(.custom("Newsreader", size: 56).italic())
                            .foregroundStyle(Tokens.Text.onInverted)
                        Text("It appeared \(tone.count) times this month.")
                            .font(.custom(EndpaperFont.meta, size: 11))
                            .tracking(11 * 0.14)
                            .textCase(.uppercase)
                            .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                    }
                    .padding(.horizontal, Tokens.Space.screenX)
                })
            }
            // 5 — what seemed difficult (only when the writing says so)
            if !signal.difficult.isEmpty {
                s.append(SequenceSlide(duration: 2.2) { Intertitle(text: "Challenges") })
                s.append(SequenceSlide(duration: 4.5) {
                    VStack(spacing: Tokens.Space.lg) {
                        ForEach(signal.difficult, id: \.self) { q in
                            SequenceQuote(quote: q, stampAsDate: true)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenX)
                })
            }
        } else {
            // The honest quiet variant — deterministic footer plus one line.
            s.append(SequenceSlide(duration: 4.5) {
                Text("A quieter month on the page. The dots know the rest.")
                    .font(.custom("Newsreader", size: 22).italic())
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
            })
        }

        // Outro — waits for Continue
        s.append(SequenceSlide(duration: nil) {
            VStack(spacing: Tokens.Space.lg) {
                Text("\(DayFormat.monthAbbr(signal.month)) → \(DayFormat.monthAbbr(signal.month % 12 + 1))")
                    .font(.custom(EndpaperFont.meta, size: 11))
                    .tracking(11 * 0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                Text("Reflect & start anew")
                    .font(.custom(EndpaperFont.heading, size: 32).weight(.medium))
                    .foregroundStyle(Tokens.Text.onInverted)
                    .multilineTextAlignment(.center)
                Button(action: onDone) {
                    Text("Continue")
                        .font(.custom(EndpaperFont.meta, size: 13))
                        .tracking(13 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted)
                }
                .padding(.top, Tokens.Space.xl)
            }
            .padding(.horizontal, Tokens.Space.screenX)
        })

        return s
    }
}

/// The recap motif — ring + near-opaque disc, on-color.
struct RecapCircles: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Tokens.Text.onInverted.opacity(0.9), lineWidth: Tokens.lineWeight)
                .frame(width: 64, height: 64)
                .offset(x: -16)
            Circle()
                .fill(Tokens.Text.onInverted.opacity(0.85))
                .frame(width: 64, height: 64)
                .offset(x: 16)
        }
    }
}

/// Slide 2: the month grid drawing itself dot by dot, then the row of three.
private struct RecapStatsSlide: View {
    let signal: MonthlySignal
    let writtenDays: Set<Int>
    @State private var drawn = 0
    @State private var statsIn = false

    var body: some View {
        let cal = Calendar.current
        let first = cal.date(from: DateComponents(year: signal.year, month: signal.month, day: 1))!
        let dayCount = cal.range(of: .day, in: .month, for: first)!.count

        VStack(spacing: Tokens.Space.xl) {
            let columns = Array(
                repeating: GridItem(.fixed(Tokens.DotSize.today), spacing: Tokens.DotSize.gap),
                count: Tokens.DotSize.gridCols
            )
            LazyVGrid(columns: columns, spacing: Tokens.DotSize.gap) {
                ForEach(1...dayCount, id: \.self) { day in
                    Circle()
                        .fill(day <= drawn && dayWritten(day)
                              ? Tokens.Text.onInverted
                              : Tokens.Text.onInverted.opacity(0.18))
                        .frame(width: Tokens.DotSize.base, height: Tokens.DotSize.base)
                        .frame(width: Tokens.DotSize.today, height: Tokens.DotSize.today)
                }
            }
            .fixedSize()

            HStack(spacing: Tokens.Space.xl) {
                SequenceStat(value: "\(signal.days)", label: "days")
                SequenceStat(value: signal.words.formatted(), label: "words")
                SequenceStat(value: "\(signal.longestRun)", label: "day run")
            }
            .opacity(statsIn ? 1 : 0)
            .animation(Tokens.Motion.base, value: statsIn)
        }
        .task {
            if UIAccessibility.isReduceMotionEnabled {
                drawn = 31; statsIn = true
                return
            }
            for d in 1...dayCount {
                drawn = d
                try? await Task.sleep(for: .milliseconds(45))
            }
            statsIn = true
        }
    }

    private func dayWritten(_ day: Int) -> Bool {
        writtenDays.contains(day)
    }
}

private struct RecapTopicSlide: View {
    let topic: MonthlySignal.Topic

    var body: some View {
        VStack(spacing: Tokens.Space.lg) {
            Text("“\(topic.word)”")
                .font(.custom("Newsreader", size: 44).italic())
                .foregroundStyle(Tokens.Text.onInverted)
            Text("\(topic.mentions) mentions · \(topic.days) days")
                .font(.custom(EndpaperFont.meta, size: 10))
                .tracking(10 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
            VStack(spacing: Tokens.Space.md) {
                ForEach(topic.quotes, id: \.self) { q in
                    SequenceQuote(quote: q, stampAsDate: true)
                }
            }
            .padding(.top, Tokens.Space.sm)
        }
        .padding(.horizontal, Tokens.Space.screenX)
    }
}
