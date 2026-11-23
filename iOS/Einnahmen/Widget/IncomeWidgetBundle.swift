import SwiftUI
import WidgetKit

/// Einstiegspunkt der Widget-Extension.
///
/// ⚠️ Hast du bereits eine Widget-Extension mit eigenem `@main`-Bundle,
/// diese Datei weglassen und dort nur `IncomeWidget()` in den `body` aufnehmen.
@main
struct IncomeWidgetBundle: WidgetBundle {
    var body: some Widget {
        IncomeWidget()
    }
}
