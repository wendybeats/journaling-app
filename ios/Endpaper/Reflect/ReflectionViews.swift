// Reflection surfaces (R1+R2) — Swift port of js/views/reflection.js:
// the consent card, the arrival moments (weekly inverted card; monthly
// full-screen sequence), and the condensed archived cards resting in the
// Notebook. All copy obeys the mirror rule — observations, the user's own
// words, no advice.

import SwiftUI
import SwiftData

// MARK: - Presentation plumbing

enum PresentedReflection: Identifiable {
    case weekly(WeeklySignal)
    case monthly(MonthlySignal, writtenDays: Set<Int>)
    case yearly(YearlySignal)

    var id: String {
        switch self {
        case .weekly(let s): return s.id
        case .monthly(let s, _): return s.id
        case .yearly(let s): return s.id
        }
    }
}

// MARK: - Labels

func weekLabel(_ signal: WeeklySignal) -> String {
    let start = DayFormat.date(fromKey: signal.startKey)
    let c = Calendar.current.dateComponents([.month, .day], from: start)
    return "Week of \(DayFormat.monthName(c.month!)) \(c.day!)"
}

func inlineLabel(_ reflection: ArchivedReflection) -> String {
    switch reflection {
    case .weekly(let s): return "Reflection · \(weekLabel(s))"
    case .monthly(let s): return "Recap · \(DayFormat.monthName(s.month)) \(String(s.year))"
    }
}

// MARK: - The weekly reflection — a two-screen sequence, like the monthly:
// stats for the week, then the words. Center-aligned on the inverted
// surface, hierarchy per the web prototype's reflection card.

struct WeeklyCardView: View {
    let signal: WeeklySignal
    var onClose: () -> Void

    var body: some View {
        SlideSequenceView(slides: slides, onDone: onClose)
    }

