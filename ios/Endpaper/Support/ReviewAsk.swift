// The rating pre-prompt — same quiet-card register as ReminderCard, shown
// on Today after five written days. "It is" summons Apple's rating sheet;
// "not yet" is remembered locally, never re-asked, and opens the door to a
// feedback email instead. Either answer retires the card for good.

import SwiftUI
import SwiftData
import StoreKit

enum ReviewAskState {
    /// Five distinct written days, and never answered before.
    static func eligible(in context: ModelContext) -> Bool {
        UserDefaults.standard.string(forKey: AppKeys.reviewAsk) == nil
            && EntryStore.daysWithEntries(in: context).count >= 5
    }

    static func answered(_ answer: String) {
        UserDefaults.standard.set(answer, forKey: AppKeys.reviewAsk)
    }
}

struct ReviewAskCard: View {
    @Environment(\.requestReview) private var requestReview
    @State private var notYet = false
    @State private var done = false

    var body: some View {
        if done { EmptyView() } else if notYet {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Noted — thank you.")
                    .typeTitle()
                Text("If you have a minute, one line about what's missing goes straight to the maker.")
                    .typeWritten()
                HStack(spacing: Tokens.Space.lg) {
                    Link(destination: URL(string:
                        "mailto:hello@endpaper.space?subject=Endpaper%20—%20what%27s%20missing")!) {
                        Text("Write to the maker").typeMeta().foregroundStyle(Tokens.Text.written)
                    }
                    Button {
                        withAnimation(Tokens.Motion.base) { done = true }
                    } label: {
                        Text("Maybe later").typeMeta()
                    }
                }
            }
            .padding(Tokens.Space.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.Surface.raised, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
        } else {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Earning its place?")
                    .typeTitle()
                Text("You've written five days. Is Endpaper earning a place in your morning? A rating helps more than you'd think.")
                    .typeWritten()
                HStack(spacing: Tokens.Space.lg) {
                    Button {
                        ReviewAskState.answered("itIs")
                        Signals.log("review.itIs")
                        withAnimation(Tokens.Motion.base) { done = true }
                        requestReview()
                    } label: {
                        Text("It is").typeMeta().foregroundStyle(Tokens.Text.written)
                    }
                    Button {
                        ReviewAskState.answered("notYet")
                        Signals.log("review.notYet")
                        withAnimation(Tokens.Motion.base) { notYet = true }
                    } label: {
                        Text("Not yet").typeMeta()
                    }
                }
            }
            .padding(Tokens.Space.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.Surface.raised, in: RoundedRectangle(cornerRadius: Tokens.Radius.card))
        }
    }
}
