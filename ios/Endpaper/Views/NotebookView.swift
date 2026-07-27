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

/// Two-line drop cap, truly nestled. One text engine does all the
/// wrapping: a UITextView with a TextKit exclusion path the size of the
/// cap, so the first two lines flow beside the initial and everything
/// after wraps beneath it at full width — no split-point math, no
/// measure-vs-render disagreement. The cap overlays the carved-out
/// corner, optically aligned cap-height to cap-height.
struct DropCapParagraph: View {
    let text: String

    var body: some View {
        let initial = String(text.prefix(1))
        let rest = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        let m = DropCapMetrics(initial: initial)

        DropCapBody(text: rest, metrics: m)
            .overlay(alignment: .topLeading) {
                Text(initial)
                    .font(.custom(EndpaperFont.body, size: m.capSize))
                    .foregroundStyle(Tokens.Text.written)
                    .fixedSize()
                    .offset(y: m.capOffsetY)
            }
            // VoiceOver reads the paragraph whole, not "L" then "ong day…"
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
    }
}

/// Shared font math for the drop cap. The cap is sized so its cap height
/// spans exactly from line 1's cap top to line 2's baseline — two written
/// lines — and offset so the tops align optically.
private struct DropCapMetrics {
    let bodyFont: UIFont
    let capFont: UIFont
    let capSize: CGFloat
    let lineGap: CGFloat        // written register: 17 × 1.8 minus natural line height
    let exclusion: CGRect       // the corner carved out of the text flow
    let capOffsetY: CGFloat

    init(initial: String) {
        let body = UIFont(name: EndpaperFont.body, size: 17) ?? .systemFont(ofSize: 17)
        bodyFont = body
        lineGap = max(0, 17 * 1.8 - body.lineHeight)
        let lineStep = body.lineHeight + lineGap

        // Cap height target: line 1 cap top → line 2 baseline.
        let target = lineStep + body.capHeight
        let size = 17 * target / body.capHeight
        capSize = size
        let cap = UIFont(name: EndpaperFont.body, size: size) ?? .systemFont(ofSize: size)
        capFont = cap

        let capWidth = (initial as NSString).size(withAttributes: [.font: cap]).width
        // Carve out lines 1–2 beside the cap; line 3 starts below the rect.
        exclusion = CGRect(x: 0, y: 0,
                           width: capWidth + Tokens.Space.sm,
                           height: lineStep + body.lineHeight - 1)

        // Align the cap glyph's top to line 1's cap top.
        let bodyCapTop = body.ascender - body.capHeight
        let capGlyphTop = cap.ascender - cap.capHeight
        capOffsetY = bodyCapTop - capGlyphTop
    }
}

private struct DropCapBody: UIViewRepresentable {
    let text: String
    let metrics: DropCapMetrics

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.isSelectable = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = metrics.lineGap
        tv.attributedText = NSAttributedString(string: text, attributes: [
            .font: metrics.bodyFont,
            .paragraphStyle: paragraph,
            .foregroundColor: UIColor(Tokens.Text.written),
        ])
        tv.textContainer.exclusionPaths = [UIBezierPath(rect: metrics.exclusion)]
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width - Tokens.Space.screenX * 2
        let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        // Never shorter than the cap itself (short first paragraphs).
        return CGSize(width: width, height: max(fit.height, metrics.exclusion.height))
    }
}
