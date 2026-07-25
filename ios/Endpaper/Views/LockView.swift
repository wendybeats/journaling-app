// The lock — optional Face ID / passcode gate over the notebook. One dot
// on bone; the system sheet does the talking. If the device has no
// passcode there is nothing to lock with, so the gate stands aside.

import SwiftUI
import LocalAuthentication

struct LockView: View {
    var onUnlock: () -> Void

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
        .onAppear(perform: attempt)
    }

    private func attempt() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            onUnlock()   // no passcode on the device — nothing to lock with
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Unlock your notebook") { ok, _ in
            if ok { DispatchQueue.main.async { onUnlock() } }
        }
    }
}
