import Foundation
import SwiftData

/// Plant wiederkehrende Einnahmen automatisch voraus und bucht fällige Termine.
@MainActor
enum RecurrenceService {
    /// So weit im Voraus werden Termine angelegt.
    static let planningHorizonMonths = 12

    /// Beim App-Start und bei jeder Rückkehr in den Vordergrund aufrufen.
    static func refresh(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        bookDuePayments(in: context, now: now)

        let descriptor = FetchDescriptor<RecurringIncome>(
            predicate: #Predicate<RecurringIncome> { $0.isActive == true }
        )
        let activeSeries = (try? context.fetch(descriptor)) ?? []
        for series in activeSeries {
            generateOccurrences(for: series, in: context, now: now, calendar: calendar)
        }

        removeDuplicateOccurrences(in: context)
        save(context)
    }

    /// Geplante Termine, deren Datum erreicht ist, gelten als eingegangen.
    static func bookDuePayments(in context: ModelContext, now: Date = .now) {
        let descriptor = FetchDescriptor<Income>(
            predicate: #Predicate<Income> { income in
                income.isPlanned == true && income.date <= now
            }
        )
        for income in (try? context.fetch(descriptor)) ?? [] {
            income.isPlanned = false
        }
    }

    /// Legt alle fehlenden Termine einer Serie bis zum Planungshorizont an.
    static func generateOccurrences(
        for series: RecurringIncome,
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        guard series.isActive else { return }

        let horizon = calendar.date(byAdding: .month, value: planningHorizonMonths, to: now) ?? now
        let limit = min(series.endDate.map { calendar.endOfDay(for: $0) } ?? horizon, horizon)
        let dates = series.interval.occurrences(from: series.startDate, through: limit, calendar: calendar)

        let existingKeys = Set(
            (series.occurrences ?? [])
                .filter { !$0.isDeleted }
                .map(\.occurrenceKey)
        )
        let alreadyGeneratedThrough = series.generatedThrough

        for date in dates {
            if let alreadyGeneratedThrough, date <= alreadyGeneratedThrough { continue }
            let key = occurrenceKey(for: series, date: date, calendar: calendar)
            guard !existingKeys.contains(key) else { continue }

            let income = Income(
                amountCents: series.amountCents,
                source: series.source,
                date: date,
                note: series.note,
                isPlanned: date > now,
                occurrenceKey: key
            )
            context.insert(income)
            income.recurringIncome = series
            income.position = series.position
        }

        if limit > (series.generatedThrough ?? .distantPast) {
            series.generatedThrough = limit
        }
    }

    /// Nach dem Bearbeiten einer Serie: zukünftige geplante Termine neu aufbauen.
    /// Bereits eingegangene Einnahmen bleiben unverändert.
    static func rebuildFuture(
        for series: RecurringIncome,
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        for income in series.occurrences ?? [] where income.isPlanned && income.date > now {
            context.delete(income)
        }
        save(context)

        series.generatedThrough = now
        generateOccurrences(for: series, in: context, now: now, calendar: calendar)
        save(context)
    }

    /// Serie pausieren oder fortsetzen.
    static func setActive(_ isActive: Bool, for series: RecurringIncome, in context: ModelContext, now: Date = .now) {
        series.isActive = isActive
        rebuildFuture(for: series, in: context, now: now)
    }

    /// Löscht die Serie und ihre noch geplanten Termine.
    /// Bereits eingegangene Einnahmen bleiben als Einzelbuchungen erhalten.
    static func delete(_ series: RecurringIncome, in context: ModelContext) {
        for income in series.occurrences ?? [] where income.isPlanned {
            context.delete(income)
        }
        context.delete(series)
        save(context)
    }

    static func occurrenceKey(for series: RecurringIncome, date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%@-%04d-%02d-%02d", series.id.uuidString, c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Entfernt doppelte Termine, die entstehen können, wenn zwei Geräte
    /// gleichzeitig offline planen und später per iCloud synchronisieren.
    static func removeDuplicateOccurrences(in context: ModelContext) {
        let descriptor = FetchDescriptor<Income>(
            predicate: #Predicate<Income> { $0.occurrenceKey != "" }
        )
        guard let incomes = try? context.fetch(descriptor) else { return }

        let groups = Dictionary(grouping: incomes, by: \.occurrenceKey)
        for (_, group) in groups where group.count > 1 {
            let sorted = group.sorted { lhs, rhs in
                if lhs.isPlanned != rhs.isPlanned { return !lhs.isPlanned } // Gebuchte behalten
                return lhs.createdAt < rhs.createdAt
            }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
            }
        }
    }

    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            assertionFailure("Speichern fehlgeschlagen: \(error)")
        }
    }
}
