// Notebook — the reverse-chronological reading view. Each day opens with a
// two-line drop cap (the web prototype measured Newsreader's metrics to make
// the cap exactly two text lines tall — 3.5em at the written size), a mono
// day stamp, and the day's writing. Archived reflections will rest at period
// boundaries here when the reflection layer ports (round 2).

import SwiftUI
import SwiftData
import UIKit

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

/// Two-line drop cap, nestled: the initial sits vertically centered against
/// exactly two lines of text, and the remainder of the paragraph wraps
/// beneath at full width — the web prototype's treatment. TextKit measures
/// where the two-line split falls for the width beside the cap.
struct DropCapParagraph: View {
    let text: String

    private static let bodySize: CGFloat = 17
    private static let capSize: CGFloat = 17 * 3.5

    var body: some View {
        let initial = String(text.prefix(1))
        let rest = String(text.dropFirst())
        let (beside, below) = Self.splitForTwoLines(rest, initial: initial)

        VStack(alignment: .leading, spacing: Self.lineGap) {
            HStack(alignment: .center, spacing: Tokens.Space.sm) {
                Text(initial)
                    .font(.custom(EndpaperFont.body, size: Self.capSize))
                    .foregroundStyle(Tokens.Text.written)
                    .lineLimit(1)
                    .fixedSize()
                Text(beside)
                    .typeWritten()
                Spacer(minLength: 0)
            }
            if !below.isEmpty {
                Text(below)
                    .typeWritten()
            }
        }
        // VoiceOver reads the paragraph whole, not "L" then "ong day…"
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    /// The written register's inter-line gap (line height minus glyph line).
    private static var lineGap: CGFloat {
        let font = UIFont(name: EndpaperFont.body, size: bodySize) ?? .systemFont(ofSize: bodySize)
        return max(0, bodySize * 1.8 - font.lineHeight)
    }

    /// Splits `rest` at the word boundary where two laid-out lines end,
    /// given the width remaining beside the cap. Portrait-only app, so the
    /// screen width is a safe stand-in for the column.
    private static func splitForTwoLines(_ rest: String, initial: String) -> (String, String) {
        guard let bodyFont = UIFont(name: EndpaperFont.body, size: bodySize),
              let capFont = UIFont(name: EndpaperFont.body, size: capSize) else {
            return (rest, "")
        }
        let capWidth = (initial as NSString).size(withAttributes: [.font: capFont]).width
        let besideWidth = UIScreen.main.bounds.width - Tokens.Space.screenX * 2 - capWidth - Tokens.Space.sm
        guard besideWidth > 60 else { return (rest, "") }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineGap
        let storage = NSTextStorage(string: rest, attributes: [.font: bodyFont, .paragraphStyle: paragraph])
        let twoLines = bodyFont.lineHeight * 2 + lineGap + 1
        let container = NSTextContainer(size: CGSize(width: besideWidth, height: twoLines))
        container.lineFragmentPadding = 0
        container.lineBreakMode = .byWordWrapping
        let layout = NSLayoutManager()
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)

        let glyphRange = layout.glyphRange(for: container)
        let fit = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        guard fit.length < (rest as NSString).length else { return (rest, "") }

        let beside = (rest as NSString).substring(to: fit.upperBound)
        let below = (rest as NSString).substring(from: fit.upperBound)
        return (beside.trimmingCharacters(in: .whitespaces),
                below.trimmingCharacters(in: .whitespaces))
    }
}
