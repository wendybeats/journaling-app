// First launch: the four-screen tutorial, the account moment ("Keep your
// notebook."), then the trial moment ("A week on me.") — Endpaper is paid,
// one week free, no freemium. Shows exactly once; replay lives in Settings
// when Settings exists. Copy and sequence per docs/endpaper-stage2-plan.md,
// ported from js/views/onboarding.js.

import SwiftUI
import UIKit

private let tutorialPages = 4

struct OnboardingView: View {
    /// Replay mode (Settings → "Show the introduction again"): the same
    /// sequence, but nothing writes — no account change, no trial re-stamp.
    var replay = false
    var onReplayDone: (() -> Void)? = nil

    @AppStorage(AppKeys.onboarded) private var onboarded = false
    @AppStorage(AppKeys.account) private var accountMode = ""
    @AppStorage(AppKeys.trial) private var trialStamp = ""

    @State private var index = 0
    private let accountIndex = tutorialPages   // slide after the tutorial

    var body: some View {
        ZStack {
            Tokens.Surface.page.ignoresSafeArea()

            Group {
                switch index {
                case 0:
                    TutorialSlide(
                        index: 0,
                        title: "Attention is a practice.",
                        body: "A few honest lines a day change how the day sits with you. Not therapy, not productivity — just noticing, kept somewhere quiet.",
                        onSkip: { jump(to: accountIndex) }
                    )
                case 1:
                    TutorialSlide(
                        index: 1,
                        title: "This is Endpaper.",
                        body: "Open it, write or speak, close it. What you write stays written — no edits, no deletions; the point is to commit. Each day you write, a dot fills in.",
                        onSkip: { jump(to: accountIndex) }
                    ) { DemoDotGrid() }
                case 2:
                    TutorialSlide(
                        index: 2,
                        title: "Reflect, if you wish.",
                        body: "Each week, month, and year, Endpaper can reflect your writing back to you — the topics and words you returned to most. Optional, always skippable, only ever yours.",
                        onSkip: { jump(to: accountIndex) }
                    ) { CirclesGlyph() }
                case 3:
                    TutorialSlide(
                        index: 3,
                        title: "Go forth.",
                        body: "Today’s page is ready.",
                        cta: "Begin",
                        onSkip: { jump(to: accountIndex) },
                        onCTA: advance
                    )
                case 4:
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
        }
        .contentShape(Rectangle())
        .onTapGesture { if index < tutorialPages - 1 { advance() } }  // tap advances the tutorial
        .animation(Tokens.Motion.base, value: index)
    }

    private func advance() { withAnimation(Tokens.Motion.base) { index += 1 } }
    private func jump(to i: Int) { withAnimation(Tokens.Motion.base) { index = i } }
}

// MARK: - Tutorial slide

private struct TutorialSlide<Extra: View>: View {
    let index: Int
    let title: String
    let body_: String
    var cta: String? = nil
    var onSkip: () -> Void
    var onCTA: (() -> Void)? = nil
    @ViewBuilder var extra: () -> Extra

    init(index: Int, title: String, body: String, cta: String? = nil,
         onSkip: @escaping () -> Void, onCTA: (() -> Void)? = nil,
         @ViewBuilder extra: @escaping () -> Extra) {
        self.index = index
        self.title = title
        self.body_ = body
        self.cta = cta
        self.onSkip = onSkip
        self.onCTA = onCTA
        self.extra = extra
    }

    var body: some View { content }
}

// Swift can't infer `Extra` from a defaulted argument, so the plain slides
// (no visual) get their own initializer.
private extension TutorialSlide where Extra == EmptyView {
    init(index: Int, title: String, body: String, cta: String? = nil,
         onSkip: @escaping () -> Void, onCTA: (() -> Void)? = nil) {
        self.init(index: index, title: title, body: body, cta: cta,
                  onSkip: onSkip, onCTA: onCTA) { EmptyView() }
    }
}

private extension TutorialSlide {

    var content: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onSkip) { Text("Skip").typeMetaSmall() }
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.top, Tokens.Space.md)

