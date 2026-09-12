// The reflection flow on Today (rev. 2026-09-12): reflections are ON by
// default (Settings can turn them off — no consent card), every pending
// reflection is its own card in the page's carousel (nothing outranks
// anything), and an arrival is announced once, on the first open that
// finds it, by an inverted sheet — the deck itself still opens on a tap.

import Foundation
import SwiftData
import SwiftUI

@MainActor
final class ReflectionFlow: ObservableObject {
    enum Card: Identifiable {
        case monthly(MonthlySignal, locked: Bool)
        case weekly(WeeklySignal, locked: Bool)
        case thin(Date)
        case year(YearlySignal)

        var id: String {
            switch self {
            case .monthly(let s, _): return s.id
            case .weekly(let s, _): return s.id
            case .thin(let d): return "thin-" + DayFormat.key(for: d)
            case .year(let s): return s.id
            }
        }
    }

    /// What the arrival sheet announces — the same two big moments.
    enum Arrival: Identifiable {
        case weekly(WeeklySignal, locked: Bool)
        case monthly(MonthlySignal, locked: Bool)
        var id: String {
            switch self {
            case .weekly(let s, _): return s.id
            case .monthly(let s, _): return s.id
            }
        }
    }

    @Published var cards: [Card] = []
    @Published var presented: PresentedReflection? = nil
    @Published var monthlyGate: MonthlySignal? = nil
    @Published var arrival: Arrival? = nil

    private var corpus = Corpus(byDay: [:])
    private var hidden = Set<String>()          // "Later" this visit (weekly / year)
    private var pendingArrival: Arrival? = nil

    // MARK: Evaluate

    func evaluate(corpus: Corpus) {
        self.corpus = corpus
        let store = ReflectionStore.shared
        let entitled = TrialGate.shared.reflectionsUnlocked
        let firstUsed = UserDefaults.standard.bool(forKey: AppKeys.firstWeeklyUsed)
        var next: [Card] = []
        pendingArrival = nil

        // Free model (1.0.4): monthly is members-only; the weekly plays
        // free exactly once. A locked pending reflection is never marked
        // seen — it waits, whole, until the member joins.
        if let monthly = store.pendingMonthly(corpus: corpus) {
            next.append(.monthly(monthly, locked: !entitled))
            pendingArrival = .monthly(monthly, locked: !entitled)
        }
        if let weekly = store.pendingWeekly(corpus: corpus), !hidden.contains(weekly.id) {
            let locked = !entitled && firstUsed
            next.append(.weekly(weekly, locked: locked))
            Analytics.once(.weeklyReflectionEligible, key: weekly.id,
                           [.locked: .bool(locked), .weekIndex: .int(Analytics.weekIndex)])
            if pendingArrival == nil { pendingArrival = .weekly(weekly, locked: locked) }
        }
        if let moved = store.pendingThinWeek(corpus: corpus) {
            next.append(.thin(moved))
        }
        // January: the year is ready (spec §3.3).
        let now = Date()
        let cal = Calendar.current
        if store.reflectionsOn, cal.component(.month, from: now) == 1 {
            let lastYear = Reflect.yearlySignal(year: cal.component(.year, from: now) - 1, corpus: corpus)
            if lastYear.days > 0, !hidden.contains(lastYear.id) { next.append(.year(lastYear)) }
        }
        cards = next
    }

    // MARK: The arrival sheet — once per arrival

    /// True when a pending weekly/monthly has not yet been announced.
    var arrivalDue: Bool {
        guard let a = pendingArrival else { return false }
        return UserDefaults.standard.string(forKey: AppKeys.arrivalSheet) != a.id
    }

    func showArrivalIfDue() {
        guard arrivalDue, let a = pendingArrival, presented == nil, monthlyGate == nil else { return }
        UserDefaults.standard.set(a.id, forKey: AppKeys.arrivalSheet)
        arrival = a
        if case .weekly(_, let locked) = a, locked {
            Analytics.track(.paywallViewed, [.surface: .surface(.arrivalSheet)])
        }
        if case .monthly(_, let locked) = a, locked {
            Analytics.track(.paywallViewed, [.surface: .surface(.arrivalSheet)])
        }
    }

