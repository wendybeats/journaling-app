// Settings — deliberately sparse, per the Stage 2 plan: the reminder row,
// the backup row, the intro replay, the export, and nothing else. Sync
// status is one mono meta line; no banners, no avatars, no cloud icons.

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppKeys.account) private var accountMode = ""

    @State private var reminderOn = ReminderManager.enabled
    @State private var reminderTime = Date()
    @State private var replaying = false
    @State private var exportURL: URL? = nil

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
                    }
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
                    Text(accountMode == AccountMode.icloud.rawValue
                         ? "Synced to your private iCloud · applies at next launch"
                         : "Saved on this device only")
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

                Text("Vellum — a placeholder name · no analytics, no tracking")
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
        .onAppear {
            let (h, m) = ReminderManager.chosenTime
            reminderTime = Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: .now) ?? .now
            exportURL = buildExport()
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
