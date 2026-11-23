import Foundation

/// Gemeinsamer Speicher von App und Widget.
///
/// ⚠️ Die ID muss in **beiden** Targets (App + Widget) unter
/// „Signing & Capabilities → App Groups" exakt so eingetragen sein.
enum AppGroup {
    static let identifier = "group.de.meinname.finanzen"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Alle Schlüssel für Einstellungen an einer Stelle.
enum SettingsKey {
    /// Monatsziel in Cent (App-Group, das Widget liest es mit).
    static let monthlyGoalCents = "income.monthlyGoalCents"
    /// Beträge ausblenden (App-Group, das Widget liest es mit).
    static let hideAmounts = "income.hideAmounts"
    /// Face ID / Touch ID beim Öffnen verlangen (App-Group).
    static let requireBiometrics = "income.requireBiometrics"
    /// iCloud-Sync aktiv (nur App, UserDefaults.standard).
    static let iCloudSync = "income.iCloudSync"
    /// Vorberechnete Monatssummen für das Widget (App-Group).
    static let widgetSnapshot = "income.widgetSnapshot"
}