    /// The sheet's primary action: dismiss it, then open what it announced.
    func readFromArrival(_ a: Arrival) {
        arrival = nil
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(450))   // let the sheet settle before the cover
            guard let self else { return }
            switch a {
            case .weekly(let s, let locked):
                if locked { self.join(weekly: s, from: .arrivalSheet) } else { self.presentWeekly(s) }
            case .monthly(let s, let locked):
                if locked { self.monthlyGate = s } else { self.presentMonthly(s) }
            }
        }
    }

    // MARK: Card actions

    func read(_ card: Card) {
        switch card {
        case .weekly(let s, let locked):
            if locked {
                Analytics.track(.paywallViewed, [.surface: .surface(.lockedCard)])
                join(weekly: s, from: .lockedCard)
            } else {
                presentWeekly(s)
            }
        case .monthly(let s, let locked):
            if locked { monthlyGate = s } else { presentMonthly(s) }
        case .year(let s):
            presented = .yearly(s)
        case .thin:
            break
        }
    }

    func later(_ card: Card) {
        switch card {
        case .monthly(let s, _): ReflectionStore.shared.deferMonthly(id: s.id)
        case .weekly(let s, _): hidden.insert(s.id)
        case .year(let s): hidden.insert(s.id)
        case .thin: ReflectionStore.shared.markThinSeen()
        }
        withAnimation(Tokens.Motion.base) { cards.removeAll { $0.id == card.id } }
    }

    func join(weekly: WeeklySignal, from surface: Analytics.Surface) {
        Task {
            await TrialGate.shared.subscribe(from: surface)
            if TrialGate.shared.reflectionsUnlocked { presentWeekly(weekly) }
        }
    }

    /// The locked monthly's gate said yes.
    func joinedFromGate(_ monthly: MonthlySignal) {
        monthlyGate = nil
        presentMonthly(monthly)
    }

    // MARK: Presentation

    func presentMonthly(_ monthly: MonthlySignal) {
        present(.monthly(monthly, writtenDays: writtenDayNumbers(of: monthly, corpus: corpus)),
                archiving: .monthly(monthly))
    }

    /// Weekly presentation spends the one free weekly for non-members —
    /// stamped at presentation, so backgrounding mid-deck can't re-mint it.
    func presentWeekly(_ weekly: WeeklySignal) {
        if !TrialGate.shared.reflectionsUnlocked {
            UserDefaults.standard.set(true, forKey: AppKeys.firstWeeklyUsed)
        }
        Analytics.track(.weeklyReflectionOpened, [.weekIndex: .int(Analytics.weekIndex)])
        present(.weekly(weekly), archiving: .weekly(weekly))
    }

    /// An arrival is marked seen (and archived) the moment it presents —
    /// backgrounding or killing the app mid-sequence must not re-arrive
    /// the same card on the next open. Nothing is lost: the full signal
    /// already rests in the Notebook archive.
    private func present(_ item: PresentedReflection, archiving reflection: ArchivedReflection) {
        ReflectionStore.shared.markSeen(reflection)
        cards.removeAll { $0.id == reflection.id }
        presented = item
    }
}

// MARK: - The arrival sheet

/// The big moment, announced (QA 2026-09-12): the reflections' own
/// inverted surface rising over the page on the first open that finds a
/// finished week or month. Read it, or later — the card stays behind.
struct ArrivalSheet: View {
    let arrival: ReflectionFlow.Arrival
    var onRead: () -> Void
    var onLater: () -> Void
    @ObservedObject private var gate = TrialGate.shared

    private var locked: Bool {
        switch arrival {
        case .weekly(_, let l), .monthly(_, let l): return l
        }
    }
    private var kicker: String {
        if case .monthly = arrival { return "Recaps" }
        return "Reflections"
    }
    private var title: String {
        switch arrival {
        case .weekly: return "Your week\nis ready."
        case .monthly(let s, _): return "Your \(DayFormat.monthName(s.month))\nrecap is ready."
        }
    }
    private var meta: String {
        if locked { return "Reflections are a membership — writing stays free" }
        if case .monthly = arrival { return "A month, handed back" }
        return "Seven days, read back to you"
    }
    private var cta: String {
        guard locked else { return "Read it" }
        if case .monthly = arrival { return "Join to read it" }
        return "Join — \(gate.product?.displayPrice ?? "$39.99") a year, first week free"
    }

    var body: some View {
        ZStack {
            Tokens.Surface.inverted.ignoresSafeArea()
            VStack(spacing: Tokens.Space.md) {
                Text(kicker)
                    .font(.custom(EndpaperFont.meta, size: 11))
                    .tracking(11 * 0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.62))
                Text(title)
                    .font(.custom(EndpaperFont.heading, size: 34).weight(.semibold))
                    .foregroundStyle(Tokens.Text.onInverted)
                    .multilineTextAlignment(.center)
                Text(meta)
                    .font(.custom(EndpaperFont.meta, size: 10))
                    .tracking(10 * 0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                    .multilineTextAlignment(.center)
                Button(action: onRead) {
                    Text(cta)
                        .font(.custom(EndpaperFont.heading, size: 17).weight(.medium))
                        .foregroundStyle(Tokens.Surface.inverted)
                        .padding(.horizontal, Tokens.Space.xl)
                        .padding(.vertical, Tokens.Space.md * 0.8)
                        .background(Tokens.Text.onInverted, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                }
                .padding(.top, Tokens.Space.sm)
                Button(action: onLater) {
                    Text("Later")
                        .font(.custom(EndpaperFont.meta, size: 11))
                        .tracking(11 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                }
            }
            .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
            .padding(.vertical, Tokens.Space.xl)
        }
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Tokens.Surface.inverted)
        .presentationCornerRadius(Tokens.Radius.card * 2)
    }
}
