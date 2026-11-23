import Charts
import SwiftUI

/// Kreis-/Ringdiagramm: Verteilung der Einnahmen nach Quelle.
struct SourcePieChartView: View {
    let slices: [IncomeStatistics.SourceSlice]
    @Binding var period: IncomeStatistics.Period

    private var totalCents: Int {
        slices.reduce(0) { $0 + $1.cents }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nach Quelle", systemImage: "chart.pie.fill")
                .font(.headline)

            Picker("Zeitraum", selection: $period) {
                ForEach(IncomeStatistics.Period.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .pickerStyle(.segmented)

            if slices.isEmpty {
                ContentUnavailableView(
                    "Keine Einnahmen",
                    systemImage: "chart.pie",
                    description: Text("Für diesen Zeitraum gibt es noch keine Einnahmen.")
                )
                .frame(height: 200)
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Betrag", Money.euros(fromCents: slice.cents)),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(slice.source.color)
                }
                .chartLegend(.hidden)
                .chartBackground { proxy in
                    GeometryReader { geometry in
                        if let plotFrame = proxy.plotFrame {
                            let frame = geometry[plotFrame]
                            VStack(spacing: 2) {
                                Text("Gesamt")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                AmountText(cents: totalCents, rounded: true)
                                    .font(.system(.headline, design: .rounded))
                            }
                            .frame(width: frame.width * 0.55)
                            .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                .frame(height: 210)
                .animation(.easeInOut, value: period)

                VStack(spacing: 10) {
                    ForEach(slices) { slice in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(slice.source.color)
                                .frame(width: 10, height: 10)
                            Text(slice.source.title)
                            Spacer()
                            Text(slice.share.formatted(.percent.precision(.fractionLength(0)).locale(Money.locale)))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            AmountText(cents: slice.cents)
                                .frame(minWidth: 96, alignment: .trailing)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .card()
    }
}

#Preview {
    SourcePieChartView(slices: PreviewData.statistics.sourceSlices(for: .year), period: .constant(.year))
        .padding()
        .background(Color(.systemGroupedBackground))
}
