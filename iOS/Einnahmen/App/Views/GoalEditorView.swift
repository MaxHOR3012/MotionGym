import SwiftUI

/// Monatsziel festlegen oder entfernen.
struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.monthlyGoalCents, store: AppGroup.defaults)
    private var goalCents = 0

    @State private var amountText = ""
    @FocusState private var focused: Bool

    private let suggestions = [100_000, 250_000, 400_000, 500_000]

    private var parsedCents: Int? { Money.parseCents(amountText) }

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("z. B. 4.000", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .focused($focused)
                    Text("€").font(.title2).foregroundStyle(.secondary)
                }
            } header: {
                Text("Monatsziel")
            } footer: {
                Text("Der Fortschritt bezieht sich auf alle Einnahmen des laufenden Monats – eingegangene und noch erwartete.")
            }

            Section("Vorschläge") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions, id: \.self) { cents in
                            Button(Money.formatRounded(cents: cents)) {
                                amountText = Money.editingString(cents: cents)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if goalCents > 0 {
                Section {
                    Button("Ziel entfernen", role: .destructive) {
                        goalCents = 0
                        WidgetSync.reload()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("Monatsziel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    goalCents = parsedCents ?? 0
                    WidgetSync.reload()
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled((parsedCents ?? 0) <= 0)
            }
        }
        .onAppear {
            amountText = Money.editingString(cents: goalCents)
            focused = true
        }
    }
}

#Preview {
    NavigationStack {
        GoalEditorView()
    }
}
