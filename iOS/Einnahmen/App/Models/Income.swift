import Foundation
import SwiftData

/// Eine einzelne Einnahme (einmalig oder Teil einer Serie).
///
/// CloudKit-Regeln: Jede Eigenschaft hat einen Standardwert oder ist optional,
/// keine `.unique`-Attribute, Beziehungen sind optional.
@Model
final class Income {
    var id: UUID = UUID()
    var amountCents: Int = 0
    var sourceRaw: String = IncomeSource.other.rawValue
    var date: Date = Date.now
    var note: String = ""
    /// `true` = vorausgeplant, noch nicht eingegangen.
    var isPlanned: Bool = false
    /// Eindeutiger Termin-Schlüssel einer Serie („<SerienID>-2026-11-28").
    /// Verhindert doppelte Termine – auch wenn zwei Geräte per iCloud gleichzeitig planen.
    var occurrenceKey: String = ""
    var createdAt: Date = Date.now

    var recurringIncome: RecurringIncome?
    var position: PortfolioPosition?

    /// Beziehungen bitte erst **nach** `context.insert(_:)` setzen.
    init(
        amountCents: Int,
        source: IncomeSource,
        date: Date,
        note: String = "",
        isPlanned: Bool = false,
        occurrenceKey: String = ""
    ) {
        self.id = UUID()
        self.amountCents = amountCents
        self.sourceRaw = source.rawValue
        self.date = date
        self.note = note
        self.isPlanned = isPlanned
        self.occurrenceKey = occurrenceKey
        self.createdAt = .now
    }

    var source: IncomeSource {
        get { IncomeSource(rawValue: sourceRaw) ?? .other }
        set { sourceRaw = newValue.rawValue }
    }

    var amount: Decimal { Money.decimal(fromCents: amountCents) }
}
