import SwiftUI
import CadenceCore

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @Binding var selectedTab: AppTab
    let startWorkout: () -> Void
    let logRun: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if model.activeWorkout != nil {
                    resumeBanner
                }
                if let today = model.todayHealth, !today.isEmpty {
                    todayFromHealth(today)
                }
                thisWeek
                actions
                if !model.personalRecords.isEmpty {
                    records
                }
                recent
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.groupedBackground)
        .navigationTitle("Summary")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Text(Date.now, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationDestination(for: ActivityItem.self) { item in
            switch item {
            case .workout(let workout): WorkoutDetailView(workoutID: workout.id)
            case .run(let run): RunDetailView(runID: run.id)
            }
        }
    }

    private var resumeBanner: some View {
        Button(action: startWorkout) {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Workout in progress")
                        .font(.subheadline.weight(.semibold))
                    Text(model.activeWorkout?.title ?? "")
                        .font(.caption)
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func todayFromHealth(_ day: HealthDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Today") {
                Button("Activity") { selectedTab = .trends }
            }
            HStack(spacing: 10) {
                StatCard(
                    title: "Steps",
                    value: (day.steps ?? 0).formatted(),
                    symbol: "figure.walk",
                    tint: .cadenceActivity
                )
                StatCard(
                    title: "Active",
                    value: "\(Int((day.activeEnergyKcal ?? 0).rounded())) kcal",
                    symbol: "flame.fill",
                    tint: .cadenceActivity
                )
                StatCard(
                    title: "Exercise",
                    value: "\(Int((day.exerciseMinutes ?? 0).rounded())) min",
                    symbol: "figure.run.circle.fill",
                    tint: .cadenceActivity
                )
            }
        }
    }

    private var thisWeek: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("This Week")
            HStack(spacing: 10) {
                StatCard(
                    title: "Workouts",
                    value: "\(model.thisWeek?.workoutCount ?? 0)",
                    symbol: "dumbbell.fill",
                    tint: .cadenceStrength
                )
                StatCard(
                    title: "Volume",
                    value: Formatters.compactVolume(kg: model.thisWeek?.volumeKg ?? 0, unit: model.settings.weightUnit),
                    symbol: "scalemass.fill",
                    tint: .cadenceStrength
                )
                StatCard(
                    title: "Distance",
                    value: Formatters.distance(meters: model.thisWeek?.runDistanceMeters ?? 0, unit: model.settings.distanceUnit, fractionDigits: 1),
                    symbol: "figure.run",
                    tint: .cadenceRunning
                )
            }
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(model.currentStreak > 0 ? Color.cadenceAccent : Color.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.currentStreak == 1 ? "1 week streak" : "\(model.currentStreak) week streak")
                        .font(.body.weight(.medium))
                    Text("Consecutive weeks with at least one workout or run.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .card(padding: 14)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: startWorkout) {
                Label("Start Workout", systemImage: "dumbbell.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button(action: logRun) {
                Label("Log Run", systemImage: "figure.run")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .fontWeight(.medium)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    private var records: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Personal Records") {
                Button("Show All") { selectedTab = .trends }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.personalRecords.prefix(8)) { record in
                        PRChip(record: record, unit: model.settings.weightUnit)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Recent") {
                Button("Show All") { selectedTab = .history }
            }
            if model.recentActivity.isEmpty {
                EmptyStateView(
                    symbol: "figure.strengthtraining.traditional",
                    title: "No Activity Yet",
                    message: "Start a workout or log a run to see it here."
                )
                .card()
            } else {
                let items = Array(model.recentActivity.prefix(5))
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(value: item) {
                            ActivityRow(item: item, settings: model.settings)
                        }
                        .buttonStyle(.plain)
                        if index < items.count - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .card(padding: 12)
            }
        }
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            trailing
                .font(.subheadline)
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DashboardView(selectedTab: .constant(.home), startWorkout: {}, logRun: {})
        }
        .environment(AppModel.preview())
    }
}