    private var slides: [SequenceSlide] {
        var s: [SequenceSlide] = []

        // 1 — the week, in numbers. The wrapped's hierarchy: one quiet
        // mono line, then big stacked numbers with generous air.
        s.append(SequenceSlide(duration: 4.5) {
            VStack(spacing: Tokens.Space.xl) {
                Text("Reflections — \(weekLabel(signal))")
                    .font(.custom(EndpaperFont.meta, size: 11))
                    .tracking(11 * 0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                    .padding(.bottom, Tokens.Space.md)
                SequenceStat(value: "\(signal.days)", label: "days written")
                SequenceStat(value: signal.words.formatted(), label: "words")
            }
        })

        // 2 — the words (holds until Continue)
        s.append(SequenceSlide(duration: nil) {
            VStack(spacing: Tokens.Space.lg) {
                if let topic = signal.topic, signal.quotes.count >= 2 {
                    Text("\u{201C}\(topic.word)\u{201D}")
                        .font(.custom("Newsreader", size: 44).italic())
                        .foregroundStyle(Tokens.Text.onInverted)
                    Text("kept surfacing — \(topic.mentions) times, across \(topic.days) days")
                        .font(.custom(EndpaperFont.meta, size: 10))
                        .tracking(10 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                    VStack(spacing: Tokens.Space.md) {
                        ForEach(signal.quotes, id: \.self) { q in
                            SequenceQuote(quote: q)
                        }
                    }
                    .padding(.top, Tokens.Space.sm)
                } else {
                    Text("No single thread this week — \(signal.days) days of writing, each in its own place. Sometimes a week is just days.")
                        .font(.custom("Newsreader", size: 22).italic())
                        .foregroundStyle(Tokens.Text.onInverted.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                Button(action: onClose) {
                    Text("Continue")
                        .font(.custom(EndpaperFont.meta, size: 13))
                        .tracking(13 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted)
                }
                .padding(.top, Tokens.Space.xl)
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .multilineTextAlignment(.center)
        })

        return s
    }
}

// MARK: - Condensed archived card (rests at period boundaries)

struct InlineReflectionRow: View {
    let reflection: ArchivedReflection
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            Text(inlineLabel(reflection))
                .font(.custom(EndpaperFont.meta, size: 11))
                .tracking(11 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Text.onInverted.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Tokens.Space.card)
                .padding(.vertical, Tokens.Space.md)
                .background(Tokens.Surface.inverted, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Consent card

struct ConsentCard: View {
    var onDecided: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("Reflections – Your Week").typeTitle()
            Text("Where is your mind? At the end of each week, see what your words say about you. Always private, for your eyes only")
                .typeWritten()
            HStack(spacing: Tokens.Space.lg) {
                Button {
                    ReflectionStore.shared.setConsent("yes")
                    onDecided(true)
                } label: {
                    Text("Yes, reflect").typeMeta().foregroundStyle(Tokens.Text.written)
                }
                Button {
                    ReflectionStore.shared.setConsent("no")
                    onDecided(false)
                } label: {
                    Text("No thanks").typeMeta()
                }
            }
        }
        .padding(Tokens.Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Surface.raised, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
    }
}

// MARK: - The flow on Today

/// Wires the reflection flow into Today: consent first; afterwards one
/// arrival per visit — monthly wins, weekly follows on the next open.
/// January adds the single quiet wrapped invite.
struct ReflectionFlowHost: View {
    @Environment(\.modelContext) private var context
    @State private var showConsent = false
    @State private var presented: PresentedReflection? = nil
    @State private var januaryYear: YearlySignal? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            if showConsent {
                ConsentCard { accepted in
                    withAnimation(Tokens.Motion.base) { showConsent = false }
                    if accepted {
                        // The consent moment pitched "your week" — deliver
                        // that first.
                        let corpus = ReflectionStore.corpus(from: context)
                        if let weekly = ReflectionStore.shared.pendingWeekly(corpus: corpus) {
                            presented = .weekly(weekly)
                        } else if let monthly = ReflectionStore.shared.pendingMonthly(corpus: corpus) {
                            presented = .monthly(monthly, writtenDays: writtenDayNumbers(of: monthly, corpus: corpus))
                        }
                    }
                }
            }
            if let year = januaryYear {
                Button {
                    presented = .yearly(year)
                } label: {
                    Text("Your year is ready →").typeMeta()
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear(perform: evaluate)
        .fullScreenCover(item: $presented) { item in
            reflectionCover(item)
        }
    }

    private func evaluate() {
        let corpus = ReflectionStore.corpus(from: context)
        let store = ReflectionStore.shared

        if store.consentEligible(corpus: corpus) {
            showConsent = true
            return
        }

        // One arrival per visit — monthly first.
        if let monthly = store.pendingMonthly(corpus: corpus) {
            let days = writtenDayNumbers(of: monthly, corpus: corpus)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                presented = .monthly(monthly, writtenDays: days)
            }
        } else if let weekly = store.pendingWeekly(corpus: corpus) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                presented = .weekly(weekly)
            }
        }

        // January: the year is ready (spec §3.3) — a single quiet line.
        let now = Date()
        let cal = Calendar.current
        if store.consent == "yes", cal.component(.month, from: now) == 1 {
            let lastYear = Reflect.yearlySignal(year: cal.component(.year, from: now) - 1, corpus: corpus)
            if lastYear.days > 0 { januaryYear = lastYear }
        }
    }

    @ViewBuilder
    private func reflectionCover(_ item: PresentedReflection) -> some View {
        switch item {
        case .weekly(let signal):
            WeeklyCardView(signal: signal) {
                ReflectionStore.shared.markSeen(.weekly(signal))
                presented = nil
            }
        case .monthly(let signal, let writtenDays):
            RecapView(signal: signal, writtenDays: writtenDays) {
                ReflectionStore.shared.markSeen(.monthly(signal))
                presented = nil
            }
        case .yearly(let signal):
            WrappedView(signal: signal) {
                presented = nil
            }
        }
    }
}

/// Day-of-month numbers written in a monthly signal's month.
func writtenDayNumbers(of signal: MonthlySignal, corpus: Corpus) -> Set<Int> {
    let prefix = String(format: "%04d-%02d-", signal.year, signal.month)
    return Set(corpus.byDay.keys.compactMap { key in
        key.hasPrefix(prefix) && corpus.has(key) ? Int(key.suffix(2)) : nil
    })
}
