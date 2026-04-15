import SwiftUI
import CadenceCore

struct ExercisePickerView: View {
    let onPick: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var customGroup: MuscleGroup = .fullBody

    var body: some View {
        NavigationStack {
            List {
                if !trimmedQuery.isEmpty && ExerciseCatalog.lookup(name: trimmedQuery) == nil {
                    Section("Custom") {
                        HStack {
                            Picker("Muscle group", selection: $customGroup) {
                                ForEach(MuscleGroup.allCases) { group in
                                    Text(group.displayName).tag(group)
                                }
                            }
                            .labelsHidden()
                            Spacer()
                            Button {
                                pick(Exercise(name: trimmedQuery, muscleGroup: customGroup))
                            } label: {
                                Label("Add \"\(trimmedQuery)\"", systemImage: "plus.circle.fill")
                                    .lineLimit(1)
                            }
                            .tint(.cadenceStrength)
                        }
                    }
                }

                ForEach(sections, id: \.group) { section in
                    Section(section.group.displayName) {
                        ForEach(section.exercises) { item in
                            Button {
                                pick(item.makeExercise())
                            } label: {
                                HStack {
                                    Label(item.name, systemImage: item.muscleGroup.symbolName)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .groupedList()
            .searchable(text: $query, prompt: "Search or type a new exercise")
            .navigationTitle("Add Exercise")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sections: [(group: MuscleGroup, exercises: [CatalogExercise])] {
        let matches = ExerciseCatalog.search(query)
        return MuscleGroup.allCases.compactMap { group in
            let items = matches.filter { $0.muscleGroup == group }
            return items.isEmpty ? nil : (group, items)
        }
    }

    private func pick(_ exercise: Exercise) {
        onPick(exercise)
        dismiss()
    }
}

struct ExercisePickerView_Previews: PreviewProvider {
    static var previews: some View {
        ExercisePickerView { _ in }
    }
}
