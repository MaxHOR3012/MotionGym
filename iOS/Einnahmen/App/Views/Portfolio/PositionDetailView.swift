import SwiftData
import SwiftUI

/// Detail einer Position: Summen, Ausschüttung verbuchen, Verlauf.
struct PositionDetailView: View {
    @Environment(\.modelContext) private var context
    let position: PortfolioPosition

    @State private var bookingSource: IncomeSource?
    @State private var editingIncome: Income?
    @State private var showingEditor = false

    private var payouts: [Income] {
        (position.incomes ?? []).sorted { $0.date > $1.date }
    }

    private var yearString: String {
        String(Calendar.current.component(.year, from: .now))
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Art", value: position.kind.title)
                if !position.identifier.isEmpty {
                    LabeledContent("Kennung", value: position.identifier)
                }
                LabeledContent("Erhalten \(yearString)") {
                    AmountText(cents: position.receivedCents(inYearOf: .now))
                }
                LabeledContent("Erhalten gesamt") {
                    AmountText(cents: position.receivedCents)
                }
            }

            Section {
                Button {
                    bookingSource = .dividend
                } label: {
                    Label("Dividende verbuchen", systemImage: IncomeSource.dividend.symbol)
                }
                Button {
                    bookingSource = .interest
                } label: {
                    Label("Zinsen verbuchen", systemImage: IncomeSource.interest.symbol)
                }
            } footer: {
                if position.lastPayoutCents > 0 {
                    HStack(spacing: 4) {
                        Text("Vorschlag aus der letzten Ausschüttung:")
                        AmountText(cents: position.lastPayoutCents)
                    }
                }
            }

            Section("Ausschüttungen") {
                if payouts.isEmpty {
                    Text("Noch keine Ausschüttungen verbucht.")
                        .foregroundStyle(.secondary)
                }
                ForEach(payouts) { income in
                    Button {
                        editingIncome = income
                    } label: {
                        IncomeRowView(income: income)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            context.delete(income)
                            try? context.save()
                            WidgetSync.update(using: context)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(position.name)
        .toolbar {
            Button("Bearbeiten") { showingEditor = true }
        }
        .sheet(item: $bookingSource) { source in
            NavigationStack {
                IncomeEditorView(viewModel: IncomeEditorViewModel(presetSource: source, position: position))
            }
        }
        .sheet(item: $editingIncome) { income in
            NavigationStack {
                IncomeEditorView(viewModel: IncomeEditorViewModel(mode: .editIncome(income)))
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                PositionEditorView(position: position)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PositionDetailView(position: PreviewData.samplePosition)
    }
    .modelContainer(PreviewData.container)
}
