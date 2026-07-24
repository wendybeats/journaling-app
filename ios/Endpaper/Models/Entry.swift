// Endpaper — the entry. Plain text, day-keyed, timestamped: the same corpus
// shape as the web prototype (endpaper.entries.v1), now as SwiftData + CloudKit.
//
// Permanence is a product rule ("what you write stays written"): nothing in
// the app exposes an edit or delete path. The only mutation anywhere is
// EntryStore's same-session append. CloudKit requires defaults on every
// property, hence the initializer-side values.

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
