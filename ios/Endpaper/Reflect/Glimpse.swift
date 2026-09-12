// The early glimpse (1.0.4, QA 2026-09-11/12): before the first
// reflection, once a word keeps coming back, it lights up ON THE PAGE —
// in the live editor the moment the word is finished, or on today's
// committed section. Tap it and a small dialogue names the count.
// Retention lever to day 7 — it proves the proposition, it is not a
// reflection: nothing is archived, nothing is offered, nothing is
// analysed. Counting only, on the weekly engine's own tokenizer.

import Foundation

struct GlimpseSignal: Codable, Equatable {
    var stem: String
    var word: String          // the commonest surface form, for the dialogue
    var forms: [String]       // every surface form, for the highlight finder
    var mentions: Int
    var days: Int
    var dayKey: String        // the day it lit up — fades at midnight
}

enum Glimpse {
    /// Eligibility floors over the current week: two written days and
    /// 120 words. The pattern bar does the rest.
    static let wordFloor = 120
    static let dayFloor = 2

    /// Words the tokenizer lets through that never make a glimpse: flat
    /// journal furniture, plus the fragments the ASCII tokenizer leaves
    /// from contractions ("didn't" → "didn"). Glimpse-only — the weekly
    /// engine keeps its parity list untouched.
    static let flat: Set<String> = [
        "said", "kind", "sort", "work", "morning", "evening", "night", "home", "house",
        "month", "year", "hour", "minute", "people", "person", "someone", "everyone",
        "thought", "think", "know", "want", "need", "tried", "trying", "wrote", "write",
        "writing", "pretty", "stuff", "lots", "some", "okay", "sure", "whole", "half",
        "didn", "wasn", "couldn", "wouldn", "shouldn", "doesn", "hasn", "haven", "hadn",
        "aren", "weren", "there", "where", "which", "while", "again", "about", "after",
        "before", "later", "since", "until", "being", "having", "doing", "done",
    ]

    struct Tally {
        var count = 0
        var days = Set<String>()
        var forms: [String: Int] = [:]
        var today = false
    }

    /// The week's counts over COMMITTED text — primed once per page
    /// refresh, then merged with the live draft on every keystroke.
    struct Base {
        var tallies: [String: Tally] = [:]
        var words = 0
        var days = Set<String>()
        let todayKey: String
    }

    static func base(corpus: Corpus, weekKeys: [String], todayKey: String) -> Base {
        var b = Base(todayKey: todayKey)
        for entry in corpus.entries(forDays: weekKeys) {
            add(entry.text, day: entry.day, to: &b)
        }
        return b
    }

    /// The draft counts as today's text, minus the word still being
    /// typed — a glimpse lands the moment the word is finished, never on
    /// a fragment of it.
    static func merging(_ base: Base, draft: String) -> Base {
        var b = base
        let complete = completeWords(draft)
        guard !complete.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return b }
        add(complete, day: base.todayKey, to: &b)
        return b
    }

    private static func add(_ text: String, day: String, to b: inout Base) {
        b.words += Reflect.wordCount(text)
        b.days.insert(day)
        for raw in Reflect.tokenize(text) {
            let s = Reflect.stem(raw)
            if flat.contains(s) || flat.contains(raw) { continue }
            var t = b.tallies[s] ?? Tally()
            t.count += 1
            t.days.insert(day)
            t.forms[raw, default: 0] += 1
            if day == b.todayKey { t.today = true }
            b.tallies[s] = t
        }
    }

    /// The draft without its trailing partial word.
    static func completeWords(_ draft: String) -> String {
        guard let last = draft.last, last.isLetter || last == "'" else { return draft }
        var s = draft
        while let c = s.last, c.isLetter || c == "'" { s.removeLast() }
        return s
    }

    /// The best stem that clears the bar and has an occurrence today (so
    /// the highlight has somewhere to live on the page). `strong` raises
    /// the bar for any glimpse after the first.
    static func candidate(in b: Base, fired: Set<String>, strong: Bool) -> GlimpseSignal? {
        guard b.days.count >= dayFloor, b.days.contains(b.todayKey), b.words >= wordFloor else { return nil }
        let minMentions = strong ? 5 : 3
        let minDays = strong ? 3 : 2
        let ranked = b.tallies
            .filter { !fired.contains($0.key) && $0.value.today
                      && $0.value.count >= minMentions && $0.value.days.count >= minDays }
            .sorted {
                ($0.value.count, $0.value.days.count) != ($1.value.count, $1.value.days.count)
                    ? ($0.value.count, $0.value.days.count) > ($1.value.count, $1.value.days.count)
                    : $0.key < $1.key
            }
        guard let best = ranked.first else { return nil }
        let word = best.value.forms
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .first!.key
        return GlimpseSignal(stem: best.key, word: word, forms: Array(best.value.forms.keys),
                             mentions: best.value.count, days: best.value.days.count, dayKey: b.todayKey)
    }

    /// The LAST whole-word occurrence of any form in `text`, as a character
    /// offset and length — the run that lights up. Case-insensitive; a
    /// word boundary is anything that isn't a letter (an apostrophe counts,
    /// matching the tokenizer's suffix strip).
    static func lastRange(of forms: [String], in text: String) -> (offset: Int, length: Int)? {
        let chars = Array(text)
        var best: (Int, Int)? = nil
        for form in forms {
            let f = Array(form.lowercased())
            guard !f.isEmpty, chars.count >= f.count else { continue }
            var i = chars.count - f.count
            while i >= 0 {
                if (best == nil || i > best!.0),
                   zip(chars[i..<(i + f.count)], f).allSatisfy({ String($0).lowercased() == String($1) }),
                   i == 0 || !chars[i - 1].isLetter,
                   i + f.count == chars.count || !chars[i + f.count].isLetter {
                    best = (i, f.count)
                    break
                }
                i -= 1
            }
        }
        return best.map { (offset: $0.0, length: $0.1) }
    }

    /// The same occurrence as a UTF-16 range, for TextKit.
    static func lastNSRange(of forms: [String], in text: String) -> NSRange? {
        guard let hit = lastRange(of: forms, in: text) else { return nil }
        let start = text.index(text.startIndex, offsetBy: hit.offset)
        let end = text.index(start, offsetBy: hit.length)
        return NSRange(start..<end, in: text)
    }
}

