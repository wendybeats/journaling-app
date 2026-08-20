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

// MARK: - The weekly reflection — a five-beat swipeable deck (1.0.2).
// One observation per page, user-paced, pager dots below. Every beat
// opens with the prompt choreography (PromptBeat); a beat without honest
// evidence removes itself from the page count. The old two-screen
// sequence is retired; the triggers and arrival flow are unchanged.

struct WeeklyCardView: View {
    let signal: WeeklySignal
    var onClose: () -> Void

    @State private var page = 0

    private enum Beat: Hashable {
        case shape, thread, bigLine, question, sitting, close
    }

    private var beats: [Beat] {
        var b: [Beat] = []
        if signal.shape != nil { b.append(.shape) }
        if signal.topic != nil, !signal.quotes.isEmpty { b.append(.thread) }
        if signal.bigLine != nil { b.append(.bigLine) }
        if signal.question != nil { b.append(.question) }
        if signal.sitting != nil { b.append(.sitting) }
        b.append(.close)
        return b
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Tokens.Surface.inverted.ignoresSafeArea()
            TabView(selection: $page) {
                ForEach(Array(beats.enumerated()), id: \.offset) { i, beat in
                    beatView(beat).tag(i)
                }
            }
            // System page dots color by scheme, not by our inverted surface —
            // they'd vanish in light mode. The deck draws its own.
            .tabViewStyle(.page(indexDisplayMode: .never))
            if beats.count > 1 {
                HStack(spacing: Tokens.Space.xs) {
                    ForEach(0..<beats.count, id: \.self) { i in
                        Circle()
                            .fill(Tokens.Text.onInverted.opacity(i == page ? 1 : 0.3))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.bottom, Tokens.Space.xl)
                .animation(Tokens.Motion.fast, value: page)
            }
        }
    }

    @ViewBuilder
    private func beatView(_ beat: Beat) -> some View {
        switch beat {
        case .shape:
            if let shape = signal.shape {
                PromptBeat(prompt: "Reflections — \(weekLabel(signal))") {
                    VStack(spacing: Tokens.Space.lg) {
                        weekDots
                        Text(shapeStatement(shape))
                            .font(.custom(EndpaperFont.heading, size: 34).weight(.semibold))
                            .foregroundStyle(Tokens.Text.onInverted)
                            .multilineTextAlignment(.center)
                        beatMeta("\(shape.days) of \(shape.total) days · \(shapePhrase(shape.bucket))")
                    }
                }
            }
        case .thread:
            if let topic = signal.topic {
                PromptBeat(prompt: "Kept surfacing") {
                    VStack(spacing: Tokens.Space.lg) {
                        Text("\u{201C}\(topic.word)\u{201D}")
                            .font(.custom("Newsreader", size: 54).italic())
                            .foregroundStyle(Tokens.Text.onInverted)
                            .minimumScaleFactor(0.5)
                        beatMeta("\(topic.mentions) times · across \(topic.days) days")
                        if let q = signal.quotes.first {
                            SequenceQuote(quote: q)
                                .padding(.top, Tokens.Space.sm)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenX)
                }
            }
        case .bigLine:
            if let line = signal.bigLine {
                PromptBeat(prompt: "You wrote this large") {
                    VStack(spacing: Tokens.Space.lg) {
                        Text(line.text)
                            .font(.custom("Newsreader", size: 46).weight(.medium))
                            .foregroundStyle(Tokens.Text.onInverted)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.4)
                        beatMeta(DayFormat.weekdayName(DayFormat.date(fromKey: line.day)))
                    }
                    .padding(.horizontal, Tokens.Space.screenX)
                }
            }
        case .question:
            if let q = signal.question {
                PromptBeat(prompt: "You asked yourself") {
                    VStack(spacing: Tokens.Space.lg) {
                        Text(q.text)
                            .font(.custom("Newsreader", size: 22).italic())
                            .foregroundStyle(Tokens.Text.onInverted.opacity(0.95))
                            .multilineTextAlignment(.center)
                        beatMeta(DayFormat.weekdayName(DayFormat.date(fromKey: q.day)))
                    }
                    .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
                }
            }
        case .sitting:
            if let sitting = signal.sitting {
                PromptBeat(prompt: "Your longest sitting") {
                    VStack(spacing: Tokens.Space.lg) {
                        Text(String(format: "%02d:%02d", sitting.seconds / 60, sitting.seconds % 60))
                            .font(.custom(EndpaperFont.meta, size: 72))
                            .monospacedDigit()
                            .foregroundStyle(Tokens.Text.onInverted)
                        beatMeta("\(DayFormat.weekdayName(DayFormat.date(fromKey: sitting.day))) · \(sitting.words) words")
                    }
                }
            }
        case .close:
            PromptBeat(prompt: weekLabel(signal)) {
                VStack(spacing: Tokens.Space.xl) {
                    SequenceStat(value: "\(signal.days)", label: "days written")
                    SequenceStat(value: signal.words.formatted(), label: "words")
                    Button(action: onClose) {
                        Text("Continue")
                            .font(.custom(EndpaperFont.meta, size: 13))
                            .tracking(13 * 0.14)
                            .textCase(.uppercase)
                            .foregroundStyle(Tokens.Text.onInverted)
                    }
                    .padding(.top, Tokens.Space.lg)
                }
            }
        }
    }

