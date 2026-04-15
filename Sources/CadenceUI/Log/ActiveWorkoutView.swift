import SwiftUI
import CadenceCore

struct ActiveWorkoutView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var showingPicker = false
    @State private var confirmingFinish = false
    @State private var confirmingDiscard = false
    @State private var toast: PersonalRecord?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if let workout = model.activeWorkout {
                    content(for: workout)
                } else {
                    startPrompt
                }
            }
            .background(Color.groupedBackground)
            .navigationTitle(model.activeWorkout?.title ?? "Workout")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView { exercise in
                    model.addExercise(exercise)
                }
            }
            .confirmationDialog("Finish workout?", isPresented: $confirmingFinish, titleVisibility: .visible) {
                Button("Finish & Save") {
                    model.finishActiveWorkout()
                    dismiss()
                }
            } message: {
                Text("Sets you haven't completed will be dropped.")
            }
            .confirmationDialog("Discard workout?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    model.discardActiveWorkout()
                    dismiss()
                }
            } message: {
                Text("This can't be undone.")
            }
            .overlay(alignment: .top) {
                if let toast {
                    PRToast(record: toast, unit: model.settings.weightUnit)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4), value: toast)
            .sensoryFeedback(.success, trigger: toast)
        }
        .onAppear {
            if model.activeWorkout == nil {
                model.startWorkout()
            }
        }
    }

    @ViewBuilder
    private func content(for workout: Workout) -> some View {
        List {
            Section {
                timerHeader(for: workout)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            ForEach(workout.exercises) { exercise in
                let recordSetID = StatsEngine.recordSet(in: exercise, history: model.workouts, excludingWorkoutID: workout.id)?.id
                Section {
                    ForEach(exercise.sets) { set in
                        SetRow(
                            index: (exercise.sets.firstIndex(of: set) ?? 0) + 1,
                            set: set,
                            unit: model.settings.weightUnit,
                            isRecord: set.id == recordSetID,
                            onChange: { model.updateSet($0, inExercise: exercise.id) },
                            onToggle: { celebrate(model.toggleSetCompletion(setID: set.id, inExercise: exercise.id)) }
                        )
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            model.removeSet(id: exercise.sets[offset].id, fromExercise: exercise.id)
                        }
                    }

                    Button {
                        model.addSet(toExercise: exercise.id)
                    } label: {
                        Label("Add Set", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                    }
                } header: {
                    HStack {
                        Label(exercise.name, systemImage: exercise.muscleGroup.symbolName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .textCase(nil)
                        Spacer()
                        Menu {
                            Button("Remove Exercise", role: .destructive) {
                                model.removeExercise(id: exercise.id)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }

            Section {
                Button {
                    showingPicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .groupedList()
        .scrollContentBackground(.hidden)
    }

    private func timerHeader(for workout: Workout) -> some View {
        VStack(spacing: 6) {
            TimelineView(.periodic(from: workout.startedAt, by: 1)) { context in
                Text(Formatters.clock(context.date.timeIntervalSince(workout.startedAt)))
                    .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            }
            HStack(spacing: 16) {
                Label("\(workout.exercises.count) exercises", systemImage: "list.bullet")
                Label("\(workout.completedSetCount) sets", systemImage: "checkmark.circle")
                Label(Formatters.compactVolume(kg: workout.totalVolumeKg, unit: model.settings.weightUnit), systemImage: "scalemass")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var startPrompt: some View {
        EmptyStateView(
            symbol: "dumbbell",
            title: "Ready when you are",
            message: "Start a workout to begin logging sets.",
            actionTitle: "Start Workout"
        ) {
            model.startWorkout()
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Menu {
                Button("Minimize") { dismiss() }
                Button("Discard Workout", role: .destructive) { confirmingDiscard = true }
            } label: {
                Image(systemName: "chevron.down")
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Finish") { confirmingFinish = true }
                .fontWeight(.semibold)
                .disabled(model.activeWorkout?.completedSetCount == 0)
        }
    }

    private func celebrate(_ record: PersonalRecord?) {
        guard let record else { return }
        toastTask?.cancel()
        toast = record
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }
}

private struct SetRow: View {
    let index: Int
    let set: ExerciseSet
    let unit: WeightUnit
    let isRecord: Bool
    let onChange: (ExerciseSet) -> Void
    let onToggle: () -> Void

    @FocusState private var focused: Field?
    private enum Field { case weight, reps }

    private var weight: Binding<Double?> {
        Binding(
            get: {
                let value = (unit.fromKg(set.weightKg) * 100).rounded() / 100
                return value > 0 ? value : nil
            },
            set: { var s = set; s.weightKg = unit.toKg(max(0, $0 ?? 0)); onChange(s) }
        )
    }

    private var reps: Binding<Int?> {
        Binding(
            get: { set.reps > 0 ? set.reps : nil },
            set: { var s = set; s.reps = max(0, $0 ?? 0); onChange(s) }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22)

            field(title: unit.symbol, value: weight, format: .number.precision(.fractionLength(0...2)), focus: .weight)
                .decimalKeyboard()
            Text("×")
                .foregroundStyle(.tertiary)
            field(title: "reps", value: reps, format: .number, focus: .reps)
                .numberKeyboard()

            if isRecord {
                PRBadge()
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer(minLength: 0)

            Button(action: onToggle) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Color.cadenceStrength : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? "Mark set incomplete" : "Mark set complete")
        }
        .animation(.snappy, value: isRecord)
        .opacity(set.isCompleted ? 0.75 : 1)
    }

    private func field<Value, Style: ParseableFormatStyle>(
        title: String,
        value: Binding<Value?>,
        format: Style,
        focus: Field
    ) -> some View where Style.FormatInput == Value, Style.FormatOutput == String {
        HStack(spacing: 4) {
            TextField("0", value: value, format: format)
                .multilineTextAlignment(.trailing)
                .font(.body.weight(.medium).monospacedDigit())
                .frame(width: 68)
                .focused($focused, equals: focus)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }
}

struct ActiveWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        let model = AppModel.preview()
        model.startWorkout(title: "Push Day")
        model.addExercise(ExerciseCatalog.all[0].makeExercise())
        model.addExercise(ExerciseCatalog.all[12].makeExercise())
        return ActiveWorkoutView().environment(model)
    }
}
