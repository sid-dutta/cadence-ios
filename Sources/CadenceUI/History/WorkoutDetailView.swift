import SwiftUI
import CadenceCore

struct WorkoutDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let workoutID: UUID

    @State private var confirmingDelete = false

    private var records: Set<UUID> {
        Set(model.personalRecords.filter { $0.workoutID == workoutID }.map { record in
            model.workout(id: workoutID)?.exercises
                .first { $0.name.lowercased() == record.exerciseName.lowercased() }?
                .bestSet?.id ?? UUID()
        })
    }

    var body: some View {
        if let workout = model.workout(id: workoutID) {
            content(workout)
        } else {
            EmptyStateView(symbol: "trash", title: "Workout deleted", message: "")
        }
    }

    private func content(_ workout: Workout) -> some View {
        let unit = model.settings.weightUnit
        return List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(workout.startedAt, format: .dateTime.weekday(.wide).month().day().year().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        StatCard(title: "Volume", value: Formatters.compactVolume(kg: workout.totalVolumeKg, unit: unit), symbol: "scalemass.fill", tint: .cadenceStrength)
                        StatCard(title: "Sets", value: "\(workout.completedSetCount)", symbol: "checkmark.circle.fill", tint: .cadenceStrength)
                        StatCard(title: "Time", value: workout.duration.map(Formatters.duration) ?? "—", symbol: "timer", tint: .cadenceStrength)
                    }
                    if !workout.muscleGroups.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(workout.muscleGroups) { group in
                                    Label(group.displayName, systemImage: group.symbolName)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.cadenceStrength.opacity(0.12), in: Capsule())
                                        .foregroundStyle(Color.cadenceStrength)
                                }
                            }
                        }
                    }
                    if !workout.notes.isEmpty {
                        Text(workout.notes)
                            .font(.callout)
                            .italic()
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }

            ForEach(workout.exercises) { exercise in
                Section {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        SetLine(index: index + 1, set: set, unit: unit, isRecord: records.contains(set.id))
                    }
                } header: {
                    HStack {
                        Label(exercise.name, systemImage: exercise.muscleGroup.symbolName)
                        Spacer()
                        if let best = exercise.bestSet, best.weightKg > 0 {
                            Text("1RM ≈ \(Formatters.weight(kg: best.estimatedOneRepMaxKg, unit: unit, fractionDigits: 0))")
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .groupedList()
        .navigationTitle(workout.title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("Delete this workout?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.deleteWorkout(id: workout.id)
                dismiss()
            }
        }
    }
}

private struct SetLine: View {
    let index: Int
    let set: ExerciseSet
    let unit: WeightUnit
    let isRecord: Bool

    private var weightText: String {
        Formatters.weight(kg: set.weightKg, unit: unit) + " × " + String(set.reps)
    }

    var body: some View {
        HStack {
            Text("Set \(index)")
                .foregroundStyle(.secondary)
            Spacer()
            Text(weightText)
                .monospacedDigit()
            if let rpe = set.rpe {
                Text("RPE " + Formatters.trimmed(rpe, maxFractionDigits: 1))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if isRecord {
                PRBadge()
            }
        }
        .opacity(set.isCompleted ? 1 : 0.4)
    }
}

struct WorkoutDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel.preview()
        return NavigationStack {
            WorkoutDetailView(workoutID: model.visibleWorkouts[0].id)
        }
        .environment(model)
    }
}
