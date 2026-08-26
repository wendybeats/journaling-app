// First launch: a five-beat deck in the reflections grammar (the pitch is
// "you write, it reads you back" — so the tutorial LOOKS like a reflection
// arriving), then the account moment ("Keep your notebook."), then the
// trial moment ("A week on me.") — Endpaper is paid, one week free, no
// freemium. Shows exactly once; replay lives in Settings. The deck runs on
// the inverted surface like the weekly/monthly cards; landing on the bone
// page afterwards IS the arrival into the product.

import SwiftUI
import UIKit

private let tutorialPages = 5

struct OnboardingView: View {
    /// Replay mode (Settings → "Show the introduction again"): the same
    /// sequence, but nothing writes — no account change, no trial re-stamp.
    var replay = false
    var onReplayDone: (() -> Void)? = nil

    @AppStorage(AppKeys.onboarded) private var onboarded = false
    @AppStorage(AppKeys.account) private var accountMode = ""
    @AppStorage(AppKeys.trial) private var trialStamp = ""

    @State private var index = 0
    private let accountIndex = tutorialPages   // slide after the deck

    var body: some View {
        ZStack {
            // The deck is inverted, like every reflection; the account and
            // trial moments sit on the page surface the user is about to
            // live on.
            (index < tutorialPages ? Tokens.Surface.inverted : Tokens.Surface.page)
                .ignoresSafeArea()

            Group {
                switch index {
                case 0: OpenerBeat()
                case 1: WriteBeat()
                case 2: SurfacingBeat()
                case 3: QuestionBeat()
                case 4: ReadyBeat(onBegin: advance)
                case 5:
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
        }
        .contentShape(Rectangle())
        // Tap anywhere advances every deck beat (incl. past "Begin");
        // swiping works too — back a beat as well as forward. The account
        // and trial moments require their buttons.
        .onTapGesture { if index < tutorialPages { advance() } }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { g in
                    guard index < tutorialPages else { return }
                    if g.translation.width < -40 {
                        advance()
                    } else if g.translation.width > 40, index > 0 {
                        withAnimation(Tokens.Motion.base) { index -= 1 }
                    }
                }
        )
        .animation(Tokens.Motion.base, value: index)
    }

    /// Skip (top right) and the deck's own pager dots (bottom) — system
    /// page dots color by scheme, not by our inverted surface.
    private var deckChrome: some View {
        VStack {
            HStack {
                Spacer()
                Button { jump(to: accountIndex) } label: {
                    Text("Skip")
                        .font(.custom(EndpaperFont.meta, size: 11))
                        .tracking(11 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                }
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.top, Tokens.Space.md)

            Spacer()

            HStack(spacing: Tokens.Space.xs) {
                ForEach(0..<tutorialPages, id: \.self) { i in
                    Circle()
                        .fill(Tokens.Text.onInverted.opacity(i == index ? 1 : 0.3))
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

// MARK: - Deck beats

/// The thesis, in the weekly opener's layout — hollow ring off the top
/// corner, statement bottom-left. The first thing read is the strategy.
private struct OpenerBeat: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                Circle()
                    .strokeBorder(Tokens.Text.onInverted, lineWidth: 2)
                    .frame(width: 260, height: 260)
                    .position(x: geo.size.width - 20, y: 60)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Endpaper")
                    .font(.custom(EndpaperFont.meta, size: 11))
                    .tracking(11 * 0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.62))
                Text("You write.\nIt reads\nyou back.")
                    .font(.custom(EndpaperFont.heading, size: 44).weight(.semibold))
                    .foregroundStyle(Tokens.Text.onInverted)
                Text("A journal, in your own words")
                    .font(.custom(EndpaperFont.meta, size: 10))
                    .tracking(10 * 0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                    .padding(.top, Tokens.Space.xs)
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.bottom, 140)
        }
    }
}

/// Act one: the page. Permanence stated once, the dot habit shown, not
/// explained.
private struct WriteBeat: View {
    var body: some View {
        PromptBeat(prompt: "Each day") {
            VStack(spacing: Tokens.Space.lg) {
                Text("One quiet page,\nsealed at midnight.")
                    .font(.custom(EndpaperFont.heading, size: 34).weight(.semibold))
                    .foregroundStyle(Tokens.Text.onInverted)
                    .multilineTextAlignment(.center)
                InvertedDotGrid()
                beatMeta("No edits · no deletions · a dot per day")
            }
            .padding(.horizontal, Tokens.Space.screenX)
        }
    }
}

/// Act two: the reflection — shown in the exact shape it will arrive in,
/// honestly labeled a sample.
private struct SurfacingBeat: View {
    var body: some View {
        PromptBeat(prompt: "Kept surfacing") {
            VStack(spacing: Tokens.Space.lg) {
                Text("\u{201C}sleep\u{201D}")
                    .font(.custom("Newsreader", size: 54).italic())
                    .foregroundStyle(Tokens.Text.onInverted)
                beatMeta("4 times · across 3 days")
                Text("A sample. Each week and month, your writing comes back to you — your own words, verbatim, never analysis.")
                    .font(.custom(EndpaperFont.body, size: 17))
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, Tokens.Space.sm)
            }
            .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
        }
    }
}

/// The therapy-adjacent promise: what you ask on the page returns when
/// you're ready — and nobody else ever sees it.
private struct QuestionBeat: View {
    var body: some View {
        PromptBeat(prompt: "You asked yourself") {
            VStack(spacing: Tokens.Space.lg) {
                Text("Why do I keep replaying what I said on Sunday?")
                    .font(.custom("Newsreader", size: 22).italic())
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.95))
                    .multilineTextAlignment(.center)
                Text("Questions come back when you're ready to answer them. Never advice, never AI — no one reads a word but you.")
                    .font(.custom(EndpaperFont.body, size: 17))
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, Tokens.Space.sm)
            }
            .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
        }
    }
}

