// Archive — one surface, three registers: Notebook (reading), Calendar
// (dots), Find (search). The tabs are words in the mono register, never
// icons, matching the web prototype's Notebook / Calendar / Find row.

import SwiftUI

enum ArchiveTab: String, CaseIterable {
    case notebook = "Notebook"
    case calendar = "Calendar"
    case find = "Find"
}

struct ArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tab: ArchiveTab = .notebook
    @State private var seedStamp = 0   // bumping re-mounts the tab content after seeding

    var body: some View {
        VStack(spacing: 0) {
            // The crumb — a bare word in the mono register (.crumb in the web
            // prototype), never a system back pill.
            HStack {
                Button { dismiss() } label: {
                    Text("← Today").typeMeta()
                }
                .buttonStyle(.plain)
                Spacer()
                NavigationLink {
                    SettingsView()
                } label: {
                    Text("Settings").typeMeta()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.top, Tokens.Space.sm)

            HStack(spacing: Tokens.Space.md) {
                ForEach(ArchiveTab.allCases, id: \.self) { t in
                    Button {
                        withAnimation(Tokens.Motion.base) { tab = t }
                    } label: {
                        Text(t.rawValue)
                            .typeMeta()
                            .foregroundStyle(tab == t ? Tokens.Text.written : Tokens.Text.meta)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, Tokens.Space.md)

            Group {
                switch tab {
                case .notebook: NotebookView()
                case .calendar: CalendarView()
                case .find: FindView()
                }
            }
            .id(seedStamp)

            if AppEnv.demoControls {
                DebugSeedFooter { seedStamp += 1 }
            }
        }
        .background(Tokens.Surface.page)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

/// The prototype's footer control, iOS edition — demo data so testers can
/// exercise the calendar, reflections, and search without a year of writing.
/// DEBUG + TestFlight only; App Store builds never show it. Clear removes
/// only the seeded batch — real entries are untouchable.
private struct DebugSeedFooter: View {
    @Environment(\.modelContext) private var context
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.lg) {
            Button {
                DebugSeed.seed(in: context)
                onChange()
            } label: {
                Text("Seed demo").typeMetaSmall()
            }
            .buttonStyle(.plain)
            Button {
                DebugSeed.clear(in: context)
                onChange()
            } label: {
                Text("Clear demo").typeMetaSmall()
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.screenX)
        .padding(.vertical, Tokens.Space.sm)
    }
}
