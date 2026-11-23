import Foundation

/// Rhythmus einer wiederkehrenden Einnahme.
enum RecurrenceInterval: String, CaseIterable, Identifiable, Codable {
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: "Monatlich"
        case .quarterly: "Vierteljährlich"
        case .yearly: "Jährlich"
        }
    }

    var months: Int {
        switch self {
        case .monthly: 1
        case .quarterly: 3
        case .yearly: 12
        }
    }

    /// Alle Termine ab `start` bis einschließlich `end`.
    ///
    /// Jeder Termin wird vom Startdatum aus berechnet (nicht vom Vortermin),
    /// damit z. B. der 31. nach einem Februar wieder auf den 31. fällt.
    func occurrences(from start: Date, through end: Date, calendar: Calendar = .current) -> [Date] {
        guard start <= end else { return [] }
        var result: [Date] = []
        var index = 0
        while index < 1_200,
              let next = calendar.date(byAdding: .month, value: index * months, to: start),
              next <= end {
            result.append(next)
            index += 1
        }
        return result
    }
}
