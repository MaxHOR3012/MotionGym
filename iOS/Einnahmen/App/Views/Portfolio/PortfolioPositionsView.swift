import SwiftData
import SwiftUI

/// Portfolio-Positionen, aus denen Dividenden und Zinsen verbucht werden.
/// Wischen nach rechts verbucht direkt eine Ausschüttung.
struct PortfolioPositionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PortfolioPosition.name) private var positions: [PortfolioPosition]

    @State private var editorTarget: PositionEditorTarget?
    @State private var booking: PayoutBooking?

    var body: some View {
        List {
            ForEach(positions) { position in
                NavigationLink {
                    PositionDetailView(position: position)
                } label: {
                    PositionRow(position: position)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        booking = PayoutBooking(position: position, source: .dividend)
                    } label: {
                        Label("Dividende", systemImage: IncomeSource.dividend.symbol)
                    }
                    .tint(IncomeSource.dividend.color)
                    Button {
                        booking = PayoutBooking(position: position, source: .interest)
                    } label: {
                        Label("Zinsen", systemImage: IncomeSource.interest.symbol)
                    }
                    .tint(IncomeSource.interest.color)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        context.delete(position)
                        try? context.save()
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                    Button {
                        editorTarget = PositionEditorTarget(position: position)
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                }
            }
        }
        .overlay {
            if positions.isEmpty {
                ContentUnavailableView {
                    Label("Keine Positionen", systemImage: "briefcase")
                } description: {
                    Text("Lege Aktien, ETFs oder Tagesgeld an, um Dividenden und Zinsen mit einem Tipp zu verbuchen.")
                } actions: {
                    Button("Position anlegen") { editorTarget = PositionEditorTarget(position: nil) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Portfolio")
        .toolbar {
            Button {
                editorTarget = PositionEditorTarget(position: nil)
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Position hinzufügen")
        }
        .sheet(item: $editorTarget) { target in
            NavigationStack {
                PositionEditorView(position: target.position)
            }
        }
        .sheet(item: $booking) { booking in
            NavigationStack {
                IncomeEditorView(viewModel: IncomeEditorViewModel(
                    presetSource: booking.source,
                    position: booking.position
                ))
            }
        }
    }
}

/// Anfrage „Ausschüttung aus Position X verbuchen".
struct PayoutBooking: Identifiable {
    let id = UUID()
    let position: PortfolioPosition
    let source: IncomeSource
}

/// Neue (`nil`) oder bestehende Position bearbeiten.
struct PositionEditorTarget: Identifiable {
    let id = UUID()
    let position: PortfolioPosition?
}

struct PositionRow: View {
    let position: PortfolioPosition

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: position.kind.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(position.name).font(.body.weight(.medium))
                Text(position.identifier.isEmpty ? position.kind.title : "\(position.kind.title) · \(position.identifier)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(cents: position.receivedCents)
                    .font(.subheadline.weight(.semibold))
                Text("erhalten")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PortfolioPositionsView()
    }
    .modelContainer(PreviewData.container)
}
