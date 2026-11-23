import Foundation

/// Reine Berechnungslogik für die Übersicht – ohne SwiftUI und ohne SwiftData,
/// dadurch leicht testbar (siehe `init(entries:)`).
///
/// Definitionen:
/// - **Diesen Monat**: alle Einnahmen im laufenden Monat (eingegangen + noch erwartet).
/// - **Vergleich**: Diesen Monat gegenüber dem gesamten Vormonat in Prozent.
/// - **Jahressumme**: 1. Januar bis Ende des laufenden Monats.
/// - **Ø pro Monat**: Jahressumme ÷ Anzahl Monate seit Januar
///   (bzw. seit der ersten Einnahme, falls diese später im Jahr liegt).
struct IncomeStatistics {
    struct Entry {
        let date: Date
        let cents: Int
        let source: IncomeSource
        let isPlanned: Bool
    }

    struct MonthBucket: Identifiable {
        let monthStart: Date
        let receivedCents: Int
        let plannedCents: Int
        var id: Date { monthStart }
        var totalCents: Int { receivedCents + plannedCents }
    }

    struct SourceSlice: Identifiable {
        let source: IncomeSource
        let cents: Int
        let share: Double
        var id: String { source.rawValue }
    }

    enum Period: String, CaseIterable, Identifiable {
        case month
        case year
        case last12Months

        var id: String { rawValue }

        var title: String {
            switch self {
            case .month: "Monat"
            case .year: "Jahr"
            case .last12Months: "12 Monate"
            }
        }
    }

    let now: Date
    let currentMonthTotal: Int
    let currentMonthPlanned: Int
    let previousMonthTotal: Int
    /// `nil`, wenn der Vormonat 0 € hatte (Prozentvergleich nicht sinnvoll).
    let changeVsPreviousMonth: Double?
    let yearTotal: Int
    let averagePerMonth: Int
    let monthlyBuckets: [MonthBucket]

    private let entries: [Entry]
    private let calendar: Calendar

    // MARK: Init

    init(
        incomes: [Income],
        now: Date = .now,
        calendar: Calendar = .current,
        pastMonths: Int = 12,
        futureMonths: Int = 3
    ) {
        self.init(
            entries: incomes.map {
                Entry(date: $0.date, cents: $0.amountCents, source: $0.source, isPlanned: $0.isPlanned)
            },
            now: now,
            calendar: calendar,
            pastMonths: pastMonths,
            futureMonths: futureMonths
        )
    }

    init(
        entries: [Entry],
        now: Date = .now,
        calendar: Calendar = .current,
        pastMonths: Int = 12,
        futureMonths: Int = 3
    ) {
        self.now = now
        self.entries = entries
        self.calendar = calendar

        let thisMonth = calendar.startOfMonth(for: now)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: thisMonth) ?? now
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth) ?? now
        let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? thisMonth

        currentMonthTotal = Self.sum(entries, from: thisMonth, to: nextMonth)
        currentMonthPlanned = Self.sum(entries, from: thisMonth, to: nextMonth, plannedOnly: true)
        previousMonthTotal = Self.sum(entries, from: lastMonth, to: thisMonth)
        changeVsPreviousMonth = previousMonthTotal > 0
            ? Double(currentMonthTotal - previousMonthTotal) / Double(previousMonthTotal)
            : nil

        yearTotal = Self.sum(entries, from: yearStart, to: nextMonth)

        // Monate zählen – ab Januar oder ab der ersten Einnahme in diesem Jahr
        let firstEntryThisYear = entries
            .filter { $0.date >= yearStart && $0.date < nextMonth }
            .map(\.date)
            .min()
        let countFrom = calendar.startOfMonth(for: firstEntryThisYear ?? thisMonth)
        let elapsed = (calendar.dateComponents([.month], from: countFrom, to: thisMonth).month ?? 0) + 1
        averagePerMonth = yearTotal / max(elapsed, 1)

        // Balken: letzte `pastMonths` Monate inkl. aktuellem + `futureMonths` Vorschau
        var buckets: [MonthBucket] = []
        for offset in -(max(pastMonths, 1) - 1)...max(futureMonths, 0) {
            guard let start = calendar.date(byAdding: .month, value: offset, to: thisMonth),
                  let end = calendar.date(byAdding: .month, value: 1, to: start)
            else { continue }
            buckets.append(MonthBucket(
                monthStart: start,
                receivedCents: Self.sum(entries, from: start, to: end, receivedOnly: true),
                plannedCents: Self.sum(entries, from: start, to: end, plannedOnly: true)
            ))
        }
        monthlyBuckets = buckets
    }

    // MARK: Abgeleitete Werte

    var monthTitle: String {
        now.formatted(.dateTime.month(.wide).year().locale(Money.locale))
    }

    var yearTitle: String {
        String(calendar.component(.year, from: now))
    }

    func goalProgress(goalCents: Int) -> Double {
        guard goalCents > 0 else { return 0 }
        return Double(currentMonthTotal) / Double(goalCents)
    }

    /// Anteile nach Quelle für das Kreisdiagramm, absteigend sortiert.
    func sourceSlices(for period: Period) -> [SourceSlice] {
        let (start, end) = dateRange(for: period)
        var totals: [IncomeSource: Int] = [:]
        for entry in entries where entry.date >= start && entry.date < end {
            totals[entry.source, default: 0] += entry.cents
        }
        let total = totals.values.reduce(0, +)
        guard total > 0 else { return [] }

        return totals
            .filter { $0.value > 0 }
            .map { SourceSlice(source: $0.key, cents: $0.value, share: Double($0.value) / Double(total)) }
            .sorted { $0.cents > $1.cents }
    }

    func dateRange(for period: Period) -> (start: Date, end: Date) {
        let thisMonth = calendar.startOfMonth(for: now)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: thisMonth) ?? now
        switch period {
        case .month:
            return (thisMonth, nextMonth)
        case .year:
            let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? thisMonth
            return (yearStart, nextMonth)
        case .last12Months:
            let start = calendar.date(byAdding: .month, value: -11, to: thisMonth) ?? thisMonth
            return (start, nextMonth)
        }
    }

    // MARK: Hilfsfunktion

    private static func sum(
        _ entries: [Entry],
        from start: Date,
        to end: Date,
        plannedOnly: Bool = false,
        receivedOnly: Bool = false
    ) -> Int {
        entries.reduce(0) { result, entry in
            guard entry.date >= start, entry.date < end else { return result }
            if plannedOnly && !entry.isPlanned { return result }
            if receivedOnly && entry.isPlanned { return result }
            return result + entry.cents
        }
    }
}
