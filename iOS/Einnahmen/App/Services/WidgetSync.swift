import Foundation
import SwiftData
import WidgetKit

/// Schreibt Monatssummen für das Home-Bildschirm-Widget in die App-Group.
@MainActor
enum WidgetSync {
    static func update(using context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let thisMonth = calendar.startOfMonth(for: now)
        guard let start = calendar.date(byAdding: .month, value: -2, to: thisMonth),
              let end = calendar.date(byAdding: .month, value: 14, to: thisMonth)
        else { return }

        let descriptor = FetchDescriptor<Income>(
            predicate: #Predicate<Income> { $0.date >= start && $0.date < end }
        )
        let incomes = (try? context.fetch(descriptor)) ?? []

        var totals: [String: Int] = [:]
        for income in incomes {
            totals[IncomeWidgetSnapshot.monthKey(for: income.date, calendar: calendar), default: 0] += income.amountCents
        }

        IncomeWidgetSnapshot(monthlyTotals: totals, updatedAt: now).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Nur neu zeichnen (z. B. nach Änderung von Ziel oder „Beträge ausblenden").
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
