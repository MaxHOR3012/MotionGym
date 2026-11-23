import Foundation
import Observation
import SwiftData

/// Filter, Suche und Monatsgruppierung für die Liste aller Einnahmen.
@Observable
@MainActor
final class IncomeListViewModel {
    struct MonthSection: Identifiable {
        let monthStart: Date
        let incomes: [Income]
        var id: Date { monthStart }
        var totalCents: Int { incomes.reduce(0) { $0 + $1.amountCents } }
        var title: String {
            monthStart.formatted(.dateTime.month(.wide).year().locale(Money.locale))
        }
    }

    var searchText = ""
    var sourceFilter: IncomeSource?
    var showPlanned = true

    var isFiltering: Bool {
        !searchText.isEmpty || sourceFilter != nil || !showPlanned
    }

    func sections(from incomes: [Income], calendar: Calendar = .current) -> [MonthSection] {
        let query = searchText.trimmingCharacters(in: .whitespaces)

        let filtered = incomes.filter { income in
            if !showPlanned && income.isPlanned { return false }
            if let sourceFilter, income.source != sourceFilter { return false }
            guard !query.isEmpty else { return true }
            return income.note.localizedCaseInsensitiveContains(query)
                || income.source.title.localizedCaseInsensitiveContains(query)
                || (income.position?.name.localizedCaseInsensitiveContains(query) ?? false)
        }

        let grouped = Dictionary(grouping: filtered) { calendar.startOfMonth(for: $0.date) }
        return grouped
            .map { MonthSection(monthStart: $0.key, incomes: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.monthStart > $1.monthStart }
    }

    func delete(_ income: Income, in context: ModelContext) {
        context.delete(income)
        try? context.save()
        WidgetSync.update(using: context)
    }
}
