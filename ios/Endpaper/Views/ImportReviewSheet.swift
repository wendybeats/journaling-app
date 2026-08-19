// The catch-point between recognition and permanence. Scanned and
// imported writing never commits sight-unseen: the extracted text lands
// here first — the same living writing surface as the page — so a
// misread word gets fixed (or the whole take discarded) before it
// becomes a section. Voice skips this sheet: a transcript was watched
// as it was spoken; a scan wasn't.

import SwiftUI

struct ImportReviewSheet: View {
    let origin: String            // "scanned" | "imported"
    let initialText: String
    var onCommit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var focused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Text("Discard").typeMeta()
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    onCommit(text)
                    dismiss()
                } label: {
                    Text("Add to page").barPill()
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, Tokens.Space.lg)

            HStack(spacing: Tokens.Space.xs) {
                Text(origin == "scanned" ? "Read from your photo" : "Read from your file")
                    .typeMetaSmall()
                Text("· fix anything it misread")
                    .font(.custom(EndpaperFont.meta, size: 10))
                    .tracking(10 * 0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Accent.capture)
            }
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
        .onAppear { text = initialText }
    }
}
