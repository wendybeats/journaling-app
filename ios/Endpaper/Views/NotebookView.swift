// Notebook — the reverse-chronological reading view. Each day opens with a
// two-line drop cap (the web prototype measured Newsreader's metrics to make
// the cap exactly two text lines tall — 3.5em at the written size), a mono
// day stamp, and the day's writing. Archived reflections will rest at period
// boundaries here when the reflection layer ports (round 2).

import SwiftUI
import SwiftData

/// One scroll item: a written day, or an archived reflection resting at its
/// period boundary (between the period's last day and the next period).
private enum NotebookItem: Identifiable {
    case day(String)
    case reflection(ArchivedReflection)

    var id: String {
        switch self {
        case .day(let key): return "d-\(key)"
        case .reflection(let r): return "r-\(r.id)"
        }
    }
}

struct NotebookView: View {
    @Environment(\.modelContext) private var context
    @State private var items: [NotebookItem] = []
    @State private var presented: PresentedReflection? = nil

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.xxl) {
                if items.isEmpty {
                    Text("Nothing here yet. The page is waiting.")
                        .typeWritten()
                        .padding(.top, Tokens.Space.xl)
                }
                ForEach(items) { item in
                    switch item {
                    case .day(let key):
                        NotebookDay(key: key, entries: EntryStore.entries(forDay: key, in: context))
                    case .reflection(let reflection):
                        InlineReflectionRow(reflection: reflection) { open(reflection) }
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, Tokens.Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tokens.Surface.page)
        .fullScreenCover(item: $presented) { item in
            reflectionCover(item)
        }
        .onAppear(perform: load)
    }

    private func load() {
        // Merge days (newest first) with archived reflections at their
        // period boundaries: a reflection sorts by its boundary day and
        // wins the tie so it rests just above that day.
        var sortable: [(key: String, tie: Int, item: NotebookItem)] = []
        for key in EntryStore.daysWithEntries(in: context) {
            sortable.append((key, 0, .day(key)))
        }
        for reflection in ReflectionStore.shared.archived() {
            sortable.append((reflection.boundaryKey(), 1, .reflection(reflection)))
        }
        items = sortable
            .sorted { ($0.key, $0.tie) > ($1.key, $1.tie) }
            .map(\.item)
    }

    /// Tapping the condensed card reopens the full moment (idempotent —
    /// no re-rolls; the archived signal is shown as stored).
    private func open(_ reflection: ArchivedReflection) {
        switch reflection {
        case .weekly(let signal):
            presented = .weekly(signal)
        case .monthly(let signal):
            let corpus = ReflectionStore.corpus(from: context)
            presented = .monthly(signal, writtenDays: writtenDayNumbers(of: signal, corpus: corpus))
        }
    }

    @ViewBuilder
    private func reflectionCover(_ item: PresentedReflection) -> some View {
        switch item {
        case .weekly(let signal):
            WeeklyCardView(signal: signal) { presented = nil }
        case .monthly(let signal, let writtenDays):
            RecapView(signal: signal, writtenDays: writtenDays) { presented = nil }
        case .yearly(let signal):
            WrappedView(signal: signal) { presented = nil }
        }
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
                .font(.custom(EndpaperFont.body, size: 17 * 3.5))
                .foregroundStyle(Tokens.Text.written)
                .frame(height: 17 * 1.8 * 2, alignment: .top)   // exactly two text lines
                .offset(y: -17 * 0.35)                          // cap flush with the first line's top
            Text(rest)
                .typeWritten()
        }
    }
}
