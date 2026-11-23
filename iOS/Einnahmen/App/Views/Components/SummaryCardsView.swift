import SwiftUI

/// Kennzahlen: Monatssumme, Vergleich zum Vormonat, Jahressumme, Ø pro Monat.
/// Ein Tipp auf die große Karte blendet alle Beträge aus bzw. ein.
struct SummaryCardsView: View {
    let stats: IncomeStatistics
    var onToggleVisibility: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Diesen Monat")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(stats.monthTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                AmountText(cents: stats.currentMonthTotal)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))

                if stats.currentMonthPlanned > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("davon")
                        AmountText(cents: stats.currentMonthPlanned)
                        Text("noch erwartet")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                ChangeBadge(change: stats.changeVsPreviousMonth)
                    .padding(.top, 2)
            }
            .card()
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggleVisibility)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Tippen, um Beträge ein- oder auszublenden")

            HStack(spacing: 12) {
                StatTile(title: "Vormonat", systemImage: "calendar", cents: stats.previousMonthTotal)
                StatTile(title: "Jahr \(stats.yearTitle)", systemImage: "sum", cents: stats.yearTotal)
                StatTile(title: "Ø / Monat", systemImage: "chart.bar.xaxis", cents: stats.averagePerMonth)
            }
        }
    }
}

struct StatTile: View {
    let title: String
    let systemImage: String
    let cents: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            AmountText(cents: cents, rounded: true)
                .font(.system(.headline, design: .rounded))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}

#Preview {
    SummaryCardsView(stats: PreviewData.statistics)
        .padding()
        .background(Color(.systemGroupedBackground))
        .modelContainer(PreviewData.container)
}
