import SwiftData
import SwiftUI

/// Eine Zeile in Listen: Symbol, Quelle, Datum/Notiz, Betrag.
struct IncomeRowView: View {
    let income: Income

    var body: some View {
        HStack(spacing: 12) {
            SourceIcon(source: income.source)

            VStack(alignment: .leading, spacing: 2) {
                Text(income.source.title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                AmountText(cents: income.amountCents)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(income.isPlanned ? Color.secondary : Color.primary)
                if income.isPlanned {
                    Label("erwartet", systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if income.recurringIncome != nil {
                    Label("wiederkehrend", systemImage: "repeat")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts = [income.date.formatted(.dateTime.day().month(.abbreviated).year().locale(Money.locale))]
        if let name = income.position?.name, !name.isEmpty { parts.append(name) }
        if !income.note.isEmpty { parts.append(income.note) }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    List {
        ForEach(PreviewData.sampleIncomes(limit: 6)) { income in
            IncomeRowView(income: income)
        }
    }
    .modelContainer(PreviewData.container)
}
