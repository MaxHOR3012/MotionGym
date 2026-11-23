import SwiftData
import SwiftUI

/// Alle Einnahmen, nach Monaten gruppiert – mit Suche und Filter.
struct IncomeListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Income.date, order: .reverse) private var incomes: [Income]

    @State private var viewModel = IncomeListViewModel()
    @State private var editingIncome: Income?

    var body: some View {
        let sections = viewModel.sections(from: incomes)

        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.incomes) { income in
                        Button {
                            editingIncome = income
                        } label: {
                            IncomeRowView(income: income)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.delete(income, in: context)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(section.title)
                        Spacer()
                        AmountText(cents: section.totalCents)
                    }
                    .textCase(nil)
                }
            }
        }
        .overlay {
            if sections.isEmpty {
                if viewModel.isFiltering {
                    ContentUnavailableView.search
                } else {
                    ContentUnavailableView(
                        "Keine Einnahmen",
                        systemImage: "tray",
                        description: Text("Lege über „+“ in der Übersicht deine erste Einnahme an.")
                    )
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Notiz, Quelle oder Position")
        .navigationTitle("Alle Einnahmen")
        .toolbar {
            Menu {
                Picker("Quelle", selection: $viewModel.sourceFilter) {
                    Text("Alle Quellen").tag(IncomeSource?.none)
                    ForEach(IncomeSource.allCases) { source in
                        Label(source.title, systemImage: source.symbol).tag(Optional(source))
                    }
                }
                Toggle("Erwartete anzeigen", isOn: $viewModel.showPlanned)
            } label: {
                Image(systemName: viewModel.isFiltering
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel("Filter")
        }
        .sheet(item: $editingIncome) { income in
            NavigationStack {
                IncomeEditorView(viewModel: IncomeEditorViewModel(mode: .editIncome(income)))
            }
        }
    }
}

#Preview {
    NavigationStack {
        IncomeListView()
    }
    .modelContainer(PreviewData.container)
}
