// First launch: the dive splash (one dot, expanded to fill — the
// calendar's motif as a front door), then a six-beat deck in the
// reflections grammar on the SYSTEM surface (QA 2026-08-27: same-color
// as the app, not inverted), then the account moment ("Keep your
// notebook.") and the trial moment ("A week on me.") — Endpaper is paid,
// one week free, no freemium. Shows exactly once; replay lives in
// Settings.

import SwiftUI
import UIKit

private let tutorialPages = 6

struct OnboardingView: View {
    /// Replay mode (Settings → "Show the introduction again"): the same
    /// sequence, but nothing writes — no account change, no trial re-stamp.
    var replay = false
    var onReplayDone: (() -> Void)? = nil

    @AppStorage(AppKeys.onboarded) private var onboarded = false
    @AppStorage(AppKeys.account) private var accountMode = ""
    @AppStorage(AppKeys.trial) private var trialStamp = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    @State private var splashFilling = false
    @State private var splashFaded = false
    @State private var splashDone = false
    private let accountIndex = tutorialPages   // slide after the deck

    var body: some View {
        ZStack {
            Tokens.Surface.page.ignoresSafeArea()

            Group {
                switch index {
                case 0: OpenerBeat()
                case 1: WriteBeat()
                case 2: SurfacingBeat()
                case 3: NamesBeat()
                case 4: CollageBeat()
                case 5: ReadyBeat(onBegin: advance)
                case 6:
                    AccountSlide { mode in
                        if !replay { accountMode = mode.rawValue }
                        advance()
                    }
                default:
                    TrialSlide(live: !replay) { restored in
                        if replay {
                            onReplayDone?()
                        } else {
                            trialStamp = restored ? "restored" : ISO8601DateFormatter().string(from: .now)
                            onboarded = true
                        }
                    }
                }
            }
            .transition(.opacity)

            if index < tutorialPages {
                deckChrome
            }

            if !splashDone {
                splash
            }
        }
        .contentShape(Rectangle())
        // Tap anywhere advances every deck beat (incl. past "Begin");
        // swiping works too — back a beat as well as forward. The account
        // and trial moments require their buttons.
        .onTapGesture { if splashDone, index < tutorialPages { advance() } }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { g in
                    guard splashDone, index < tutorialPages else { return }
                    if g.translation.width < -40 {
                        advance()
                    } else if g.translation.width > 40, index > 0 {
                        withAnimation(Tokens.Motion.base) { index -= 1 }
                    }
                }
        )
        .animation(Tokens.Motion.base, value: index)
    }

    /// The dive, inverted: a lone dot held on the page, expanded until
    /// its ink fills the screen, then faded to reveal the first beat.
    /// Reduce Motion: straight to the deck.
    private var splash: some View {
        ZStack {
            Tokens.Surface.page
            Circle()
                .fill(Tokens.Dot.filled)
                .frame(width: 12, height: 12)
                .scaleEffect(splashFilling ? 280 : 1)
        }
        .ignoresSafeArea()
        .opacity(splashFaded ? 0 : 1)
        .task {
            if reduceMotion {
                splashDone = true
                return
            }
            try? await Task.sleep(for: .seconds(0.7))
            withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.55)) { splashFilling = true }
            try? await Task.sleep(for: .seconds(0.62))
            withAnimation(Tokens.Motion.base) { splashFaded = true }
            try? await Task.sleep(for: .seconds(Tokens.Motion.baseDuration))
            splashDone = true
        }
    }

    /// Skip (top right) and the deck's own pager dots (bottom) — literal
    /// Endpaper dots, page-surface colors.
    private var deckChrome: some View {
        VStack {
            HStack {
                Spacer()
                Button { jump(to: accountIndex) } label: {
                    Text("Skip")
                        .font(.custom(EndpaperFont.meta, size: 11))
                        .tracking(11 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.meta)
                }
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.top, Tokens.Space.md)

            Spacer()

            HStack(spacing: Tokens.Space.xs) {
                ForEach(0..<tutorialPages, id: \.self) { i in
                    Circle()
                        .fill(i == index ? Tokens.Dot.filled : Tokens.Dot.empty)
                        .frame(width: 5, height: 5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(index + 1) of \(tutorialPages)")
            .padding(.bottom, Tokens.Space.xl)
        }
    }

    private func advance() { withAnimation(Tokens.Motion.base) { index += 1 } }
    private func jump(to i: Int) { withAnimation(Tokens.Motion.base) { index = i } }
}

/// The deck's small mono meta line, page-surface flavor.
private func deckMeta(_ text: String) -> some View {
    Text(text)
        .font(.custom(EndpaperFont.meta, size: 10))
        .tracking(10 * 0.14)
        .textCase(.uppercase)
        .foregroundStyle(Tokens.Text.meta)
        .multilineTextAlignment(.center)
}

// MARK: - Deck beats

/// The thesis, centered: overline, then the claim. Nothing else.
private struct OpenerBeat: View {
    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            Text("Endpaper")
                .font(.custom(EndpaperFont.meta, size: 11))
                .tracking(11 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Text.meta)
            Text("The journal\nthat reflects.")
                .font(.custom(EndpaperFont.heading, size: 44).weight(.semibold))
                .foregroundStyle(Tokens.Text.heading)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Tokens.Space.screenX)
    }
}

