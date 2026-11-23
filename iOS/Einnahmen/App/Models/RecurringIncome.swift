import Foundation
import SwiftData

/// Vorlage für wiederkehrende Einnahmen (z. B. Gehalt, Miete, Quartalsdividende).
/// Der `RecurrenceService` erzeugt daraus konkrete `Income`-Termine.
@Model
final class RecurringIncome {
    var id: UUID = UUID()
    var amountCents: Int = 0
    var sourceRaw: String = IncomeSource.other.rawValue
    var intervalRaw: String = RecurrenceInterval.monthly.rawValue
    var startDate: Date = Date.now
    var endDate: Date?
    var note: String = ""
    var isActive: Bool = true
    /// Bis zu diesem Datum wurden Termine bereits erzeugt.
    /// Manuell gelöschte Termine werden dadurch nicht erneut angelegt.
    var generatedThrough: Date?
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Income.recurringIncome)
    var occurrences: [Income]? = []

    var position: PortfolioPosition?

    init(
        amountCents: Int,
        source: IncomeSource,
        interval: RecurrenceInterval,
        startDate: Date,
        endDate: Date? = nil,
        note: String = ""
    ) {
        self.id = UUID()
        self.amountCents = amountCents
        self.sourceRaw = source.rawValue
        self.intervalRaw = interval.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.note = note
        self.isActive = true
        self.createdAt = .now
    }

    var source: IncomeSource {
        get { IncomeSource(rawValue: sourceRaw) ?? .other }
        set { sourceRaw = newValue.rawValue }
    }

    var interval: RecurrenceInterval {
        get { RecurrenceInterval(rawValue: intervalRaw) ?? .monthly }
        set { intervalRaw = newValue.rawValue }
    }

    /// Nächster geplanter (noch nicht eingegangener) Termin.
    var nextPlannedDate: Date? {
        (occurrences ?? [])
            .filter { $0.isPlanned }
            .map(\.date)
            .min()
    }

    /// Auf einen Monat umgerechneter Betrag (für Übersichten).
    var monthlyEquivalentCents: Int {
        amountCents / interval.months
    }
}
