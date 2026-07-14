// Vellum — small persisted flags, mirroring the web prototype's localStorage
// keys one for one so the two implementations stay comparable.

import Foundation
import SwiftUI

enum AppKeys {
    static let onboarded = "vellum.onboarded.v1"
    static let account = "vellum.account.v1"        // "icloud" | "local"
    static let trial = "vellum.trial.v1"            // ISO date the trial started
    static let draft = "vellum.draft.v1"            // uncommitted writing survives relaunch
    static let draftDay = "vellum.draft.day.v1"
    static let reminder = "vellum.reminder.v1"      // "yes" | "no" — the pre-prompt answer
    static let reflection = "vellum.reflection.v1"  // consent state (round 2 port)
}

enum AccountMode: String {
    case icloud, local
}
