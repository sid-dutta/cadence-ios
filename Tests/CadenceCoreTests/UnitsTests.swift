import XCTest
@testable import CadenceCore

final class UnitsTests: XCTestCase {

    func testWeightRoundTrip() {
        let kg = 100.0
        XCTAssertEqual(WeightUnit.lb.toKg(WeightUnit.lb.fromKg(kg)), kg, accuracy: 1e-9)
        XCTAssertEqual(WeightUnit.lb.fromKg(100), 220.46, accuracy: 0.01)
        XCTAssertEqual(WeightUnit.kg.fromKg(100), 100)
    }

    func testDistanceRoundTrip() {
        XCTAssertEqual(DistanceUnit.mi.fromMeters(1609.344), 1, accuracy: 1e-9)
        XCTAssertEqual(DistanceUnit.km.toMeters(5), 5000)
        XCTAssertEqual(DistanceUnit.mi.toMeters(DistanceUnit.mi.fromMeters(4242)), 4242, accuracy: 1e-6)
    }

    func testPaceFormatting() {
        XCTAssertEqual(Formatters.pace(secondsPerKm: 300, unit: .km), "5:00 /km")
        XCTAssertEqual(Formatters.pace(secondsPerKm: 312.4, unit: .km), "5:12 /km")
        XCTAssertEqual(Formatters.pace(secondsPerKm: 300, unit: .mi), "8:03 /mi")
        XCTAssertEqual(Formatters.pace(secondsPerKm: nil, unit: .km), "—")
        XCTAssertEqual(Formatters.pace(secondsPerKm: 0, unit: .km), "—")
    }

    func testDurationFormatting() {
        XCTAssertEqual(Formatters.duration(45 * 60 + 12), "45:12")
        XCTAssertEqual(Formatters.duration(3600 + 5 * 60), "1h 05m")
        XCTAssertEqual(Formatters.duration(-5), "0:00")
        XCTAssertEqual(Formatters.clock(3600 + 5 * 60 + 9), "1:05:09")
        XCTAssertEqual(Formatters.clock(65), "01:05")
    }

    func testWeightAndVolumeFormatting() {
        XCTAssertEqual(Formatters.weight(kg: 100, unit: .kg), "100 kg")
        XCTAssertEqual(Formatters.weight(kg: 102.5, unit: .kg), "102.5 kg")
        XCTAssertEqual(Formatters.compactVolume(kg: 12_400, unit: .kg), "12.4k kg")
        XCTAssertEqual(Formatters.compactVolume(kg: 900, unit: .kg), "900 kg")
    }
}
