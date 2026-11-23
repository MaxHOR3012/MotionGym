import SwiftData
import SwiftUI

/// Formular für neue Einnahmen, Bearbeiten einzelner Zahlungen und ganzer Serien.
struct IncomeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PortfolioPosition.name) private var positions: [PortfolioPosition]

    @State private var viewModel: IncomeEditorViewModel
    @State private var showingDeleteConfirmation = false
    @FocusState private var amountFocused: Bool

    init(viewModel: IncomeEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            amountSection
            detailsSection

            if !positions.isEmpty {
                Section("Portfolio") {
                    Picker("Position", selection: $viewModel.position) {
                        Text("Keine").tag(PortfolioPosition?.none)
                        ForEach(positions) { position in
                            Label(position.name, systemImage: position.kind.symbol)
                                .tag(Optional(position))
                        }
                    }
                }
            }

            if viewModel.showsRecurrenceSection {
                recurrenceSection
            }

            if viewModel.isSeriesOccurrence {
                Section {
                    Label(
                        "Diese Zahlung gehört zu einer wiederkehrenden Einnahme. Änderungen gelten nur für diese eine Zahlung.",
                        systemImage: "repeat"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            if viewModel.canDelete {
                Section {
                    Button(viewModel.deleteTitle, role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.locale, Money.locale)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    viewModel.save(in: context)
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(!viewModel.canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { amountFocused = false }
            }
        }
        .confirmationDialog(
            viewModel.deleteTitle + "?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                viewModel.delete(in: context)
                dismiss()
            }
        } message: {
            Text(viewModel.deleteMessage)
        }
        .onAppear {
            if viewModel.isNew && viewModel.amountText.isEmpty {
                amountFocused = true
            }
        }
    }

    // MARK: Abschnitte

    private var amountSection: some View {
        Section {
            HStack {
                TextField("0,00", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .focused($amountFocused)
                Text("€")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Betrag")
        } footer: {
            if viewModel.showsAmountError {
                Text("Bitte einen gültigen Betrag eingeben, z. B. 1.250,00")
                    .foregroundStyle(.red)
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            Picker("Quelle", selection: $viewModel.source) {
                ForEach(IncomeSource.allCases) { source in
                    Label(source.title, systemImage: source.symbol).tag(source)
                }
            }
            DatePicker(viewModel.dateLabel, selection: $viewModel.date, displayedComponents: .date)
            TextField("Notiz (optional)", text: $viewModel.note, axis: .vertical)
                .lineLimit(1...4)
        }
    }

    private var recurrenceSection: some View {
        Section {
            if viewModel.canToggleRecurring {
                Toggle("Wiederkehrend", isOn: $viewModel.isRecurring.animation())
            }
            if viewModel.isRecurring {
                Picker("Intervall", selection: $viewModel.interval) {
                    ForEach(RecurrenceInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                Toggle("Enddatum", isOn: $viewModel.hasEndDate.animation())
                if viewModel.hasEndDate {
                    DatePicker(
                        "Endet am",
                        selection: $viewModel.endDate,
                        in: viewModel.date...,
                        displayedComponents: .date
                    )
                }
            }
        } header: {
            Text("Wiederholung")
        } footer: {
            if viewModel.isRecurring {
                Text(viewModel.recurrenceSummary)
            }
        }
    }
}

#Preview("Neu") {
    NavigationStack {
        IncomeEditorView(viewModel: IncomeEditorViewModel())
    }
    .modelContainer(PreviewData.container)
}

#Preview("Wiederkehrend") {
    NavigationStack {
        IncomeEditorView(viewModel: IncomeEditorViewModel(startRecurring: true, presetSource: .salary))
    }
    .modelContainer(PreviewData.container)
}

#Preview("Bearbeiten") {
    NavigationStack {
        IncomeEditorView(viewModel: IncomeEditorViewModel(mode: .editIncome(PreviewData.sampleIncomes(limit: 1)[0])))
    }
    .modelContainer(PreviewData.container)
}
