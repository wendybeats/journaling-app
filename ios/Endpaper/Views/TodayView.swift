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
    @AppStorage(AppKeys.draftStart) private var draftStart = ""

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
    @State private var pendingImport: PendingImport?
    @State private var barStamp = 0
    @State private var hookDone = false     // the first-word moment has played (or doesn't apply)
    @State private var dateShrunk = false   // heading resting at "Sep 5" (QA 2026-09-06: 5s after typing)
    @State private var shrinkArmed = false
    @StateObject private var flow = ReflectionFlow()
    @State private var hookSeated = false
    @State private var hookWord = ""
    @State private var hookSeatScale: CGFloat = 1
    @State private var glimpse: GlimpseSignal? = nil   // today's lit word, if any (Glimpse.swift)
    @State private var glimpseSheet = false
    @State private var glimpseEntryID: UUID? = nil
    @State private var editorGlimpseForms: [String]? = nil

    struct PendingImport: Identifiable {
        let id = UUID()
        let text: String
        let origin: String
    }

    private let now = Date()
    private var key: String { DayFormat.key(for: now) }

    /// "3 entries · 4 min" — the old meta row minus its date.
    private var entriesMeta: String {
        let words = todayEntries.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
        let mins = max(1, Int((Double(words) / 200).rounded()))
        return "\(todayEntries.count) \(todayEntries.count == 1 ? "entry" : "entries") · \(mins) min"
    }

    /// The resting countdown under the date (1.0.4).
    private var countdownLine: String {
        switch ReflectionCadence.daysUntilReflection(now: now) {
        case 0: return "Reflection today"
        case 1: return "Reflection tomorrow"
        case let n: return "Reflection in \(n) days"
        }
    }

    /// The first week's ghost questions — deliberately charged (pain,
    /// jealousy, guilt, excitement; Wendell 2026-08-28). Nil from day
    /// eight on, and nil once anything is written today.
    private static let ghostPrompts = [
        "What's taking up space in your head right now?",
        "Who are you jealous of — and of what, exactly?",
        "What hurt more than you let on?",
        "What do you feel guilty about that nobody knows?",
        "What are you secretly excited about?",
        "What did you almost say out loud today?",
        "What would you write if no one could ever read it?",
    ]

    private var ghostPrompt: String? {
        guard todayEntries.isEmpty else { return nil }
        guard let firstKey = UserDefaults.standard.string(forKey: AppKeys.firstDay) else { return nil }
        let days = Calendar.current.dateComponents(
            [.day], from: DayFormat.date(fromKey: firstKey), to: now).day ?? 0
        guard (0..<Self.ghostPrompts.count).contains(days) else { return nil }
        return Self.ghostPrompts[days]
    }

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

                // Five seconds after the day's first words, the heading
                // steps back to "Sep 5" — 30% smaller, smoothly — and
                // stays there (QA 2026-09-06). scaleEffect keeps the
                // shrink continuous (font sizes can't tween); the frame
                // height animates the layout below it closed.
                Text(dateShrunk ? DayFormat.shortDay(now) : DayFormat.dayHeading(now))
                    .typeDisplay()
                    .contentTransition(.opacity)
                    .scaleEffect(dateShrunk ? 0.7 : 1, anchor: .topLeading)
                    .frame(height: dateShrunk ? 25 : 36, alignment: .topLeading)
                    .animation(Tokens.Motion.base, value: dateShrunk)
                    .padding(.top, Tokens.Space.xl)

                // No repeated date here any more — just the day's tally,
                // and only once there is one.
                if !todayEntries.isEmpty {
                    Text(entriesMeta)
                        .typeMeta()
                        .padding(.top, Tokens.Space.sm)
                }

                // The week's destination, resting under the date — the same
                // line the daily arrival held large (1.0.4 retention pair),
                // with the reflections motif in miniature beside it.
                if ReflectionStore.shared.reflectionsOn {
                    HStack(spacing: Tokens.Space.xs + 2) {
                        Text(countdownLine).typeMetaSmall()
                        ReflectMark()
                    }
                    .padding(.top, Tokens.Space.xs)
                }

                Rectangle()
                    .fill(Tokens.Line.rule)
                    .frame(height: Tokens.lineWeight)
                    .padding(.top, Tokens.Space.md)

                // The day's committed sections
                VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                    ForEach(todayEntries, id: \.id) { entry in
                        EntrySection(entry: entry, onEdited: { refresh() },
                                     glimpse: entry.id == glimpseEntryID ? glimpse?.forms : nil,
                                     onGlimpseTap: openGlimpse)
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

                // The page's cards (reflections / reminder / rating). One
                // card rests inline; more than one becomes a horizontal
                // sliding set (QA 2026-09-06) — never a vertical stack,
                // and every card carries its own no/later.
                let cardCount = flow.cards.count
                    + (reminderOffer ? 1 : 0) + (reviewOffer ? 1 : 0)
                if cardCount > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: Tokens.Space.md) {
                            ReflectionCards(flow: flow, carousel: true)
                            if reminderOffer {
                                ReminderCard()
                                    .containerRelativeFrame(.horizontal)
                            }
                            if reviewOffer {
                                ReviewAskCard()
                                    .containerRelativeFrame(.horizontal)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollClipDisabled()
                    .padding(.top, Tokens.Space.xl)
                } else {
                    ReflectionCards(flow: flow, carousel: false)
                        .padding(.top, Tokens.Space.xl)
                    if reminderOffer {
                        ReminderCard()
                            .padding(.top, Tokens.Space.xl)
                    }
                    if reviewOffer {
                        ReviewAskCard()
                            .padding(.top, Tokens.Space.xl)
                    }
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
        // barStamp forces the inset to re-install after a navigation
        // round-trip — QA 8-20 hit a state where the keyboard returned but
        // the bar never re-anchored above it (Archive → seed → back).
        .safeAreaInset(edge: .bottom) { writingBar.id(barStamp) }
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
        } message: {
            Text("Works best with printed or neatly written text. You'll review before it lands.")
        }
        .sheet(item: $pendingImport) { pending in
            ImportReviewSheet(origin: pending.origin, initialText: pending.text) { final in
                commitCaptured(final, origin: pending.origin)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: DailyArrival.finished)) { _ in
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                flow.showArrivalIfDue()
            }
        }
        .fullScreenCover(item: $flow.presented) { item in
            switch item {
            case .weekly(let signal):
                WeeklyCardView(signal: signal) { flow.presented = nil }
            case .monthly(let signal, let writtenDays):
                RecapView(signal: signal, writtenDays: writtenDays) { flow.presented = nil }
            case .yearly(let signal):
                WrappedView(signal: signal) { flow.presented = nil }
            }
        }
        // The locked monthly's full-screen moment (QA 2026-09-05): the
        // recap opener's own design carrying the offer, join or dismiss.
        .fullScreenCover(item: $flow.monthlyGate) { monthly in
            MonthlyGateView(signal: monthly) {
                flow.joinedFromGate(monthly)
            } onClose: {
                flow.monthlyGate = nil
            }
        }
        .sheet(item: $flow.arrival) { a in
            ArrivalSheet(arrival: a) {
                flow.readFromArrival(a)
            } onLater: {
                flow.arrival = nil
            }
        }
        .sheet(isPresented: $glimpseSheet) {
            if let g = glimpse {
                GlimpseSheet(signal: g) {
                    GlimpseStore.shared.acknowledge()
                    glimpse = nil
                    glimpseSheet = false
                }
            }
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
            barStamp += 1
            adoptStaleDraft()
            refresh()
            // The hook plays only for the day's true first words: skip it
            // when entries exist or a restored draft is already past its
            // first word (returning mid-thought must not replay it).
            if !todayEntries.isEmpty
                || draft.drop(while: \.isWhitespace).contains(where: \.isWhitespace) {
                hookDone = true
            } else {
                advanceHook(with: draft)   // a restored single word resumes at center
            }
            reminderOffer = ReminderManager.shouldOfferPrompt(in: context)
            reviewOffer = ReviewAskState.eligible(in: context) && !reminderOffer
            // refresh() above already evaluated the cards on ONE corpus
            // fetch. The arrival sheet rises once the day's splash has
            // cleared — or right away when there was none.
            if flow.arrivalDue, !DailyArrival.playing {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    flow.showArrivalIfDue()
                }
            }
            // The heading rests short whenever the day already has words.
            if !todayEntries.isEmpty { dateShrunk = true }
            else if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { armDateShrink() }
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

    // One uniform row: actions (REC, UPLOAD) lead, Done trails. No
    // overlay — the old centered-group-plus-trailing-Done collided on
    // smaller devices (QA 8-20, iPhone 15).
    private var writingBar: some View {
        HStack(spacing: Tokens.Space.sm) {
            RecPill(recording: voice.isRecording) {
                guard !takingVoice else { return }
                // The keyboard stands down while the mic is up — one
                // writer at a time. Voice never touches the draft: the
                // take lives on the card and commits as its own section.
                writingFocused = false
                voice.start()
            }
            // Import capture is held back from production for now — the
            // handwriting expectation isn't ready for the people who'd
            // reach for it first (decided 2026-08-20). TestFlight and
            // debug builds keep it so the flow stays tested; everything
            // behind it ships dormant.
            if AppEnv.demoControls {
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
            Spacer()
            // Done hides while recording — only one control may look like
            // it stops the take.
            if writingFocused && !takingVoice {
                Button {
                    writingFocused = false
                } label: {
                    Text("Done").barPill()
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(takingVoice ? 0 : 1)
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

    /// The day's first moment runs the hook (QA 2026-09-05): the ghost
    /// question sits centered so the reader types over it; their first
    /// word renders large and centered (the editor types concealed
    /// underneath); on the first space it travels to its seat at the
    /// top-left and the real text is revealed.
    private var hookMode: Bool { todayEntries.isEmpty && !hookDone }

    private var writingSurface: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    // First week: a provocative ghost question seeds the
                    // page (1.0.4). It vanishes on the first keystroke and
                    // retires for good after day seven — never a template,
                    // just a door. From day eight: the plain invitation.
                    // In hook mode it rests centered with the brand's
                    // rule-cursor blinking beside it — the "you can type
                    // here" the centered layout was missing (QA 2026-09-05).
                    if hookMode {
                        // The cursor sits centered BENEATH the question —
                        // where the first word will land — not beside a
                        // two-line block, where it read as right-aligned
                        // (QA 2026-09-08).
                        VStack(spacing: Tokens.Space.md) {
                            Text(ghostPrompt ?? "Write. This page is yours.")
                                .font(ghostPrompt == nil
                                      ? .custom(EndpaperFont.body, size: 28)
                                      : .custom(EndpaperFont.body, size: 22).italic())
                                .lineSpacing(ghostPrompt == nil ? 0 : 9)
                                .foregroundStyle(Tokens.Text.meta)
                                .multilineTextAlignment(.center)
                            BlinkingCursor(height: 30)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .allowsHitTesting(false)
                    } else {
                        Text(ghostPrompt ?? (todayEntries.isEmpty ? "Write. This page is yours." : "Write."))
                            .font(ghostPrompt == nil
                                  ? .custom(EndpaperFont.body, size: 28)
                                  : .custom(EndpaperFont.body, size: 22).italic())
                            .lineSpacing(ghostPrompt == nil ? 0 : 9)
                            .foregroundStyle(Tokens.Text.meta)
                            .allowsHitTesting(false)
                    }
                }
                LivingWriteView(text: $draft, focused: $writingFocused,
                                concealed: hookMode,
                                glimpseForms: editorGlimpseForms,
                                onGlimpseTap: openGlimpse)
                // The overlay word — what the reader sees themselves type,
                // rule-cursor riding its right edge until it seats. Same
                // animation family as the prompt choreography.
                if hookMode, !hookWord.isEmpty {
                    HStack(alignment: .center, spacing: 8) {
                        Text(hookWord)
                            .font(.custom(EndpaperFont.body, size: 40))
                            .foregroundStyle(Tokens.Text.written)
                        if !hookSeated {
                            BlinkingCursor(height: 42)
                        }
                    }
                    .scaleEffect(hookSeated ? hookSeatScale : 1, anchor: .topLeading)
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity,
                           alignment: hookSeated ? .topLeading : .center)
                    .allowsHitTesting(false)
                }
            }
            .frame(minHeight: hookMode ? 230 : nil, alignment: .topLeading)
            .animation(Tokens.Motion.base, value: hookDone)
            // The editor's own hit area hugs its (small) text — the whole
            // region must take the tap, especially with the centered ghost
            // (QA 2026-09-06: "hard to select").
            .contentShape(Rectangle())
            .onTapGesture { writingFocused = true }
            .onChange(of: draft) { _, text in
                draftDay = key
                idleCommit?.cancel()
                advanceHook(with: text)
                syncGlimpse()
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                armDateShrink()
                // Stamp the session's start on the first real words — the
                // committed section sorts by when writing BEGAN, so a
                // voice note taken mid-draft lands after these words.
                if draftStart.isEmpty {
                    draftStart = ISO8601DateFormatter().string(from: .now)
                }
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

    /// Five seconds after the first words land, the heading steps back —
    /// long enough to not distract from the act of starting (QA 2026-09-06).
    private func armDateShrink() {
        guard !dateShrunk, !shrinkArmed else { return }
        shrinkArmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(Tokens.Motion.base) { dateShrunk = true }
        }
    }

    /// The first space (or newline) after the first word seats it: the
    /// overlay travels from center to the top-left at the living-type
    /// size the line will actually render at, then the concealed editor
    /// is revealed underneath and the overlay leaves.
    private func advanceHook(with text: String) {
        guard hookMode else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            hookWord = ""
            return
        }
        hookWord = String(trimmed.split(whereSeparator: \.isWhitespace).first ?? "")
        let body = text.drop(while: \.isWhitespace)
        guard !hookSeated, body.contains(where: \.isWhitespace) else { return }
        hookSeatScale = WrittenFormat.large / 40
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.45)) { hookSeated = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            hookDone = true
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
                // Recognition is fallible (handwriting especially) — the
                // words pause on a review sheet before they become a
                // section. Committing happens there, never sight-unseen.
                ackVisible = false
                pendingImport = PendingImport(text: text, origin: origin)
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
        let started = ISO8601DateFormatter().date(from: draftStart) ?? .now
        let entry = EntryStore.commit(text, at: started, lastAt: .now, in: context)
        draft = ""
        draftDay = ""
        draftStart = ""
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
        draftStart = ""
    }

    private func refresh() {
        todayEntries = EntryStore.entries(forDay: key, in: context)
        // The glimpse re-evaluates whenever the page's committed text
        // changes — it can only light a word that is on today's page.
        // ONE corpus fetch feeds the glimpse, the cards and the notes
        // (perf 2026-09-12).
        let corpus = ReflectionStore.corpus(from: context)
        GlimpseStore.shared.prime(corpus: corpus, todayKey: key)
        syncGlimpse()
        flow.evaluate(corpus: corpus)
        Task { @MainActor in await ReminderManager.rearmReflectionNotes(corpus: corpus) }
    }

    /// The glimpse over the primed week plus the live draft — runs on
    /// every keystroke (cheap: only the draft is re-read). The wash lives
    /// in the editor while the draft holds the word, else on the latest
    /// committed section that does.
    private func syncGlimpse() {
        glimpse = GlimpseStore.shared.evaluate(draft: draft, todayKey: key)
        guard let g = glimpse else {
            editorGlimpseForms = nil
            glimpseEntryID = nil
            return
        }
        if Glimpse.lastRange(of: g.forms, in: draft) != nil {
            editorGlimpseForms = g.forms
            glimpseEntryID = nil
        } else {
            editorGlimpseForms = nil
            glimpseEntryID = todayEntries.last { Glimpse.lastRange(of: g.forms, in: $0.text) != nil }?.id
        }
    }

    private func openGlimpse() {
        guard glimpse != nil else { return }
        Analytics.track(.earlyInsightOpened)
        glimpseSheet = true
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
    /// The glimpse (1.0.4): surface forms of the word that keeps coming
    /// back — its last occurrence in this section lights up and taps.
    var glimpse: [String]? = nil
    var onGlimpseTap: (() -> Void)? = nil

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
            // The simplified grammar (WrittenFormat, QA 2026-09-06): first
            // word large, measured first line medium, body after, bullets
            // italic — one concatenated Text so mixed sizes share a line.
            if let forms = glimpse {
                WashedTextView(text: entry.text, forms: forms, onTap: onGlimpseTap)
                    .accessibilityHint("A word that keeps coming back. Tap it.")
            } else {
                WrittenFormat.text(for: entry.text)
                    .typeWrittenScaled(WrittenFormat.body)
                    .textSelection(.enabled)
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
            // The styled card (1.0.4 share v1): the section as a kit-grammar
            // image — drop cap, day stamp, wordmark. The writer chose to
            // share it, so the words are consented by definition.
            ShareLink(
                item: ShareCard.image(LineCardView(text: entry.text, date: entry.at)),
                preview: SharePreview("Endpaper card",
                                      image: ShareCard.image(LineCardView(text: entry.text, date: entry.at)))
            ) {
                Label("Share as card", systemImage: "square.text.square")
            }
        }
        .sheet(isPresented: $editing) {
            EditSessionSheet(entry: entry) { onEdited?() }
        }
    }

    private var shareText: String {
        "\(DayFormat.dayHeading(entry.at)) · \(DayFormat.timeOfDay(entry.at))\n\n\(entry.text)"
    }

}

/// The reflections motif in miniature — one outlined circle, one filled,
/// overlapping — sitting beside the countdown in the same meta tone
/// (QA 2026-09-05).
private struct ReflectMark: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Tokens.Text.meta, lineWidth: 1)
                .frame(width: 11, height: 11)
                .offset(x: -3.5)
            Circle()
                .fill(Tokens.Text.meta.opacity(0.9))
                .frame(width: 11, height: 11)
                .offset(x: 3.5)
        }
        .frame(width: 19, height: 11)
        .accessibilityHidden(true)
    }
}

/// The brand's rule-cursor — the thin vertical line from the quote
/// Reels' type-on frames — blinking beside whatever invites typing
/// (QA 2026-09-05: the centered ghost needed a visible affordance).
private struct BlinkingCursor: View {
    var height: CGFloat = 24
    @State private var dimmed = false

    var body: some View {
        Rectangle()
            .fill(Tokens.Line.cursor)
            .frame(width: 1.5, height: height)
            .opacity(dimmed ? 0.08 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
            .accessibilityHidden(true)
    }
}
