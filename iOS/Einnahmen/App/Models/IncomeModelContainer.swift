import Foundation
import SwiftData

/// Erzeugt den SwiftData-Container – lokal oder mit iCloud-Sync (CloudKit).
enum IncomeModelContainer {
    static var schema: Schema {
        Schema([Income.self, RecurringIncome.self, PortfolioPosition.self])
    }

    /// Wird in den Einstellungen umgeschaltet und wirkt nach einem Neustart der App.
    static var isCloudSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.iCloudSync)
    }

    static func make(inMemory: Bool = false) -> ModelContainer {
        let cloudKit: ModelConfiguration.CloudKitDatabase =
            (!inMemory && isCloudSyncEnabled) ? .automatic : .none

        let configuration = ModelConfiguration(
            "Einnahmen",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            groupContainer: .none,          // Datenbank bleibt in der App-Sandbox
            cloudKitDatabase: cloudKit      // .automatic = private iCloud-Datenbank
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("SwiftData-Container konnte nicht erstellt werden: \(error)")
        }
    }
}
