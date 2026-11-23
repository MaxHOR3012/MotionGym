import SwiftUI

/// Herkunft einer Einnahme.
enum IncomeSource: String, CaseIterable, Identifiable, Codable {
    case salary
    case dividend
    case interest
    case rent
    case sale
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .salary: "Gehalt"
        case .dividend: "Dividende"
        case .interest: "Zinsen"
        case .rent: "Mieteinnahmen"
        case .sale: "Verkauf"
        case .other: "Sonstiges"
        }
    }

    var symbol: String {
        switch self {
        case .salary: "briefcase.fill"
        case .dividend: "chart.line.uptrend.xyaxis"
        case .interest: "percent"
        case .rent: "house.fill"
        case .sale: "cart.fill"
        case .other: "ellipsis"
        }
    }

    /// Systemfarben passen sich automatisch an Hell-/Dunkelmodus an.
    var color: Color {
        switch self {
        case .salary: .blue
        case .dividend: .green
        case .interest: .teal
        case .rent: .orange
        case .sale: .purple
        case .other: .gray
        }
    }

    /// Kann direkt aus einer Portfolio-Position verbucht werden.
    var isPortfolioPayout: Bool {
        self == .dividend || self == .interest
    }
}
