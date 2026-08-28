// Calendar — rounds 1–3 of the choreography plan
// (docs/endpaper-calendar-choreography.md).
//
// Registers (resting views, static):
//   Year  — one piece: twelve rows, 31 dot columns, month-letter gutter.
//   Month — vertically paged, one month per screen, grid centered.
//   Day   — the read-only page.
//
// The Stage (round 2): transitions between year and month mount a
// full-screen, page-colored overlay of explicitly positioned dots.
// The tapped month's dots are *travelers* — they fly from their year-row
// positions into the centered grid, growing 6→34, each on its own
// deterministic delay. Every other visible dot is *chaff* — it drifts
// ~90–160pt along a jittered radial vector away from the forming grid and
// dissolves. The register swap happens underneath the stage, so a flash
// is structurally impossible: the stage's first frame matches the old
// register, its last frame matches the new one, both computed from the
// same CalendarLayout math the resting views use.
//
// The survivor beat (round 3): month → day. The tapped day survives — it
// glides to screen center and grows while every other dot scatters and
// dissolves; after a held beat the stage fades and the day page is simply
// there beneath it. The day is presented in-place (not nav-pushed) so the
// reverse leg can fade the stage back in over the page and fly everything
// home to the month grid.

import SwiftUI
import SwiftData
import UIKit

private struct MonthRef: Hashable {
    let year: Int
    let month: Int
    var key: String { String(format: "%04d-%02d", year, month) }
}

/// A day opened from the month register — carried whole so the reverse
/// leg can rebuild the choreography without re-deriving anything.
private struct DayCtx: Equatable {
    let key: String
    let ref: MonthRef
    let day: Int
}

// MARK: - Shared layout math (resting views and the Stage both use this)

enum CalendarLayout {
    // Year register — one-piece block
    static let yearDot: CGFloat = 6
    static let yearGapX: CGFloat = 4.4
    static let yearRowH: CGFloat = 17
    static let yearGutter: CGFloat = 20

    static func yearDotCenter(month: Int, day: Int) -> CGPoint {
        CGPoint(
            x: yearGutter + CGFloat(day - 1) * (yearDot + yearGapX) + yearDot / 2,
            y: CGFloat(month - 1) * yearRowH + yearRowH / 2
        )
    }
    static var yearBlockSize: CGSize {
        CGSize(width: yearGutter + 31 * yearDot + 30 * yearGapX, height: 12 * yearRowH)
    }

    // Month register — centered grid
    static let monthCell: CGFloat = 46
    static let monthDot: CGFloat = 34
    static let monthDotToday: CGFloat = 40
    static let dayFocus: CGFloat = 48    // the survivor's size at screen center

    static func monthDotCenter(day: Int, in width: CGFloat) -> CGPoint {
        let col = (day - 1) % 7
        let row = (day - 1) / 7
        let gridW = 7 * monthCell
        let x0 = (width - gridW) / 2
        return CGPoint(
            x: x0 + CGFloat(col) * monthCell + monthCell / 2,
            y: CGFloat(row) * monthCell + monthCell / 2
        )
    }
    static func monthGridHeight(days: Int) -> CGFloat {
        CGFloat((days + 6) / 7) * monthCell
    }

    static func daysIn(year: Int, month: Int) -> Int {
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        return cal.range(of: .day, in: .month, for: date)!.count
    }
}

// MARK: - Frame reporting (year blocks tell the stage where they are)

private struct YearFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - The calendar

struct CalendarView: View {
    @Environment(\.modelContext) private var context

    @State private var monthCounts: [String: [Int: Int]] = [:]
    @State private var years: [Int] = []
    @State private var anchor: MonthRef? = nil       // nil = year register
    @State private var singleMonthRoot = false
    @State private var pagedMonth: String? = nil
    @State private var openDayCtx: DayCtx? = nil     // day presented in-place (round 3)
    @State private var wrappedSignal: YearlySignal? = nil

    // Stage state
    @State private var stageDots: [ChoreoDot]? = nil
    @State private var fly = false
    @State private var yearFrames: [Int: CGRect] = [:]
    @State private var containerSize: CGSize = .zero

