import Foundation
import SwiftData

/// Art einer Portfolio-Position.
enum PositionKind: String, CaseIterable, Identifiable, Codable {
    case stock
    case etf
    case bond
    case savings
    case realEstate
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stock: "Aktie"
        case .etf: "ETF / Fonds"
        case .bond: "Anleihe"
        case .savings: "Tages-/Festgeld"
        case .realEstate: "Immobilie"
        case .other: "Sonstiges"
        }
    }

    var symbol: String {
        switch self {
        case .stock: "building.columns.fill"
        case .etf: "chart.pie.fill"
        case .bond: "doc.text.fill"
        case .savings: "banknote.fill"
        case .realEstate: "house.fill"
        case .other: "square.stack.fill"
        }
    }

    /// Welche Einnahmeart typischerweise aus dieser Position kommt.
    var defaultSource: IncomeSource {
        switch self {
        case .stock, .etf: .dividend
        case .bond, .savings: .interest
        case .realEstate: .rent
        case .other: .other
        }
    }
}

/// Eine Position im Geld-Portfolio, aus der Dividenden/Zinsen verbucht werden.
///
/// Hast du in deiner App schon ein eigenes Positions-Modell, kannst du statt
/// dieser Klasse dort die beiden Beziehungen `incomes` und `recurringIncomes`
/// ergänzen und `Income.position` / `RecurringIncome.position` auf deinen Typ ändern.
@Model
final class PortfolioPosition {
    var id: UUID = UUID()
    var name: String = ""
    /// ISIN, WKN, IBAN o. Ä. (optional)
    var identifier: String = ""
    var kindRaw: String = PositionKind.other.rawValue
    /// Letzte verbuchte Ausschüttung – wird beim nächsten Verbuchen vorgeschlagen.
    var lastPayoutCents: Int = 0
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Income.position)
    var incomes: [Income]? = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringIncome.position)
    var recurringIncomes: [RecurringIncome]? = []

    init(name: String, identifier: String = "", kind: PositionKind) {
        self.id = UUID()
        self.name = name
        self.identifier = identifier
        self.kindRaw = kind.rawValue
        self.createdAt = .now
    }

    var kind: PositionKind {
        get { PositionKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    /// Summe aller bereits eingegangenen Ausschüttungen.
    var receivedCents: Int {
        (incomes ?? [])
            .filter { !$0.isPlanned }
            .reduce(0) { $0 + $1.amountCents }
    }

    func receivedCents(inYearOf date: Date, calendar: Calendar = .current) -> Int {
        (incomes ?? [])
            .filter { !$0.isPlanned && calendar.isDate($0.date, equalTo: date, toGranularity: .year) }
            .reduce(0) { $0 + $1.amountCents }
    }
}
