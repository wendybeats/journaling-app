// Settings — deliberately sparse, per the Stage 2 plan: the reminder row,
// the backup row, the intro replay, the export, and nothing else. Sync
// status is one mono meta line; no banners, no avatars, no cloud icons.

import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppKeys.account) private var accountMode = ""

    @AppStorage(AppKeys.faceLock) private var faceLock = false
    @State private var reminderOn = ReminderManager.enabled
    @State private var reminderTime = Date()
    @State private var editsCloseOn = ReminderManager.editsCloseEnabled
    @State private var reflectionsOn = ReflectionStore.shared.consent == "yes"
    @State private var replaying = false
    @State private var exportURL: URL? = nil
    @State private var syncLine = ""
    @State private var redeeming = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                HStack {
                    Button { dismiss() } label: {
                        Text("← Back").typeMeta()
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.top, Tokens.Space.sm)

                Text("Settings").typeDisplay()

                // --- One reminder, each morning ---
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Toggle(isOn: $reminderOn) {
                        Text("One reminder, each morning").typeWritten()
                    }
                    .tint(Tokens.Surface.inverted)
                    .onChange(of: reminderOn) { _, on in
                        Task { await ReminderManager.setEnabled(on, in: context) }
                    }
                    if reminderOn {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .onChange(of: reminderTime) { _, time in
                                let c = Calendar.current.dateComponents([.hour, .minute], from: time)
                                ReminderManager.setChosenTime(hour: c.hour ?? 8, minute: c.minute ?? 0)
                                Task { await ReminderManager.rearm(in: context) }
                            }
                        Text("Skipped on days you've already written")
                            .typeMetaSmall()

                        Toggle(isOn: $editsCloseOn) {
                            Text("A last call at 11 PM").typeWritten()
                        }
                        .tint(Tokens.Surface.inverted)
                        .padding(.top, Tokens.Space.sm)
                        .onChange(of: editsCloseOn) { _, on in
                            Task { await ReminderManager.setEditsCloseEnabled(on) }
                        }
                        Text("Anything else from today? Edits end at midnight")
                            .typeMetaSmall()
                    }
                }

                rule

                // --- Reflections ---
                // The same consent the in-page card asks for, revisitable.
                // Off means silence: no weekly card, no monthly recap, no
                // January invite. Already-archived reflections stay in the
                // Notebook — they're part of the record.
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Toggle(isOn: $reflectionsOn) {
                        Text("Reflections").typeWritten()
                    }
                    .tint(Tokens.Surface.inverted)
                    .onChange(of: reflectionsOn) { _, on in
                        ReflectionStore.shared.setConsent(on ? "yes" : "no")
                    }
                    Text("Your week and month, in your own words — always private")
                        .typeMetaSmall()
                }

                rule

                // --- Back up your notebook ---
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Toggle(isOn: Binding(
                        get: { accountMode == AccountMode.icloud.rawValue },
                        set: { accountMode = ($0 ? AccountMode.icloud : AccountMode.local).rawValue }
                    )) {
                        Text("Back up with iCloud").typeWritten()
                    }
                    .tint(Tokens.Surface.inverted)
                    Text(syncLine)
                        .typeMetaSmall()
                }

                rule

                // --- Face ID lock ---
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Toggle(isOn: $faceLock) {
                        Text("Lock with Face ID").typeWritten()
                    }
                    .tint(Tokens.Surface.inverted)
                    Text("Asks whenever the app returns")
                        .typeMetaSmall()
                }

                rule

                // --- Export ---
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Text("Export your notebook").typeWritten()
                        }
                    } else {
                        Text("Export your notebook").typeWritten().opacity(0.4)
                    }
                    Text("Plain text, yours to keep").typeMetaSmall()
                }

                rule

                // --- Intro replay ---
                Button { replaying = true } label: {
                    Text("Show the introduction again").typeWritten()
                }
                .buttonStyle(.plain)

                rule

                // --- Founding / offer codes ---
                // Redeemable before the paywall ever appears, so a founding
                // member's year starts on day one, not day eight.
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Button { redeeming = true } label: {
                        Text("Redeem a code").typeWritten()
                    }
                    .buttonStyle(.plain)
                    Text("Founding-member and gift codes")
                        .typeMetaSmall()
                }

                rule

                Text("Endpaper · no analytics, no tracking")
                    .typeMetaSmall()
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.bottom, Tokens.Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tokens.Surface.page)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $replaying) {
            OnboardingView(replay: true) { replaying = false }
        }
        .offerCodeRedemption(isPresented: $redeeming)
        .onAppear {
            let (h, m) = ReminderManager.chosenTime
            reminderTime = Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: .now) ?? .now
            exportURL = buildExport()
            refreshSyncLine()
        }
        .onChange(of: accountMode) { _, _ in refreshSyncLine() }
    }

    /// The one quiet meta line the sync status is allowed (stage-2 plan
    /// §1.2): never a banner, never on the page. ubiquityIdentityToken is
    /// the crash-safe signal — nil when iCloud is signed out, restricted,
    /// or the entitlement is absent in this build.
    private func refreshSyncLine() {
        guard accountMode == AccountMode.icloud.rawValue else {
            syncLine = "Saved on this device only — deleting the app deletes the notebook"
            return
        }
        if FileManager.default.ubiquityIdentityToken != nil {
            syncLine = "Synced to your private iCloud · applies at next launch"
        } else {
            syncLine = "iCloud unavailable — saved on this device for now"
        }
    }

    private var rule: some View {
        Rectangle().fill(Tokens.Line.rule).frame(height: Tokens.lineWeight)
    }

    /// The whole notebook as one Markdown file — day-headed, sessions
    /// time-stamped, oldest first. The writing is the user's; this is the door.
    private func buildExport() -> URL? {
        var out = "# Notebook\n"
        for key in EntryStore.daysWithEntries(in: context).reversed() {
            let date = DayFormat.date(fromKey: key)
            out += "\n## \(DayFormat.dayHeading(date)), \(Calendar.current.component(.year, from: date))\n"
            for entry in EntryStore.entries(forDay: key, in: context) {
                out += "\n*\(DayFormat.timeOfDay(entry.at))*\n\n\(entry.text)\n"
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notebook.md")
        do {
            try out.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
