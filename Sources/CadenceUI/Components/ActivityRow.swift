import SwiftUI
import CadenceCore

/// One line of history: a workout or a run.
struct ActivityRow: View {
    let item: ActivityItem
    let settings: UserSettings

    var body: some View {
        HStack(spacing: 14) {
            icon
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.date, format: .dateTime.month(.abbreviated).day())
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var tint: Color {
        switch item {
        case .workout: .cadenceStrength
        case .run: .cadenceRunning
        }
    }

    private var icon: some View {
        switch item {
        case .workout: Image(systemName: "dumbbell.fill")
        case .run: Image(systemName: "figure.run")
        }
    }

    private var title: String {
        switch item {
        case .workout(let w): w.title
        case .run(let r): "\(Formatters.distance(meters: r.distanceMeters, unit: settings.distanceUnit)) run"
        }
    }

    private var subtitle: String {
        switch item {
        case .workout(let w):
            var parts = ["\(w.exercises.count) exercises", "\(w.completedSetCount) sets"]
            if w.totalVolumeKg > 0 {
                parts.append(Formatters.compactVolume(kg: w.totalVolumeKg, unit: settings.weightUnit))
            }
            if let duration = w.duration {
                parts.append(Formatters.duration(duration))
            }
            return parts.joined(separator: " · ")
        case .run(let r):
            return "\(Formatters.duration(r.durationSeconds)) · \(Formatters.pace(secondsPerKm: r.paceSecondsPerKm, unit: settings.distanceUnit))"
        }
    }
}
