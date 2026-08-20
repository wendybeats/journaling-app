// Reflection engine (R1+R2) — the Swift port of js/reflect.js, the
// deterministic stand-in for the two-stage pipeline in
// docs/endpaper-reflection-spec.md. It only surfaces what the entries
// literally contain: topics need repeated mentions, every quote is a
// verbatim sentence, tone words must be the user's own, difficulty needs
// explicit textual evidence, and thin periods get silence (weekly) or the
// honest quiet variant (monthly) — never a reach.
//
// Port rule: same thresholds, same ordering, same quote-dedupe passes as
// the JS engine. One deliberate deviation: JS relies on stable sort +
// insertion order for ties; Swift's sort is not stable, so every ranking
// carries an explicit alphabetical tiebreak. Both engines stay
// deterministic; ties may order differently between them.

import Foundation

// MARK: - Signal types (Codable — archived reflections persist whole)

struct RQuote: Codable, Hashable {
    var text: String
    var day: String   // day key "2026-07-05"
}

struct WeeklySignal: Codable {
    struct Topic: Codable {
        var word: String
        var mentions: Int
        var days: Int
    }
    // 1.0.2 deck beats — all optional: archived signals from older builds
    // decode with them absent, and a nil beat simply doesn't render
    // (the silence rule, for free).
    struct Shape: Codable {
        var bucket: String    // "morning" | "afternoon" | "evening" | "late"
        var days: Int         // written days in the dominant bucket
        var total: Int        // written days that had session times
    }
    struct Sitting: Codable {
        var seconds: Int
        var day: String
        var words: Int
    }
    var id: String        // "w-2026-06-29"
    var startKey: String
    var days: Int
    var words: Int
    var sufficient: Bool
    var topic: Topic?
    var quotes: [RQuote]
    var writtenKeys: [String]? = nil   // for the deck's seven-dot row
    var shape: Shape? = nil
    var bigLine: RQuote? = nil         // the week's largest written line
    var question: RQuote? = nil        // a verbatim "?" sentence
    var sitting: Sitting? = nil        // longest single session
}

struct MonthlySignal: Codable {
    struct Topic: Codable {
        var stem: String
        var word: String
        var mentions: Int
        var days: Int
        var quotes: [RQuote]
    }
    struct Tone: Codable {
        var word: String
        var count: Int
    }
    // 1.0.2 sequence beats — optional for the same decode-compat and
    // silence-rule reasons as the weekly fields.
    struct Turn: Codable {
        var from: String      // first-half tone leader
        var to: String        // second-half tone leader
    }
    struct Person: Codable {
        var name: String
        var days: Int
    }
    struct Rhythm: Codable {
        var weekdayCounts: [Int]   // written days per weekday, Sunday-first
        var peakWeekday: Int       // 0 = Sunday
        var bucket: String?        // dominant writing time, when times exist
    }
    var id: String        // "m-2026-06"
    var year: Int
    var month: Int        // 1-based (JS is 0-based; the id format matches)
    var days: Int
    var words: Int
    var longestRun: Int
    var sufficient: Bool
    var topics: [Topic]
    var tone: Tone?
    var difficult: [RQuote]
    var opened: RQuote? = nil      // first sentence of the month
    var closed: RQuote? = nil      // last sentence of the month
    var turn: Turn? = nil          // tone leader changed mid-month
    var people: [Person]? = nil    // recurring proper names
    var rhythm: Rhythm? = nil
    var spokenCount: Int? = nil    // sections that arrived by voice
}

struct YearlySignal: Codable {
    struct Topic: Codable {
        var stem: String
        var word: String
        var mentions: Int
        var days: Int
    }
    struct Reveal: Codable {
        var topic: Topic
        var first: RQuote
    }
    var id: String        // "y-2026"
    var year: Int
    var days: Int
    var words: Int
    var entries: Int
    var longestRun: Int
    var sufficient: Bool
    var topics: [Topic]
    var reveal: Reveal?
    var writtenKeys: Set<String>
}

// `id` properties above satisfy Identifiable — used by fullScreenCover(item:).
extension WeeklySignal: Identifiable {}
extension MonthlySignal: Identifiable {}
extension YearlySignal: Identifiable {}

/// One session with its timing and arrival — the raw material for the
/// time-shaped signals (writing hour, longest sitting, spoken count).
/// The JS reference corpus carries no timestamps, so these signals are
/// Swift-only and stay out of the parity comparison.
struct RSession {
    let text: String
    let at: Date
    let lastAt: Date
    let origin: String
}

