import SwiftUI
import CadenceCore

struct RunDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let runID: UUID

    @State private var editing = false
    @State private var confirmingDelete = false

    var body: some View {
        if let run = model.run(id: runID) {
            content(run)
        } else {
            EmptyStateView(symbol: "trash", title: "Run deleted", message: "")
        }
    }

    private func content(_ run: Run) -> some View {
        let unit = model.settings.distanceUnit
        let fastest = StatsEngine.fastestRun(in: model.runs)
        let longest = StatsEngine.longestRun(in: model.runs)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.startedAt, format: .dateTime.weekday(.wide).month().day().year().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Formatters.distance(meters: run.distanceMeters, unit: unit))
                        .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                }

                HStack(spacing: 10) {
                    StatCard(title: "Time", value: Formatters.duration(run.durationSeconds), symbol: "timer", tint: .cadenceRunning)
                    StatCard(title: "Pace", value: Formatters.pace(secondsPerKm: run.paceSecondsPerKm, unit: unit), symbol: "speedometer", tint: .cadenceRunning)
                }

                if fastest?.id == run.id || longest?.id == run.id {
                    HStack(spacing: 8) {
                        if fastest?.id == run.id {
                            badge("Fastest pace", symbol: "bolt.fill")
                        }
                        if longest?.id == run.id {
                            badge("Longest run", symbol: "arrow.left.and.right")
                        }
                    }
                }

                if !run.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.headline)
                        Text(run.notes)
                            .font(.callout)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
            }
            .padding()
        }
        .background(Color.groupedBackground)
        .navigationTitle("Run")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { editing = true }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $editing) {
            RunLogView(existing: run)
        }
        .confirmationDialog("Delete this run?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.deleteRun(id: run.id)
                dismiss()
            }
        }
    }

    private func badge(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.cadenceAccent.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.cadenceAccent)
    }
}

struct RunDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel.preview()
        return NavigationStack {
            RunDetailView(runID: model.visibleRuns[0].id)
        }
        .environment(model)
    }
}
