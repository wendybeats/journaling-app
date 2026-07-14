// Archive — one surface, three registers: Notebook (reading), Calendar
// (dots), Find (search). The tabs are words in the mono register, never
// icons, matching the web prototype's Notebook / Calendar / Find row.

import SwiftUI

enum ArchiveTab: String, CaseIterable {
    case notebook = "Notebook"
    case calendar = "Calendar"
    case find = "Find"
}

struct ArchiveView: View {
    @State private var tab: ArchiveTab = .notebook

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Space.md) {
                ForEach(ArchiveTab.allCases, id: \.self) { t in
                    Button {
                        withAnimation(Tokens.Motion.base) { tab = t }
                    } label: {
                        Text(t.rawValue)
                            .typeMeta()
                            .foregroundStyle(tab == t ? Tokens.Text.written : Tokens.Text.meta)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, Tokens.Space.md)

            switch tab {
            case .notebook: NotebookView()
            case .calendar: CalendarView()
            case .find: FindView()
            }
        }
        .background(Tokens.Surface.page)
        .toolbarBackground(Tokens.Surface.page, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }
}
