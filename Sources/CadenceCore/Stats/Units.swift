import Foundation

public enum WeightUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case kg
    case lb

    public var id: String { rawValue }
    public var symbol: String { rawValue }

    private static let lbPerKg = 2.204_622_621_8

    public func fromKg(_ kg: Double) -> Double {
        switch self {
        case .kg: kg
        case .lb: kg * Self.lbPerKg
        }
    }

    public func toKg(_ value: Double) -> Double {
        switch self {
        case .kg: value
        case .lb: value / Self.lbPerKg
        }
    }

    public var defaultIncrement: Double {
        switch self {
        case .kg: 2.5
        case .lb: 5
        }
    }
}

public enum DistanceUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case km
    case mi

    public var id: String { rawValue }
    public var symbol: String { rawValue }

    private static let metersPerMile = 1609.344

    public func fromMeters(_ meters: Double) -> Double {
        switch self {
        case .km: meters / 1000
        case .mi: meters / Self.metersPerMile
        }
    }

    public func toMeters(_ value: Double) -> Double {
        switch self {
        case .km: value * 1000
        case .mi: value * Self.metersPerMile
        }
    }

    public func pace(fromSecondsPerKm secondsPerKm: Double) -> Double {
        switch self {
        case .km: secondsPerKm
        case .mi: secondsPerKm * (Self.metersPerMile / 1000)
        }
    }
}

public enum Formatters {

    public static func weight(kg: Double, unit: WeightUnit, fractionDigits: Int = 1) -> String {
        let value = unit.fromKg(kg)
        return "\(trimmed(value, maxFractionDigits: fractionDigits)) \(unit.symbol)"
    }

    public static func distance(meters: Double, unit: DistanceUnit, fractionDigits: Int = 2) -> String {
        let value = unit.fromMeters(meters)
        return "\(trimmed(value, maxFractionDigits: fractionDigits)) \(unit.symbol)"
    }

    public static func pace(secondsPerKm: Double?, unit: DistanceUnit) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite, secondsPerKm > 0 else { return "—" }
        let perUnit = unit.pace(fromSecondsPerKm: secondsPerKm)
        let total = Int(perUnit.rounded())
        return String(format: "%d:%02d /%@", total / 60, total % 60, unit.symbol)
    }

    public static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    public static func compactVolume(kg: Double, unit: WeightUnit) -> String {
        let value = unit.fromKg(kg)
        if value >= 10_000 {
            return "\(trimmed(value / 1000, maxFractionDigits: 1))k \(unit.symbol)"
        }
        return "\(trimmed(value, maxFractionDigits: 0)) \(unit.symbol)"
    }

    public static func trimmed(_ value: Double, maxFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
