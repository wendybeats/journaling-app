// Same-day revision — the permanence boundary is the day, not the commit.
// Reached from a today-section's long-press menu; the sheet is the same
// living writing surface as the page, so revised lines re-classify their
// size exactly like written ones. After midnight the menu item is gone and
// the day is permanent (EntryStore.revise re-checks, so no stale sheet can
// slip an edit past the boundary).

import SwiftUI
import SwiftData

struct EditSessionSheet: View {
    let entry: Entry
    var onSaved: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var focused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Text("Cancel").typeMeta()
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    EntryStore.revise(entry, to: text, in: context)
                    onSaved?()
                    dismiss()
                } label: {
                    Text("Save").barPill()
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, Tokens.Space.lg)

            Text(DayFormat.timeOfDay(entry.at))
                .typeMetaSmall()
                .padding(.top, Tokens.Space.xl)

            ScrollView {
                LivingWriteView(text: $text, focused: $focused)
                    .padding(.top, Tokens.Space.md)
                    .padding(.bottom, Tokens.Space.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, Tokens.Space.screenX)
        .background(Tokens.Surface.page)
        .onAppear {
            text = entry.text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }
}
