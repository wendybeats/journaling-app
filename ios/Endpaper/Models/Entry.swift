// Endpaper — the entry. Plain text, day-keyed, timestamped: the same corpus
// shape as the web prototype (endpaper.entries.v1), now as SwiftData + CloudKit.
//
// Permanence is a product rule ("what you write stays written"), and its
// boundary is the day: same-day revision exists (EntryStore.revise), but at
// midnight the day archives and nothing can touch it again. There is no
// delete path anywhere. CloudKit requires defaults on every property,
// hence the initializer-side values.

import Foundation
import SwiftData

@Model
final class Entry {
    var id: UUID = UUID()
    var dayKey: String = ""      // "2026-07-05", local time
    var at: Date = Date()        // session start
    var lastAt: Date = Date()    // last append within the session
    var text: String = ""

    init(id: UUID = UUID(), dayKey: String, at: Date, text: String) {
        self.id = id
        self.dayKey = dayKey
        self.at = at
        self.lastAt = at
        self.text = text
    }
}
