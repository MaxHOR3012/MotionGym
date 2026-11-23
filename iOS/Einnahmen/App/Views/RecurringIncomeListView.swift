import SwiftData
import SwiftUI

/// Übersicht aller wiederkehrenden Einnahmen (Serien).
struct RecurringIncomeListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringIncome.createdAt) private var allSeries: [RecurringIncome]

    @State private var editingSeries: RecurringIncome?
    @State private var showingNew = false
    @State private var seriesToDelete: RecurringIncome?

    private var activeSeries: [RecurringIncome] { allSeries.filter(\.isActive) }
    private var pausedSeries: [RecurringIncome] { allSeries.filter { !$0.isActive } }

    private var monthlyEquivalent: Int {
        activeSeries.reduce(0) { $0 + $1.monthlyEquivalentCents }
    }

    var body: some View {
        List {
            if !activeSeries.isEmpty {
                Section {
                    ForEach(activeSeries) { row(for: $0) }
                } header: {
                    Text("Aktiv")
                } footer: {
                    HStack(spacing: 4) {
                        Text("Monatlich umgerechnet:")
                        AmountText(cents: monthlyEquivalent)
                    }
                }
            }
            if !pausedSeries.isEmpty {
                Section("Pausiert") {
                    ForEach(pausedSeries) { row(for: $0) }
                }
            }
        }
        .overlay {
            if allSeries.isEmpty {
                ContentUnavailableView {
                    Label("Keine wiederkehrenden Einnahmen", systemImage: "repeat")
                } description: {
                    Text("Gehalt, Miete oder Quartalsdividenden einmal anlegen – die Termine werden automatisch geplant.")
                } actions: {
                    Button("Anlegen") { showingNew = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Wiederkehrend")
        .toolbar {
            Button {
                showingNew = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Wiederkehrende Einnahme hinzufügen")
        }
        .sheet(isPresented: $showingNew) {
            NavigationStack {
                IncomeEditorView(viewModel: IncomeEditorViewModel(startRecurring: true))
            }
        }
        .sheet(item: $editingSeries) { series in
            NavigationStack {
                IncomeEditorView(viewModel: IncomeEditorViewModel(mode: .editSeries(series)))
            }
        }
        .confirmationDialog(
            "Wiederkehrende Einnahme löschen?",
            isPresented: Binding(
                get: { seriesToDelete != nil },
                set: { if !$0 { seriesToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: seriesToDelete
        ) { series in
            Button("Löschen", role: .destructive) {
                RecurrenceService.delete(series, in: context)
                WidgetSync.update(using: context)
            }
        } message: { _ in
            Text("Geplante, noch nicht eingegangene Zahlungen werden entfernt. Bereits eingegangene Einnahmen bleiben erhalten.")
        }
    }

    private func row(for series: RecurringIncome) -> some View {
        Button {
            editingSeries = series
        } label: {
            HStack(spacing: 12) {
                SourceIcon(source: series.source)
                    .opacity(series.isActive ? 1 : 0.4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(series.note.isEmpty ? series.source.title : series.note)
                        .font(.body.weight(.medium))
                    Text(detailText(for: series))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                AmountText(cents: series.amountCents)
                    .font(.body.weight(.semibold))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                seriesToDelete = series
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                RecurrenceService.setActive(!series.isActive, for: series, in: context)
                WidgetSync.update(using: context)
            } label: {
                if series.isActive {
                    Label("Pausieren", systemImage: "pause.fill")
                } else {
                    Label("Fortsetzen", systemImage: "play.fill")
                }
            }
            .tint(series.isActive ? Color.orange : Color.green)
        }
    }

    private func detailText(for series: RecurringIncome) -> String {
        var parts = [series.interval.title]
        if let position = series.position { parts.append(position.name) }
        if !series.isActive {
            parts.append("pausiert")
        } else if let next = series.nextPlannedDate {
            parts.append("nächste: " + next.formatted(.dateTime.day().month(.abbreviated).year().locale(Money.locale)))
        }
        if let end = series.endDate {
            parts.append("bis " + end.formatted(.dateTime.month(.abbreviated).year().locale(Money.locale)))
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack {
        RecurringIncomeListView()
    }
    .modelContainer(PreviewData.container)
}
