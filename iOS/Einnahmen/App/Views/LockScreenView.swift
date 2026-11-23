import SwiftUI

/// Sperrbildschirm, wenn „Mit Face ID schützen" aktiv ist.
struct LockScreenView: View {
    var isAuthenticating: Bool
    var onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Einnahmen gesperrt")
                        .font(.title2.bold())
                    Text("Entsperre mit \(BiometricAuthService.biometryName), um deine Einnahmen zu sehen.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                Button(action: onUnlock) {
                    Label("Entsperren", systemImage: BiometricAuthService.biometrySymbol)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAuthenticating)
            }
            .padding(32)
            .frame(maxWidth: 420)
        }
    }
}

/// Verdeckt Inhalte im App-Umschalter, wenn der Schutz aktiv ist.
struct PrivacyCoverView: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThickMaterial).ignoresSafeArea()
            Image(systemName: "eurosign.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    LockScreenView(isAuthenticating: false) {}
}
