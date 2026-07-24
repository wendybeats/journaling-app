// The yearly wrapped — Endpaper's one moment of theater, still monochrome,
// still typographic. Ported from js/views/wrapped.js: the year matrix draws
// itself → the big numbers → five threads → the most-discussed reveal with
// its first-ever mention → "See you on the page." with save-as-image
// (dots and counts only — the writing never leaves).

import SwiftUI
import UIKit

struct WrappedView: View {
    let signal: YearlySignal
    var onDone: () -> Void

    var body: some View {
        SlideSequenceView(slides: slides, onDone: onDone)
    }

    private var slides: [SequenceSlide] {
        var s: [SequenceSlide] = []

        // 1 — the year, drawn dot by dot (the emotional opener)
        s.append(SequenceSlide(duration: 6) {
            VStack(spacing: Tokens.Space.lg) {
                YearMatrixDrawing(signal: signal)
                Text(String(signal.year))
                    .font(.custom(EndpaperFont.meta, size: 11))
                    .tracking(11 * 0.14)
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
            }
        })

        // 2 — the numbers, mono, huge
        s.append(SequenceSlide(duration: 6) {
            VStack(spacing: Tokens.Space.xl) {
                SequenceStat(value: "\(signal.days)", label: "days written")
                SequenceStat(value: signal.words.formatted(), label: "words")
                SequenceStat(value: "\(signal.longestRun)", label: "longest run")
            }
        })

        if signal.sufficient && !signal.topics.isEmpty {
            // 3 — five threads
            s.append(SequenceSlide(duration: 6) {
                VStack(spacing: Tokens.Space.md) {
                    Intertitle(text: "Five threads")
                        .padding(.bottom, Tokens.Space.md)
                    ForEach(Array(signal.topics.enumerated()), id: \.offset) { _, topic in
                        HStack(spacing: Tokens.Space.md) {
                            Text("“\(topic.word)”")
                                .font(.custom("Newsreader", size: 22).italic())
                                .foregroundStyle(Tokens.Text.onInverted)
                            Text("\(topic.days) days")
                                .font(.custom(EndpaperFont.meta, size: 10))
                                .tracking(10 * 0.14)
                                .textCase(.uppercase)
                                .foregroundStyle(Tokens.Text.onInverted.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, Tokens.Space.screenX)
            })

            // 4 — the reveal
            if let reveal = signal.reveal {
                s.append(SequenceSlide(duration: 7) {
                    VStack(spacing: Tokens.Space.lg) {
                        Text("Most discussed")
                            .font(.custom(EndpaperFont.meta, size: 11))
                            .tracking(11 * 0.14)
                            .textCase(.uppercase)
                            .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                        Text("“\(reveal.topic.word)”")
                            .font(.custom("Newsreader", size: 56).italic())
                            .foregroundStyle(Tokens.Text.onInverted)
                        VStack(spacing: Tokens.Space.sm) {
                            Text("It started on \(DayFormat.dayMetaDate(DayFormat.date(fromKey: reveal.first.day))):")
                                .font(.custom(EndpaperFont.meta, size: 10))
                                .tracking(10 * 0.14)
                                .textCase(.uppercase)
                                .foregroundStyle(Tokens.Text.onInverted.opacity(0.5))
                            SequenceQuote(quote: reveal.first, stampAsDate: true)
                        }
                        .padding(.top, Tokens.Space.md)
                    }
                    .padding(.horizontal, Tokens.Space.screenX)
                })
            }
        } else {
            s.append(SequenceSlide(duration: 4.5) {
                Text("A quieter year on the page. The dots know the rest.")
                    .font(.custom("Newsreader", size: 22).italic())
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
            })
        }

        // 5 — closing card + share
        s.append(SequenceSlide(duration: nil) {
            WrappedOutro(signal: signal, onDone: onDone)
        })

        return s
    }
}

// MARK: - The matrix

/// Twelve compact month matrices, dots cascading in.
private struct YearMatrixDrawing: View {
    let signal: YearlySignal
    @State private var drawnThrough = 0   // day-of-year high-water mark

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.md), count: 3)
        LazyVGrid(columns: columns, spacing: Tokens.Space.lg) {
            ForEach(1...12, id: \.self) { month in
                YearMatrixMonth(signal: signal, month: month, drawnThrough: drawnThrough)
            }
        }
        .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
        .task {
            if UIAccessibility.isReduceMotionEnabled {
                drawnThrough = 366
                return
            }
            // The whole year cascades in over ~4 s.
            for d in stride(from: 0, through: 366, by: 4) {
                drawnThrough = d
                try? await Task.sleep(for: .milliseconds(40))
            }
            drawnThrough = 366
        }
    }
}

