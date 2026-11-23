import SwiftData
import SwiftUI

/// Position anlegen oder bearbeiten.
struct PositionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let position: PortfolioPosition?

    @State private var name: String
    @State private var identifier: String
    @State private var kind: PositionKind

    init(position: PortfolioPosition?) {
        self.position = position
        _name = State(initialValue: position?.name ?? "")
        _identifier = State(initialValue: position?.identifier ?? "")
        _kind = State(initialValue: position?.kind ?? .etf)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name, z. B. MSCI World ETF", text: $name)
                TextField("ISIN / WKN / IBAN (optional)", text: $identifier)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Picker("Art", selection: $kind) {
                    ForEach(PositionKind.allCases) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }
            } footer: {
                Text("Typische Einnahme: \(kind.defaultSource.title)")
            }
        }
        .navigationTitle(position == nil ? "Neue Position" : "Position bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    save()
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(trimmedName.isEmpty)
            }
        }
    }

    private func save() {
        let cleanIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if let position {
            position.name = trimmedName
            position.identifier = cleanIdentifier
            position.kind = kind
        } else {
            context.insert(PortfolioPosition(name: trimmedName, identifier: cleanIdentifier, kind: kind))
        }
        try? context.save()
    }
}

#Preview {
    NavigationStack {
        PositionEditorView(position: nil)
    }
    .modelContainer(PreviewData.container)
}
