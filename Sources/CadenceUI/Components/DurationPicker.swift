import SwiftUI

struct DurationPicker: View {
    @Binding var seconds: TimeInterval

    private var hours: Binding<Int> {
        Binding(
            get: { Int(seconds) / 3600 },
            set: { seconds = TimeInterval($0 * 3600 + minutes.wrappedValue * 60 + secs.wrappedValue) }
        )
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { (Int(seconds) % 3600) / 60 },
            set: { seconds = TimeInterval(hours.wrappedValue * 3600 + $0 * 60 + secs.wrappedValue) }
        )
    }

    private var secs: Binding<Int> {
        Binding(
            get: { Int(seconds) % 60 },
            set: { seconds = TimeInterval(hours.wrappedValue * 3600 + minutes.wrappedValue * 60 + $0) }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            wheel("hr", selection: hours, range: 0..<24)
            wheel("min", selection: minutes, range: 0..<60)
            wheel("sec", selection: secs, range: 0..<60)
        }
    }

    private func wheel(_ label: String, selection: Binding<Int>, range: Range<Int>) -> some View {
        Picker(label, selection: selection) {
            ForEach(range, id: \.self) { value in
                Text("\(value) \(label)").tag(value)
            }
        }
        .wheelPicker()
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
