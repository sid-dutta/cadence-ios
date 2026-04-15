import SwiftUI
import CadenceCore

struct PRBadge: View {
    var body: some View {
        Text("PR")
            .font(.caption2.weight(.heavy))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.cadenceAccent, in: Capsule())
            .foregroundStyle(.white)
            .accessibilityLabel("Personal record")
    }
}

struct PRToast: View {
    let record: PersonalRecord
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(Color.cadenceAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("New record · \(record.exerciseName)")
                    .font(.subheadline.weight(.semibold))
                Text("\(Formatters.weight(kg: record.weightKg, unit: unit)) × \(record.reps)  ·  1RM ≈ \(Formatters.weight(kg: record.estimatedOneRepMaxKg, unit: unit, fractionDigits: 0))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .padding(.horizontal)
    }
}

struct PRChip: View {
    let record: PersonalRecord
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: record.muscleGroup.symbolName)
                    .foregroundStyle(Color.cadenceStrength)
                Text(record.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Text(Formatters.weight(kg: record.estimatedOneRepMaxKg, unit: unit, fractionDigits: 0))
                .font(.title3.weight(.bold).monospacedDigit())
            Text("\(Formatters.weight(kg: record.weightKg, unit: unit)) × \(record.reps)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 150, alignment: .leading)
        .card(padding: 14)
    }
}

struct PRBadge_Previews: PreviewProvider {
    static var previews: some View {
        let record = PersonalRecord(exerciseName: "Bench Press", muscleGroup: .chest, weightKg: 100, reps: 5, estimatedOneRepMaxKg: 116.7, achievedAt: .now, workoutID: UUID())
        VStack(spacing: 20) {
            PRBadge()
            PRToast(record: record, unit: .lb)
            PRChip(record: record, unit: .kg)
        }
        .padding()
        .background(Color.groupedBackground)
    }
}
