// Share cards (1.0.4, v1): the two safe shareables — a line the writer
// chose, and the month as a constellation of dots. Both render in the
// brand's own kit grammar (drop cap, day stamp, the mono wordmark), so a
// shared card is indistinguishable from Endpaper's social content: every
// share is a quiet ad. Rendered off-screen at story-friendly 4:5.

import SwiftUI

enum ShareCard {
    /// 4:5 canvas, rendered @3x for stories and feeds.
    static let size = CGSize(width: 360, height: 450)

    @MainActor
    static func image<V: View>(_ card: V) -> Image {
        let renderer = ImageRenderer(content: card.frame(width: size.width, height: size.height))
        renderer.scale = 3
        if let ui = renderer.uiImage {
            return Image(uiImage: ui)
        }
        return Image(systemName: "square")   // unreachable in practice
    }
}

/// One chosen line on the page: huge first letter, the writing register,
/// the day it was written, the wordmark. Bone ground — the page itself.
struct LineCardView: View {
    let text: String
    let date: Date

    private var first: String { String(text.prefix(1)) }
    private var rest: String { String(text.dropFirst()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            (Text(first)
                .font(.custom(EndpaperFont.body, size: 64).weight(.medium))
             + Text(rest)
                .font(.custom(EndpaperFont.body, size: 26)))
                .foregroundStyle(Color(red: 0.086, green: 0.082, blue: 0.078))
                .lineSpacing(6)
                .lineLimit(12)
                .minimumScaleFactor(0.5)
            Spacer()
            HStack {
                Text("Written on \(DayFormat.dayHeading(date))")
                Spacer()
                Text("ENDPAPER.SPACE")
            }
            .font(.custom(EndpaperFont.meta, size: 9))
            .tracking(9 * 0.14)
            .textCase(.uppercase)
            .foregroundStyle(Color(red: 0.086, green: 0.082, blue: 0.078).opacity(0.5))
        }
        .padding(28)
        .background(Color(red: 0.91, green: 0.902, blue: 0.882))
    }
}

/// A month as its dots — no words, nothing private, just the shape of a
/// writing life. Char ground: the sealed register.
struct ConstellationCardView: View {
    let month: Int
    let year: Int
    let writtenDays: Set<Int>
    let dayCount: Int

    private let ink = Color(red: 0.91, green: 0.902, blue: 0.882)
    private let ground = Color(red: 0.086, green: 0.082, blue: 0.078)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            let columns = Array(repeating: GridItem(.fixed(18), spacing: 14), count: 7)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(1...dayCount, id: \.self) { day in
                    Circle()
                        .strokeBorder(ink.opacity(0.25), lineWidth: 1)
                        .background(Circle().fill(writtenDays.contains(day) ? ink : .clear))
                        .frame(width: 18, height: 18)
                }
            }
            Spacer()
            HStack(alignment: .lastTextBaseline) {
                Text("\(DayFormat.monthName(month)) \(String(year))")
                    .font(.custom(EndpaperFont.body, size: 30).weight(.medium))
                    .foregroundStyle(ink)
                Spacer()
                Text("ENDPAPER.SPACE")
                    .font(.custom(EndpaperFont.meta, size: 9))
                    .tracking(9 * 0.14)
                    .foregroundStyle(ink.opacity(0.5))
            }
        }
        .padding(28)
        .background(ground)
    }
}
