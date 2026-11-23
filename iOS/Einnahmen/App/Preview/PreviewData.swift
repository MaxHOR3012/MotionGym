import Foundation
import SwiftData

/// Beispieldaten für SwiftUI-Vorschauen (nur im Arbeitsspeicher).
/// Enthält 13 Monate Historie, wiederkehrende Serien und Portfolio-Positionen.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let container = IncomeModelContainer.make(inMemory: true)
        seed(into: container.mainContext)
        // Nur für Vorschauen: Monatsziel vorbelegen (wird nicht gespeichert)
        AppGroup.defaults.register(defaults: [SettingsKey.monthlyGoalCents: 450_000])
        return container
    }()

    static var statistics: IncomeStatistics {
        IncomeStatistics(incomes: allIncomes)
    }

    static var allIncomes: [Income] {
        let descriptor = FetchDescriptor<Income>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }

    static func sampleIncomes(limit: Int) -> [Income] {
        Array(allIncomes.filter { !$0.isPlanned }.prefix(limit))
    }

    static var samplePosition: PortfolioPosition {
        let descriptor = FetchDescriptor<PortfolioPosition>(sortBy: [SortDescriptor(\.name)])
        if let position = (try? container.mainContext.fetch(descriptor))?.first {
            return position
        }
        return PortfolioPosition(name: "Beispiel-ETF", kind: .etf)
    }

    static func seed(into context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        let thisMonth = calendar.startOfMonth(for: now)

        func date(monthsAgo: Int, day: Int) -> Date {
            let month = calendar.date(byAdding: .month, value: -monthsAgo, to: thisMonth) ?? thisMonth
            return calendar.date(byAdding: .day, value: day - 1, to: month) ?? month
        }

        // Portfolio
        let etf = PortfolioPosition(name: "MSCI World ETF", identifier: "IE00B4L5Y983", kind: .etf)
        let allianz = PortfolioPosition(name: "Allianz SE", identifier: "DE0008404005", kind: .stock)
        let tagesgeld = PortfolioPosition(name: "Tagesgeld", identifier: "DE02 1203 0000 0000 2020 51", kind: .savings)
        for position in [etf, allianz, tagesgeld] { context.insert(position) }

        // Wiederkehrende Einnahmen
        let salary = RecurringIncome(amountCents: 3_250_00, source: .salary, interval: .monthly,
                                     startDate: date(monthsAgo: 13, day: 27), note: "Nettogehalt")
        let rent = RecurringIncome(amountCents: 650_00, source: .rent, interval: .monthly,
                                   startDate: date(monthsAgo: 13, day: 3), note: "Wohnung Lindenstraße")
        let etfDividend = RecurringIncome(amountCents: 84_30, source: .dividend, interval: .quarterly,
                                          startDate: date(monthsAgo: 12, day: 15), note: "Quartalsausschüttung")
        let interest = RecurringIncome(amountCents: 41_20, source: .interest, interval: .monthly,
                                       startDate: date(monthsAgo: 13, day: 1), note: "Zinsgutschrift")
        for series in [salary, rent, etfDividend, interest] { context.insert(series) }
        etfDividend.position = etf
        interest.position = tagesgeld
        etf.lastPayoutCents = 84_30
        tagesgeld.lastPayoutCents = 41_20

        // Einmalige Einnahmen
        let oneTime: [(Int, IncomeSource, Int, Int, String, PortfolioPosition?)] = [
            (690_00, .dividend, 7, 12, "Dividende Hauptversammlung", allianz),
            (1_200_00, .sale, 4, 20, "E-Bike verkauft", nil),
            (2_100_00, .salary, 5, 27, "Urlaubsgeld", nil),
            (480_00, .other, 2, 9, "Steuererstattung", nil),
            (85_00, .sale, 1, 14, "Kleinanzeigen", nil),
            (3_050_00, .salary, 0, 27, "Weihnachtsgeld", nil),
        ]
        for (cents, source, monthsAgo, day, note, position) in oneTime {
            let incomeDate = date(monthsAgo: monthsAgo, day: day)
            let income = Income(amountCents: cents, source: source, date: incomeDate, note: note, isPlanned: incomeDate > now)
            context.insert(income)
            income.position = position
        }
        allianz.lastPayoutCents = 690_00

        RecurrenceService.refresh(in: context, now: now)
    }
}