/// Act one: the page. The month draws itself above the words — nearly
/// full, a few days missed, at the calendar's own scale.
private struct WriteBeat: View {
    var body: some View {
        PromptBeat(prompt: "Each day", onPage: true) {
            VStack(spacing: Tokens.Space.lg) {
                MonthDotsDemo()
                Text("Your space to write,\nsealed at midnight.")
                    .font(.custom(EndpaperFont.heading, size: 34).weight(.semibold))
                    .foregroundStyle(Tokens.Text.heading)
                    .multilineTextAlignment(.center)
                deckMeta("No edits · no deletions · a dot per day")
            }
            .padding(.horizontal, Tokens.Space.screenX)
        }
    }
}

/// Act two: the reflection — shown in the exact shape it will arrive in,
/// honestly labeled a sample.
private struct SurfacingBeat: View {
    var body: some View {
        PromptBeat(prompt: "What did I say?", onPage: true) {
            VStack(spacing: Tokens.Space.lg) {
                Text("\u{201C}stressed\u{201D}")
                    .font(.custom("Newsreader", size: 54).italic())
                    .foregroundStyle(Tokens.Text.written)
                deckMeta("4 times · across 3 days")
                Text("A sample. Each week and month, your writing comes back to you — your own words, verbatim, never analysis.")
                    .font(.custom(EndpaperFont.body, size: 17))
                    .foregroundStyle(Tokens.Text.written)
                    .multilineTextAlignment(.center)
                    .padding(.top, Tokens.Space.sm)
            }
            .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
        }
    }
}

/// The people beat — who kept appearing — and the privacy promise that
/// makes writing about them safe.
private struct NamesBeat: View {
    var body: some View {
        PromptBeat(prompt: "Who did I talk about?", onPage: true) {
            VStack(spacing: Tokens.Space.lg) {
                Text("Sam")
                    .font(.custom("Newsreader", size: 54).weight(.medium))
                    .foregroundStyle(Tokens.Text.written)
                deckMeta("A sample · on 5 days this month")
                Text("Never advice, never AI — no one reads a word but you.")
                    .font(.custom(EndpaperFont.body, size: 17))
                    .foregroundStyle(Tokens.Text.written)
                    .multilineTextAlignment(.center)
                    .padding(.top, Tokens.Space.sm)
            }
            .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
        }
    }
}

