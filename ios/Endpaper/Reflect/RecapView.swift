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

        // 1 — opener: the brand dot, huge and cropped — its one appearance.
        // Left-set type breaks the centered rhythm before it starts.
        s.append(SequenceSlide(duration: 4) {
            ZStack(alignment: .topLeading) {
                GeometryReader { geo in
                    Circle()
                        .fill(Tokens.Text.onInverted)
                        .frame(width: 300, height: 300)
                        .position(x: geo.size.width + 20, y: geo.size.height - 60)
                }
                VStack(alignment: .leading, spacing: Tokens.Space.md) {
                    Text("Reflections")
                        .font(.custom(EndpaperFont.meta, size: 11))
                        .tracking(11 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted.opacity(0.62))
                    Text("Your\nmonth.")
                        .font(.custom(EndpaperFont.heading, size: 44).weight(.semibold))
                        .foregroundStyle(Tokens.Text.onInverted)
                    Text(monthTitle)
                        .font(.custom(EndpaperFont.meta, size: 10))
                        .tracking(10 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                        .padding(.top, Tokens.Space.xs)
                }
                .padding(.horizontal, Tokens.Space.screenX)
                .padding(.top, 120)
            }
        })

        // 2 — the month grid draws itself (the wrapped's matrix moment)
        s.append(SequenceSlide(duration: 4.5) {
            RecapGridSlide(signal: signal, writtenDays: writtenDays)
        })

        // 3 — the numbers as three fast beats, one per screen
        for (value, label) in [("\(signal.days)", "days written"),
                               (signal.words.formatted(), "words"),
                               ("\(signal.longestRun)", "longest run")] {
            s.append(SequenceSlide(duration: 2.2) {
                VStack(spacing: Tokens.Space.md) {
                    Text(value)
                        .font(.custom(EndpaperFont.meta, size: 100))
                        .monospacedDigit()
                        .minimumScaleFactor(0.4)
                        .foregroundStyle(Tokens.Text.onInverted)
                    Text(label)
                        .font(.custom(EndpaperFont.meta, size: 10))
                        .tracking(10 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                }
                .padding(.horizontal, Tokens.Space.screenX)
            })
        }

        if signal.sufficient {
            // 4 — opened / closed: the split. No commentary — the distance speaks.
            if let opened = signal.opened, let closed = signal.closed {
                s.append(SequenceSlide(duration: 8) {
                    VStack(spacing: Tokens.Space.lg) {
                        VStack(spacing: Tokens.Space.sm) {
                            beatMeta("The month opened")
                            SequenceQuote(quote: opened, stampAsDate: true)
                        }
                        Rectangle()
                            .fill(Tokens.Text.onInverted.opacity(0.18))
                            .frame(height: 1)
                            .padding(.horizontal, Tokens.Space.xl)
                        VStack(spacing: Tokens.Space.sm) {
                            beatMeta("The month closed")
                            SequenceQuote(quote: closed, stampAsDate: true)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenX)
                })
            }

            // 5 — the turn: ghost is before, ink is now. Weight renders time.
            if let turn = signal.turn {
                s.append(SequenceSlide(duration: 6) {
                    PromptBeat(prompt: "Your word, turning") {
                        VStack(spacing: Tokens.Space.md) {
                            Text("“\(turn.from)”")
                                .font(.custom("Newsreader", size: 48).italic())
                                .foregroundStyle(Tokens.Text.onInverted.opacity(0.32))
                            Text("“\(turn.to)”")
                                .font(.custom("Newsreader", size: 48).italic())
                                .foregroundStyle(Tokens.Text.onInverted)
                            beatMeta("after the 15th")
                                .padding(.top, Tokens.Space.xs)
                        }
                        .padding(.horizontal, Tokens.Space.screenX)
                    }
                })
            }

            // 6 — recurring ideas
            if !signal.topics.isEmpty {
                s.append(SequenceSlide(duration: 2.2) { Intertitle(text: "Recurring ideas") })
                for topic in signal.topics {
                    // Two quotes need reading time — slower than the stat slides.
                    s.append(SequenceSlide(duration: 5.5) { RecapTopicSlide(topic: topic) })
                }
            }
            // 7 — the tone, in the user's own word (the turn supersedes it —
            // a changed word says more than a counted one)
            if let tone = signal.tone, signal.turn == nil {
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

            // 8 — people: a name in roman — people aren't quotes.
            if let person = signal.people?.first {
                s.append(SequenceSlide(duration: 5.5) {
                    PromptBeat(prompt: "Kept appearing") {
                        VStack(spacing: Tokens.Space.md) {
                            Text(person.name)
                                .font(.custom("Newsreader", size: 58).weight(.medium))
                                .foregroundStyle(Tokens.Text.onInverted)
                                .minimumScaleFactor(0.5)
                            beatMeta("\(person.days) days this month")
                        }
                        .padding(.horizontal, Tokens.Space.screenX)
                    }
                })
            }

            // 9 — rhythm: the product's only chart, in type-weight strokes.
            if let rhythm = signal.rhythm {
                s.append(SequenceSlide(duration: 6.5) {
                    PromptBeat(prompt: "Your rhythm") {
                        RecapRhythm(rhythm: rhythm)
                    }
                })
            }

            // 10 — spoken: the capture rose's one appearance in the recap.
            if let spoken = signal.spokenCount {
                s.append(SequenceSlide(duration: 5.5) {
                    PromptBeat(prompt: "Said out loud") {
                        VStack(spacing: Tokens.Space.md) {
                            RecapWaveGlyph()
                            Text("\(spoken)")
                                .font(.custom(EndpaperFont.meta, size: 72))
                                .monospacedDigit()
                                .foregroundStyle(Tokens.Text.onInverted)
                            beatMeta(spoken == 1 ? "section spoken this month" : "sections spoken\nthis month")
                        }
                    }
                })
            }

            // 11 — what seemed difficult (only when the writing says so)
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

/// Slide 2: the month grid drawing itself dot by dot, month label beneath.
private struct RecapGridSlide: View {
    let signal: MonthlySignal
    let writtenDays: Set<Int>
    @State private var drawn = 0

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

            Text("\(DayFormat.monthName(signal.month)) \(String(signal.year))")
                .font(.custom(EndpaperFont.meta, size: 11))
                .tracking(11 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
        }
        .task {
            if UIAccessibility.isReduceMotionEnabled {
                drawn = 31
                return
            }
            for d in 1...dayCount {
                drawn = d
                try? await Task.sleep(for: .milliseconds(45))
            }
        }
    }

    private func dayWritten(_ day: Int) -> Bool {
        writtenDays.contains(day)
    }
}

/// The weekday histogram — mono bars, Sunday-first, peak named beneath.
struct RecapRhythm: View {
    let rhythm: MonthlySignal.Rhythm

    var body: some View {
        let maxCount = max(rhythm.weekdayCounts.max() ?? 1, 1)
        let labels = ["S", "M", "T", "W", "T", "F", "S"]
        VStack(spacing: Tokens.Space.lg) {
            HStack(alignment: .bottom, spacing: Tokens.Space.sm) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: Tokens.Space.sm) {
                        Rectangle()
                            .fill(Tokens.Text.onInverted.opacity(i == rhythm.peakWeekday ? 1 : 0.55))
                            .frame(width: 14,
                                   height: max(4, 120 * CGFloat(rhythm.weekdayCounts[i]) / CGFloat(maxCount)))
                        Text(labels[i])
                            .font(.custom(EndpaperFont.meta, size: 9))
                            .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                    }
                }
            }
            beatMeta(rhythmPhrase)
        }
    }

    private var rhythmPhrase: String {
        let day = ["Sundays", "Mondays", "Tuesdays", "Wednesdays",
                   "Thursdays", "Fridays", "Saturdays"][rhythm.peakWeekday]
        switch rhythm.bucket {
        case "morning": return "\(day), usually before noon"
        case "afternoon": return "\(day), usually midday"
        case "evening": return "\(day), usually after 5 pm"
        case "late": return "\(day), usually after midnight"
        default: return day
        }
    }
}

/// A small fixed seismograph in the capture rose — the voice card's
/// waveform, remembered.
struct RecapWaveGlyph: View {
    private let heights: [CGFloat] = [4, 6, 10, 22, 34, 18, 8, 26, 38, 30, 12, 6, 16, 28, 20, 10, 5]

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, h in
                Capsule()
                    .fill(Tokens.Accent.capture)
                    .frame(width: 2, height: h)
            }
        }
        .frame(height: 40)
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
