// Endpaper — the journal that is just a journal.
// Path A (decided July 8): no accounts, no server. "Back up with iCloud"
// turns on the CloudKit private database; "Continue without an account"
// keeps the store local-only. Switching modes re-targets the container on
// next launch (the store file is shared, CloudKit adopts existing rows).

import SwiftUI
import SwiftData

@main
struct EndpaperApp: App {
    private let container: ModelContainer

    init() {
        let icloud = UserDefaults.standard.string(forKey: AppKeys.account) == AccountMode.icloud.rawValue
        container = Self.makeContainer(icloud: icloud)
    }

    private static func makeContainer(icloud: Bool) -> ModelContainer {
        let config = ModelConfiguration(
            cloudKitDatabase: icloud ? .private("iCloud.com.wendellbarton.endpaper") : .none
        )
        do {
            return try ModelContainer(for: Entry.self, configurations: config)
        } catch {
            // CloudKit unavailable (no entitlement in a fresh checkout, managed
            // device, signed-out iCloud): fall back to local-only rather than die.
            do {
                return try ModelContainer(
                    for: Entry.self,
                    configurations: ModelConfiguration(cloudKitDatabase: .none)
                )
            } catch {
                fatalError("Endpaper could not open its store: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(nil)   // token-level dark mode follows the system
        }
        .modelContainer(container)
    }
}
