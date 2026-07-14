// Notebook — the reverse-chronological reading view. Each day opens with a
// two-line drop cap (the web prototype measured Newsreader's metrics to make
// the cap exactly two text lines tall — 3.5em at the written size), a mono
// day stamp, and the day's writing. Archived reflections will rest at period
// boundaries here when the reflection layer ports (round 2).

import SwiftUI
import SwiftData

struct NotebookView: View {
    @Environment(\.modelContext) private var context
    @State private var days: [String] = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.xxl) {
                if days.isEmpty {
                    Text("Nothing here yet. The page is waiting.")
                        .typeWritten()
                        .padding(.top, Tokens.Space.xl)
                }
                ForEach(days, id: \.self) { key in
                    NotebookDay(key: key, entries: EntryStore.entries(forDay: key, in: context))
                }
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, Tokens.Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tokens.Surface.page)
        .onAppear { days = EntryStore.daysWithEntries(in: context) }
    }
}

struct NotebookDay: View {
    let key: String
    let entries: [Entry]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(DayFormat.dayMetaRow(DayFormat.date(fromKey: key), entries: entries, withMin: false))
                .typeMeta()

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                DayText(text: entry.text, dropCap: index == 0)
                    .padding(.top, index == 0 ? Tokens.Space.sm : Tokens.Space.lg)
            }
        }
    }
}

/// The day's writing; the first paragraph carries the two-line drop cap.
struct DayText: View {
    let text: String
    var dropCap = false

    var body: some View {
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, para in
                if dropCap && index == 0 {
                    DropCapParagraph(text: para)
                } else {
                    Text(para).typeWritten()
                }
            }
        }
    }
}

/// Two-line drop cap: the initial set at 3.5× the written size (the value
/// measured against Newsreader's metrics in the web prototype), the rest of
/// the paragraph wrapping beside then beneath it.
struct DropCapParagraph: View {
    let text: String

    var body: some View {
        let initial = String(text.prefix(1))
        let rest = String(text.dropFirst())

        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Text(initial)
                .font(.custom(VellumFont.body, size: 17 * 3.5))
                .foregroundStyle(Tokens.Text.written)
                .frame(height: 17 * 1.8 * 2, alignment: .top)   // exactly two text lines
                .offset(y: -17 * 0.35)                          // cap flush with the first line's top
            Text(rest)
                .typeWritten()
        }
    }
}
