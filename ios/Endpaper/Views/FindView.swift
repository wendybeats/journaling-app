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
    @FocusState private var focused: Bool

    var body: some View {
        let results = search()

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
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenX)
                    .padding(.bottom, Tokens.Space.xxl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(Tokens.Surface.page)
        .navigationDestination(item: $openDay) { key in
            DayPageView(key: key)
        }
        .onAppear { focused = true }
    }

    private struct DayHits {
        let day: String
        let snippets: [String]
    }

    private func search() -> [DayHits] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }

        var hits: [DayHits] = []
        for day in EntryStore.daysWithEntries(in: context) {
            var snippets: [String] = []
            for entry in EntryStore.entries(forDay: day, in: context) {
                for sentence in entry.text.components(separatedBy: "\n\n") {
                    if sentence.lowercased().contains(q) {
                        snippets.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
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
