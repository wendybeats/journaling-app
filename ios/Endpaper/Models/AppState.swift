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
    static let draftStart = "endpaper.draft.start.v1" // ISO — when the draft's first words landed
    static let voiceLocale = "endpaper.voice.locale.v1" // "" = match device; else e.g. "ru-RU"
    static let paymentsUnavailable = "endpaper.payments.unavailable.v1" // storefront can't transact
    static let theme = "endpaper.theme.v1"            // "" = system | "light" | "dark"
    static let reminder = "endpaper.reminder.v1"      // "yes" | "no" — the pre-prompt answer
    static let reminderHour = "endpaper.reminder.hour.v1"     // Int, default 8
    static let reminderMinute = "endpaper.reminder.minute.v1" // Int, default 0
    static let editsClose = "endpaper.editsclose.v1"  // Bool — the 11 PM "edits end in 1 hour" note
    static let reflection = "endpaper.reflection.v1"  // consent state (round 2 port)
    static let faceLock = "endpaper.facelock.v1"      // Bool — lock the app behind Face ID
    static let reviewAsk = "endpaper.reviewask.v1"    // "itIs" | "notYet" — answered once, kept forever
    static let signals = "endpaper.signals.v1"        // [String] — local-only event notes (Signals.swift)
    // Free model (1.0.4): writing is free forever; reflections are the
    // membership. First weekly plays free; the offer closes its deck.
    static let firstDay = "endpaper.firstday.v1"      // day key of first open — drives the ghost-prompt week
    static let lastArrival = "endpaper.lastarrival.v1" // day key the daily splash last played
    static let firstWeeklyUsed = "endpaper.reflection.first.v1" // Bool — the free weekly has been spent
}

enum AccountMode: String {
    case icloud, local
}