/// The deck's close, mirroring the weekly card's — then the surface flips
/// to bone and the product begins.
private struct ReadyBeat: View {
    var onBegin: () -> Void

    var body: some View {
        PromptBeat(prompt: "Whenever you're ready") {
            VStack(spacing: Tokens.Space.lg) {
                Text("Today's page\nis ready.")
                    .font(.custom(EndpaperFont.heading, size: 34).weight(.semibold))
                    .foregroundStyle(Tokens.Text.onInverted)
                    .multilineTextAlignment(.center)
                Button(action: onBegin) {
                    Text("Begin")
                        .font(.custom(EndpaperFont.meta, size: 13))
                        .tracking(13 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted)
                }
                .padding(.top, Tokens.Space.md)
            }
        }
    }
}

/// A month of dots filling in one by one — the DemoDotGrid moment, redrawn
/// for the inverted surface (VDot's tokens are page-surface colors).
private struct InvertedDotGrid: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = Set<Int>()
    private let filled: [Int] = [1, 3, 4, 8, 10, 11, 15, 17, 20, 22, 23, 26]

    var body: some View {
        let columns = Array(
            repeating: GridItem(.fixed(Tokens.DotSize.today), spacing: Tokens.DotSize.gap),
            count: Tokens.DotSize.gridCols
        )
        LazyVGrid(columns: columns, spacing: Tokens.DotSize.gap) {
            ForEach(0..<28, id: \.self) { i in
                Circle()
                    .strokeBorder(Tokens.Text.onInverted.opacity(0.28), lineWidth: 1)
                    .background(
                        Circle().fill(filled.contains(i) && visible.contains(i)
                                      ? Tokens.Text.onInverted : .clear)
                    )
                    .frame(width: Tokens.DotSize.today, height: Tokens.DotSize.today)
            }
        }
        .task {
            if reduceMotion {
                visible = Set(filled)     // static filled grid under Reduce Motion
                return
            }
            try? await Task.sleep(for: .seconds(0.9))   // after the prompt seats
            for i in filled {
                withAnimation(Tokens.Motion.fast) { _ = visible.insert(i) }
                try? await Task.sleep(for: .seconds(0.14))
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
