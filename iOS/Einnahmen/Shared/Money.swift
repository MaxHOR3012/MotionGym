import Foundation

/// Geldbeträge werden intern als ganze Cent (`Int`) gespeichert –
/// keine Rundungsfehler, CloudKit-kompatibel und schnell summierbar.
enum Money {
    static let locale = Locale(identifier: "de_DE")
    static let currencyCode = "EUR"
    static let maskedText = "•••• €"

    // MARK: Umrechnung

    static func decimal(fromCents cents: Int) -> Decimal {
        Decimal(cents) / 100
    }

    static func euros(fromCents cents: Int) -> Double {
        Double(cents) / 100
    }

    static func cents(from decimal: Decimal) -> Int {
        var value = decimal * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    // MARK: Formatierung (de-DE)

    /// „1.234,56 €"
    static func format(cents: Int) -> String {
        decimal(fromCents: cents)
            .formatted(.currency(code: currencyCode).locale(locale))
    }

    /// „1.235 €" – für knappe Darstellungen (Kacheln, Diagrammachsen).
    static func formatRounded(cents: Int) -> String {
        decimal(fromCents: cents)
            .formatted(.currency(code: currencyCode).locale(locale).precision(.fractionLength(0)))
    }

    static func formatRounded(euros: Double) -> String {
        euros.formatted(.currency(code: currencyCode).locale(locale).precision(.fractionLength(0)))
    }

    /// „1234,56" – Vorbelegung für Eingabefelder (ohne Tausenderpunkt und €).
    static func editingString(cents: Int) -> String {
        guard cents != 0 else { return "" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: decimal(fromCents: cents) as NSDecimalNumber) ?? ""
    }

    // MARK: Eingabe parsen

    /// Akzeptiert „1234,56", „1.234,56", „1.234", „1234.56", „12 €" usw.
    /// Gibt `nil` zurück, wenn die Eingabe kein gültiger, nicht-negativer Betrag ist.
    static func parseCents(_ text: String) -> Int? {
        var normalized = text
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }

        if normalized.contains(",") {
            // Deutsches Format: Punkt = Tausender, Komma = Dezimal
            normalized = normalized
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        } else if normalized.range(of: #"^\d{1,3}(\.\d{3})+$"#, options: .regularExpression) != nil {
            // „1.234" bzw. „12.500" = Tausenderpunkte
            normalized = normalized.replacingOccurrences(of: ".", with: "")
        }

        guard normalized.range(of: #"^\d+(\.\d{1,2})?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
        else { return nil }

        return cents(from: value)
    }
}
