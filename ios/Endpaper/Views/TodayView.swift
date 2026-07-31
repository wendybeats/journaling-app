// Today — the blank page is the home screen. Heading, mono meta row, the
// day's committed sections, and the writing surface with the cursor ready.
// Entries auto-commit (5 s idle / backgrounding / navigating away); a faint
// "SAVED 9:41 AM" is the only acknowledgment. Committed text is permanent —
// there is no edit path, matching the product rule taught in onboarding.

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(AppKeys.draft) private var draft = ""
    @AppStorage(AppKeys.draftDay) private var draftDay = ""

    @State private var todayEntries: [Entry] = []
    @State private var reminderOffer = false
    @State private var settlingID: UUID?
    @State private var ack = ""
    @State private var ackVisible = false
    @State private var idleCommit: Task<Void, Never>?
    @FocusState private var writingFocused: Bool
    @StateObject private var voice = VoiceCapture()

    private let now = Date()
    private var key: String { DayFormat.key(for: now) }

    var body: some View {
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
                        EntrySection(entry: entry)
                            .opacity(settlingID == entry.id ? 0 : 1)
                            .animation(Tokens.Motion.fast, value: settlingID)
                    }
                }
                .padding(.top, Tokens.Space.lg)

                writingSurface
                    .padding(.top, todayEntries.isEmpty ? Tokens.Space.md : Tokens.Space.lg)

                // Consent card / arrivals / January invite (reflection.js flow)
                ReflectionFlowHost()
                    .padding(.top, Tokens.Space.xl)

                // The reminder pre-prompt defers to the consent card — never
                // two asks on one page.
                if reminderOffer {
                    ReminderCard()
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
        .onAppear {
            voice.onText = { draft = $0 }
            adoptStaleDraft()
            refresh()
            reminderOffer = ReminderManager.shouldOfferPrompt(in: context)
                && !ReflectionStore.shared.consentEligible(corpus: ReflectionStore.corpus(from: context))
            focusSoon()   // cursor ready — the app opens writable
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                commit()
                // Release focus cleanly. Backgrounding tears the keyboard
                // down behind SwiftUI's back; a FocusState left `true` with
                // no keyboard silently eats every later tap on the field.
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
                    voice.start(base: draft)
                }
            }
            if writingFocused {
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
            TextField(
                todayEntries.isEmpty ? "Write. This page is yours." : "Write.",
                text: $draft,
                axis: .vertical
            )
            .typeWrittenScaled(draftSize)
            .animation(Tokens.Motion.base, value: draftSize)
            .tint(Tokens.Line.cursor)
            .focused($writingFocused)
            .lineLimit(1...)
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
            .onSubmit(commit)

            Text(ack)
                .typeMetaSmall()
                .opacity(ackVisible ? 1 : 0)
                .animation(Tokens.Motion.base, value: ackVisible)
        }
    }

    /// The surface meets your first words large and settles as the draft
    /// grows — short entries read designed, like a quote.
    private var draftSize: CGFloat {
        let len = draft.count
        if len <= 70 && !draft.contains("\n") { return 28 }
        if len <= 150 { return 22 }
        return 17
    }

    // MARK: - Commit choreography

    private func commit() {
        voice.stop()
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

/// One committed session: a small time stamp and the serif paragraphs.
/// Short single-thought sections render at quote scale; long-press any
/// section to copy or share it (read-only outbound — permanence holds).
struct EntrySection: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(DayFormat.timeOfDay(entry.at))
                .typeMetaSmall()
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, para in
                Text(para).typeWrittenScaled(isQuote ? 24 : 17)
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = entry.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            ShareLink(item: shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var isQuote: Bool {
        paragraphs.count == 1 && entry.text.count <= 100
    }

    private var shareText: String {
        "\(DayFormat.dayHeading(entry.at)) · \(DayFormat.timeOfDay(entry.at))\n\n\(entry.text)"
    }

    private var paragraphs: [String] {
        entry.text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
