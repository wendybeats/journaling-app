// The lock — optional Face ID / passcode gate over the notebook. One dot
// on bone; the system sheet does the talking. If the device has no
// passcode there is nothing to lock with, so the gate stands aside.

import SwiftUI
import LocalAuthentication

struct LockView: View {
    var onUnlock: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var authInFlight = false

    var body: some View {
        VStack(spacing: Tokens.Space.lg) {
            Spacer()
            Circle()
                .fill(Tokens.Dot.filled)
                .frame(width: Tokens.DotSize.today, height: Tokens.DotSize.today)
            Text("Endpaper").typeMeta()
            Spacer()
            Button(action: attempt) {
                Text("Unlock").typeMeta().foregroundStyle(Tokens.Text.written)
            }
            .padding(.bottom, Tokens.Space.xxl)
        }
        .frame(maxWidth: .infinity)
        .background(Tokens.Surface.page.ignoresSafeArea())
        // The lock usually mounts while the app is backgrounding — the
        // system can't show an auth prompt then, and a prompt attempted
        // there dies silently. Fire only when the scene is actually
        // active, and re-fire on every return to foreground.
        .onAppear { if scenePhase == .active { attempt() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { attempt() }
        }
    }

    private func attempt() {
        guard !authInFlight else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            onUnlock()   // no passcode on the device — nothing to lock with
            return
        }
        authInFlight = true
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Unlock your notebook") { ok, _ in
            DispatchQueue.main.async {
                authInFlight = false
                if ok { onUnlock() }
            }
        }
    }
}
