import SwiftUI

/// Fortschritt zum Monatsziel. Antippen öffnet den Ziel-Editor.
struct GoalProgressView: View {
    let currentCents: Int
    let goalCents: Int
    var onEdit: () -> Void = {}

    private var progress: Double {
        goalCents > 0 ? Double(currentCents) / Double(goalCents) : 0
    }

    private var isReached: Bool { goalCents > 0 && currentCents >= goalCents }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Monatsziel", systemImage: "target")
                        .font(.headline)
                    Spacer()
                    if goalCents > 0 {
                        Text(progress.formatted(.percent.precision(.fractionLength(0)).locale(Money.locale)))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(isReached ? Color.green : Color.secondary)
                    } else {
                        Text("Festlegen")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                }

                if goalCents > 0 {
                    ProgressBar(value: min(progress, 1), tint: isReached ? .green : .accentColor)

                    HStack(spacing: 4) {
                        AmountText(cents: currentCents, rounded: true)
                        Text("von")
                        AmountText(cents: goalCents, rounded: true)
                        Spacer()
                        if isReached {
                            Label("Erreicht", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("fehlen")
                            AmountText(cents: goalCents - currentCents, rounded: true)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Lege ein Monatsziel fest, um deinen Fortschritt zu sehen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Monatsziel bearbeiten")
    }
}

/// Schlanker, abgerundeter Fortschrittsbalken.
struct ProgressBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(geometry.size.width * value, value > 0 ? 8 : 0))
            }
        }
        .frame(height: 10)
        .animation(.spring(duration: 0.5), value: value)
        .accessibilityElement()
        .accessibilityValue(value.formatted(.percent.precision(.fractionLength(0)).locale(Money.locale)))
    }
}

#Preview {
    VStack(spacing: 16) {
        GoalProgressView(currentCents: 312_000, goalCents: 450_000)
        GoalProgressView(currentCents: 512_000, goalCents: 450_000)
        GoalProgressView(currentCents: 512_000, goalCents: 0)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
