import SwiftUI
import CadenceCore

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", workouts = "Workouts", runs = "Runs"
        var id: String { rawValue }
    }

    private var items: [ActivityItem] {
        switch filter {
        case .all: model.recentActivity
        case .workouts: model.visibleWorkouts.map(ActivityItem.workout)
        case .runs: model.visibleRuns.map(ActivityItem.run)
        }
    }

    private var sections: [(month: Date, items: [ActivityItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.date(from: calendar.dateComponents([.year, .month], from: item.date)) ?? item.date
        }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyStateView(
                    symbol: "calendar.badge.exclamationmark",
                    title: "Nothing here yet",
                    message: "Your completed workouts and runs will be listed by month."
                )
            } else {
                List {
                    ForEach(sections, id: \.month) { section in
                        Section {
                            ForEach(section.items) { item in
                                NavigationLink(value: item) {
                                    ActivityRow(item: item, settings: model.settings)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(section.month, format: .dateTime.month(.wide).year())
                        }
                    }
                }
                .groupedList()
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
        .navigationDestination(for: ActivityItem.self) { item in
            switch item {
            case .workout(let workout): WorkoutDetailView(workoutID: workout.id)
            case .run(let run): RunDetailView(runID: run.id)
            }
        }
    }

    private func delete(_ item: ActivityItem) {
        withAnimation {
            switch item {
            case .workout(let workout): model.deleteWorkout(id: workout.id)
            case .run(let run): model.deleteRun(id: run.id)
            }
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { HistoryView() }
            .environment(AppModel.preview())
    }
}
