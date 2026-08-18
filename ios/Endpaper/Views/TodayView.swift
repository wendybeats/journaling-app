// Today — the blank page is the home screen. Heading, mono meta row, the
// day's committed sections, and the writing surface with the cursor ready.
// Entries auto-commit (idle / backgrounding / navigating away); a faint
// "SAVED 9:41 AM" is the only acknowledgment. Committed sections can be
// revised until the day ends (long-press → Edit); at midnight the day
// archives and becomes permanent — the product rule taught in onboarding.

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(AppKeys.draft) private var draft = ""
    @AppStorage(AppKeys.draftDay) private var draftDay = ""

    @State private var todayEntries: [Entry] = []
    @State private var reminderOffer = false
    @State private var reviewOffer = false
    @State private var settlingID: UUID?
    @State private var ack = ""
    @State private var ackVisible = false
    @State private var idleCommit: Task<Void, Never>?
    @State private var writingFocused = false   // UIKit truth via LivingWriteView
    @StateObject private var voice = VoiceCapture()

    private let now = Date()
    private var key: String { DayFormat.key(for: now) }

    var body: some View {
        ScrollViewReader { proxy in
            scroll(proxy)
        }
    }

    private func scroll(_ proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // The crumb — a bare word in the mono register, like the web
                // prototype's .crumb. No capsule, no chrome.
                HStack {
                    Spacer()
                    NavigationLink {
                        ArchiveView()
                    } label: {
                        Text("Archive").typeMeta()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, Tokens.Space.sm)

                Text(DayFormat.dayHeading(now))
                    .typeDisplay()
                    .padding(.top, Tokens.Space.xl)

                Text(DayFormat.dayMetaRow(now, entries: todayEntries))
                    .typeMeta()
                    .padding(.top, Tokens.Space.sm)

                Rectangle()
                    .fill(Tokens.Line.rule)
                    .frame(height: Tokens.lineWeight)
                    .padding(.top, Tokens.Space.md)

                // The day's committed sections
                VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                    ForEach(todayEntries, id: \.id) { entry in
                        EntrySection(entry: entry, onEdited: { refresh() })
                            .opacity(settlingID == entry.id ? 0 : 1)
                            .animation(Tokens.Motion.fast, value: settlingID)
                    }
                }
                .padding(.top, Tokens.Space.lg)

                writingSurface
                    .padding(.top, todayEntries.isEmpty ? Tokens.Space.md : Tokens.Space.lg)

                // The caret's landing light: writing follows the last line
                // into view instead of sliding under the keyboard.
                Color.clear.frame(height: 1).id("caret")

                // Consent card / arrivals / January invite (reflection.js flow)
                ReflectionFlowHost()
                    .padding(.top, Tokens.Space.xl)

                // The reminder pre-prompt defers to the consent card — never
                // two asks on one page.
                if reminderOffer {
                    ReminderCard()
                        .padding(.top, Tokens.Space.xl)
                }

                // The rating ask waits its turn behind every other card —
                // one ask per page, and this is the least urgent of them.
                if reviewOffer {
                    ReviewAskCard()
                        .padding(.top, Tokens.Space.xl)
                }
            }
            .padding(.horizontal, Tokens.Space.screenX)
            // A full line of air under the last written line — the writing
            // bar sits below and must never crowd the text.
            .padding(.bottom, Tokens.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Tokens.Surface.page)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { writingBar }
        .onChange(of: draft) { _, _ in
            guard writingFocused || voice.isRecording else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo("caret", anchor: .bottom)
            }
        }
        .onAppear {
            voice.onText = { draft = $0 }
            adoptStaleDraft()
            refresh()
            let consentPending = ReflectionStore.shared.consentEligible(corpus: ReflectionStore.corpus(from: context))
            reminderOffer = ReminderManager.shouldOfferPrompt(in: context) && !consentPending
            reviewOffer = ReviewAskState.eligible(in: context) && !consentPending && !reminderOffer
            focusSoon()   // cursor ready — the app opens writable
        }
        .onChange(of: scenePhase) { _, phase in
            // Background only — .inactive also fires for permission alerts,
            // Control Center, and notification pulls, and committing there
            // once resurrected a just-committed draft mid-dictation.
            if phase == .background {
                commit()
                // Release focus cleanly on background so the resign/become
                // cycle starts fresh on return.
                writingFocused = false
            } else if phase == .active {
                focusSoon()
            }
        }
        .onDisappear { commit() }   // navigating away commits the session
    }

    // MARK: - The writing bar
    // Page-colored (never the system's white), REC centered, Done at the
    // trailing edge while the keyboard is up. `safeAreaInset` keeps it
    // above the keyboard when writing and at the page foot when not —
    // the two resting states from Wendell's markups.

    private var writingBar: some View {
        ZStack {
            RecPill(recording: voice.isRecording) {
                if voice.isRecording {
                    voice.stop()
                } else {
                    // The keyboard stands down while the mic is up — typing
                    // (or Return) mid-dictation mutated the draft underneath
                    // the transcript and overwrote spoken words (QA
                    // 2026-08-18). One writer at a time.
                    writingFocused = false
                    // The base is read when recording actually begins (after
                    // any permission flow), never captured at tap time.
                    voice.start { draft }
                }
            }
            // Done hides while recording — only one control may look like
            // it stops the take.
            if writingFocused && !voice.isRecording {
                HStack {
                    Spacer()
                    Button {
                        writingFocused = false
                    } label: {
                        Text("Done").barPill()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Tokens.Space.screenX)
        .padding(.vertical, Tokens.Space.sm)
        .background(Tokens.Surface.page)
        .animation(Tokens.Motion.fast, value: writingFocused)
        .animation(Tokens.Motion.fast, value: voice.isRecording)
    }

    /// Focus the writing surface once the view has settled. The false→true
    /// hop forces a fresh first-responder request even if a previous focus
    /// attempt raced a transition and left the state stuck.
    private func focusSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            writingFocused = false
            DispatchQueue.main.async { writingFocused = true }
        }
    }

    // MARK: - Writing surface

    private var writingSurface: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text(todayEntries.isEmpty ? "Write. This page is yours." : "Write.")
                        .font(.custom(EndpaperFont.body, size: 28))
                        .foregroundStyle(Tokens.Text.meta)
                        .allowsHitTesting(false)
                }
                LivingWriteView(text: $draft, focused: $writingFocused)
            }
            .onChange(of: draft) { _, text in
                draftDay = key
                idleCommit?.cancel()
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                // Three minutes: a pause to think is not an event. Commit
                // still fires instantly on Done, leaving, or backgrounding.
                idleCommit = Task {
                    try? await Task.sleep(for: .seconds(180))
                    if !Task.isCancelled { commit() }
                }
            }

            Text(ack)
                .typeMetaSmall()
                .opacity(ackVisible ? 1 : 0)
                .animation(Tokens.Motion.base, value: ackVisible)
        }
    }

    // MARK: - Commit choreography

    private func commit() {
        // Hard cancel, not stop: the draft is about to be committed and
        // cleared, so no trailing transcription may resurrect it.
        voice.cancel()
        idleCommit?.cancel()
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let entry = EntryStore.commit(text, in: context)
        draft = ""
        draftDay = ""
        refresh()

        // The 180 ms settle: the new section arrives faint, then takes ink.
        settlingID = entry.id
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Motion.fastDuration) {
            settlingID = nil
        }

        ack = "saved \(DayFormat.timeOfDay(entry.at))"
        ackVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { ackVisible = false }

        ReminderManager.suppressTodayIfWritten(in: context)
    }

    /// A draft from a previous day commits to that day rather than lingering.
    private func adoptStaleDraft() {
        guard !draft.isEmpty, !draftDay.isEmpty, draftDay != key else { return }
        let cal = Calendar.current
        let day = DayFormat.date(fromKey: draftDay)
        let lateThatDay = cal.date(bySettingHour: 23, minute: 59, second: 0, of: day) ?? day
        EntryStore.commit(draft.trimmingCharacters(in: .whitespacesAndNewlines), at: lateThatDay, in: context)
        draft = ""
        draftDay = ""
    }

    private func refresh() {
        todayEntries = EntryStore.entries(forDay: key, in: context)
    }
}

