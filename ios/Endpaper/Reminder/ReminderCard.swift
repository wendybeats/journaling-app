// The reminder pre-prompt — a quiet in-system card on Today, shown after
// two written days. The system permission dialog is never the first touch;
// it only ever follows the card's yes. A no is remembered and never re-asked.

import SwiftUI
import SwiftData

struct ReminderCard: View {
    @Environment(\.modelContext) private var context
    @State private var answered = false

    var body: some View {
        if answered { EmptyView() } else {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("A morning nudge?")
                    .typeTitle()
                Text("Want a nudge each morning? One line, once a day.")
                    .typeWritten()
                HStack(spacing: Tokens.Space.lg) {
                    Button {
                        withAnimation(Tokens.Motion.base) { answered = true }
                        Task { await ReminderManager.accepted(in: context) }
                    } label: {
                        Text("Yes, 8:00 AM").typeMeta().foregroundStyle(Tokens.Text.written)
                    }
                    Button {
                        withAnimation(Tokens.Motion.base) { answered = true }
                        ReminderManager.declined()
                    } label: {
                        Text("No thanks").typeMeta()
                    }
                }
            }
            .padding(Tokens.Space.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.Surface.raised, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
        }
    }
}