            Spacer()

            VStack(spacing: Tokens.Space.md) {
                Text(title)
                    .typeDisplay()
                    .multilineTextAlignment(.center)
                Text(body_)
                    .typeWritten()
                    .multilineTextAlignment(.center)
                extra()
                    .padding(.top, Tokens.Space.sm)
                if let cta {
                    Button(action: { onCTA?() }) {
                        Text(cta).typeMeta().foregroundStyle(Tokens.Text.written)
                    }
                    .padding(.top, Tokens.Space.lg)
                }
            }
            .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)

            Spacer()

            // Literal Endpaper dots as the page indicator — the habit metaphor,
            // taught silently before a word about it is read.
            HStack(spacing: Tokens.DotSize.gap) {
                ForEach(0..<tutorialPages, id: \.self) { i in
                    VDot(filled: i == index)
                }
            }
            .padding(.bottom, Tokens.Space.xl)
        }
    }
}

/// The one animated moment: a month of dots filling in, one by one.
private struct DemoDotGrid: View {
    @State private var visible = Set<Int>()
    private let filled: [Int] = [1, 3, 4, 8, 10, 11, 15, 17, 20, 22, 23, 26]

    var body: some View {
        let columns = Array(
            repeating: GridItem(.fixed(Tokens.DotSize.today), spacing: Tokens.DotSize.gap),
            count: Tokens.DotSize.gridCols
        )
        LazyVGrid(columns: columns, spacing: Tokens.DotSize.gap) {
            ForEach(0..<28, id: \.self) { i in
                VDot(filled: filled.contains(i) && visible.contains(i))
                    .frame(width: Tokens.DotSize.today, height: Tokens.DotSize.today)
            }
        }
        .padding(Tokens.Space.card)
        .background(Tokens.Surface.raised, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
        .task {
            if UIAccessibility.isReduceMotionEnabled {
                visible = Set(filled)     // static filled grid under Reduce Motion
                return
            }
            try? await Task.sleep(for: .seconds(0.7))
            for i in filled {
                withAnimation(Tokens.Motion.fast) { _ = visible.insert(i) }
                try? await Task.sleep(for: .seconds(0.18))
            }
        }
    }
}

/// The reflections motif — the recap's overlapping circles, small.
private struct CirclesGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Tokens.Dot.filled, lineWidth: Tokens.lineWeight)
                .frame(width: 56, height: 56)
                .offset(x: -14)
            Circle()
                .fill(Tokens.Dot.filled.opacity(0.9))
                .frame(width: 56, height: 56)
                .offset(x: 14)
        }
        .padding(.top, Tokens.Space.sm)
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
            Text("Your writing stays in your private storage — no profile, no analytics, nothing read by anyone but you.")
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

            Text("Saved on this device only").typeMetaSmall()
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

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            Spacer()
            Text("A week on me.")
                .typeDisplay()
                .multilineTextAlignment(.center)
            Text("Every page, every reflection, free for seven days. After that, Endpaper is $29.99 a year — about the price of one good paper notebook.")
                .typeWritten()
                .multilineTextAlignment(.center)

            Button {
                Task {
                    if live { await TrialGate.shared.startTrial() }
                    start(false)
                }
            } label: {
                Text("Start my free week")
                    .font(.custom(EndpaperFont.heading, size: 17).weight(.medium))
                    .foregroundStyle(Tokens.Text.onInverted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.Space.md * 0.8)
                    .background(Tokens.Surface.inverted, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
            }
            .padding(.top, Tokens.Space.lg)

            Text("$29.99/year after trial · cancel anytime").typeMetaSmall()

            Button {
                Task {
                    if live { await TrialGate.shared.restore() }
                    start(true)
                }
            } label: {
                Text("Restore purchase").typeMetaSmall()
            }
            .padding(.top, Tokens.Space.xl)
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
    }
}