/// The rest of the deck, tossed on the table: overlapping reflection
/// cards — voice, rhythm, counters, a line written large — landing one
/// by one, deliberately a little messy.
private struct CollageBeat: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        PromptBeat(prompt: "Your week, handed back", onPage: true) {
            ZStack {
                collageCard(0, rotation: -7, x: -62, y: -128) { CounterCard(value: "23", label: "days written") }
                collageCard(1, rotation: 5, x: 72, y: -78) { RhythmCard() }
                collageCard(2, rotation: 8, x: -58, y: 16) { VoiceMiniCard() }
                collageCard(3, rotation: -4, x: 66, y: 68) { CounterCard(value: "4,120", label: "words") }
                collageCard(4, rotation: 3, x: -8, y: 168) { BigLineCard() }
            }
            .frame(height: 420)
        }
        .task {
            if reduceMotion {
                shown = 5
                return
            }
            try? await Task.sleep(for: .seconds(1.35))   // after the prompt seats
            for i in 1...5 {
                withAnimation(Tokens.Motion.base) { shown = i }
                try? await Task.sleep(for: .milliseconds(140))
            }
        }
    }

    private func collageCard<C: View>(_ i: Int, rotation: Double, x: CGFloat, y: CGFloat,
                                      @ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(Tokens.Space.md)
            .background(Tokens.Surface.inverted, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
            .rotationEffect(.degrees(rotation))
            .offset(x: x, y: y)
            .opacity(i < shown ? 1 : 0)
            .scaleEffect(i < shown ? 1 : 0.92)
    }
}

private struct CounterCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(value)
                .font(.custom(EndpaperFont.meta, size: 34))
                .monospacedDigit()
                .foregroundStyle(Tokens.Text.onInverted)
            Text(label)
                .font(.custom(EndpaperFont.meta, size: 9))
                .tracking(9 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
        }
    }
}

private struct VoiceMiniCard: View {
    private let bars: [CGFloat] = [8, 18, 11, 26, 15, 22, 9, 17, 12]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text("Spoken · Tue")
                .font(.custom(EndpaperFont.meta, size: 9))
                .tracking(9 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
            HStack(alignment: .center, spacing: 3) {
                ForEach(bars.indices, id: \.self) { i in
                    Capsule()
                        .fill(Tokens.Accent.capture)
                        .frame(width: 3, height: bars[i])
                }
            }
            Text("02:41")
                .font(.custom(EndpaperFont.meta, size: 11))
                .monospacedDigit()
                .foregroundStyle(Tokens.Text.onInverted.opacity(0.8))
        }
    }
}

private struct RhythmCard: View {
    private let bars: [CGFloat] = [10, 26, 40, 18, 8, 14, 30]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text("When you write")
                .font(.custom(EndpaperFont.meta, size: 9))
                .tracking(9 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(bars.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Tokens.Text.onInverted.opacity(i == 2 ? 1 : 0.45))
                        .frame(width: 7, height: bars[i])
                }
            }
        }
    }
}

private struct BigLineCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text("Enough.")
                .font(.custom("Newsreader", size: 26).weight(.medium))
                .foregroundStyle(Tokens.Text.onInverted)
            Text("You wrote this large")
                .font(.custom(EndpaperFont.meta, size: 9))
                .tracking(9 * 0.14)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
        }
    }
}

/// The deck's close — then the page itself.
private struct ReadyBeat: View {
    var onBegin: () -> Void

    var body: some View {
        PromptBeat(prompt: "Whenever you're ready", onPage: true) {
            VStack(spacing: Tokens.Space.lg) {
                Text("Today's page\nis ready.")
                    .font(.custom(EndpaperFont.heading, size: 34).weight(.semibold))
                    .foregroundStyle(Tokens.Text.heading)
                    .multilineTextAlignment(.center)
                Button(action: onBegin) {
                    Text("Begin")
                        .font(.custom(EndpaperFont.meta, size: 13))
                        .tracking(13 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.written)
                }
                .padding(.top, Tokens.Space.md)
            }
        }
    }
}

/// A month of dots at the calendar's own register — nearly full, a few
/// days missed — filling in one by one above the words. Page-surface
/// colors (VDot's own tokens, hand-tuned sizes: bigger than the small
/// demo grid the deck used before).
private struct MonthDotsDemo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = 0
    private let missed: Set<Int> = [6, 13, 22]

    private let dot: CGFloat = 16
    private let gap: CGFloat = 13

    var body: some View {
        let columns = Array(
            repeating: GridItem(.fixed(dot), spacing: gap),
            count: Tokens.DotSize.gridCols
        )
        LazyVGrid(columns: columns, spacing: gap) {
            ForEach(0..<28, id: \.self) { i in
                Circle()
                    .strokeBorder(Tokens.Dot.empty, lineWidth: 1)
                    .background(
                        Circle().fill(i < visible && !missed.contains(i)
                                      ? Tokens.Dot.filled : .clear)
                    )
                    .frame(width: dot, height: dot)
            }
        }
        .task {
            if reduceMotion {
                visible = 28     // static filled grid under Reduce Motion
                return
            }
            try? await Task.sleep(for: .seconds(0.9))   // after the prompt seats
            for i in 1...28 {
                withAnimation(Tokens.Motion.fast) { visible = i }
                try? await Task.sleep(for: .milliseconds(55))
            }
        }
    }
}