/// The corpus the engine reads: day key → session texts in time order.
/// Built once per evaluation from the SwiftData store.
struct Corpus {
    let byDay: [String: [String]]
    var sessions: [String: [RSession]] = [:]

    func has(_ key: String) -> Bool {
        !(byDay[key] ?? []).isEmpty
    }

    /// (day, text) pairs for the given keys, day order then session order —
    /// the same iteration order as the JS engine's `all`.
    func entries(forDays keys: [String]) -> [(day: String, text: String)] {
        keys.filter(has).flatMap { k in (byDay[k] ?? []).map { (k, $0) } }
    }
}

// MARK: - The engine

enum Reflect {

    // Words that can never be a "topic" — function words plus journal
    // furniture, plus generic descriptors (true but never a thread worth
    // mirroring). Verbatim from js/reflect.js.
    static let stopwords: Set<String> = Set(("the a an and or but if then than that this these those i me my mine we our you your it its " +
        "is are was were be been being am do does did doing have has had having not no yes of in on at by for with about into " +
        "over under again more most other some such only own same so too very just there here when where why how what which who " +
        "whom will would can could should may might must shall out up down off before after above below between through during " +
        "each few both all any nor as from to because while until once now today yesterday tomorrow day days week thing things " +
        "time way one two three still even also around never always keep kept feel felt like really them they he she his her " +
        "him hers itself myself something anything nothing everything went going gone got get " +
        "long short good great bad better best hard easy small little big first last much many made make come came back " +
        "right different actually finally really quite maybe almost enough every another other instead though although " +
        "however anyway anymore toward towards besides without within less least most fewer").split(separator: " ").map(String.init))

