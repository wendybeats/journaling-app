// The early glimpse (1.0.4, QA 2026-09-11): before the first reflection,
// once a word keeps coming back, its latest occurrence on today's page
// lights up. Tap it and a small dialogue names the count. Retention
// lever to day 7 — it proves the proposition, it is not a reflection:
// nothing is archived, nothing is offered, nothing is analysed. Counting
// only, on the weekly engine's own tokenizer.

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
    /// The tap target the highlighted run carries.
    static let link = URL(string: "endpaper://glimpse")!

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

    /// The best stem over `weekKeys` that clears the bar and has an
    /// occurrence today (so the highlight has somewhere to live on
    /// Today). `strong` raises the bar for any glimpse after the first.
    static func candidate(corpus: Corpus, weekKeys: [String], todayKey: String,
                          fired: Set<String>, strong: Bool) -> GlimpseSignal? {
        let writtenDays = weekKeys.filter(corpus.has)
        guard writtenDays.count >= dayFloor, writtenDays.contains(todayKey) else { return nil }
        let all = corpus.entries(forDays: weekKeys)
        guard all.reduce(0, { $0 + Reflect.wordCount($1.text) }) >= wordFloor else { return nil }

        struct Tally {
            var count = 0
            var days = Set<String>()
            var forms: [String: Int] = [:]
            var today = false
        }
        var tallies: [String: Tally] = [:]
        for entry in all {
            for raw in Reflect.tokenize(entry.text) {
                let s = Reflect.stem(raw)
                if flat.contains(s) || flat.contains(raw) { continue }
                var t = tallies[s] ?? Tally()
                t.count += 1
                t.days.insert(entry.day)
                t.forms[raw, default: 0] += 1
                if entry.day == todayKey { t.today = true }
                tallies[s] = t
            }
        }

        let minMentions = strong ? 5 : 3
        let minDays = strong ? 3 : 2
        let ranked = tallies
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
                             mentions: best.value.count, days: best.value.days.count, dayKey: todayKey)
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
}

/// Glimpse state — which stems have fired (once each, ever), the one
/// active today, and the per-week count — persisted under one key.
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

    /// Today's glimpse — the active one if it lit up today, else a fresh
    /// candidate if the rules allow one. Nil is silence. An explicit "no"
    /// to reflections is respected; unasked is eligible.
    func evaluate(corpus: Corpus, todayKey: String, now: Date = .now) -> GlimpseSignal? {
        guard ReflectionStore.shared.consent != "no" else { return nil }
        if let active = state.active, active.dayKey == todayKey { return active }
        if state.active != nil {                       // yesterday's faded at midnight
            state.active = nil
            persist()
        }
        guard state.lastDay != todayKey else { return nil }
        guard ReflectionCadence.daysUntilReflection(now: now) != 0 else { return nil }   // the reflection owns its day
        let weekStart = ReflectionCadence.currentWeekStart(now: now)
        let weekKey = DayFormat.key(for: weekStart)
        guard (state.weekCounts[weekKey] ?? 0) < Self.perWeekCap else { return nil }
        let keys = Reflect.weekDayKeys(start: weekStart).filter { $0 <= todayKey }
        guard let found = Glimpse.candidate(corpus: corpus, weekKeys: keys, todayKey: todayKey,
                                            fired: Set(state.fired), strong: !state.fired.isEmpty)
        else { return nil }
        state.active = found
        state.fired.append(found.stem)
        state.lastDay = todayKey
        state.weekCounts[weekKey, default: 0] += 1
        persist()
        return found
    }

    /// "Noted": the highlight goes out. The stem never fires again.
    func acknowledge() {
        state.active = nil
        persist()
    }

    /// Demo tools only (DEBUG + TestFlight), beside ReflectionStore.resetAll.
    func resetAll() {
        state = State()
        persist()
    }
}
