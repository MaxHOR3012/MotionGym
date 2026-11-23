import Foundation

/// Kleiner Datenauszug, den die App für das Widget in die App-Group schreibt.
///
/// Das Widget greift dadurch nicht selbst auf SwiftData/CloudKit zu –
/// das ist schneller, stromsparender und braucht im Widget keine iCloud-Rechte.
/// Enthalten sind die Summen (gebucht + geplant) vom Vormonat bis 12 Monate
/// im Voraus, damit das Widget auch zum Monatswechsel ohne App-Start stimmt.
struct IncomeWidgetSnapshot: Codable {
    /// Schlüssel „yyyy-MM" → Summe in Cent
    var monthlyTotals: [String: Int]
    var updatedAt: Date

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    func total(for date: Date, calendar: Calendar = .current) -> Int? {
        monthlyTotals[Self.monthKey(for: date, calendar: calendar)]
    }

    static func load() -> IncomeWidgetSnapshot? {
        guard let data = AppGroup.defaults.data(forKey: SettingsKey.widgetSnapshot) else { return nil }
        return try? JSONDecoder().decode(IncomeWidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        AppGroup.defaults.set(data, forKey: SettingsKey.widgetSnapshot)
    }
}