    /// Runs of [a-z'] in the lowercased text, apostrophe-suffix stripped
    /// ("boat's" → "boat"), ≥4 letters, non-stopword. ASCII only, like the
    /// JS regex — a curly apostrophe splits the token in both engines.
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty {
                let word = String(current.prefix(while: { $0 != "'" }))
                if word.count >= 4 && !stopwords.contains(word) { tokens.append(word) }
                current = ""
            }
        }
        for ch in text.lowercased() {
            if (ch >= "a" && ch <= "z") || ch == "'" {
                current.append(ch)
            } else {
                flush()
            }
        }
        flush()
        return tokens
    }

    /// Light stem so "mornings" and "morning" count as one thread.
    static func stem(_ word: String) -> String {
        word.hasSuffix("s") && !word.hasSuffix("ss") ? String(word.dropLast()) : word
    }

    /// Split into sentences after [.?!]+whitespace or at newlines —
    /// the JS `/(?<=[.?!])\s+|\n+/` split, hand-rolled.
    static func sentences(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\n" {
                out.append(current)
                current = ""
                while i < chars.count && chars[i] == "\n" { i += 1 }
                continue
            }
            current.append(c)
            if (c == "." || c == "?" || c == "!"),
               i + 1 < chars.count, chars[i + 1].isWhitespace {
                out.append(current)
                current = ""
                i += 1
                while i < chars.count && chars[i].isWhitespace && chars[i] != "\n" { i += 1 }
                continue
            }
            i += 1
        }
        out.append(current)
        return out.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    // MARK: Week geometry

    /// Sunday that starts the last fully completed week.
    static func lastCompletedWeekStart(now: Date = .now, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: day)   // 1 = Sunday
        return calendar.date(byAdding: .day, value: -(weekday - 1) - 7, to: day)!
    }

    static func weekDayKeys(start: Date, calendar: Calendar = .current) -> [String] {
        (0..<7).map { DayFormat.key(for: calendar.date(byAdding: .day, value: $0, to: start)!) }
    }

    // MARK: Weekly

    /// Stage 1 over one week; `sufficient == false` means the week stays silent.
    static func weeklySignal(start: Date, corpus: Corpus, calendar: Calendar = .current) -> WeeklySignal {
        let keys = weekDayKeys(start: start, calendar: calendar)
        let writtenDays = keys.filter(corpus.has)
        let all = corpus.entries(forDays: keys)
        let words = all.reduce(0) { $0 + wordCount($1.text) }
        let sufficient = writtenDays.count >= 3 && words >= 300

        // Candidate topics: a stem needs ≥3 mentions spread over ≥2 days;
        // ≥3 distinct days wins outright.
        var counts: [String: (count: Int, days: Set<String>, display: String)] = [:]
        for entry in all {
            for raw in tokenize(entry.text) {
                let s = stem(raw)
                var c = counts[s] ?? (0, [], raw)
                c.count += 1
                c.days.insert(entry.day)
                counts[s] = c
            }
        }
        let candidates = counts
            .filter { $0.value.days.count >= 3 || ($0.value.count >= 3 && $0.value.days.count >= 2) }
            .sorted {
                ($0.value.days.count, $0.value.count) != ($1.value.days.count, $1.value.count)
                    ? ($0.value.days.count, $0.value.count) > ($1.value.days.count, $1.value.count)
                    : $0.key < $1.key
            }

        var topic: WeeklySignal.Topic? = nil
        var quotes: [RQuote] = []
        if let best = candidates.first {
            // One verbatim sentence per day the topic appears, oldest first,
            // max 3. Never quote the same sentence twice — repetition across
            // days is the observation, not the evidence.
            var seenDays = Set<String>()
            var seenText = Set<String>()
            for entry in all {
                if seenDays.contains(entry.day) || seenDays.count >= 3 { continue }
                if let hit = sentences(entry.text).first(where: { line in
                    tokenize(line).map(stem).contains(best.key) && !seenText.contains(line)
                }) {
                    quotes.append(RQuote(text: hit, day: entry.day))
                    seenDays.insert(entry.day)
                    seenText.insert(hit)
                }
            }
            topic = WeeklySignal.Topic(word: best.value.display, mentions: best.value.count, days: best.value.days.count)
        }

        let startKey = DayFormat.key(for: start)
        var signal = WeeklySignal(id: "w-\(startKey)", startKey: startKey,
                                  days: writtenDays.count, words: words,
                                  sufficient: sufficient, topic: topic, quotes: quotes)

        // Deck beats (1.0.2). Text-shaped beats come from the corpus text;
        // time-shaped beats need session times and stay nil without them.
        signal.writtenKeys = writtenDays
        signal.bigLine = biggestLine(in: all)
        signal.question = bestQuestion(in: all)
        let weekSessions = keys.flatMap { corpus.sessions[$0] ?? [] }
        signal.shape = shape(of: weekSessions, writtenDayCount: writtenDays.count)
        signal.sitting = longestSitting(in: weekSessions)
        return signal
    }

    // MARK: Deck-beat helpers (Swift-only; not part of the JS parity surface)

    /// The largest-written line of the period — the user already marked it
    /// as important by writing it big; we just remember. nil when nothing
    /// classified above body size.
    static func biggestLine(in all: [(day: String, text: String)]) -> RQuote? {
        var best: (size: CGFloat, quote: RQuote)? = nil
        for entry in all {
            for raw in entry.text.components(separatedBy: "\n") {
                let line = raw.trimmingCharacters(in: .whitespaces)
                guard !line.isEmpty else { continue }
                let size = WrittenScale.size(for: line)
                guard size >= 28 else { continue }
                if best == nil || size > best!.size {
                    best = (size, RQuote(text: line, day: entry.day))
                }
            }
        }
        return best?.quote
    }

    /// A verbatim question the user asked themself — the longest "?"
    /// sentence of substance. Handed back unanswered.
    static func bestQuestion(in all: [(day: String, text: String)]) -> RQuote? {
        var best: RQuote? = nil
        for entry in all {
            for line in sentences(entry.text) where line.hasSuffix("?") {
                guard line.count >= 12, line.count <= 160 else { continue }
                if best == nil || line.count > best!.text.count {
                    best = RQuote(text: line, day: entry.day)
                }
            }
        }
        return best
    }

    /// Hour → writing-time bucket.
    static func bucket(forHour h: Int) -> String {
        switch h {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<24: return "evening"
        default: return "late"
        }
    }

    /// The week's dominant writing time: at least 3 written days with
    /// session times, and one bucket carrying ≥60% of them.
    static func shape(of sessions: [RSession], writtenDayCount: Int,
                      calendar: Calendar = .current) -> WeeklySignal.Shape? {
        guard !sessions.isEmpty else { return nil }
        var daysByBucket: [String: Set<String>] = [:]
        var timedDays = Set<String>()
        for s in sessions {
            let day = DayFormat.key(for: s.at)
            let b = bucket(forHour: calendar.component(.hour, from: s.at))
            daysByBucket[b, default: []].insert(day)
            timedDays.insert(day)
        }
        guard timedDays.count >= 3,
              let top = daysByBucket.max(by: {
                  ($0.value.count, $1.key) < ($1.value.count, $0.key)
              }),
              top.value.count * 5 >= timedDays.count * 3 else { return nil }
        return WeeklySignal.Shape(bucket: top.key, days: top.value.count, total: timedDays.count)
    }

    /// The longest single session ≥ 2 minutes.
    static func longestSitting(in sessions: [RSession]) -> WeeklySignal.Sitting? {
        let best = sessions.max {
            $0.lastAt.timeIntervalSince($0.at) < $1.lastAt.timeIntervalSince($1.at)
        }
        guard let best, best.lastAt.timeIntervalSince(best.at) >= 120 else { return nil }
        return WeeklySignal.Sitting(seconds: Int(best.lastAt.timeIntervalSince(best.at)),
                                    day: DayFormat.key(for: best.at),
                                    words: wordCount(best.text))
    }

    // MARK: Monthly

    // Tone vocabulary — the tone section may only use the user's own
    // recurring words, drawn from this feeling-adjacent list.
    static let toneWords = ("tired calm quiet quietly slow slowly heavy light lighter easy easier hard harder soft softer " +
        "angry sad happy grateful anxious restless hopeful proud lonely warm cold dark bright gentle rough steady " +
        "frustrated content peaceful uneasy raw tender flat full empty").split(separator: " ").map(String.init)

    // Difficulty markers — explicit textual evidence only, never sentiment inference.
    static let difficultPattern = "fighting|struggl|difficult|too hard|bad sleep|short fuse|hurt|exhaust|worried|worry|afraid|fear|couldn't|can't stop|falling behind"

    static func isDifficult(_ line: String) -> Bool {
        line.range(of: difficultPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Stage 1 over one calendar month (1-based). Always returns a signal —
    /// an insufficient month arrives as the quiet variant, not silence.
    static func monthlySignal(year: Int, month: Int, corpus: Corpus, calendar: Calendar = .current) -> MonthlySignal {
        let first = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let dayCount = calendar.range(of: .day, in: .month, for: first)!.count
        let keys = (1...dayCount).map { String(format: "%04d-%02d-%02d", year, month, $0) }
        let writtenDays = keys.filter(corpus.has)
        let all = corpus.entries(forDays: keys)
        let words = all.reduce(0) { $0 + wordCount($1.text) }
        let sufficient = writtenDays.count >= 8

        var longestRun = 0, run = 0
        for k in keys {
            run = corpus.has(k) ? run + 1 : 0
            longestRun = max(longestRun, run)
        }

        // Tone: the user's own recurring feeling-word (≥3 occurrences).
        var tone: MonthlySignal.Tone? = nil
        let joined = all.map { $0.text.lowercased() }.joined(separator: " ")
        for w in toneWords {
            let count = countMatches(of: "\\b\(w)\\b", in: joined)
            if count >= 3 && count > (tone?.count ?? 0) { tone = .init(word: w, count: count) }
        }

        // Recurring topics: the monthly bar is higher — ≥4 mentions across
        // ≥3 days. The tone word belongs to the tone section, not the list.
        var counts: [String: (count: Int, days: Set<String>, display: String)] = [:]
        for entry in all {
            for raw in tokenize(entry.text) {
                let st = stem(raw)
                var c = counts[st] ?? (0, [], raw)
                c.count += 1
                c.days.insert(entry.day)
                counts[st] = c
            }
        }
        let toneStem = tone.map { stem($0.word) }
        var ranked = counts
            .filter { $0.value.count >= 4 && $0.value.days.count >= 3 && $0.key != toneStem }
            .sorted {
                ($0.value.days.count, $0.value.count) != ($1.value.days.count, $1.value.count)
                    ? ($0.value.days.count, $0.value.count) > ($1.value.days.count, $1.value.count)
                    : $0.key < $1.key
            }
            .prefix(8)
            .map { MonthlySignal.Topic(stem: $0.key, word: $0.value.display,
                                       mentions: $0.value.count, days: $0.value.days.count, quotes: []) }

        // Two verbatim example quotes per topic — distinct sentences (never
        // reused across topics), distinct days where possible.
        var usedText = Set<String>()
        for i in ranked.indices {
            var usedDays = Set<String>()
            for entry in all {
                if ranked[i].quotes.count >= 2 { break }
                if usedDays.contains(entry.day) { continue }
                if let hit = sentences(entry.text).first(where: { line in
                    tokenize(line).map(stem).contains(ranked[i].stem) && !usedText.contains(line)
                }) {
                    ranked[i].quotes.append(RQuote(text: hit, day: entry.day))
                    usedDays.insert(entry.day)
                    usedText.insert(hit)
                }
            }
            // Second pass: a same-day second sentence beats showing only one.
            if ranked[i].quotes.count < 2 {
                outer: for entry in all {
                    for line in sentences(entry.text) {
                        if ranked[i].quotes.count >= 2 { break outer }
                        if tokenize(line).map(stem).contains(ranked[i].stem) && !usedText.contains(line) {
                            ranked[i].quotes.append(RQuote(text: line, day: entry.day))
                            usedText.insert(line)
                        }
                    }
                }
            }
        }

        // Topics that can show two examples come first.
        let topics = Array(ranked
            .sorted {
                let a2 = $0.quotes.count >= 2 ? 1 : 0, b2 = $1.quotes.count >= 2 ? 1 : 0
                if a2 != b2 { return a2 > b2 }
                if ($0.days, $0.mentions) != ($1.days, $1.mentions) { return ($0.days, $0.mentions) > ($1.days, $1.mentions) }
                return $0.stem < $1.stem
            }
            .prefix(3))

        // Difficulty: explicit markers, quoted; up to two distinct sentences.
        var difficult: [RQuote] = []
        var seenText = Set<String>()
        for entry in all {
            if difficult.count >= 2 { break }
            if let hit = sentences(entry.text).first(where: { isDifficult($0) && !seenText.contains($0) }) {
                difficult.append(RQuote(text: hit, day: entry.day))
                seenText.insert(hit)
            }
        }

        var signal = MonthlySignal(id: String(format: "m-%04d-%02d", year, month),
                                   year: year, month: month,
                                   days: writtenDays.count, words: words, longestRun: longestRun,
                                   sufficient: sufficient, topics: topics, tone: tone, difficult: difficult)

        // Sequence beats (1.0.2) — juxtaposition and rhythm. Each stays nil
        // without honest evidence; the sequence simply skips the slide.

        // The month opened / the month closed: first sentence of the first
        // entry against the last sentence of the last. No commentary — the
        // distance speaks.
        if all.count >= 2,
           let first = sentences(all.first!.text).first, first.count <= 220,
           let last = sentences(all.last!.text).last, last.count <= 220,
           first != last {
            signal.opened = RQuote(text: first, day: all.first!.day)
            signal.closed = RQuote(text: last, day: all.last!.day)
        }

        // The turn: the tone leader changed between the halves of the month.
        let firstHalf = all.filter { Int($0.day.suffix(2)) ?? 0 <= 15 }
        let secondHalf = all.filter { Int($0.day.suffix(2)) ?? 0 > 15 }
        if let from = toneLeader(in: firstHalf), let to = toneLeader(in: secondHalf), from != to {
            signal.turn = MonthlySignal.Turn(from: from, to: to)
        }

        // People: recurring proper names — capitalized mid-sentence, never
        // seen lowercase in the month (a real name rarely is), ≥3 distinct
        // days. At most two; silence otherwise.
        signal.people = recurringNames(in: all)

        // Rhythm: written days per weekday plus the dominant writing time.
        if writtenDays.count >= 8 {
            var counts = [Int](repeating: 0, count: 7)
            for k in writtenDays {
                counts[calendar.component(.weekday, from: DayFormat.date(fromKey: k)) - 1] += 1
            }
            if let peak = counts.indices.max(by: { counts[$0] < counts[$1] }), counts[peak] >= 2 {
                let monthSessions = keys.flatMap { corpus.sessions[$0] ?? [] }
                let b = shape(of: monthSessions, writtenDayCount: writtenDays.count)?.bucket
                signal.rhythm = MonthlySignal.Rhythm(weekdayCounts: counts, peakWeekday: peak, bucket: b)
            }
        }

        // Spoken: sections that arrived by voice this month.
        let spoken = keys.flatMap { corpus.sessions[$0] ?? [] }.filter { $0.origin == "spoken" }.count
        if spoken > 0 { signal.spokenCount = spoken }

        return signal
    }

    /// The dominant tone word (≥2 occurrences) of a set of entries.
    static func toneLeader(in entries: [(day: String, text: String)]) -> String? {
        let joined = entries.map { $0.text.lowercased() }.joined(separator: " ")
        var best: (word: String, count: Int)? = nil
        for w in toneWords {
            let count = countMatches(of: "\\b\(w)\\b", in: joined)
            if count >= 2 && count > (best?.count ?? 0) { best = (w, count) }
        }
        return best?.word
    }

    /// Proper names appearing on ≥3 distinct days: capitalized, ≥3 letters,
    /// never sentence-initial, never seen lowercase anywhere in the period.
    static func recurringNames(in all: [(day: String, text: String)]) -> [MonthlySignal.Person]? {
        let calendarWords: Set<String> = Set(
            ["January","February","March","April","May","June","July","August",
             "September","October","November","December",
             "Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"])
        let lowercaseCorpus = Set(all.flatMap { tokenize($0.text) })
        var days: [String: Set<String>] = [:]
        for entry in all {
            for line in sentences(entry.text) {
                var isFirst = true
                for rawWord in line.split(whereSeparator: { !$0.isLetter && $0 != "'" }) {
                    let word = String(rawWord.prefix(while: { $0 != "'" }))
                    defer { isFirst = false }
                    guard !isFirst, word.count >= 3,
                          let head = word.first, head.isUppercase,
                          word.dropFirst().allSatisfy({ $0.isLowercase }),
                          !calendarWords.contains(word),
                          !lowercaseCorpus.contains(word.lowercased())
                    else { continue }
                    days[word, default: []].insert(entry.day)
                }
            }
        }
        let ranked = days
            .filter { $0.value.count >= 3 }
            .sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }
            .prefix(2)
            .map { MonthlySignal.Person(name: $0.key, days: $0.value.count) }
        return ranked.isEmpty ? nil : Array(ranked)
    }

    // MARK: Yearly

    /// Stage 1 over one calendar year (through today if current). The
    /// wrapped: top five topics, the most-discussed reveal with its
    /// first-ever mention, and the deterministic counts.
    static func yearlySignal(year: Int, corpus: Corpus, now: Date = .now, calendar: Calendar = .current) -> YearlySignal {
        let currentYear = calendar.component(.year, from: now)
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let end = year == currentYear
            ? calendar.startOfDay(for: now)
            : calendar.date(from: DateComponents(year: year, month: 12, day: 31))!

        var keys: [String] = []
        var cursor = start
        while cursor <= end {
            keys.append(DayFormat.key(for: cursor))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }

        let writtenDays = keys.filter(corpus.has)
        let all = corpus.entries(forDays: keys)
        let words = all.reduce(0) { $0 + wordCount($1.text) }
        let sufficient = writtenDays.count >= 30

        var longestRun = 0, run = 0
        for k in keys {
            run = corpus.has(k) ? run + 1 : 0
            longestRun = max(longestRun, run)
        }

        // Top five topics — the yearly bar is the highest: ≥6 mentions, ≥4 days.
        var counts: [String: (count: Int, days: Set<String>, display: String)] = [:]
        for entry in all {
            for raw in tokenize(entry.text) {
                let st = stem(raw)
                var c = counts[st] ?? (0, [], raw)
                c.count += 1
                c.days.insert(entry.day)
                counts[st] = c
            }
        }
        let topics = counts
            .filter { $0.value.count >= 6 && $0.value.days.count >= 4 }
            .sorted {
                ($0.value.days.count, $0.value.count) != ($1.value.days.count, $1.value.count)
                    ? ($0.value.days.count, $0.value.count) > ($1.value.days.count, $1.value.count)
                    : $0.key < $1.key
            }
            .prefix(5)
            .map { YearlySignal.Topic(stem: $0.key, word: $0.value.display,
                                      mentions: $0.value.count, days: $0.value.days.count) }

        // The reveal: the most-discussed thing and its first-ever mention.
        var reveal: YearlySignal.Reveal? = nil
        if sufficient, let top = topics.first {
            for entry in all {
                if let hit = sentences(entry.text).first(where: { line in
                    tokenize(line).map(stem).contains(top.stem)
                }) {
                    reveal = .init(topic: top, first: RQuote(text: hit, day: entry.day))
                    break
                }
            }
        }

        return YearlySignal(id: "y-\(year)", year: year,
                            days: writtenDays.count, words: words, entries: all.count,
                            longestRun: longestRun, sufficient: sufficient,
                            topics: sufficient ? Array(topics) : [], reveal: reveal,
                            writtenKeys: Set(writtenDays))
    }

    private static func countMatches(of pattern: String, in text: String) -> Int {
        var count = 0
        var searchRange = text.startIndex..<text.endIndex
        while let r = text.range(of: pattern, options: .regularExpression, range: searchRange) {
            count += 1
            if r.upperBound == searchRange.upperBound { break }
            searchRange = r.upperBound..<text.endIndex
        }
        return count
    }
}
