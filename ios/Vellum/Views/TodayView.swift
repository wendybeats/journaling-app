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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Tokens.Surface.page)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            adoptStaleDraft()
            refresh()
            reminderOffer = ReminderManager.shouldOfferPrompt(in: context)
                && !ReflectionStore.shared.consentEligible(corpus: ReflectionStore.corpus(from: context))
            // Cursor ready — the app opens writable
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { writingFocused = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive { commit() }
        }
        .onDisappear { commit() }   // navigating away commits the session
    }

    // MARK: - Writing surface

    private var writingSurface: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            TextField(
                todayEntries.isEmpty ? "Write. This page is yours." : "Write.",
                text: $draft,
                axis: .vertical
            )
            .typeWritten()
            .tint(Tokens.Line.cursor)
            .focused($writingFocused)
            .lineLimit(1...)
            .onChange(of: draft) { _, text in
                draftDay = key
                idleCommit?.cancel()
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                idleCommit = Task {
                    try? await Task.sleep(for: .seconds(5))
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

    // MARK: - Commit choreography

    private func commit() {
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

/// One committed session: a small time stamp and the serif paragraphs.
struct EntrySection: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(DayFormat.timeOfDay(entry.at))
                .typeMetaSmall()
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, para in
                Text(para).typeWritten()
            }
        }
    }

    private var paragraphs: [String] {
        entry.text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