// MARK: - Account moment (Path A — Apple-native, decided July 8)

private struct AccountSlide: View {
    var choose: (AccountMode) -> Void

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            Spacer()
            Text("Keep your notebook.")
                .typeDisplay()
                .multilineTextAlignment(.center)
            Text("Your writing stays in your private storage. No profile, no analytics, nothing read by anyone but you.")
                .typeWritten()
                .multilineTextAlignment(.center)

            Button { choose(.icloud) } label: {
                Text("Back up with iCloud")
                    .font(.custom(EndpaperFont.heading, size: 17).weight(.medium))
                    .foregroundStyle(Tokens.Text.onInverted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.Space.md * 0.8)
                    .background(Tokens.Surface.inverted, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
            }
            .padding(.top, Tokens.Space.lg)

            Button { choose(.local) } label: {
                Text("Continue without an account →").typeMeta()
            }
            .padding(.top, Tokens.Space.md)

            Text("Saved on this device only — deleting the app deletes the notebook")
                .typeMetaSmall()
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
    }
}

// MARK: - The trial moment — paid with one free week, no freemium, no skip.
// Prices are placeholders until the pre-submission pricing pass.

private struct TrialSlide: View {
    var live = true                       // false in replay: no StoreKit, no stamps
    var start: (_ restored: Bool) -> Void
    @ObservedObject private var gate = TrialGate.shared

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            Spacer()
            // Where Apple processes no payments, there is no week to give
            // and no price to name — the honest version of that page is a
            // different page, not the same one with a dead button.
            Text(gate.paymentsUnavailable ? "Endpaper is yours." : "A week, on me.")
                .typeDisplay()
                .multilineTextAlignment(.center)
            Text(gate.paymentsUnavailable
                 ? "Apple doesn't process payments in your region, so Endpaper is free here — every page, every reflection, for as long as that's true."
                 : "Every page, every reflection, free for seven days. After that, Endpaper is $39.99 a year — about the price of one good paper notebook.")
                .typeWritten()
                .multilineTextAlignment(.center)

            Button {
                Task {
                    // Proceed only when the subscription verifies — a
                    // dismissed sheet keeps us on this slide (no shadow
                    // week; the double-trial bug lived here).
                    if live {
                        if await TrialGate.shared.startTrial() { start(false) }
                    } else {
                        start(false)
                    }
                }
            } label: {
                Text(gate.paymentsUnavailable ? "Start writing" : "Start my free week")
                    .font(.custom(EndpaperFont.heading, size: 17).weight(.medium))
                    .foregroundStyle(Tokens.Text.onInverted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.Space.md * 0.8)
                    .background(Tokens.Surface.inverted, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
            }
            .padding(.top, Tokens.Space.lg)

            if !gate.paymentsUnavailable {
                Text("$39.99/year after trial · cancel anytime").typeMetaSmall()
            }

            // TestFlight/debug-only store diagnostic: if the product never
            // loads, startTrial() takes the silent offline fallback and no
            // purchase sheet can ever appear — this line makes that state
            // visible instead of mysterious (QA 2026-08-20: "never seen
            // the sheet in TestFlight"). App Store builds never show it.
            if live && AppEnv.demoControls {
                Text(gate.product == nil
                     ? "store check: product not loaded — sheet cannot appear"
                     : "store check: \(gate.product!.id) loaded ✓")
                    .typeMetaSmall()
                    .foregroundStyle(Tokens.Accent.capture)
                    .onAppear { Task { await gate.refresh() } }
            }

            // Nothing to restore where nothing can be bought.
            if !gate.paymentsUnavailable {
                Button {
                    Task {
                        if live { await TrialGate.shared.restore() }
                        start(true)
                    }
                } label: {
                    Text("Restore purchase").typeMetaSmall()
                }
                .padding(.top, Tokens.Space.xl)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
    }
}
