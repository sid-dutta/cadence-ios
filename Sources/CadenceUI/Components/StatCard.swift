import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var caption: String? = nil
    var symbol: String
    var tint: Color = .cadenceAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

struct StatCard_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            StatCard(title: "Workouts", value: "3", caption: "this week", symbol: "dumbbell.fill", tint: .cadenceStrength)
            StatCard(title: "Volume", value: "12.4k lb", symbol: "scalemass.fill", tint: .cadenceStrength)
            StatCard(title: "Distance", value: "13.2 mi", symbol: "figure.run", tint: .cadenceRunning)
        }
        .padding()
        .background(Color.groupedBackground)
    }
}