    /// The seven days as tap-size dots, filled where written.
    private var weekDots: some View {
        let start = DayFormat.date(fromKey: signal.startKey)
        let cal = Calendar.current
        let written = Set(signal.writtenKeys ?? [])
        return HStack(spacing: Tokens.Space.sm) {
            ForEach(0..<7, id: \.self) { i in
                let key = DayFormat.key(for: cal.date(byAdding: .day, value: i, to: start)!)
                Circle()
                    .strokeBorder(Tokens.Text.onInverted.opacity(0.28), lineWidth: 1)
                    .background(Circle().fill(written.contains(key) ? Tokens.Text.onInverted : .clear))
                    .frame(width: 20, height: 20)
            }
        }
    }

    private func shapeStatement(_ shape: WeeklySignal.Shape) -> String {
        switch shape.bucket {
        case "morning": return "Morning\nwriter."
        case "afternoon": return "Afternoon\nwriter."
        case "late": return "Night owl."
        default: return "Evening\nwriter."
        }
    }

    private func shapePhrase(_ bucket: String) -> String {
        switch bucket {
        case "morning": return "before noon"
        case "afternoon": return "midday"
        case "late": return "after midnight"
        default: return "after 5 pm"
        }
    }
}

/// The deck's small mono meta line.
func beatMeta(_ text: String) -> some View {
    Text(text)
        .font(.custom(EndpaperFont.meta, size: 10))
        .tracking(10 * 0.14)
        .textCase(.uppercase)
        .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
        .multilineTextAlignment(.center)
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
                            present(.weekly(weekly), archiving: .weekly(weekly))
                        } else if let monthly = ReflectionStore.shared.pendingMonthly(corpus: corpus) {
                            present(.monthly(monthly, writtenDays: writtenDayNumbers(of: monthly, corpus: corpus)),
                                    archiving: .monthly(monthly))
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
                present(.monthly(monthly, writtenDays: days), archiving: .monthly(monthly))
            }
        } else if let weekly = store.pendingWeekly(corpus: corpus) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                present(.weekly(weekly), archiving: .weekly(weekly))
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

    /// An arrival is marked seen (and archived) the moment it presents —
    /// backgrounding or killing the app mid-sequence must not re-arrive
    /// the same card on the next open. Nothing is lost: the full signal
    /// already rests in the Notebook archive.
    private func present(_ item: PresentedReflection, archiving reflection: ArchivedReflection) {
        ReflectionStore.shared.markSeen(reflection)
        presented = item
    }

    @ViewBuilder
    private func reflectionCover(_ item: PresentedReflection) -> some View {
        switch item {
        case .weekly(let signal):
            WeeklyCardView(signal: signal) {
                presented = nil
            }
        case .monthly(let signal, let writtenDays):
            RecapView(signal: signal, writtenDays: writtenDays) {
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
