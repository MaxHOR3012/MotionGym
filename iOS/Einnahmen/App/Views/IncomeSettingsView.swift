import SwiftUI

/// Privatsphäre, Monatsziel, iCloud-Sync und Datenschutz-Hinweise.
struct IncomeSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.hideAmounts, store: AppGroup.defaults)
    private var hideAmounts = false
    @AppStorage(SettingsKey.requireBiometrics, store: AppGroup.defaults)
    private var requireBiometrics = false
    @AppStorage(SettingsKey.monthlyGoalCents, store: AppGroup.defaults)
    private var goalCents = 0
    @AppStorage(SettingsKey.iCloudSync)
    private var iCloudSync = false

    @State private var showingGoalEditor = false
    @State private var iCloudChanged = false

    private let biometryName = BiometricAuthService.biometryName

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $hideAmounts) {
                    Label("Beträge ausblenden", systemImage: "eye.slash")
                }
                Toggle(isOn: biometricsBinding) {
                    Label("Mit \(biometryName) schützen", systemImage: BiometricAuthService.biometrySymbol)
                }
                .disabled(!BiometricAuthService.isAvailable)
            } header: {
                Text("Privatsphäre")
            } footer: {
                Text("Ein Tipp auf die Monatssumme blendet Beträge ebenfalls ein oder aus. Ausgeblendete Beträge sind auch im Widget verborgen.")
            }

            Section("Ziel") {
                Button {
                    showingGoalEditor = true
                } label: {
                    LabeledContent {
                        if goalCents > 0 {
                            AmountText(cents: goalCents)
                        } else {
                            Text("Nicht festgelegt")
                        }
                    } label: {
                        Label("Monatsziel", systemImage: "target")
                            .foregroundStyle(.primary)
                    }
                }
            }

            Section {
                Toggle(isOn: $iCloudSync) {
                    Label("iCloud-Synchronisierung", systemImage: "icloud")
                }
                if iCloudChanged {
                    Label("Bitte App neu starten, damit die Änderung wirksam wird.", systemImage: "arrow.clockwise")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Daten")
            } footer: {
                Text("Synchronisiert verschlüsselt über deine private iCloud-Datenbank (CloudKit). Ohne iCloud bleiben alle Daten ausschließlich auf diesem Gerät.")
            }

            Section("Datenschutz") {
                Label("Alles funktioniert offline.", systemImage: "wifi.slash")
                Label("Keine externen Server, keine Tracker, keine Werbung.", systemImage: "hand.raised.fill")
                Label("Daten liegen nur auf deinem Gerät bzw. in deiner privaten iCloud.", systemImage: "lock.shield.fill")
            }
            .font(.subheadline)
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
            }
        }
        .onChange(of: hideAmounts) { WidgetSync.reload() }
        .onChange(of: iCloudSync) { iCloudChanged = true }
        .sheet(isPresented: $showingGoalEditor) {
            NavigationStack { GoalEditorView() }
        }
    }

    /// Ein- und Ausschalten des Schutzes muss selbst bestätigt werden.
    private var biometricsBinding: Binding<Bool> {
        Binding(
            get: { requireBiometrics },
            set: { newValue in
                Task { @MainActor in
                    let reason = newValue
                        ? "Schutz für deine Einnahmen aktivieren"
                        : "Schutz für deine Einnahmen deaktivieren"
                    if await BiometricAuthService.authenticate(reason: reason) {
                        requireBiometrics = newValue
                    }
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        IncomeSettingsView()
    }
}