    var body: some View {
        ZStack {
            if let a = anchor {
                monthPager(year: a.year)
            } else {
                yearRegister
            }
            // The day rides above the pager in-place, so the survivor beat
            // controls its arrival and departure (a nav push would slide
            // over the stage).
            if let d = openDayCtx {
                DayPageView(key: d.key, onBack: { closeDayLeg(d) })
                    .background(Tokens.Surface.page)
            }
            if let dots = stageDots {
                DotStage(dots: dots, fly: fly)
                    .transition(.opacity)
            }
        }
        .coordinateSpace(name: "cal")
        .background(
            GeometryReader { g in
                Color.clear.onAppear { containerSize = g.size }
                    .onChange(of: g.size) { _, s in containerSize = s }
            }
        )
        .onPreferenceChange(YearFrameKey.self) { yearFrames = $0 }
        .background(Tokens.Surface.page)
        .fullScreenCover(item: $wrappedSignal) { signal in
            WrappedView(signal: signal) { wrappedSignal = nil }
        }
        .onAppear(perform: load)
    }

    // MARK: Year register — one piece per year

    private var yearRegister: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                ForEach(years, id: \.self) { year in
                    VStack(alignment: .leading, spacing: Tokens.Space.md) {
                        HStack {
                            Text(String(year)).typeMeta()
                            Spacer()
                            if ReflectionStore.shared.consent == "yes" {
                                Button {
                                    let corpus = ReflectionStore.corpus(from: context)
                                    wrappedSignal = Reflect.yearlySignal(year: year, corpus: corpus)
                                } label: {
                                    Text("Your year →").typeMetaSmall()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        YearBlock(
                            year: year,
                            counts: monthCounts,
                            onTapMonth: { month in openMonth(MonthRef(year: year, month: month)) }
                        )
                        .background(
                            GeometryReader { g in
                                Color.clear.preference(key: YearFrameKey.self,
                                                       value: [year: g.frame(in: .named("cal"))])
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, Tokens.Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Month register — paged, one month per screen

    private func monthPager(year: Int) -> some View {
        ScrollViewReader { sp in
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(1...12, id: \.self) { month in
                    let ref = MonthRef(year: year, month: month)
                    MonthPage(
                        ref: ref,
                        counts: monthCounts[ref.key] ?? [:],
                        todayDay: todayDay(ref),
                        onTapDay: { day in openDayLeg(ref, day: day) },
                        onPageUp: month > 1 ? {
                            withAnimation(Tokens.Motion.base) {
                                pagedMonth = MonthRef(year: year, month: month - 1).key
                            }
                        } : nil,
                        onPageDown: month < 12 ? {
                            withAnimation(Tokens.Motion.base) {
                                pagedMonth = MonthRef(year: year, month: month + 1).key
                            }
                        } : nil
                    )
                    .containerRelativeFrame(.vertical)
                    .id(ref.key)
                }
            }
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pagedMonth)
        .scrollIndicators(.hidden)
        .onAppear {
            // LazyVStack ignores the initial scrollPosition binding, which
            // stranded every arrival on January. Assert the tapped month
            // the moment the pager mounts (it lands under the stage, so
            // the jump is never seen).
            if let key = pagedMonth ?? anchor?.key {
                sp.scrollTo(key, anchor: .top)
            }
        }
        .overlay(alignment: .topLeading) {
            if !singleMonthRoot {
                Button {
                    closeMonth(year: year)
                } label: {
                    Text("← \(String(year))").typeMeta()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Tokens.Space.screenX)
                .padding(.top, Tokens.Space.md)
            }
        }
        }   // ScrollViewReader
    }

    // MARK: The legs

    /// Year → Month: travelers fly into the forming grid; chaff scatters.
    private func openMonth(_ ref: MonthRef) {
        guard !UIAccessibility.isReduceMotionEnabled,
              let block = yearFrames[ref.year], containerSize != .zero else {
            pagedMonth = ref.key
            withAnimation(Tokens.Motion.base) { anchor = ref }
            return
        }

        let days = CalendarLayout.daysIn(year: ref.year, month: ref.month)
        let gridH = CalendarLayout.monthGridHeight(days: days)
        let gridTop = (containerSize.height - gridH) / 2
        let gridCenter = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let counts = monthCounts[ref.key] ?? [:]
        var dots: [ChoreoDot] = []

        // Travelers — the tapped month's dots
        for day in 1...days {
            let local = CalendarLayout.yearDotCenter(month: ref.month, day: day)
            let from = CGPoint(x: block.minX + local.x, y: block.minY + local.y)
            let toLocal = CalendarLayout.monthDotCenter(day: day, in: containerSize.width)
            let to = CGPoint(x: toLocal.x, y: gridTop + toLocal.y)
            dots.append(ChoreoDot(
                id: "t-\(day)", from: from, to: to,
                fromSize: CalendarLayout.yearDot, toSize: CalendarLayout.monthDot,
                toOpacity: 1, filled: counts[day] != nil,
                duration: Choreo.travel, delay: Choreo.delay(day)
            ))
        }

        // Chaff — every other visible year dot drifts away and dissolves
        for (year, frame) in yearFrames {
            for month in 1...12 where !(year == ref.year && month == ref.month) {
                let mCounts = monthCounts[String(format: "%04d-%02d", year, month)] ?? [:]
                for day in 1...CalendarLayout.daysIn(year: year, month: month) {
                    let local = CalendarLayout.yearDotCenter(month: month, day: day)
                    let from = CGPoint(x: frame.minX + local.x, y: frame.minY + local.y)
                    guard from.y > -20, from.y < containerSize.height + 20 else { continue }
                    let seed = day * 131 + month * 17 + year
                    dots.append(ChoreoDot(
                        id: "c-\(year)-\(month)-\(day)", from: from,
                        to: Choreo.scatter(seed: seed, from: from, center: gridCenter),
                        fromSize: CalendarLayout.yearDot, toSize: CalendarLayout.yearDot * 0.6,
                        toOpacity: 0, filled: mCounts[day] != nil,
                        duration: Choreo.chaff, delay: Choreo.delay(seed)
                    ))
                }
            }
        }

        runStage(dots) {
            pagedMonth = ref.key
            anchor = ref            // swap happens under the stage
        }
    }

    /// Month → Year: travelers shrink home; chaff flies back in (reversed).
    private func closeMonth(year: Int) {
        guard !UIAccessibility.isReduceMotionEnabled,
              let currentKey = pagedMonth ?? anchor?.key,
              containerSize != .zero else {
            withAnimation(Tokens.Motion.base) { anchor = nil }
            return
        }
        let parts = currentKey.split(separator: "-").compactMap { Int($0) }
        let ref = parts.count == 2 ? MonthRef(year: parts[0], month: parts[1]) : MonthRef(year: year, month: 1)

        // Swap to the year register first (under the stage), then read the
        // block's landed frame on the next runloop tick and fly home.
        let days = CalendarLayout.daysIn(year: ref.year, month: ref.month)
        let gridH = CalendarLayout.monthGridHeight(days: days)
        let gridTop = (containerSize.height - gridH) / 2
        let gridCenter = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let counts = monthCounts[ref.key] ?? [:]

        // Mount the stage frozen on the month grid so the swap is covered.
        var holding: [ChoreoDot] = []
        for day in 1...days {
            let local = CalendarLayout.monthDotCenter(day: day, in: containerSize.width)
            let from = CGPoint(x: local.x, y: gridTop + local.y)
            holding.append(ChoreoDot(
                id: "t-\(day)", from: from, to: from,
                fromSize: CalendarLayout.monthDot, toSize: CalendarLayout.monthDot,
                toOpacity: 1, filled: counts[day] != nil,
                duration: Choreo.travel, delay: 0
            ))
        }
        stageDots = holding
        fly = false
        anchor = nil                 // year register mounts beneath

        // Two hops: the year register lays out on the first, its frame
        // preference lands by the second — then we fly to fresh coordinates.
        DispatchQueue.main.async { DispatchQueue.main.async {
            guard let block = yearFrames[ref.year] else {
                stageDots = nil
                return
            }
            var dots: [ChoreoDot] = []
            for day in 1...days {
                let local = CalendarLayout.monthDotCenter(day: day, in: containerSize.width)
                let from = CGPoint(x: local.x, y: gridTop + local.y)
                let toLocal = CalendarLayout.yearDotCenter(month: ref.month, day: day)
                let to = CGPoint(x: block.minX + toLocal.x, y: block.minY + toLocal.y)
                dots.append(ChoreoDot(
                    id: "t-\(day)", from: from, to: to,
                    fromSize: CalendarLayout.monthDot, toSize: CalendarLayout.yearDot,
                    toOpacity: 1, filled: counts[day] != nil,
                    duration: Choreo.travel, delay: Choreo.delay(day)
                ))
            }
            // Chaff returns: other visible dots fade back IN from scattered
            // positions to their year spots.
            for (y, frame) in yearFrames {
                for month in 1...12 where !(y == ref.year && month == ref.month) {
                    let mCounts = monthCounts[String(format: "%04d-%02d", y, month)] ?? [:]
                    for day in 1...CalendarLayout.daysIn(year: y, month: month) {
                        let local = CalendarLayout.yearDotCenter(month: month, day: day)
                        let to = CGPoint(x: frame.minX + local.x, y: frame.minY + local.y)
                        guard to.y > -20, to.y < containerSize.height + 20 else { continue }
                        let seed = day * 131 + month * 17 + y
                        dots.append(ChoreoDot(
                            id: "c-\(y)-\(month)-\(day)",
                            from: Choreo.scatter(seed: seed, from: to, center: gridCenter),
                            to: to,
                            fromSize: CalendarLayout.yearDot * 0.6, toSize: CalendarLayout.yearDot,
                            toOpacity: 1, filled: mCounts[day] != nil,
                            duration: Choreo.chaff, delay: Choreo.delay(seed)
                        ))
                    }
                }
            }
            // Returning chaff starts invisible-ish: model by starting from
            // scattered position at small size; opacity animates 1→1, so
            // fade-in is approximated by the size/position arrival.
            stageDots = dots
            DispatchQueue.main.async { fly = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + Choreo.total) {
                stageDots = nil
                fly = false
            }
        } }   // second hop closes here (see the two-hop note above)
    }

    /// Month → Day (round 3, the survivor beat): the tapped day is the
    /// *survivor* — every other dot scatters and dissolves while it glides
    /// to screen center and grows a step. It holds a beat, then the stage
    /// fades out and the day page is simply there beneath it, the survivor
    /// dissolving into the top of the text.
    private func openDayLeg(_ ref: MonthRef, day: Int) {
        let ctx = DayCtx(
            key: String(format: "%04d-%02d-%02d", ref.year, ref.month, day),
            ref: ref, day: day
        )
        guard !UIAccessibility.isReduceMotionEnabled, containerSize != .zero else {
            withAnimation(Tokens.Motion.base) { openDayCtx = ctx }
            return
        }

        let days = CalendarLayout.daysIn(year: ref.year, month: ref.month)
        let gridH = CalendarLayout.monthGridHeight(days: days)
        let gridTop = (containerSize.height - gridH) / 2
        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let counts = monthCounts[ref.key] ?? [:]
        let today = todayDay(ref)
        func restSize(_ d: Int) -> CGFloat {
            d == today ? CalendarLayout.monthDotToday : CalendarLayout.monthDot
        }
        func gridPoint(_ d: Int) -> CGPoint {
            let local = CalendarLayout.monthDotCenter(day: d, in: containerSize.width)
            return CGPoint(x: local.x, y: gridTop + local.y)
        }

        var dots: [ChoreoDot] = []
        dots.append(ChoreoDot(
            id: "s-\(day)", from: gridPoint(day), to: center,
            fromSize: restSize(day), toSize: CalendarLayout.dayFocus,
            toOpacity: 1, filled: true,
            duration: Choreo.travel, delay: 0
        ))
        for d in 1...days where d != day {
            let from = gridPoint(d)
            let seed = d * 131 + 7
            dots.append(ChoreoDot(
                id: "c-\(d)", from: from,
                to: Choreo.scatter(seed: seed, from: from, center: center),
                fromSize: restSize(d), toSize: restSize(d) * 0.6,
                toOpacity: 0, filled: counts[d] != nil,
                duration: Choreo.chaff, delay: Choreo.delay(seed)
            ))
        }

        stageDots = dots
        fly = false
        openDayCtx = ctx             // day mounts beneath the opaque stage
        DispatchQueue.main.async { fly = true }
        // Survivor lands, holds a beat, then the whole stage — page color
        // and dot together — fades, revealing the page beneath.
        DispatchQueue.main.asyncAfter(deadline: .now() + Choreo.travel + 0.12) {
            withAnimation(.easeOut(duration: 0.22)) { stageDots = nil }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { fly = false }
        }
    }

    /// Day → Month: the reverse beat. The stage fades in over the page —
    /// the survivor reappearing at center, the scattered field small and
    /// waiting — then everything flies home to the month grid.
    private func closeDayLeg(_ d: DayCtx) {
        guard !UIAccessibility.isReduceMotionEnabled, containerSize != .zero else {
            withAnimation(Tokens.Motion.base) { openDayCtx = nil }
            return
        }

        let ref = d.ref
        let days = CalendarLayout.daysIn(year: ref.year, month: ref.month)
        let gridH = CalendarLayout.monthGridHeight(days: days)
        let gridTop = (containerSize.height - gridH) / 2
        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let counts = monthCounts[ref.key] ?? [:]
        let today = todayDay(ref)
        func restSize(_ n: Int) -> CGFloat {
            n == today ? CalendarLayout.monthDotToday : CalendarLayout.monthDot
        }
        func gridPoint(_ n: Int) -> CGPoint {
            let local = CalendarLayout.monthDotCenter(day: n, in: containerSize.width)
            return CGPoint(x: local.x, y: gridTop + local.y)
        }

        var dots: [ChoreoDot] = []
        dots.append(ChoreoDot(
            id: "s-\(d.day)", from: center, to: gridPoint(d.day),
            fromSize: CalendarLayout.dayFocus, toSize: restSize(d.day),
            toOpacity: 1, filled: true,
            duration: Choreo.travel, delay: 0
        ))
        for n in 1...days where n != d.day {
            let home = gridPoint(n)
            let seed = n * 131 + 7
            dots.append(ChoreoDot(
                id: "c-\(n)",
                from: Choreo.scatter(seed: seed, from: home, center: center),
                to: home,
                fromSize: restSize(n) * 0.6, toSize: restSize(n),
                toOpacity: 1, filled: counts[n] != nil,
                duration: Choreo.chaff, delay: Choreo.delay(seed)
            ))
        }

        fly = false
        withAnimation(.easeIn(duration: 0.15)) { stageDots = dots }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            openDayCtx = nil          // page unmounts under the opaque stage
            pagedMonth = ref.key
            DispatchQueue.main.async { fly = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + Choreo.total) {
                stageDots = nil       // last frame matches the month register
                fly = false
            }
        }
    }

    private func runStage(_ dots: [ChoreoDot], swap: @escaping () -> Void) {
        stageDots = dots
        fly = false
        swap()
        DispatchQueue.main.async { fly = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + Choreo.total) {
            stageDots = nil
            fly = false
        }
    }

    // MARK: Data

    private func load() {
        var counts: [String: [Int: Int]] = [:]
        var yearSet = Set<Int>()
        for key in EntryStore.daysWithEntries(in: context) {
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { continue }
            let mk = String(format: "%04d-%02d", parts[0], parts[1])
            counts[mk, default: [:]][parts[2]] = EntryStore.entries(forDay: key, in: context).count
            yearSet.insert(parts[0])
        }
        let now = Calendar.current.dateComponents([.year, .month], from: .now)
        yearSet.insert(now.year!)
        monthCounts = counts
        years = yearSet.sorted(by: >)

        if counts.keys.count <= 1 {
            let ref = counts.keys.first
                .flatMap { k -> MonthRef? in
                    let p = k.split(separator: "-").compactMap { Int($0) }
                    return p.count == 2 ? MonthRef(year: p[0], month: p[1]) : nil
                } ?? MonthRef(year: now.year!, month: now.month!)
            singleMonthRoot = true
            anchor = ref
            pagedMonth = ref.key
        } else {
            singleMonthRoot = false
        }
    }

    private func todayDay(_ ref: MonthRef) -> Int? {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return (c.year == ref.year && c.month == ref.month) ? c.day : nil
    }
}

// MARK: - Year block: twelve rows, 31 columns, one object

private struct YearBlock: View {
    let year: Int
    let counts: [String: [Int: Int]]
    var onTapMonth: (Int) -> Void

    private static let letters = ["J","F","M","A","M","J","J","A","S","O","N","D"]

    var body: some View {
        let size = CalendarLayout.yearBlockSize
        let cal = Calendar.current
        let today = cal.dateComponents([.year, .month, .day], from: .now)

        ZStack(alignment: .topLeading) {
            ForEach(1...12, id: \.self) { month in
                Text(Self.letters[month - 1])
                    .font(.custom(EndpaperFont.meta, size: 9))
                    .foregroundStyle(Tokens.Text.meta)
                    .position(x: 6, y: CGFloat(month - 1) * CalendarLayout.yearRowH + CalendarLayout.yearRowH / 2)
            }
            ForEach(1...12, id: \.self) { month in
                let ref = String(format: "%04d-%02d", year, month)
                let monthDays = counts[ref] ?? [:]
                ForEach(1...CalendarLayout.daysIn(year: year, month: month), id: \.self) { day in
                    let isToday = today.year == year && today.month == month && today.day == day
                    Circle()
                        .fill(monthDays[day] != nil ? Tokens.Dot.filled : Tokens.Dot.empty)
                        .frame(width: CalendarLayout.yearDot, height: CalendarLayout.yearDot)
                        .overlay {
                            if isToday {
                                Circle()
                                    .strokeBorder(Tokens.Dot.today, lineWidth: 1)
                                    .padding(-2)
                            }
                        }
                        .position(CalendarLayout.yearDotCenter(month: month, day: day))
                }
            }
            ForEach(1...12, id: \.self) { month in
                let written = (counts[String(format: "%04d-%02d", year, month)] ?? [:]).count
                // Every month row is a touch target — tapping July lands on
                // July; an accidental adjacent month is one swipe away.
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: size.width, height: CalendarLayout.yearRowH)
                    .position(x: size.width / 2, y: CGFloat(month - 1) * CalendarLayout.yearRowH + CalendarLayout.yearRowH / 2)
                    .onTapGesture { onTapMonth(month) }
                    .accessibilityElement()
                    .accessibilityLabel("\(DayFormat.monthName(month)) \(String(year)), \(written) days written")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Month page: viewport-filling, grid centered

private struct MonthPage: View {
    let ref: MonthRef
    let counts: [Int: Int]
    let todayDay: Int?
    var onTapDay: (Int) -> Void
    var onPageUp: (() -> Void)? = nil
    var onPageDown: (() -> Void)? = nil

    var body: some View {
        let dayCount = CalendarLayout.daysIn(year: ref.year, month: ref.month)
        GeometryReader { geo in
            let gridH = CalendarLayout.monthGridHeight(days: dayCount)
            let originY = (geo.size.height - gridH) / 2

            ZStack(alignment: .topLeading) {
                Text("\(DayFormat.monthName(ref.month)) \(String(ref.year))")
                    .typeTitle()
                    // Share v1 (1.0.4): long-press the month name for the
                    // constellation card — the month as dots, nothing
                    // private, in the sealed register.
                    .contextMenu {
                        ShareLink(
                            item: ShareCard.image(constellationCard),
                            preview: SharePreview("\(DayFormat.monthName(ref.month)) \(String(ref.year))",
                                                  image: ShareCard.image(constellationCard))
                        ) {
                            Label("Share this month", systemImage: "square.and.arrow.up")
                        }
                    }
                    .position(x: geo.size.width / 2, y: originY - Tokens.Space.xl)

                // Quiet paging affordances — typographic arrows in the meta
                // register at the container edges; tap pages, swipe still works.
                if let onPageUp {
                    Button(action: onPageUp) {
                        Text("↑").typeMeta()
                    }
                    .buttonStyle(.plain)
                    .position(x: geo.size.width / 2, y: Tokens.Space.xl)
                    .accessibilityLabel("Previous month")
                }
                if let onPageDown {
                    Button(action: onPageDown) {
                        Text("↓").typeMeta()
                    }
                    .buttonStyle(.plain)
                    .position(x: geo.size.width / 2, y: geo.size.height - Tokens.Space.lg)
                    .accessibilityLabel("Next month")
                }

                ForEach(1...dayCount, id: \.self) { day in
                    let count = counts[day] ?? 0
                    let written = count > 0
                    let isToday = day == todayDay
                    let dotSize = isToday ? CalendarLayout.monthDotToday : CalendarLayout.monthDot
                    let center = CalendarLayout.monthDotCenter(day: day, in: geo.size.width)

                    ZStack {
                        Circle()
                            .fill(written ? Tokens.Dot.filled : Tokens.Dot.empty)
                            .overlay {
                                if isToday {
                                    Circle()
                                        .strokeBorder(Tokens.Dot.today, lineWidth: Tokens.DotSize.todayRing)
                                        .padding(-(Tokens.DotSize.todayRing + Tokens.DotSize.todayRingOffset))
                                }
                            }
                        if written {
                            Text("\(count)")
                                .font(.custom(EndpaperFont.meta, size: 9))
                                .foregroundStyle(Tokens.Text.onInverted.opacity(0.75))
                        }
                    }
                    .frame(width: dotSize, height: dotSize)
                    .frame(width: CalendarLayout.monthCell, height: CalendarLayout.monthCell)
                    .contentShape(Rectangle())
                    .position(x: center.x, y: originY + center.y)
                    .onTapGesture { if written { onTapDay(day) } }
                    .accessibilityLabel(dayLabel(day, count: count, isToday: isToday))
                    .accessibilityAddTraits(written ? .isButton : [])
                }
            }
        }
    }

    private var constellationCard: ConstellationCardView {
        ConstellationCardView(
            month: ref.month,
            year: ref.year,
            writtenDays: Set(counts.filter { $0.value > 0 }.keys),
            dayCount: CalendarLayout.daysIn(year: ref.year, month: ref.month)
        )
    }

    private func dayLabel(_ day: Int, count: Int, isToday: Bool) -> String {
        var label = "\(DayFormat.monthName(ref.month)) \(day)"
        if isToday { label += ", today" }
        if count > 0 { label += ", \(count) \(count == 1 ? "entry" : "entries")" }
        return label
    }
}

/// A past day, read-only — the page as it was.
struct DayPageView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let key: String
    /// When presented in-place by the calendar's survivor beat, back runs
    /// the reverse choreography instead of a navigation pop.
    var onBack: (() -> Void)? = nil

    var body: some View {
        let date = DayFormat.date(fromKey: key)
        let entries = EntryStore.entries(forDay: key, in: context)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        if let onBack { onBack() } else { dismiss() }
                    } label: {
                        Text("← Back").typeMeta()
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.top, Tokens.Space.sm)

                Text(DayFormat.dayHeading(date))
                    .typeDisplay()
                    .padding(.top, Tokens.Space.xl)
                Text(DayFormat.dayMetaRow(date, entries: entries, withMin: false))
                    .typeMeta()
                    .padding(.top, Tokens.Space.sm)
                Rectangle()
                    .fill(Tokens.Line.rule)
                    .frame(height: Tokens.lineWeight)
                    .padding(.top, Tokens.Space.md)

                VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                    ForEach(entries, id: \.id) { entry in
                        EntrySection(entry: entry)
                    }
                }
                .padding(.top, Tokens.Space.lg)
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tokens.Surface.page)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}