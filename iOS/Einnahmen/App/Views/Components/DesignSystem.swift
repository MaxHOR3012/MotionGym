import SwiftUI

// MARK: - Karte

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }
}

extension View {
    /// Einheitlicher Karten-Look, funktioniert in Hell- und Dunkelmodus.
    func card() -> some View {
        modifier(CardBackground())
    }
}

// MARK: - Betrag (mit Privatsphäre-Modus)

/// Zeigt einen Betrag im de-DE-Format – oder „•••• €", wenn Beträge ausgeblendet sind.
struct AmountText: View {
    let cents: Int
    var rounded = false

    @AppStorage(SettingsKey.hideAmounts, store: AppGroup.defaults)
    var hideAmounts = false

    var body: some View {
        Text(displayText)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
            .privacySensitive()
            .accessibilityLabel(hideAmounts ? "Betrag ausgeblendet" : displayText)
    }

    private var displayText: String {
        if hideAmounts { return Money.maskedText }
        return rounded ? Money.formatRounded(cents: cents) : Money.format(cents: cents)
    }
}

// MARK: - Quellen-Symbol

struct SourceIcon: View {
    let source: IncomeSource
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: source.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(source.color.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Veränderung zum Vormonat

struct ChangeBadge: View {
    let change: Double?

    var body: some View {
        if let change {
            let isUp = change >= 0
            HStack(spacing: 4) {
                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                Text(change.formatted(
                    .percent
                        .precision(.fractionLength(0...1))
                        .sign(strategy: .always())
                        .locale(Money.locale)
                ))
                Text("ggü. Vormonat")
                    .foregroundStyle(Color.secondary)
                    .fontWeight(.regular)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isUp ? Color.green : Color.red)
        } else {
            Text("Kein Vergleich zum Vormonat möglich")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Navigationszeile in Karten

struct CardLinkRow: View {
    let title: String
    let systemImage: String
    var detail: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 28)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview("Bausteine") {
    VStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
            AmountText(cents: 412_550).font(.largeTitle.bold())
            ChangeBadge(change: 0.084)
            ChangeBadge(change: -0.12)
            ChangeBadge(change: nil)
        }
        .card()
        HStack {
            ForEach(IncomeSource.allCases) { SourceIcon(source: $0) }
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
