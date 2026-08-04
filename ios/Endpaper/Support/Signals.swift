// Local-only event notes. The privacy policy promises no analytics and no
// third-party SDKs, first- or third-party — so nothing here may ever touch
// the network. This is a bounded on-device list of moments worth knowing
// about ("review.notYet"), readable only if the user chooses to include it
// in a feedback email. If a telemetry provider is ever adopted (policy
// change first), this is the single seam it would plug into.

import Foundation

enum Signals {
    private static let cap = 200

    static func log(_ name: String) {
        var events = UserDefaults.standard.stringArray(forKey: AppKeys.signals) ?? []
        events.append("\(ISO8601DateFormatter().string(from: .now)) \(name)")
        if events.count > cap { events.removeFirst(events.count - cap) }
        UserDefaults.standard.set(events, forKey: AppKeys.signals)
    }

    static var all: [String] {
        UserDefaults.standard.stringArray(forKey: AppKeys.signals) ?? []
    }
}
