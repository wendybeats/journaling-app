// Calendar — dynamic by how much has been written (July 27 gameplan):
//   < 1 month of entries  → one big month calendar, nothing else
//   more months           → the year breakdown (twelve mini matrices)
//   a year or more        → the same view stacks year sections (the
//                           original web register — months over days)
// Click-in everywhere: year mini-matrix morphs into its month; the month's
// dots are large and tappable, each written day carrying a faint entry
// count; a day opens its page. matchedGeometryEffect carries the grid
// between registers so the journey year → month → day reads as one motion.

import SwiftUI
import SwiftData

private struct MonthRef: Hashable {
    let year: Int
    let month: Int
    var key: String { String(format: "%04d-%02d", year, month) }
}

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Namespace private var morph

    // "yyyy-MM" → day-of-month → entry count
    @State private var monthCounts: [String: [Int: Int]] = [:]
    @State private var years: [Int] = []
    @State private var openMonth: MonthRef? = nil
    @State private var singleMonthRoot = false   // < 1 month of entries: month IS the landing
    @State private var navigateDay: String? = nil
    @State private var wrappedSignal: YearlySignal? = nil

    var body: some View {
        ScrollView {
            Group {
                if let open = openMonth {
                    monthDetail(open)
                        .transition(.opacity)
                } else {
                    yearsList
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, Tokens.Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(Tokens.Motion.base, value: openMonth)
        }
        .background(Tokens.Surface.page)
        .navigationDestination(item: $navigateDay) { key in
            DayPageView(key: key)
        }
        .fullScreenCover(item: $wrappedSignal) { signal in
            WrappedView(signal: signal) { wrappedSignal = nil }
        }
        .onAppear(perform: load)
    }

    // MARK: - Year register (mini matrices; sections stack per year)

    private var yearsList: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            ForEach(years, id: \.self) { year in
                yearSection(year)
            }
        }
    }

    private func yearSection(_ year: Int) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Text(String(year)).typeMeta()
                Spacer()
                // The wrapped, replayable from the year view (spec §6)
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

            let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.md, alignment: .topLeading), count: 3)
            LazyVGrid(columns: columns, alignment: .leading, spacing: Tokens.Space.lg) {
                ForEach(1...12, id: \.self) { month in
                    let ref = MonthRef(year: year, month: month)
                    let written = writtenSet(ref)
                    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                        YearMonthMatrix(year: year, month: month, writtenDays: written)
                            .matchedGeometryEffect(id: ref.key, in: morph)
                        Text(DayFormat.monthAbbr(month)).typeMetaSmall()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !written.isEmpty || isCurrentMonth(ref) else { return }
                        withAnimation(Tokens.Motion.base) { openMonth = ref }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(DayFormat.monthName(month)) \(String(year)), \(written.count) days written")
                    .accessibilityAddTraits(written.isEmpty && !isCurrentMonth(ref) ? [] : .isButton)
                }
            }
        }
    }

    // MARK: - Month register (large tappable dots, faint entry counts)

    private func monthDetail(_ ref: MonthRef) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            if !singleMonthRoot {
                Button {
                    withAnimation(Tokens.Motion.base) { openMonth = nil }
                } label: {
                    Text("← \(String(ref.year))").typeMeta()
                }
                .buttonStyle(.plain)
            }

            Text("\(DayFormat.monthName(ref.month)) \(String(ref.year))")
                .typeTitle()

            BigMonthGrid(
                ref: ref,
                counts: monthCounts[ref.key] ?? [:],
                todayDay: todayDay(ref),
                onTapDay: { day in
                    navigateDay = String(format: "%04d-%02d-%02d", ref.year, ref.month, day)
                }
            )
            .matchedGeometryEffect(id: ref.key, in: morph)
        }
    }

    // MARK: - Data

    private func load() {
        var counts: [String: [Int: Int]] = [:]
        var yearSet = Set<Int>()
        for key in EntryStore.daysWithEntries(in: context) {
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { continue }
            let mk = String(format: "%04d-%02d", parts[0], parts[1])
            let dayEntries = EntryStore.entries(forDay: key, in: context).count
            counts[mk, default: [:]][parts[2]] = dayEntries
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
            openMonth = ref
        } else {
            singleMonthRoot = false
        }
    }

    private func writtenSet(_ ref: MonthRef) -> Set<Int> {
        Set((monthCounts[ref.key] ?? [:]).keys)
    }

    private func isCurrentMonth(_ ref: MonthRef) -> Bool {
        let c = Calendar.current.dateComponents([.year, .month], from: .now)
        return c.year == ref.year && c.month == ref.month
    }

    private func todayDay(_ ref: MonthRef) -> Int? {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return (c.year == ref.year && c.month == ref.month) ? c.day : nil
    }
}

/// The month register: large tappable dots, today enlarged with the ring,
/// written days carrying a faint entry count on the dot itself.
private struct BigMonthGrid: View {
    let ref: MonthRef
    let counts: [Int: Int]
    let todayDay: Int?
    var onTapDay: (Int) -> Void

    private var dayCount: Int {
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: ref.year, month: ref.month, day: 1))!
        return cal.range(of: .day, in: .month, for: date)!.count
    }

    var body: some View {
        let cell: CGFloat = 42
        let columns = Array(
            repeating: GridItem(.fixed(cell), spacing: Tokens.Space.xs),
            count: Tokens.DotSize.gridCols
        )
        LazyVGrid(columns: columns, spacing: Tokens.Space.sm) {
            ForEach(1...dayCount, id: \.self) { day in
                let count = counts[day] ?? 0
                let written = count > 0
                let isToday = day == todayDay
                let size: CGFloat = isToday ? 40 : 34

                ZStack {
                    Circle()
                        .fill(written ? Tokens.Dot.filled : Tokens.Dot.empty)
                        .frame(width: size, height: size)
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
                .frame(width: cell, height: cell)
                .contentShape(Rectangle())
                .onTapGesture { if written { onTapDay(day) } }
                .accessibilityLabel(dayLabel(day, count: count, isToday: isToday))
                .accessibilityAddTraits(written ? .isButton : [])
            }
        }
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