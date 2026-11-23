import Charts
import SwiftUI

/// Balkendiagramm: Einnahmen pro Monat (eingegangen + erwartet), mit Ziellinie.
/// Antippen/Ziehen über das Diagramm zeigt den Wert eines Monats.
struct MonthlyBarChartView: View {
    let buckets: [IncomeStatistics.MonthBucket]
    let goalCents: Int

    @AppStorage(SettingsKey.hideAmounts, store: AppGroup.defaults)
    var hideAmounts = false

    @State var selectedMonth: Date?

    private var selectedBucket: IncomeStatistics.MonthBucket? {
        guard let selectedMonth else { return nil }
        return buckets.first {
            Calendar.current.isDate($0.monthStart, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Pro Monat", systemImage: "chart.bar.fill")
                    .font(.headline)
                Spacer()
                if let bucket = selectedBucket {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(bucket.monthStart.formatted(.dateTime.month(.wide).year().locale(Money.locale)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        AmountText(cents: bucket.totalCents)
                            .font(.subheadline.weight(.semibold))
                    }
                } else {
                    Text("Tippen für Details")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Chart {
                ForEach(buckets) { bucket in
                    BarMark(
                        x: .value("Monat", bucket.monthStart, unit: .month),
                        y: .value("Betrag", Money.euros(fromCents: bucket.receivedCents))
                    )
                    .foregroundStyle(by: .value("Status", "Eingegangen"))
                    .opacity(isDimmed(bucket) ? 0.35 : 1)

                    BarMark(
                        x: .value("Monat", bucket.monthStart, unit: .month),
                        y: .value("Betrag", Money.euros(fromCents: bucket.plannedCents))
                    )
                    .foregroundStyle(by: .value("Status", "Erwartet"))
                    .opacity(isDimmed(bucket) ? 0.35 : 1)
                }

                if goalCents > 0 {
                    RuleMark(y: .value("Ziel", Money.euros(fromCents: goalCents)))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(Color.green)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Ziel")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.green)
                        }
                }
            }
            .chartForegroundStyleScale([
                "Eingegangen": Color.accentColor,
                "Erwartet": Color.accentColor.opacity(0.35),
            ])
            .chartXSelection(value: $selectedMonth)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let euros = value.as(Double.self) {
                            Text(hideAmounts ? "" : Money.formatRounded(euros: euros))
                        }
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 220)
            .environment(\.locale, Money.locale)
            .accessibilityLabel("Balkendiagramm der Einnahmen pro Monat")
        }
        .card()
    }

    private func isDimmed(_ bucket: IncomeStatistics.MonthBucket) -> Bool {
        guard let selected = selectedBucket else { return false }
        return selected.id != bucket.id
    }
}

#Preview {
    MonthlyBarChartView(buckets: PreviewData.statistics.monthlyBuckets, goalCents: 450_000)
        .padding()
        .background(Color(.systemGroupedBackground))
}
