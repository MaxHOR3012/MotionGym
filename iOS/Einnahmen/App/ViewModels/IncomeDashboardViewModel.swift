import Foundation
import Observation
import SwiftData

/// Zustand und Aktionen der Übersicht.
/// Die Daten selbst kommen per `@Query` aus der View – so aktualisiert SwiftUI
/// automatisch, auch wenn iCloud im Hintergrund Änderungen einspielt.
@Observable
@MainActor
final class IncomeDashboardViewModel {
    enum Sheet: String, Identifiable {
        case newIncome
        case newRecurring
        case goal
        case settings

        var id: String { rawValue }
    }

    var activeSheet: Sheet?
    var editingIncome: Income?
    var piePeriod: IncomeStatistics.Period = .year

    func statistics(for incomes: [Income], now: Date = .now) -> IncomeStatistics {
        IncomeStatistics(incomes: incomes, now: now)
    }

    func recentIncomes(from incomes: [Income], limit: Int = 5) -> [Income] {
        Array(
            incomes
                .filter { !$0.isPlanned }
                .sorted { $0.date > $1.date }
                .prefix(limit)
        )
    }

    func upcomingIncomes(from incomes: [Income], limit: Int = 3) -> [Income] {
        Array(
            incomes
                .filter { $0.isPlanned }
                .sorted { $0.date < $1.date }
                .prefix(limit)
        )
    }

    /// Prüfsumme, um Änderungen (auch aus iCloud) zu erkennen und das Widget zu aktualisieren.
    func fingerprint(of incomes: [Income]) -> Int {
        incomes.reduce(incomes.count) { partial, income in
            partial &+ income.amountCents &+ Int(income.date.timeIntervalSince1970) &+ (income.isPlanned ? 1 : 0)
        }
    }

    func incomesDidChange(in context: ModelContext) {
        WidgetSync.update(using: context)
    }

    func delete(_ income: Income, in context: ModelContext) {
        context.delete(income)
        try? context.save()
        WidgetSync.update(using: context)
    }
}
