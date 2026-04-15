import SwiftUI
import CadenceCore

/// Manual run entry. (A future HealthKit importer would feed the same
/// `Run` value through `model.logRun`.)
struct RunLogView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing run to edit it.
    var existing: Run? = nil

    @State private var date = Date()
    /// Optional so the field shows a placeholder until the user types.
    @State private var distance: Double?
    @State private var duration: TimeInterval = 0
    @State private var notes = ""

    private var unit: DistanceUnit { model.settings.distanceUnit }

    private var preview: Run {
        Run(
            id: existing?.id ?? UUID(),
            startedAt: date,
            distanceMeters: unit.toMeters(distance ?? 0),
            durationSeconds: duration,
            notes: notes
        )
    }

    private var canSave: Bool {
        (distance ?? 0) > 0 && duration > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date)
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("0", value: $distance, format: .number.precision(.fractionLength(0...2)))
                            .multilineTextAlignment(.trailing)
                            .decimalKeyboard()
                            .submitLabel(.done)
                            .frame(maxWidth: 100)
                        Text(unit.symbol)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Duration") {
                    DurationPicker(seconds: $duration)
                }

                Section {
                    LabeledContent("Pace", value: Formatters.pace(secondsPerKm: preview.paceSecondsPerKm, unit: unit))
                    LabeledContent("Avg speed", value: speedText)
                }
                .foregroundStyle(canSave ? .primary : .secondary)

                Section("Notes") {
                    TextField("How did it feel?", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(existing == nil ? "Log Run" : "Edit Run")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.logRun(preview)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear(perform: loadExisting)
        }
        .tint(.cadenceRunning)
    }

    private var speedText: String {
        let kmh = preview.averageSpeedKmh
        switch unit {
        case .km: return String(format: "%.1f km/h", kmh)
        case .mi: return String(format: "%.1f mph", kmh / 1.609_344)
        }
    }

    private func loadExisting() {
        guard let existing else { return }
        date = existing.startedAt
        distance = (unit.fromMeters(existing.distanceMeters) * 100).rounded() / 100
        duration = existing.durationSeconds
        notes = existing.notes
    }
}

struct RunLogView_Previews: PreviewProvider {
    static var previews: some View {
        RunLogView().environment(AppModel.preview())
    }
}
