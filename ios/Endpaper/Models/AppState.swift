// Endpaper — small persisted flags, mirroring the web prototype's localStorage
// keys one for one so the two implementations stay comparable.

import Foundation
import SwiftUI

enum AppKeys {
    static let onboarded = "endpaper.onboarded.v1"
    static let account = "endpaper.account.v1"        // "icloud" | "local"
    static let trial = "endpaper.trial.v1"            // ISO date the trial started
    static let draft = "endpaper.draft.v1"            // uncommitted writing survives relaunch
    static let draftDay = "endpaper.draft.day.v1"
    static let reminder = "endpaper.reminder.v1"      // "yes" | "no" — the pre-prompt answer
    static let reminderHour = "endpaper.reminder.hour.v1"     // Int, default 8
    static let reminderMinute = "endpaper.reminder.minute.v1" // Int, default 0
    static let reflection = "endpaper.reflection.v1"  // consent state (round 2 port)
    static let faceLock = "endpaper.facelock.v1"      // Bool — lock the app behind Face ID
}

enum AccountMode: String {
    case icloud, local
}
