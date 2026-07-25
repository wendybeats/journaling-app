// Engine parity — the launch-plan checklist item "Swift engine agrees
// with the JS engine on the seed corpus."
//
// tools/parity/gen-corpus.mjs writes the shared corpus; run-js.mjs runs
// the reference engine (js/reflect.js) over it and records every signal
// in expected.json. These tests run Reflect.swift over the same corpus
// and assert the signals match.
//
// Known tolerated divergence (documented in Reflect.swift's header): JS
// relies on stable sort + Map insertion order for ranking ties; Swift
// carries explicit alphabetical tiebreaks. If a failure here is a pure
// tie artifact (same days/mentions, different pick), record it and align
// the comparator — don't paper over a real divergence.

import XCTest
@testable import Endpaper

// MARK: - Fixture shapes (mirror expected.json / corpus.json)

private struct FQuote: Codable, Equatable {
    let text: String
    let day: String
}

private struct FWeekly: Codable {
    struct Topic: Codable {
        let word: String
        let mentions: Int
        let days: Int
    }
    let id: String
    let startKey: String
    let days: Int
    let words: Int
    let sufficient: Bool
    let topic: Topic?
    let quotes: [FQuote]
}

private struct FMonthly: Codable {
    struct Topic: Codable {
        let stem: String
        let word: String
        let mentions: Int
        let days: Int
        let quotes: [FQuote]
    }
    struct Tone: Codable {
        let word: String
        let count: Int
    }
    let id: String
    let year: Int
    let month: Int          // 1-based (normalized by run-js.mjs)
    let days: Int
    let words: Int
    let longestRun: Int
    let sufficient: Bool
    let tone: Tone?
    let topics: [Topic]
    let difficult: [FQuote]
}

private struct FYearly: Codable {
    struct Topic: Codable {
        let stem: String
        let word: String
        let mentions: Int
        let days: Int
    }
    struct Reveal: Codable {
        let stem: String
        let first: FQuote
    }
    let id: String
    let year: Int
    let days: Int
    let words: Int
    let entries: Int
    let longestRun: Int
    let sufficient: Bool
    let topics: [Topic]
    let reveal: Reveal?
}

private struct Fixture: Codable {
    let anchor: String
    let weekly: [FWeekly]
    let monthly: [FMonthly]
    let yearly: [FYearly]
}

private struct FCorpusSession: Codable {
    let minuteOfDay: Int
    let text: String
}

private struct FCorpus: Codable {
    let anchor: String
    let byDay: [String: [FCorpusSession]]
}

// MARK: - Tests

final class ParityTests: XCTestCase {

    private static var corpus: Corpus!
    private static var fixture: Fixture!
    private static var now: Date!

    override class func setUp() {
        super.setUp()
        let bundle = Bundle(for: ParityTests.self)
        func load<T: Decodable>(_ name: String, as type: T.Type) -> T {
            guard let url = bundle.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(T.self, from: data) else {
                fatalError("Missing or undecodable fixture \(name).json — regenerate with tools/parity/*.mjs")
            }
            return decoded
        }
        let rawCorpus = load("corpus", as: FCorpus.self)
        corpus = Corpus(byDay: rawCorpus.byDay.mapValues { $0.map(\.text) })
        fixture = load("expected", as: Fixture.self)

        let anchor = DayFormat.date(fromKey: fixture.anchor)
        now = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: anchor)!
    }

    func testWeekStartAgrees() {
        let start = Reflect.lastCompletedWeekStart(now: Self.now)
        XCTAssertEqual(DayFormat.key(for: start), Self.fixture.weekly.first?.startKey,
                       "lastCompletedWeekStart diverges from the JS engine")
    }

    func testWeeklyParity() {
        for expected in Self.fixture.weekly {
            let start = DayFormat.date(fromKey: expected.startKey)
            let signal = Reflect.weeklySignal(start: start, corpus: Self.corpus)

            XCTAssertEqual(signal.id, expected.id)
            XCTAssertEqual(signal.days, expected.days, "\(expected.id): written days")
            XCTAssertEqual(signal.words, expected.words, "\(expected.id): word count")
            XCTAssertEqual(signal.sufficient, expected.sufficient, "\(expected.id): sufficiency")
            XCTAssertEqual(signal.topic?.word, expected.topic?.word, "\(expected.id): topic word (tie-order?)")
            XCTAssertEqual(signal.topic?.mentions, expected.topic?.mentions, "\(expected.id): topic mentions")
            XCTAssertEqual(signal.topic?.days, expected.topic?.days, "\(expected.id): topic days")
            XCTAssertEqual(signal.quotes.map(\.text), expected.quotes.map(\.text), "\(expected.id): quote texts")
            XCTAssertEqual(signal.quotes.map(\.day), expected.quotes.map(\.day), "\(expected.id): quote days")
        }
    }

    func testMonthlyParity() {
        for expected in Self.fixture.monthly {
            let signal = Reflect.monthlySignal(year: expected.year, month: expected.month, corpus: Self.corpus)

            XCTAssertEqual(signal.id, expected.id)
            XCTAssertEqual(signal.days, expected.days, "\(expected.id): written days")
            XCTAssertEqual(signal.words, expected.words, "\(expected.id): word count")
            XCTAssertEqual(signal.longestRun, expected.longestRun, "\(expected.id): longest run")
            XCTAssertEqual(signal.sufficient, expected.sufficient, "\(expected.id): sufficiency")
            XCTAssertEqual(signal.tone?.word, expected.tone?.word, "\(expected.id): tone word")
            XCTAssertEqual(signal.tone?.count, expected.tone?.count, "\(expected.id): tone count")

            XCTAssertEqual(signal.topics.map(\.stem), expected.topics.map(\.stem),
                           "\(expected.id): topic stems/order (tie-order?)")
            for (got, want) in zip(signal.topics, expected.topics) {
                XCTAssertEqual(got.mentions, want.mentions, "\(expected.id) “\(want.stem)”: mentions")
                XCTAssertEqual(got.days, want.days, "\(expected.id) “\(want.stem)”: days")
                XCTAssertEqual(got.quotes.map(\.text), want.quotes.map(\.text), "\(expected.id) “\(want.stem)”: quotes")
            }
            XCTAssertEqual(signal.difficult.map(\.text), expected.difficult.map(\.text),
                           "\(expected.id): difficulty quotes")
        }
    }

    func testYearlyParity() {
        for expected in Self.fixture.yearly {
            let signal = Reflect.yearlySignal(year: expected.year, corpus: Self.corpus, now: Self.now)

            XCTAssertEqual(signal.id, expected.id)
            XCTAssertEqual(signal.days, expected.days, "\(expected.id): written days")
            XCTAssertEqual(signal.words, expected.words, "\(expected.id): word count")
            XCTAssertEqual(signal.entries, expected.entries, "\(expected.id): entry count")
            XCTAssertEqual(signal.longestRun, expected.longestRun, "\(expected.id): longest run")
            XCTAssertEqual(signal.sufficient, expected.sufficient, "\(expected.id): sufficiency")
            XCTAssertEqual(signal.topics.map(\.stem), expected.topics.map(\.stem),
                           "\(expected.id): top-five stems/order (tie-order?)")
            XCTAssertEqual(signal.reveal?.topic.stem, expected.reveal?.stem, "\(expected.id): reveal stem")
            XCTAssertEqual(signal.reveal?.first.text, expected.reveal?.first.text, "\(expected.id): first mention")
            XCTAssertEqual(signal.reveal?.first.day, expected.reveal?.first.day, "\(expected.id): first-mention day")
        }
    }
}
