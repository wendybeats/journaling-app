// First launch: the dive splash (one dot, expanded to fill — the
// calendar's motif as a front door), then a six-beat deck in the
// reflections grammar on the SYSTEM surface (QA 2026-08-27: same-color
// as the app, not inverted), then the account moment ("Keep your
// notebook.") — and straight onto the page. Free model (1.0.4): writing
// is free forever, so there is no trial slide and no payment sheet here;
// the membership is named in one quiet line on the closing beat, and the
// offer itself lives at the end of the first weekly reflection. Shows
// exactly once; replay lives in Settings.

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
                default:
                    // The last moment: choose where the notebook lives,
                    // then the page. No payment stands between a person
                    // and their first words.
                    AccountSlide { mode in
                        if replay {
                            onReplayDone?()
                        } else {
                            accountMode = mode.rawValue
                            onboarded = true
                            Analytics.once(.onboardingCompleted)
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
                .font(.custom(EndpaperFont.heading, size: 54).weight(.semibold))
                .foregroundStyle(Tokens.Text.display)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, Tokens.Space.screenX)
    }
}

/// Act one: the page. One dot becomes a week becomes a month, in the
/// calendar's own morph grammar, above the words.
private struct WriteBeat: View {
    var body: some View {
        PromptBeat(prompt: "Each day", onPage: true, hold: 0.5) {
            VStack(spacing: Tokens.Space.lg) {
                MonthFillDemo()
                Text("Write each day,\nsealed at midnight.")
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
        PromptBeat(prompt: "What did I say?", onPage: true, hold: 0.5) {
            VStack(spacing: Tokens.Space.lg) {
                Text("\u{201C}stressed\u{201D}")
                    .font(.custom("Newsreader", size: 54).italic())
                    .foregroundStyle(Tokens.Text.written)
                deckMeta("2 times this week")
                Text("Each week and month, your writing comes back to you — no analysis, no AI.")
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
        PromptBeat(prompt: "Who did I talk about?", onPage: true, hold: 0.5) {
            VStack(spacing: Tokens.Space.lg) {
                Text("\u{201C}Mom\u{201D}")
                    .font(.custom("Newsreader", size: 54).italic())
                    .foregroundStyle(Tokens.Text.written)
                deckMeta("Mentioned 3 times this week")
                Text("Get to know yourself better through your writing.")
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
        PromptBeat(prompt: "Your week, handed back", onPage: true, hold: 0.5) {
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
            try? await Task.sleep(for: .seconds(0.9))   // after the prompt seats
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
        PromptBeat(prompt: "Whenever you're ready", onPage: true, hold: 0.5) {
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
                // The model, named once, honestly — no price, no button.
                // The offer itself waits at the end of the first weekly
                // reflection, where they can see what they'd be buying.
                deckMeta("Writing is free, forever · reflections are\na membership — your first one's on me")
                    .padding(.top, Tokens.Space.lg)
            }
        }
    }
}

/// The calendar's morph grammar as a demo: one dot (today) splits into
/// a week, then blooms into the month — every dot travels from the
/// center of the week row to its grid seat, so the story is one day
/// becoming a record. Three days stay unfilled (an honest month).
/// Reduce Motion: the finished grid, at rest.
/// The month drawing itself (QA 2026-09-12): the recap grid's own
/// choreography — thirty dots filling one by one, a day at a time, the
/// three ringed misses staying open. Replaces the one→week→month morph.
private struct MonthFillDemo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = 0

    private let missed: Set<Int> = [5, 12, 26]
    private let dot: CGFloat = 14
    private let gap: CGFloat = 12
    private let cols = 7
    private let count = 30

    var body: some View {
        let columns = Array(repeating: GridItem(.fixed(dot), spacing: gap), count: cols)
        LazyVGrid(columns: columns, spacing: gap) {
            ForEach(1...count, id: \.self) { day in
                Group {
                    if missed.contains(day) {
                        Circle().strokeBorder(Tokens.Dot.empty, lineWidth: 1)
                    } else {
                        Circle().fill(Tokens.Dot.filled)
                    }
                }
                .frame(width: dot, height: dot)
                .scaleEffect(day <= drawn ? 1 : 0.35)
                .opacity(day <= drawn ? 1 : 0.15)
                .animation(.timingCurve(0.16, 0.84, 0.24, 1, duration: 0.35), value: drawn)
            }
        }
        .fixedSize()
        .task {
            if reduceMotion {
                drawn = count
                return
            }
            // PromptBeat reveals the content ~1.15s in — the grid must be
            // visible before it starts filling.
            try? await Task.sleep(for: .seconds(1.3))
            for d in 1...count {
                drawn = d
                try? await Task.sleep(for: .milliseconds(55))
            }
        }
        .accessibilityHidden(true)
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
            Text("Your writing stays in your private storage. No profile, nothing read by anyone but you. We count taps, never words.")
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

