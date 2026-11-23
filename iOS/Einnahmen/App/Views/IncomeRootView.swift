import SwiftData
import SwiftUI

/// Einstiegspunkt des Features: Sperre, Planung beim Öffnen, Navigation.
///
/// In einer bestehenden App z. B. als Tab einbinden:
/// ```swift
/// IncomeRootView()
///     .tabItem { Label("Einnahmen", systemImage: "eurosign.circle") }
/// ```
struct IncomeRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

    @AppStorage(SettingsKey.requireBiometrics, store: AppGroup.defaults)
    private var requireBiometrics = false

    @State private var isUnlocked = false
    @State private var isAuthenticating = false
    @State private var shouldPromptOnActive = true

    var body: some View {
        ZStack {
            NavigationStack {
                IncomeDashboardView()
            }

            if requireBiometrics && !isUnlocked {
                LockScreenView(isAuthenticating: isAuthenticating) {
                    Task { await unlock() }
                }
                .transition(.opacity)
            } else if requireBiometrics && scenePhase != .active {
                PrivacyCoverView()
            }
        }
        .environment(\.locale, Money.locale)
        .task {
            refreshData()
            if requireBiometrics {
                shouldPromptOnActive = false
                await unlock()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                if requireBiometrics {
                    isUnlocked = false
                    shouldPromptOnActive = true
                }
            case .active:
                refreshData()
                if requireBiometrics && !isUnlocked && shouldPromptOnActive {
                    shouldPromptOnActive = false
                    Task { await unlock() }
                }
            default:
                break
            }
        }
        .onChange(of: requireBiometrics) { _, enabled in
            // Wer den Schutz gerade aktiviert hat, ist bereits authentifiziert.
            if enabled { isUnlocked = true }
        }
    }

    private func refreshData() {
        RecurrenceService.refresh(in: context)
        WidgetSync.update(using: context)
    }

    private func unlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        let success = await BiometricAuthService.authenticate(reason: "Entsperre deine Einnahmen")
        isAuthenticating = false
        withAnimation { isUnlocked = success }
    }
}

#Preview {
    IncomeRootView()
        .modelContainer(PreviewData.container)
}
