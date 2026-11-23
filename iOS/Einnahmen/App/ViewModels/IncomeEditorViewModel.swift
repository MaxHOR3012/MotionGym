import Foundation
import Observation
import SwiftData

/// Erfassen und Bearbeiten von Einnahmen und wiederkehrenden Serien.
@Observable
@MainActor
final class IncomeEditorViewModel {
    enum Mode {
        case create
        case editIncome(Income)
        case editSeries(RecurringIncome)
    }

    let mode: Mode

    var amountText = ""
    var source: IncomeSource = .salary
    var date: Date = .now
    var note = ""
    var position: PortfolioPosition?

    var isRecurring = false
    var interval: RecurrenceInterval = .monthly
    var hasEndDate = false
    var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now

    /// - Parameters:
    ///   - startRecurring: Neue Einnahme direkt als wiederkehrend anlegen.
    ///   - presetSource: Vorbelegte Quelle (z. B. `.dividend` aus dem Portfolio).
    ///   - position: Portfolio-Position, aus der verbucht wird.
    init(
        mode: Mode = .create,
        startRecurring: Bool = false,
        presetSource: IncomeSource? = nil,
        position: PortfolioPosition? = nil
    ) {
        self.mode = mode

        switch mode {
        case .create:
            isRecurring = startRecurring
            self.position = position
            if let position {
                source = presetSource ?? position.kind.defaultSource
                if position.lastPayoutCents > 0 {
                    amountText = Money.editingString(cents: position.lastPayoutCents)
                }
            } else if let presetSource {
                source = presetSource
            }

        case .editIncome(let income):
            amountText = Money.editingString(cents: income.amountCents)
            source = income.source
            date = income.date
            note = income.note
            self.position = income.position

        case .editSeries(let series):
            amountText = Money.editingString(cents: series.amountCents)
            source = series.source
            date = series.startDate
            note = series.note
            self.position = series.position
            isRecurring = true
            interval = series.interval
            if let seriesEnd = series.endDate {
                hasEndDate = true
                endDate = seriesEnd
            }
        }
    }

    // MARK: Abgeleitete Werte

    var amountCents: Int? { Money.parseCents(amountText) }

    var showsAmountError: Bool {
        !amountText.trimmingCharacters(in: .whitespaces).isEmpty && amountCents == nil
    }

    var canSave: Bool {
        guard let cents = amountCents, cents > 0 else { return false }
        if isRecurring && hasEndDate && endDate < date { return false }
        return true
    }

    var isNew: Bool {
        switch mode {
        case .create: return true
        default: return false
        }
    }

    var isSeries: Bool {
        switch mode {
        case .editSeries: return true
        default: return false
        }
    }

    var isSeriesOccurrence: Bool {
        switch mode {
        case .editIncome(let income): return income.recurringIncome != nil
        default: return false
        }
    }

    var canToggleRecurring: Bool { isNew }
    var showsRecurrenceSection: Bool { isNew || isSeries }
    var canDelete: Bool { !isNew }

    var title: String {
        switch mode {
        case .create:
            if position != nil { return "Ausschüttung verbuchen" }
            return isRecurring ? "Wiederkehrende Einnahme" : "Neue Einnahme"
        case .editIncome:
            return "Einnahme bearbeiten"
        case .editSeries:
            return "Serie bearbeiten"
        }
    }

    var dateLabel: String { isRecurring ? "Erste Zahlung" : "Datum" }

    var deleteTitle: String { isSeries ? "Serie löschen" : "Einnahme löschen" }

    var deleteMessage: String {
        isSeries
            ? "Geplante, noch nicht eingegangene Zahlungen werden entfernt. Bereits eingegangene Einnahmen bleiben erhalten."
            : "Diese Einnahme wird dauerhaft gelöscht."
    }

    /// Vorschau der nächsten Termine im Formular.
    var recurrenceSummary: String {
        guard isRecurring else { return "" }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let farFuture = calendar.date(byAdding: .year, value: 4, to: max(date, .now)) ?? date
        let end = hasEndDate ? calendar.endOfDay(for: endDate) : farFuture

        let next = interval
            .occurrences(from: date, through: end, calendar: calendar)
            .filter { $0 >= today }
            .prefix(3)
            .map { $0.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(Money.locale)) }

        let planning = "Termine werden \(RecurrenceService.planningHorizonMonths) Monate im Voraus geplant und am Fälligkeitstag automatisch verbucht."
        guard !next.isEmpty else { return planning }
        return "Nächste Zahlungen: \(next.joined(separator: ", ")).\n\(planning)"
    }

    // MARK: Aktionen

    func save(in context: ModelContext, now: Date = .now) {
        guard let cents = amountCents, cents > 0 else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .create where isRecurring:
            let series = RecurringIncome(
                amountCents: cents,
                source: source,
                interval: interval,
                startDate: date,
                endDate: hasEndDate ? endDate : nil,
                note: trimmedNote
            )
            context.insert(series)
            series.position = position
            RecurrenceService.generateOccurrences(for: series, in: context, now: now)

        case .create:
            let income = Income(
                amountCents: cents,
                source: source,
                date: date,
                note: trimmedNote,
                isPlanned: date > now
            )
            context.insert(income)
            income.position = position

        case .editIncome(let income):
            income.amountCents = cents
            income.source = source
            income.date = date
            income.note = trimmedNote
            income.position = position
            income.isPlanned = date > now

        case .editSeries(let series):
            series.amountCents = cents
            series.source = source
            series.interval = interval
            series.startDate = date
            series.endDate = hasEndDate ? endDate : nil
            series.note = trimmedNote
            series.position = position
            RecurrenceService.rebuildFuture(for: series, in: context, now: now)
        }

        // Betrag für das nächste Verbuchen aus dieser Position merken
        if let position, source.isPortfolioPayout {
            position.lastPayoutCents = cents
        }

        try? context.save()
        WidgetSync.update(using: context)
    }

    func delete(in context: ModelContext) {
        switch mode {
        case .create:
            return
        case .editIncome(let income):
            context.delete(income)
        case .editSeries(let series):
            RecurrenceService.delete(series, in: context)
        }
        try? context.save()
        WidgetSync.update(using: context)
    }
}
