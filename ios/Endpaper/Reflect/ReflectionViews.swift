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
    @ObservedObject private var gate = TrialGate.shared

    private enum Beat: Hashable {
        case intro, shape, thread, bigLine, question, sitting, days, words, challenge, close, offer
    }

    private var beats: [Beat] {
        var b: [Beat] = [.intro]
        if signal.shape != nil { b.append(.shape) }
        if signal.topic != nil, !signal.quotes.isEmpty { b.append(.thread) }
        if signal.bigLine != nil { b.append(.bigLine) }
        if signal.question != nil { b.append(.question) }
        if signal.sitting != nil { b.append(.sitting) }
        b.append(.days)
        b.append(.words)
        if signal.challenge != nil { b.append(.challenge) }
        // Free model (1.0.4): a non-member's deck closes on the offer —
        // the ask lands right after they've seen their own week read back,
        // and what's gated is the future, never the card they just read.
        b.append(gate.reflectionsUnlocked ? .close : .offer)
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
        case .intro:
            // The weekly opener — sibling of the monthly's cropped disc,
            // deliberately lighter: a hollow ring, opposite corner. A week
            // is an outline of a month.
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geo in
                    Circle()
                        .strokeBorder(Tokens.Text.onInverted, lineWidth: 2)
                        .frame(width: 260, height: 260)
                        .position(x: geo.size.width - 20, y: 60)
                }
                VStack(alignment: .leading, spacing: Tokens.Space.md) {
                    Text("Reflections")
                        .font(.custom(EndpaperFont.meta, size: 11))
                        .tracking(11 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted.opacity(0.62))
                    Text("Your\nweek.")
                        .font(.custom(EndpaperFont.heading, size: 44).weight(.semibold))
                        .foregroundStyle(Tokens.Text.onInverted)
                    Text(weekLabel(signal))
                        .font(.custom(EndpaperFont.meta, size: 10))
                        .tracking(10 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                        .padding(.top, Tokens.Space.xs)
                }
                .padding(.horizontal, Tokens.Space.screenX)
                .padding(.bottom, 140)
            }
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
        case .days:
            CounterStat(value: signal.days, label: "days written")
        case .words:
            CounterStat(value: signal.words, label: "words")
        case .challenge:
            if let challenge = signal.challenge {
                PromptBeat(prompt: "Challenges") {
                    SequenceQuote(quote: challenge, stampAsDate: true)
                        .padding(.horizontal, Tokens.Space.screenX)
                }
            }
        case .close:
            PromptBeat(prompt: weekLabel(signal)) {
                VStack(spacing: Tokens.Space.lg) {
                    Text("See you on the page.")
                        .font(.custom(EndpaperFont.heading, size: 28).weight(.medium))
                        .foregroundStyle(Tokens.Text.onInverted)
                    Button(action: onClose) {
                        Text("Continue")
                            .font(.custom(EndpaperFont.meta, size: 13))
                            .tracking(13 * 0.14)
                            .textCase(.uppercase)
                            .foregroundStyle(Tokens.Text.onInverted)
                    }
                    .padding(.top, Tokens.Space.md)
                }
            }
        case .offer:
            // The membership ask, at peak: their own week, just read back.
            PromptBeat(prompt: "That was your week") {
                VStack(spacing: Tokens.Space.lg) {
                    Text("Every week.\nEvery month.\nA year you can hold.")
                        .font(.custom(EndpaperFont.heading, size: 32).weight(.semibold))
                        .foregroundStyle(Tokens.Text.onInverted)
                        .multilineTextAlignment(.center)
                    beatMeta("Writing stays free, forever")
                    Button {
                        Task {
                            await TrialGate.shared.subscribe()
                            if TrialGate.shared.reflectionsUnlocked { onClose() }
                        }
                    } label: {
                        Text(joinLabel)
                            .font(.custom(EndpaperFont.heading, size: 17).weight(.medium))
                            .foregroundStyle(Tokens.Surface.inverted)
                            .padding(.horizontal, Tokens.Space.xl)
                            .padding(.vertical, Tokens.Space.md * 0.8)
                            .background(Tokens.Text.onInverted, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                    }
                    .padding(.top, Tokens.Space.sm)
                    Button(action: onClose) {
                        Text("Not now")
                            .font(.custom(EndpaperFont.meta, size: 11))
                            .tracking(11 * 0.14)
                            .textCase(.uppercase)
                            .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                    }
                }
                .padding(.horizontal, Tokens.Space.screenX)
            }
        }
    }

    private var joinLabel: String {
        if let price = gate.product?.displayPrice {
            return "Join — \(price) a year, first week free"
        }
        return "Join — $39.99 a year, first week free"
    }

    /// The seven days as tap-size dots, filling in one by one — the week
    /// drawing itself, like the monthly grid. Reduce Motion: pre-drawn.
    private var weekDots: some View {
        WeekDotsDrawing(startKey: signal.startKey, writtenKeys: Set(signal.writtenKeys ?? []))
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

/// The seven-dot row, drawing itself left to right.
private struct WeekDotsDrawing: View {
    let startKey: String
    let writtenKeys: Set<String>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = 0

    var body: some View {
        let start = DayFormat.date(fromKey: startKey)
        let cal = Calendar.current
        HStack(spacing: Tokens.Space.sm) {
            ForEach(0..<7, id: \.self) { i in
                let key = DayFormat.key(for: cal.date(byAdding: .day, value: i, to: start)!)
                Circle()
                    .strokeBorder(Tokens.Text.onInverted.opacity(0.28), lineWidth: 1)
                    .background(Circle().fill(i < drawn && writtenKeys.contains(key)
                                              ? Tokens.Text.onInverted : .clear))
                    .frame(width: 20, height: 20)
            }
        }
        .task {
            if reduceMotion {
                drawn = 7
                return
            }
            for d in 1...7 {
                withAnimation(Tokens.Motion.fast) { drawn = d }
                try? await Task.sleep(for: .milliseconds(110))
            }
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
    @State private var readyWeekly: WeeklySignal? = nil
    @State private var weeklyLocked = false
    @State private var readyMonthly: MonthlySignal? = nil
    @State private var monthlyLocked = false
    @State private var showMonthlyGate = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            if showConsent {
                ConsentCard { accepted in
                    withAnimation(Tokens.Motion.base) { showConsent = false }
                    if accepted {
                        // Opting in never presents anything (QA 2026-09-05:
                        // a new user has no week yet — the card is the
                        // notice, the arrival is a later card). It does arm
                        // the D6/D7 weekly notes.
                        Task { await ReminderManager.rearmReflectionNotes(requestPermission: true) }
                        evaluate()
                    }
                }
            }
            // End of week: the same card position announces the arrival —
            // the reader taps to open the deck, nothing auto-presents.
            if let weekly = readyWeekly {
                ReadyCard(
                    title: "Your week is ready.",
                    meta: weeklyLocked ? "Reflections are a membership — writing stays free"
                                       : "Seven days, read back to you",
                    cta: weeklyLocked ? "Join to read it →" : "Read it →"
                ) {
                    if weeklyLocked {
                        Task {
                            await TrialGate.shared.subscribe()
                            if TrialGate.shared.reflectionsUnlocked {
                                weeklyLocked = false
                                presentWeekly(weekly)
                            }
                        }
                    } else {
                        presentWeekly(weekly)
                    }
                }
            }
            if let monthly = readyMonthly {
                ReadyCard(
                    title: "Your \(DayFormat.monthName(monthly.month)) recap is ready.",
                    meta: monthlyLocked ? "Reflections are a membership — writing stays free"
                                        : "A month, handed back",
                    cta: monthlyLocked ? "Open →" : "Read it →"
                ) {
                    if monthlyLocked {
                        showMonthlyGate = true
                    } else {
                        presentMonthly(monthly)
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
        // The locked monthly's full-screen moment (QA 2026-09-05): the
        // recap opener's own design carrying the offer, join or dismiss.
        .fullScreenCover(isPresented: $showMonthlyGate) {
            if let monthly = readyMonthly {
                MonthlyGateView(signal: monthly) {
                    showMonthlyGate = false
                    monthlyLocked = false
                    presentMonthly(monthly)
                } onClose: {
                    showMonthlyGate = false
                }
            }
        }
    }

    private func evaluate() {
        let corpus = ReflectionStore.corpus(from: context)
        let store = ReflectionStore.shared
        let entitled = TrialGate.shared.reflectionsUnlocked
        let firstUsed = UserDefaults.standard.bool(forKey: AppKeys.firstWeeklyUsed)

        if store.consentEligible(corpus: corpus) {
            showConsent = true
            return
        }

        // Ready cards, monthly first. Free model (1.0.4): monthly is
        // members-only; the weekly plays free exactly once. A locked
        // pending reflection is never marked seen — it waits, whole,
        // until the member joins.
        readyWeekly = nil
        readyMonthly = nil
        if let monthly = store.pendingMonthly(corpus: corpus) {
            readyMonthly = monthly
            monthlyLocked = !entitled
        } else if let weekly = store.pendingWeekly(corpus: corpus) {
            readyWeekly = weekly
            weeklyLocked = !entitled && firstUsed
        }

        // January: the year is ready (spec §3.3) — a single quiet line.
        let now = Date()
        let cal = Calendar.current
        if store.consent == "yes", cal.component(.month, from: now) == 1 {
            let lastYear = Reflect.yearlySignal(year: cal.component(.year, from: now) - 1, corpus: corpus)
            if lastYear.days > 0 { januaryYear = lastYear }
        }
    }

    private func presentMonthly(_ monthly: MonthlySignal) {
        let corpus = ReflectionStore.corpus(from: context)
        present(.monthly(monthly, writtenDays: writtenDayNumbers(of: monthly, corpus: corpus)),
                archiving: .monthly(monthly))
    }

    /// An arrival is marked seen (and archived) the moment it presents —
    /// backgrounding or killing the app mid-sequence must not re-arrive
    /// the same card on the next open. Nothing is lost: the full signal
    /// already rests in the Notebook archive.
    private func present(_ item: PresentedReflection, archiving reflection: ArchivedReflection) {
        ReflectionStore.shared.markSeen(reflection)
        presented = item
    }

    /// Weekly presentation spends the one free weekly for non-members —
    /// stamped at presentation, so backgrounding mid-deck can't re-mint it.
    private func presentWeekly(_ weekly: WeeklySignal) {
        if !TrialGate.shared.reflectionsUnlocked {
            UserDefaults.standard.set(true, forKey: AppKeys.firstWeeklyUsed)
        }
        present(.weekly(weekly), archiving: .weekly(weekly))
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

/// The arrival card — the consent card's sibling, resting in the same
/// position on Today: a reflection is ready, tap to open it. Nothing
/// auto-presents any more (QA 2026-09-05).
private struct ReadyCard: View {
    let title: String
    let meta: String
    let cta: String
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(title).typeTitle()
            Text(meta).typeMetaSmall()
            Button(action: onTap) {
                Text(cta).typeMeta().foregroundStyle(Tokens.Text.written)
            }
            .padding(.top, Tokens.Space.xs)
        }
        .padding(Tokens.Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Surface.raised, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
    }
}

/// The locked monthly, full screen — the recap opener's own grammar
/// (inverted surface, cropped disc, statement bottom-left) carrying the
/// membership offer instead of the deck. Join opens the real recap on
/// the spot; Not now returns to the page with the card still resting.
struct MonthlyGateView: View {
    let signal: MonthlySignal
    var onJoin: () -> Void
    var onClose: () -> Void

    @ObservedObject private var gate = TrialGate.shared

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Tokens.Surface.inverted.ignoresSafeArea()
            GeometryReader { geo in
                Circle()
                    .fill(Tokens.Text.onInverted)
                    .frame(width: 300, height: 300)
                    .position(x: geo.size.width - 24, y: 30)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Recaps")
                    .font(.custom(EndpaperFont.meta, size: 11))
                    .tracking(11 * 0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.62))
                Text("Your \(DayFormat.monthName(signal.month))\nrecap is ready.")
                    .font(.custom(EndpaperFont.heading, size: 40).weight(.semibold))
                    .foregroundStyle(Tokens.Text.onInverted)
                Text("Join to read it — every week, every month, a year you can hold. Writing stays free, forever.")
                    .font(.custom(EndpaperFont.body, size: 17))
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.9))
                Button {
                    Task {
                        await TrialGate.shared.subscribe()
                        if TrialGate.shared.reflectionsUnlocked { onJoin() }
                    }
                } label: {
                    Text("Join — \(gate.product?.displayPrice ?? "$39.99") a year, first week free")
                        .font(.custom(EndpaperFont.heading, size: 17).weight(.medium))
                        .foregroundStyle(Tokens.Surface.inverted)
                        .padding(.horizontal, Tokens.Space.xl)
                        .padding(.vertical, Tokens.Space.md * 0.8)
                        .background(Tokens.Text.onInverted, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                }
                .padding(.top, Tokens.Space.sm)
                Button(action: onClose) {
                    Text("Not now")
                        .font(.custom(EndpaperFont.meta, size: 11))
                        .tracking(11 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                }
                .padding(.top, Tokens.Space.sm)
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.bottom, 100)
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
