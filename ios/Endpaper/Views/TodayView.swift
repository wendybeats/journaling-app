// Today — the blank page is the home screen. Heading, mono meta row, the
// day's committed sections, and the writing surface with the cursor ready.
// Entries auto-commit (idle / backgrounding / navigating away); a faint
// "SAVED 9:41 AM" is the only acknowledgment. Committed sections can be
// revised until the day ends (long-press → Edit); at midnight the day
// archives and becomes permanent — the product rule taught in onboarding.

import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var takingVoice = false      // the card is up (incl. grace hold)
    @State private var importMenu = false
    @State private var scanning = false
    @State private var pickingPhoto = false
    @State private var photoPick: PhotosPickerItem?
    @State private var pickingFile = false

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
            guard writingFocused else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo("caret", anchor: .bottom)
            }
        }
        .onChange(of: voice.isRecording) { _, on in
            // The card rises only once recording truly begins — after the
            // permission flow, and never on a denied ask.
            if on { withAnimation(Tokens.Motion.base) { takingVoice = true } }
        }
        .overlay(alignment: .bottom) {
            if takingVoice {
                VoiceCard(voice: voice) { finishVoiceTake() }
                    .padding(.bottom, Tokens.Space.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .confirmationDialog("Add writing", isPresented: $importMenu, titleVisibility: .visible) {
            if DocScanner.isAvailable {
                Button("Take a photo") { scanning = true }
            }
            Button("From your photos") { pickingPhoto = true }
            Button("Choose a file") { pickingFile = true }
        }
        .sheet(isPresented: $scanning) {
            DocScanner { pages in importPages(pages) }
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $pickingPhoto, selection: $photoPick, matching: .images)
        .onChange(of: photoPick) { _, item in
            guard let item else { return }
            photoPick = nil
            importPhoto(item)
        }
        .fileImporter(isPresented: $pickingFile, allowedContentTypes: ImportCapture.fileTypes) { result in
            if case .success(let url) = result { importFile(url) }
        }
        .onAppear {
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
                abandonVoiceTake()
                commit()
                // Release focus cleanly on background so the resign/become
                // cycle starts fresh on return.
                writingFocused = false
            } else if phase == .active {
                focusSoon()
            }
        }
        .onDisappear {              // navigating away commits the session
            abandonVoiceTake()
            commit()
        }
    }

    // MARK: - The writing bar
    // Page-colored (never the system's white), REC centered, Done at the
    // trailing edge while the keyboard is up. `safeAreaInset` keeps it
    // above the keyboard when writing and at the page foot when not —
    // the two resting states from Wendell's markups.

    private var writingBar: some View {
        ZStack {
            HStack(spacing: Tokens.Space.sm) {
                RecPill(recording: voice.isRecording) {
                    guard !takingVoice else { return }
                    // The keyboard stands down while the mic is up — one
                    // writer at a time. Voice never touches the draft: the
                    // take lives on the card and commits as its own section.
                    writingFocused = false
                    voice.start()
                }
                Button {
                    writingFocused = false
                    importMenu = true
                } label: {
                    HStack(spacing: Tokens.Space.xs) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Tokens.Dot.filled)
                        Text("Upload")
                    }
                    .barPill()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add writing from a photo or file")
            }
            .opacity(takingVoice ? 0 : 1)
            // Done hides while recording — only one control may look like
            // it stops the take.
            if writingFocused && !takingVoice {
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
        .animation(Tokens.Motion.fast, value: takingVoice)
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

    // MARK: - Voice take

    /// The card's stop button: end the take, hold for the recognizer's
    /// trailing final, then commit the words as their own section.
    private func finishVoiceTake() {
        voice.finish { text in
            withAnimation(Tokens.Motion.base) { takingVoice = false }
            commitCaptured(text, origin: "spoken")
            focusSoon()   // the pen comes back once the card is down
        }
    }

    /// Backgrounding or navigating away mid-take: no grace window — keep
    /// what the take already holds and put it on the page.
    private func abandonVoiceTake() {
        guard takingVoice else { return }
        let text = voice.transcript
        voice.cancel()
        takingVoice = false
        commitCaptured(text, origin: "spoken")
    }

    // MARK: - Photo & file import

    private func importPages(_ pages: [UIImage]) {
        readCaptured(origin: "scanned") { try await ImportCapture.text(fromPages: pages) }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        readCaptured(origin: "scanned") {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { throw ImportCapture.Failure.unreadable }
            return try await ImportCapture.text(from: image)
        }
    }

    private func importFile(_ url: URL) {
        readCaptured(origin: "imported") { try await ImportCapture.text(fromFile: url) }
    }

    /// Shared read → commit choreography: a quiet "reading…" while OCR or
    /// extraction runs, then the section settles onto the page — or the
    /// failure explains itself in the same quiet register.
    private func readCaptured(origin: String, _ read: @escaping () async throws -> String) {
        ack = "reading your writing…"
        ackVisible = true
        Task { @MainActor in
            do {
                let text = try await read()
                commitCaptured(text, origin: origin)
            } catch {
                ack = (error as? ImportCapture.Failure)?.errorDescription ?? "Couldn't read that."
                ackVisible = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { ackVisible = false }
            }
        }
    }

    /// Commit words that arrived by capture (voice, photo, file). Always a
    /// discrete section — never merged into the typed session.
    private func commitCaptured(_ text: String, origin: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            ackVisible = false
            return
        }
        let entry = EntryStore.commit(trimmed, origin: origin, in: context)
        refresh()

        settlingID = entry.id
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Motion.fastDuration) {
            settlingID = nil
        }
        ack = "saved \(DayFormat.timeOfDay(entry.at))"
        ackVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { ackVisible = false }

        ReminderManager.suppressTodayIfWritten(in: context)
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
            HStack(spacing: Tokens.Space.xs) {
                Text(DayFormat.timeOfDay(entry.at))
                    .typeMetaSmall()
                // The quiet arrival marker: "· spoken" / "· scanned" /
                // "· imported", in the capture rose. Meta register by hand —
                // the modifier's own color would override the accent.
                if !entry.origin.isEmpty {
                    Text("· \(entry.origin)")
                        .font(.custom(EndpaperFont.meta, size: 10))
                        .tracking(10 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Accent.capture)
                }
            }
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
