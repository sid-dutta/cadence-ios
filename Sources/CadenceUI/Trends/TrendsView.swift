import SwiftUI
import Charts
import CadenceCore

struct TrendsView: View {
    @Environment(AppModel.self) private var model
    @State private var mode: Mode = .strength
    @State private var selectedExercise: String?
    @State private var weeks = 8

    enum Mode: String, CaseIterable, Identifiable {
        case strength = "Strength", running = "Running", activity = "Activity"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .strength: strength
                case .running: running
                case .activity: activity
                }
            }
            .padding()
        }
        .background(Color.groupedBackground)
        .navigationTitle("Trends")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Range", selection: $weeks) {
                    Text("4 weeks").tag(4)
                    Text("8 weeks").tag(8)
                    Text("12 weeks").tag(12)
                    Text("26 weeks").tag(26)
                }
                .pickerStyle(.menu)
            }
        }
        .onAppear {
            if selectedExercise == nil {
                selectedExercise = StatsEngine.trackedExerciseNames(in: model.workouts).first
            }
        }
    }

    private var summaries: [WeeklySummary] { model.weeklySummaries(weeks: weeks) }
    private var weightUnit: WeightUnit { model.settings.weightUnit }
    private var distanceUnit: DistanceUnit { model.settings.distanceUnit }

    @ViewBuilder
    private var strength: some View {
        if model.visibleWorkouts.isEmpty {
            EmptyStateView(symbol: "chart.bar", title: "No workouts yet", message: "Finish a workout to see volume and strength trends.")
                .card()
        } else {
            chartCard("Weekly Volume", subtitle: Formatters.compactVolume(kg: summaries.reduce(0) { $0 + $1.volumeKg }, unit: weightUnit) + " total") {
                Chart(summaries) { week in
                    BarMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Volume", weightUnit.fromKg(week.volumeKg))
                    )
                    .foregroundStyle(Color.cadenceStrength.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: max(1, weeks / 4))) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxisLabel(weightUnit.symbol)
            }

            chartCard("Estimated 1RM", subtitle: "Best set per workout") {
                VStack(alignment: .leading, spacing: 12) {
                    exercisePicker
                    if let name = selectedExercise {
                        let points = StatsEngine.exerciseHistory(name: name, in: model.workouts)
                            .filter { $0.date >= cutoff }
                        if points.count < 2 {
                            Text("Log \(name) at least twice to see a trend.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(height: 160)
                        } else {
                            Chart(points) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("1RM", weightUnit.fromKg(point.bestOneRepMaxKg))
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Color.cadenceStrength)
                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("1RM", weightUnit.fromKg(point.bestOneRepMaxKg))
                                )
                                .foregroundStyle(Color.cadenceStrength)
                            }
                            .chartYScale(domain: .automatic(includesZero: false))
                            .chartYAxisLabel(weightUnit.symbol)
                        }
                    }
                }
            }

            prList
        }
    }

    private var exercisePicker: some View {
        Picker("Exercise", selection: $selectedExercise) {
            ForEach(StatsEngine.trackedExerciseNames(in: model.workouts), id: \.self) { name in
                Text(name).tag(Optional(name))
            }
        }
        .pickerStyle(.menu)
        .tint(.cadenceStrength)
        .labelsHidden()
    }

    private var prList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(.title3.weight(.bold))
            VStack(spacing: 0) {
                ForEach(Array(model.personalRecords.enumerated()), id: \.element.id) { index, record in
                    HStack {
                        Image(systemName: record.muscleGroup.symbolName)
                            .foregroundStyle(Color.cadenceStrength)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.exerciseName)
                                .font(.body.weight(.medium))
                            Text(record.achievedAt, format: .dateTime.month(.abbreviated).day().year())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Formatters.weight(kg: record.estimatedOneRepMaxKg, unit: weightUnit, fractionDigits: 0))
                                .font(.body.weight(.semibold).monospacedDigit())
                            Text("\(Formatters.weight(kg: record.weightKg, unit: weightUnit)) × \(record.reps)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    if index < model.personalRecords.count - 1 {
                        Divider()
                    }
                }
            }
            .card(padding: 12)
        }
    }

    @ViewBuilder
    private var running: some View {
        if model.visibleRuns.isEmpty {
            EmptyStateView(symbol: "figure.run", title: "No runs yet", message: "Log a run to see distance and pace trends.")
                .card()
        } else {
            chartCard("Weekly Distance", subtitle: Formatters.distance(meters: summaries.reduce(0) { $0 + $1.runDistanceMeters }, unit: distanceUnit, fractionDigits: 1) + " total") {
                Chart(summaries) { week in
                    BarMark(
                        x: .value("Week", week.weekStart, unit: .weekOfYear),
                        y: .value("Distance", distanceUnit.fromMeters(week.runDistanceMeters))
                    )
                    .foregroundStyle(Color.cadenceRunning.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: max(1, weeks / 4))) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxisLabel(distanceUnit.symbol)
            }

            chartCard("Pace", subtitle: "lower is faster") {
                let runs = model.visibleRuns.filter { $0.startedAt >= cutoff && $0.paceSecondsPerKm != nil }.reversed()
                Chart(Array(runs)) { run in
                    let pace = distanceUnit.pace(fromSecondsPerKm: run.paceSecondsPerKm ?? 0)
                    LineMark(x: .value("Date", run.startedAt), y: .value("Pace", pace))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.cadenceRunning)
                    PointMark(x: .value("Date", run.startedAt), y: .value("Pace", pace))
                        .foregroundStyle(Color.cadenceRunning)
                        .symbolSize(distanceUnit.fromMeters(run.distanceMeters) * 12)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let seconds = value.as(Double.self) {
                                Text(String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60))
                            }
                        }
                    }
                }
                .chartYAxisLabel("min/\(distanceUnit.symbol)")
            }

            runRecords
        }
    }

    private var runRecords: some View {
        HStack(spacing: 10) {
            if let fastest = StatsEngine.fastestRun(in: model.runs) {
                StatCard(
                    title: "Fastest",
                    value: Formatters.pace(secondsPerKm: fastest.paceSecondsPerKm, unit: distanceUnit),
                    caption: Formatters.distance(meters: fastest.distanceMeters, unit: distanceUnit, fractionDigits: 1),
                    symbol: "bolt.fill",
                    tint: .cadenceRunning
                )
            }
            if let longest = StatsEngine.longestRun(in: model.runs) {
                StatCard(
                    title: "Longest",
                    value: Formatters.distance(meters: longest.distanceMeters, unit: distanceUnit, fractionDigits: 1),
                    caption: Formatters.duration(longest.durationSeconds),
                    symbol: "arrow.left.and.right",
                    tint: .cadenceRunning
                )
            }
            StatCard(
                title: "Total",
                value: Formatters.distance(meters: StatsEngine.totalDistanceMeters(in: model.runs), unit: distanceUnit, fractionDigits: 0),
                caption: "\(model.visibleRuns.count) runs",
                symbol: "sum",
                tint: .cadenceRunning
            )
        }
    }

    private var activityDays: [HealthDay] {
        model.healthSeries(days: min(weeks * 7, 90))
    }

    @ViewBuilder
    private var activity: some View {
        if !model.isHealthAvailable {
            EmptyStateView(symbol: "heart.slash", title: "Health Unavailable", message: "Apple Health isn't available on this device.")
                .card()
        } else if !model.isHealthConnected {
            EmptyStateView(
                symbol: "heart.text.square",
                title: "Connect Apple Health",
                message: "See your steps, active energy, exercise minutes, resting heart rate and weight next to your workouts.",
                actionTitle: "Connect"
            ) {
                Task { await model.connectHealth() }
            }
            .card()
        } else if activityDays.allSatisfy(\.isEmpty) {
            EmptyStateView(symbol: "heart.text.square", title: "No Health Data Yet", message: "Nothing has been recorded for this period.")
                .card()
        } else {
            let days = activityDays
            HStack(spacing: 10) {
                StatCard(
                    title: "Avg Steps",
                    value: HealthStats.averageSteps(days).formatted(),
                    caption: "per day",
                    symbol: "figure.walk",
                    tint: .cadenceActivity
                )
                if let hr = HealthStats.averageRestingHeartRate(days) {
                    StatCard(title: "Resting HR", value: "\(Int(hr.rounded()))", caption: "bpm", symbol: "heart.fill", tint: .cadenceActivity)
                }
                if let kg = HealthStats.latestBodyMassKg(days) {
                    StatCard(title: "Weight", value: Formatters.weight(kg: kg, unit: weightUnit), caption: "latest", symbol: "scalemass", tint: .cadenceActivity)
                }
            }

            chartCard("Steps", subtitle: "\(HealthStats.totalSteps(days).formatted()) total") {
                Chart(days) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Steps", day.steps ?? 0)
                    )
                    .foregroundStyle(Color.cadenceActivity.gradient)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, days.count / 6))) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
            }

            chartCard("Exercise Minutes", subtitle: "\(Int(HealthStats.totalExerciseMinutes(days).rounded())) min total") {
                Chart(days) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Minutes", day.exerciseMinutes ?? 0)
                    )
                    .foregroundStyle(Color.cadenceActivity.gradient)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, days.count / 6))) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxisLabel("min")
            }

            chartCard("Active Energy", subtitle: "\(Int(HealthStats.totalActiveEnergy(days).rounded())) kcal total") {
                Chart(days) { day in
                    LineMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("kcal", day.activeEnergyKcal ?? 0)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.cadenceActivity)
                    AreaMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("kcal", day.activeEnergyKcal ?? 0)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.cadenceActivity.opacity(0.12))
                }
                .chartYAxisLabel("kcal")
            }
        }
    }

    private var cutoff: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: -weeks, to: StatsEngine.startOfWeek(containing: Date())) ?? .distantPast
    }

    private func chartCard<Content: View>(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
                .frame(minHeight: 180)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct TrendsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { TrendsView() }
            .environment(AppModel.preview())
    }
}
