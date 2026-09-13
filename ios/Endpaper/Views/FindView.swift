// Find — the search register. The field sits centered and huge until the
// user types; the query shrinks as it grows (the web prototype's fit-to-
// width gesture, approximated with minimumScaleFactor), results grouped by
// day with the matches underlined. Reflections are excluded by construction:
// only entries are searched.

import SwiftUI
import SwiftData

struct FindView: View {
    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var openDay: String? = nil
    @State private var results: [DayHits] = []
    @State private var searchTask: Task<Void, Never>? = nil
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if query.isEmpty { Spacer() }   // centered until you type

            TextField("Find", text: $query)
                .font(.custom(EndpaperFont.heading, size: 44).weight(.medium))
                .minimumScaleFactor(0.25)   // starts huge, shrinks to fit
                .foregroundStyle(Tokens.Text.heading)
                .tint(Tokens.Line.cursor)
                .multilineTextAlignment(query.isEmpty ? .center : .leading)
                .focused($focused)
                .padding(.horizontal, Tokens.Space.screenX)
                .padding(.vertical, Tokens.Space.md)

            if query.isEmpty {
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Tokens.Space.lg) {
                        if results.isEmpty {
                            Text("Nothing found.").typeMeta()
                        }
                        // Every result clicks through to its day's page.
                        ForEach(results, id: \.day) { group in
                            Button {
                                openDay = group.day
                            } label: {
                                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                                    Text(DayFormat.dayMetaDate(DayFormat.date(fromKey: group.day)))
                                        .typeMeta()
                                    ForEach(Array(group.snippets.enumerated()), id: \.offset) { _, snippet in
                                        Text(highlighted(snippet))
                                            .typeWritten()
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            // Long-press copies the found block right here —
                            // no need to open the day just to grab the text.
                            // A single tap still opens the day as always.
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string =
                                        group.snippets.joined(separator: "\n\n")
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenX)
                    .padding(.bottom, Tokens.Space.xxl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(Tokens.Surface.page)
        // The field glides from centered to top as typing begins — no jump.
        .animation(Tokens.Motion.base, value: query.isEmpty)
        .navigationDestination(item: $openDay) { key in
            DayPageView(key: key)
        }
        .onAppear { focused = true }
        // Perf 2026-09-13: the search used to run inside body, on the main
        // thread, with one database fetch per day per keystroke (a seeded
        // year = ~300 fetches a character). Now: the cached notebook
        // snapshot, matched off-main after a short debounce.
        .onChange(of: query) { _, q in
            searchTask?.cancel()
            let corpus = ReflectionStore.corpus(from: context)
            searchTask = Task.detached(priority: .userInitiated) {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                let hits = Self.search(q, in: corpus)
                guard !Task.isCancelled else { return }
                await MainActor.run { results = hits }
            }
        }
    }

    private struct DayHits: Sendable {
        let day: String
        let snippets: [String]
    }

    /// At most this many matching paragraphs per day — a common word in a
    /// long day no longer renders every paragraph.
    private static let snippetCap = 3

    /// Pure: newest day first, paragraphs that contain the query.
    private static func search(_ raw: String, in corpus: Corpus) -> [DayHits] {
        let q = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }

        var hits: [DayHits] = []
        for day in corpus.byDay.keys.sorted(by: >) {
            var snippets: [String] = []
            for text in corpus.byDay[day] ?? [] {
                for sentence in text.components(separatedBy: "\n\n") where sentence.lowercased().contains(q) {
                    snippets.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
                    if snippets.count >= snippetCap { break }
                }
                if snippets.count >= snippetCap { break }
            }
            if !snippets.isEmpty { hits.append(DayHits(day: day, snippets: snippets)) }
        }
        return hits
    }

    /// Underline every occurrence of the query, case-insensitively.
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return attributed }

        var searchStart = attributed.startIndex
        while let range = attributed[searchStart...].range(of: q, options: .caseInsensitive) {
            attributed[range].underlineStyle = .single
            searchStart = range.upperBound
        }
        return attributed
    }
}
