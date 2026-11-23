import SwiftUI
import WidgetKit

// MARK: - Eintrag

struct IncomeEntry: TimelineEntry {
    let date: Date
    let monthCents: Int
    let previousMonthCents: Int
    let goalCents: Int
    let hideAmounts: Bool

    var progress: Double {
        goalCents > 0 ? Double(monthCents) / Double(goalCents) : 0
    }

    var changeVsPreviousMonth: Double? {
        previousMonthCents > 0 ? Double(monthCents - previousMonthCents) / Double(previousMonthCents) : nil
    }

    var amountText: String {
        hideAmounts ? Money.maskedText : Money.format(cents: monthCents)
    }

    var monthName: String {
        date.formatted(.dateTime.month(.wide).locale(Money.locale))
    }

    var progressText: String {
        progress.formatted(.percent.precision(.fractionLength(0)).locale(Money.locale))
    }

    static let placeholder = IncomeEntry(
        date: .now,
        monthCents: 4_125_50,
        previousMonthCents: 3_980_00,
        goalCents: 4_500_00,
        hideAmounts: false
    )
}

// MARK: - Timeline

struct IncomeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> IncomeEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (IncomeEntry) -> Void) {
        completion(context.isPreview ? .placeholder : makeEntry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IncomeEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date.now
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: calendar.startOfMonth(for: now))
            ?? now.addingTimeInterval(86_400)

        // Jetzt + automatischer Wechsel am Monatsersten (Summen liegen im Snapshot bereits vor).
        let entries = [makeEntry(for: now), makeEntry(for: nextMonth)]
        completion(Timeline(entries: entries, policy: .after(nextMonth)))
    }

    private func makeEntry(for date: Date) -> IncomeEntry {
        let snapshot = IncomeWidgetSnapshot.load()
        let defaults = AppGroup.defaults
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: date) ?? date

        return IncomeEntry(
            date: date,
            monthCents: snapshot?.total(for: date) ?? 0,
            previousMonthCents: snapshot?.total(for: previousMonth) ?? 0,
            goalCents: defaults.integer(forKey: SettingsKey.monthlyGoalCents),
            hideAmounts: defaults.bool(forKey: SettingsKey.hideAmounts)
        )
    }
}

// MARK: - Ansichten

struct IncomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: IncomeEntry

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text("Einnahmen: \(entry.amountText)")
                .privacySensitive()
        case .accessoryCircular:
            Gauge(value: min(entry.progress, 1)) {
                Image(systemName: "eurosign")
            } currentValueLabel: {
                Text(entry.goalCents > 0 ? entry.progressText : "–")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Einnahmen \(entry.monthName)")
                    .font(.caption)
                    .widgetAccentable()
                Text(entry.amountText)
                    .font(.headline)
                    .privacySensitive()
                if entry.goalCents > 0 {
                    ProgressView(value: min(entry.progress, 1))
                }
            }
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "eurosign.circle.fill")
                .foregroundStyle(.green)
            Text("Einnahmen")
                .font(.caption.weight(.semibold))
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Text(entry.monthName)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(entry.amountText)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .privacySensitive()
            if entry.goalCents > 0 {
                ProgressView(value: min(entry.progress, 1))
                    .tint(entry.progress >= 1 ? Color.green : Color.accentColor)
                Text("\(entry.progressText) vom Ziel")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            smallView

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vormonat")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.hideAmounts ? Money.maskedText : Money.formatRounded(cents: entry.previousMonthCents))
                        .font(.subheadline.weight(.semibold))
                        .privacySensitive()
                    if let change = entry.changeVsPreviousMonth {
                        Label(
                            change.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()).locale(Money.locale)),
                            systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(change >= 0 ? Color.green : Color.red)
                    }
                }
                if entry.goalCents > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monatsziel")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(entry.hideAmounts ? Money.maskedText : Money.formatRounded(cents: entry.goalCents))
                            .font(.subheadline.weight(.semibold))
                            .privacySensitive()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Widget

struct IncomeWidget: Widget {
    let kind = "IncomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IncomeTimelineProvider()) { entry in
            IncomeWidgetView(entry: entry)
                .environment(\.locale, Money.locale)
        }
        .configurationDisplayName("Einnahmen")
        .description("Summe deiner Einnahmen im aktuellen Monat.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

#Preview(as: .systemSmall) {
    IncomeWidget()
} timeline: {
    IncomeEntry.placeholder
    IncomeEntry(date: .now, monthCents: 4_125_50, previousMonthCents: 3_980_00, goalCents: 4_500_00, hideAmounts: true)
}

#Preview(as: .systemMedium) {
    IncomeWidget()
} timeline: {
    IncomeEntry.placeholder
}
