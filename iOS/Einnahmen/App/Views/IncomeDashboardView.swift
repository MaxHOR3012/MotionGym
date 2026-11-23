import SwiftData
import SwiftUI

/// Hauptansicht: Kennzahlen, Monatsziel, Diagramme, letzte und erwartete Einnahmen.
struct IncomeDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Income.date, order: .reverse) private var incomes: [Income]

    @AppStorage(SettingsKey.monthlyGoalCents, store: AppGroup.defaults)
    private var goalCents = 0
    @AppStorage(SettingsKey.hideAmounts, store: AppGroup.defaults)
    private var hideAmounts = false

    @State private var viewModel = IncomeDashboardViewModel()

    var body: some View {
        let stats = viewModel.statistics(for: incomes)

        ScrollView {
            VStack(spacing: 16) {
                if incomes.isEmpty {
                    emptyState
                } else {
                    SummaryCardsView(stats: stats) {
                        withAnimation { hideAmounts.toggle() }
                    }

                    GoalProgressView(currentCents: stats.currentMonthTotal, goalCents: goalCents) {
                        viewModel.activeSheet = .goal
                    }

                    MonthlyBarChartView(buckets: stats.monthlyBuckets, goalCents: goalCents)

                    SourcePieChartView(
                        slices: stats.sourceSlices(for: viewModel.piePeriod),
                        period: $viewModel.piePeriod
                    )

                    incomeSection(title: "Demnächst erwartet", systemImage: "clock",
                                  items: viewModel.upcomingIncomes(from: incomes))
                    incomeSection(title: "Zuletzt eingegangen", systemImage: "tray.and.arrow.down",
                                  items: viewModel.recentIncomes(from: incomes))
                }

                navigationCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Einnahmen")
        .toolbar { toolbarContent }
        .sheet(item: $viewModel.activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .newIncome:
                    IncomeEditorView(viewModel: IncomeEditorViewModel())
                case .newRecurring:
                    IncomeEditorView(viewModel: IncomeEditorViewModel(startRecurring: true))
                case .goal:
                    GoalEditorView()
                case .settings:
                    IncomeSettingsView()
                }
            }
        }
        .sheet(item: $viewModel.editingIncome) { income in
            NavigationStack {
                IncomeEditorView(viewModel: IncomeEditorViewModel(mode: .editIncome(income)))
            }
        }
        // Änderungen – auch per iCloud von anderen Geräten – ans Widget weitergeben
        .onChange(of: viewModel.fingerprint(of: incomes)) {
            viewModel.incomesDidChange(in: context)
        }
    }

    // MARK: Abschnitte

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Noch keine Einnahmen", systemImage: "eurosign.circle")
        } description: {
            Text("Erfasse dein Gehalt, Dividenden, Zinsen oder Mieteinnahmen – einmalig oder wiederkehrend.")
        } actions: {
            Button("Erste Einnahme erfassen") { viewModel.activeSheet = .newIncome }
                .buttonStyle(.borderedProminent)
            Button("Wiederkehrende Einnahme anlegen") { viewModel.activeSheet = .newRecurring }
        }
        .card()
    }

    @ViewBuilder
    private func incomeSection(title: String, systemImage: String, items: [Income]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .padding(.bottom, 4)
                ForEach(items) { income in
                    Button {
                        viewModel.editingIncome = income
                    } label: {
                        IncomeRowView(income: income)
                    }
                    .buttonStyle(.plain)
                    if income.id != items.last?.id {
                        Divider().padding(.leading, 46)
                    }
                }
            }
            .card()
        }
    }

    private var navigationCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                IncomeListView()
            } label: {
                CardLinkRow(title: "Alle Einnahmen", systemImage: "list.bullet", detail: String(incomes.count))
            }
            Divider().padding(.leading, 40)
            NavigationLink {
                RecurringIncomeListView()
            } label: {
                CardLinkRow(title: "Wiederkehrende Einnahmen", systemImage: "repeat")
            }
            Divider().padding(.leading, 40)
            NavigationLink {
                PortfolioPositionsView()
            } label: {
                CardLinkRow(title: "Portfolio-Ausschüttungen", systemImage: "briefcase.fill")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                withAnimation { hideAmounts.toggle() }
            } label: {
                Image(systemName: hideAmounts ? "eye.slash" : "eye")
            }
            .accessibilityLabel(hideAmounts ? "Beträge einblenden" : "Beträge ausblenden")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button {
                    viewModel.activeSheet = .newIncome
                } label: {
                    Label("Einmalige Einnahme", systemImage: "plus")
                }
                Button {
                    viewModel.activeSheet = .newRecurring
                } label: {
                    Label("Wiederkehrende Einnahme", systemImage: "repeat")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .accessibilityLabel("Einnahme hinzufügen")

            Button {
                viewModel.activeSheet = .settings
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Einstellungen")
        }
    }
}

#Preview("Übersicht") {
    NavigationStack {
        IncomeDashboardView()
    }
    .modelContainer(PreviewData.container)
    .environment(\.locale, Money.locale)
}

#Preview("Übersicht – Dunkel") {
    NavigationStack {
        IncomeDashboardView()
    }
    .modelContainer(PreviewData.container)
    .environment(\.locale, Money.locale)
    .preferredColorScheme(.dark)
}

#Preview("Leer") {
    NavigationStack {
        IncomeDashboardView()
    }
    .modelContainer(IncomeModelContainer.make(inMemory: true))
}