private struct YearMatrixMonth: View {
    let signal: YearlySignal
    let month: Int
    let drawnThrough: Int

    var body: some View {
        let cal = Calendar.current
        let first = cal.date(from: DateComponents(year: signal.year, month: month, day: 1))!
        let dayCount = cal.range(of: .day, in: .month, for: first)!.count
        let firstOrdinal = cal.ordinality(of: .day, in: .year, for: first) ?? 0

        let columns = Array(
            repeating: GridItem(.fixed(Tokens.DotSize.year), spacing: Tokens.DotSize.gapYear),
            count: Tokens.DotSize.gridCols
        )
        LazyVGrid(columns: columns, spacing: Tokens.DotSize.gapYear) {
            ForEach(1...dayCount, id: \.self) { day in
                let key = String(format: "%04d-%02d-%02d", signal.year, month, day)
                let visible = firstOrdinal + day - 1 <= drawnThrough
                Circle()
                    .fill(visible && signal.writtenKeys.contains(key)
                          ? Tokens.Text.onInverted
                          : Tokens.Text.onInverted.opacity(0.15))
                    .frame(width: Tokens.DotSize.year, height: Tokens.DotSize.year)
            }
        }
    }
}

// MARK: - Outro + share image

private struct WrappedOutro: View {
    let signal: YearlySignal
    var onDone: () -> Void
    @State private var shareImage: Image? = nil

    var body: some View {
        VStack(spacing: Tokens.Space.lg) {
            Text("See you on the page.")
                .font(.custom(EndpaperFont.heading, size: 32).weight(.medium))
                .foregroundStyle(Tokens.Text.onInverted)
                .multilineTextAlignment(.center)

            if let shareImage {
                ShareLink(
                    item: shareImage,
                    preview: SharePreview("\(signal.year) — \(signal.days) days written", image: shareImage)
                ) {
                    Text("Save your year")
                        .font(.custom(EndpaperFont.meta, size: 13))
                        .tracking(13 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted)
                }
            }

            Button(action: onDone) {
                Text("Done")
                    .font(.custom(EndpaperFont.meta, size: 11))
                    .tracking(11 * 0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
            }
            .padding(.top, Tokens.Space.md)
        }
        .padding(.horizontal, Tokens.Space.screenX)
        .task { renderShareImage() }
    }

    /// Dots and counts only — the writing never leaves.
    @MainActor
    private func renderShareImage() {
        let renderer = ImageRenderer(content: YearShareCard(signal: signal))
        renderer.scale = 3
        if let ui = renderer.uiImage {
            shareImage = Image(uiImage: ui)
        }
    }
}

/// The shareable card: the matrix, the counts, the year. 360×450 @3x.
private struct YearShareCard: View {
    let signal: YearlySignal

    var body: some View {
        VStack(spacing: 24) {
            Text(String(signal.year))
                .font(.custom(EndpaperFont.meta, size: 12))
                .tracking(12 * 0.14)
                .foregroundStyle(Color(red: 0.91, green: 0.90, blue: 0.88))

            let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(1...12, id: \.self) { month in
                    YearMatrixMonth(signal: signal, month: month, drawnThrough: 366)
                }
            }
            .padding(.horizontal, 24)

            Text("\(signal.days) days · \(signal.words.formatted()) words")
                .font(.custom(EndpaperFont.meta, size: 10))
                .tracking(10 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(Color(red: 0.91, green: 0.90, blue: 0.88).opacity(0.6))
        }
        .frame(width: 360, height: 450)
        .background(Color(red: 0.10, green: 0.10, blue: 0.10))
    }
}
