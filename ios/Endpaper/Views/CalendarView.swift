// Calendar — round 1 of the choreography plan
// (docs/endpaper-calendar-choreography.md).
//
// Registers:
//   Year  — one piece, the original web layout: twelve rows (one per
//           month), 31 dot columns, single-letter month gutter. Years
//           stack; a row tap opens that month.
//   Month — vertically *paged*: each month fills the viewport with its
//           grid centered; swipe snaps month to month.
//   Day   — the read-only page.
//
// Every dot position comes from CalendarLayout — pure math shared by the
// resting views today and by the transition Stage in round 2, so the
// stage's capture/handoff can be pixel-identical by construction.
// Transitions are a plain crossfade until the Stage lands.

import SwiftUI
import SwiftData

private struct MonthRef: Hashable {
    let year: Int
    let month: Int
    var key: String { String(format: "%04d-%02d", year, month) }
}

// MARK: - Shared layout math (the Stage reuses this in round 2)

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
}

// MARK: - The calendar

struct CalendarView: View {
    @Environment(\.modelContext) private var context

    @State private var monthCounts: [String: [Int: Int]] = [:]
    @State private var years: [Int] = []
    @State private var anchor: MonthRef? = nil       // nil = year register
    @State private var singleMonthRoot = false
    @State private var pagedMonth: String? = nil
    @State private var navigateDay: String? = nil
    @State private var wrappedSignal: YearlySignal? = nil

    var body: some View {
        ZStack {
            if let a = anchor {
                monthPager(year: a.year)
                    .transition(.opacity)
            } else {
                yearRegister
                    .transition(.opacity)
            }
        }
        .animation(Tokens.Motion.base, value: anchor)
        .background(Tokens.Surface.page)
        .navigationDestination(item: $navigateDay) { key in
            DayPageView(key: key)
        }
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
                            onTapMonth: { month in open(MonthRef(year: year, month: month)) }
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

    // MARK: Month register — paged, one month per screen, grid centered

    private func monthPager(year: Int) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(1...12, id: \.self) { month in
                    let ref = MonthRef(year: year, month: month)
                    MonthPage(
                        ref: ref,
                        counts: monthCounts[ref.key] ?? [:],
                        todayDay: todayDay(ref),
                        onTapDay: { day in
                            navigateDay = String(format: "%04d-%02d-%02d", ref.year, ref.month, day)
                        }
                    )
                    .containerRelativeFrame(.vertical)
                    .id(ref.key)
                }
            }
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pagedMonth)
        .scrollIndicators(.hidden)
        .overlay(alignment: .topLeading) {
            if !singleMonthRoot {
                Button {
                    withAnimation(Tokens.Motion.base) { anchor = nil }
                } label: {
                    Text("← \(String(year))").typeMeta()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Tokens.Space.screenX)
                .padding(.top, Tokens.Space.md)
            }
        }
    }

    private func open(_ ref: MonthRef) {
        pagedMonth = ref.key
        withAnimation(Tokens.Motion.base) { anchor = ref }
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

        // The dynamic register: with less than a month of entries, the big
        // single month IS the calendar — no daunting empty year behind it.
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
            // Month gutter letters
            ForEach(1...12, id: \.self) { month in
                Text(Self.letters[month - 1])
                    .font(.custom(EndpaperFont.meta, size: 9))
                    .foregroundStyle(Tokens.Text.meta)
                    .position(x: 6, y: CGFloat(month - 1) * CalendarLayout.yearRowH + CalendarLayout.yearRowH / 2)
            }
            // The year's dots, positioned by the shared layout math
            ForEach(1...12, id: \.self) { month in
                let ref = String(format: "%04d-%02d", year, month)
                let monthDays = counts[ref] ?? [:]
                let dayCount = daysIn(year: year, month: month)
                ForEach(1...dayCount, id: \.self) { day in
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
            // Row-sized tap targets
            ForEach(1...12, id: \.self) { month in
                let written = (counts[String(format: "%04d-%02d", year, month)] ?? [:]).count
                let isCurrent = today.year == year && today.month == month
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: size.width, height: CalendarLayout.yearRowH)
                    .position(x: size.width / 2, y: CGFloat(month - 1) * CalendarLayout.yearRowH + CalendarLayout.yearRowH / 2)
                    .onTapGesture {
                        if written > 0 || isCurrent { onTapMonth(month) }
                    }
                    .accessibilityElement()
                    .accessibilityLabel("\(DayFormat.monthName(month)) \(String(year)), \(written) days written")
                    .accessibilityAddTraits(written > 0 || isCurrent ? .isButton : [])
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func daysIn(year: Int, month: Int) -> Int {
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        return cal.range(of: .day, in: .month, for: date)!.count
    }
}

// MARK: - Month page: viewport-filling, grid centered

private struct MonthPage: View {
    let ref: MonthRef
    let counts: [Int: Int]
    let todayDay: Int?
    var onTapDay: (Int) -> Void

    var body: some View {
        let dayCount = daysIn()
        GeometryReader { geo in
            let gridH = CalendarLayout.monthGridHeight(days: dayCount)
            let originY = (geo.size.height - gridH) / 2

            ZStack(alignment: .topLeading) {
                Text("\(DayFormat.monthName(ref.month)) \(String(ref.year))")
                    .typeTitle()
                    .position(x: geo.size.width / 2, y: originY - Tokens.Space.xl)

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

    private func daysIn() -> Int {
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: ref.year, month: ref.month, day: 1))!
        return cal.range(of: .day, in: .month, for: date)!.count
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

    var body: some View {
        let date = DayFormat.date(fromKey: key)
        let entries = EntryStore.entries(forDay: key, in: context)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
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