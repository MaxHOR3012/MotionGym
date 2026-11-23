import SwiftData
import SwiftUI

/// Beispiel-Einstiegspunkt.
///
/// ⚠️ Hat dein Projekt bereits eine `@main`-App, diese Datei **nicht** hinzufügen,
/// sondern dort nur `.modelContainer(IncomeModelContainer.make())` an die
/// `WindowGroup` hängen und `IncomeRootView()` z. B. als Tab einbinden.
@main
struct EinnahmenApp: App {
    private let container = IncomeModelContainer.make()

    var body: some Scene {
        WindowGroup {
            IncomeRootView()
                .environment(\.locale, Money.locale)
        }
        .modelContainer(container)
    }
}