// MARK: - Writing-bar furniture (the quiet pill register)

/// Mono uppercase in a hairline capsule — the writing bar's button shape.
struct BarPill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .typeMeta()
            .padding(.horizontal, Tokens.Space.md)
            .padding(.vertical, Tokens.Space.sm)
            .overlay(Capsule().strokeBorder(Tokens.Line.rule, lineWidth: 1))
            .contentShape(Capsule())
    }
}

extension View {
    func barPill() -> some View { modifier(BarPill()) }
}

/// The mic: a small dot and REC in a pill. The dot is hollow at rest,
/// ink while recording, breathing slowly — the only motion on the page.
struct RecPill: View {
    let recording: Bool
    var action: () -> Void
    @State private var breathe = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.xs) {
                Circle()
                    .strokeBorder(Tokens.Dot.filled, lineWidth: 1)
                    .background(Circle().fill(recording ? Tokens.Dot.filled : .clear))
                    .frame(width: 6, height: 6)
                    .opacity(recording && breathe ? 0.35 : 1)
                Text("Rec")
            }
            .barPill()
        }
        .buttonStyle(.plain)
        .onChange(of: recording) { _, on in
            if on {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            } else {
                withAnimation(Tokens.Motion.fast) { breathe = false }
            }
        }
        .accessibilityLabel(recording ? "Stop voice note" : "Start voice note")
    }
}

/// One committed session: a small time stamp and the serif lines, each
/// resting at exactly the size it was written — per-line WrittenScale,
/// the same classifier as the writing surface, so a preserved big line
/// stays big on the page forever. Long-press to copy or share — and,
/// while the section's day is still today, to edit. At midnight the day
/// archives and the menu goes read-only: permanence begins when the day
/// ends.
struct EntrySection: View {
    let entry: Entry
    var onEdited: (() -> Void)? = nil

    @State private var editing = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(DayFormat.timeOfDay(entry.at))
                .typeMetaSmall()
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                let size = WrittenScale.size(for: line)
                Text(line)
                    .typeWrittenScaled(size)
                    .textSelection(.enabled)
                    .padding(.top, size >= 36 ? 6 : 0)
                    .padding(.bottom, size >= 36 ? 2 : 0)
            }
        }
        .contextMenu {
            if EntryStore.isEditable(entry) {
                Button {
                    editing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            Button {
                UIPasteboard.general.string = entry.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            ShareLink(item: shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .sheet(isPresented: $editing) {
            EditSessionSheet(entry: entry) { onEdited?() }
        }
    }

    private var shareText: String {
        "\(DayFormat.dayHeading(entry.at)) · \(DayFormat.timeOfDay(entry.at))\n\n\(entry.text)"
    }

    private var lines: [String] {
        entry.text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