/// Glimpse state — which stems have fired (once each, ever), the one
/// active today, and the per-week count — persisted under one key. The
/// primed week base lives in memory only.
final class GlimpseStore {
    static let shared = GlimpseStore()

    /// At most two glimpses in any reflection week; at most one a day.
    static let perWeekCap = 2

    private struct State: Codable {
        var fired: [String] = []
        var active: GlimpseSignal? = nil
        var lastDay: String? = nil
        var weekCounts: [String: Int] = [:]
    }

    private var state: State
    private var base: Glimpse.Base? = nil
    private let key = AppKeys.glimpse

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(State.self, from: data) {
            state = decoded
        } else {
            state = State()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Count the week's committed text once — on page appear and after
    /// every commit — so the per-keystroke pass only reads the draft.
    func prime(corpus: Corpus, todayKey: String, now: Date = .now) {
        let weekStart = ReflectionCadence.currentWeekStart(now: now)
        let keys = Reflect.weekDayKeys(start: weekStart).filter { $0 <= todayKey }
        base = Glimpse.base(corpus: corpus, weekKeys: keys, todayKey: todayKey)
    }

    /// Today's glimpse — the active one if it lit up today, else a fresh
    /// candidate over the primed week plus the live draft. Nil is
    /// silence. An explicit "no" to reflections is respected; unasked is
    /// eligible. Cheap enough to run on every keystroke.
    func evaluate(draft: String, todayKey: String, now: Date = .now) -> GlimpseSignal? {
        guard ReflectionStore.shared.reflectionsOn else { return nil }
        if let active = state.active, active.dayKey == todayKey { return active }
        if state.active != nil {                       // yesterday's faded at midnight
            state.active = nil
            persist()
        }
        guard state.lastDay != todayKey else { return nil }
        guard ReflectionCadence.daysUntilReflection(now: now) != 0 else { return nil }   // the reflection owns its day
        let weekKey = DayFormat.key(for: ReflectionCadence.currentWeekStart(now: now))
        guard (state.weekCounts[weekKey] ?? 0) < Self.perWeekCap else { return nil }
        guard let base, base.todayKey == todayKey else { return nil }
        guard let found = Glimpse.candidate(in: Glimpse.merging(base, draft: draft),
                                            fired: Set(state.fired), strong: !state.fired.isEmpty)
        else { return nil }
        state.active = found
        state.fired.append(found.stem)
        state.lastDay = todayKey
        state.weekCounts[weekKey, default: 0] += 1
        persist()
        Analytics.track(.earlyInsightEligible)   // that a word lit up — never which
        return found
    }

    /// "Noted": the highlight goes out. The stem never fires again.
    func acknowledge() {
        state.active = nil
        persist()
        Analytics.track(.earlyInsightNoted)
    }

    /// Demo tools only (DEBUG + TestFlight), beside ReflectionStore.resetAll.
    func resetAll() {
        state = State()
        base = nil
        persist()
    }
}
