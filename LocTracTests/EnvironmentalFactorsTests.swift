//
//  EnvironmentalFactorsTests.swift
//  LocTracTests
//
//  Unit tests for Car model, CO2 calculations, car-trip matching,
//  retroactive recalculation, and import backward compatibility.
//

import Testing
import Foundation
@testable import LocTrac

// MARK: - Car Model Tests

@Suite("Car Model")
struct CarModelTests {

    // MARK: - CO2 Per Mile Derivation

    @Test("Gas car CO2 per mile derived from MPG")
    func gasCO2Derivation() {
        let car = TestDataFactory.makeCar(fuelType: .gas, mpg: 25.0)
        // 19.6 lbs/gallon / 25 MPG = 0.784 lbs/mile
        #expect(abs(car.co2PerMile - 0.784) < 0.001)
    }

    @Test("Diesel car CO2 per mile derived from MPG")
    func dieselCO2Derivation() {
        let car = TestDataFactory.makeCar(fuelType: .diesel, mpg: 30.0)
        // 22.4 lbs/gallon / 30 MPG = 0.7467 lbs/mile
        #expect(abs(car.co2PerMile - (22.4 / 30.0)) < 0.001)
    }

    @Test("Hybrid car CO2 per mile uses gas constant with hybrid MPG")
    func hybridCO2Derivation() {
        let car = TestDataFactory.makeCar(fuelType: .hybrid, mpg: 35.0)
        // 19.6 lbs/gallon / 35 MPG = 0.56 lbs/mile
        #expect(abs(car.co2PerMile - (19.6 / 35.0)) < 0.001)
    }

    @Test("Electric car CO2 per mile uses grid emissions")
    func electricCO2Derivation() {
        let car = TestDataFactory.makeCar(
            fuelType: .electric, mpg: nil, kWhPer100Miles: 30.0
        )
        // (30 kWh/100mi) / 100 * 0.855 lbs/kWh = 0.2565 lbs/mile
        #expect(abs(car.co2PerMile - (30.0 / 100.0 * 0.855)) < 0.001)
    }

    @Test("CO2 override takes precedence over derived value")
    func co2Override() {
        let car = TestDataFactory.makeCar(
            fuelType: .gas, mpg: 25.0, co2PerMileOverride: 1.5
        )
        #expect(car.co2PerMile == 1.5)
    }

    @Test("Default MPG used when MPG is nil for gas car")
    func defaultMPGForGas() {
        let car = TestDataFactory.makeCar(fuelType: .gas, mpg: nil)
        // Default gas MPG = 25.0 -> 19.6 / 25.0 = 0.784
        #expect(abs(car.co2PerMile - (19.6 / 25.0)) < 0.001)
    }

    @Test("Default kWh used when kWh is nil for electric car")
    func defaultKWhForElectric() {
        let car = TestDataFactory.makeCar(
            fuelType: .electric, mpg: nil, kWhPer100Miles: nil
        )
        // Default EV = 30 kWh/100mi -> 0.3 * 0.855 = 0.2565
        #expect(abs(car.co2PerMile - (30.0 / 100.0 * 0.855)) < 0.001)
    }

    @Test("Default hybrid MPG is 35")
    func defaultHybridMPG() {
        #expect(Car.FuelType.hybrid.defaultMPG == 35.0)
    }

    // MARK: - Date Range

    @Test("coversDate returns true for date within range")
    func coversDateWithinRange() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let end = cal.date(from: DateComponents(year: 2024, month: 12, day: 31))!
        let check = cal.date(from: DateComponents(year: 2024, month: 6, day: 15))!

        let car = TestDataFactory.makeCar(startDate: start, endDate: end)
        #expect(car.coversDate(check) == true)
    }

    @Test("coversDate returns false for date before start")
    func coversDateBeforeStart() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = cal.date(from: DateComponents(year: 2024, month: 6, day: 1))!
        let check = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!

        let car = TestDataFactory.makeCar(startDate: start)
        #expect(car.coversDate(check) == false)
    }

    @Test("coversDate returns true for any future date when no end date")
    func coversDateNoEnd() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = cal.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        let check = cal.date(from: DateComponents(year: 2030, month: 12, day: 31))!

        let car = TestDataFactory.makeCar(startDate: start, endDate: nil)
        #expect(car.coversDate(check) == true)
    }

    @Test("coversDate returns false for date after end")
    func coversDateAfterEnd() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let end = cal.date(from: DateComponents(year: 2024, month: 6, day: 30))!
        let check = cal.date(from: DateComponents(year: 2024, month: 7, day: 1))!

        let car = TestDataFactory.makeCar(startDate: start, endDate: end)
        #expect(car.coversDate(check) == false)
    }

    // MARK: - Codable Roundtrip

    @Test("Car encodes and decodes correctly")
    func codableRoundtrip() throws {
        let car = TestDataFactory.makeCar(
            name: "2024 Tesla Model 3",
            fuelType: .electric,
            kWhPer100Miles: 25.0,
            co2PerMileOverride: 0.2,
            isDefault: true,
            notes: "Primary EV"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(car)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Car.self, from: data)

        #expect(decoded.id == car.id)
        #expect(decoded.name == car.name)
        #expect(decoded.fuelType == .electric)
        #expect(decoded.kWhPer100Miles == 25.0)
        #expect(decoded.co2PerMileOverride == 0.2)
        #expect(decoded.isDefault == true)
        #expect(decoded.notes == "Primary EV")
    }
}

// MARK: - DataStore Car CRUD Tests

@Suite("DataStore Car CRUD")
@MainActor
struct DataStoreCarCRUDTests {

    private func makeStore() -> DataStore {
        DataStore(preview: true)
    }

    @Test("addCar appends to cars array")
    func addCar() {
        let store = makeStore()
        let car = TestDataFactory.makeCar(name: "Test Sedan")
        store.addCar(car)
        #expect(store.cars.count == 1)
        #expect(store.cars.first?.name == "Test Sedan")
    }

    @Test("addCar with isDefault clears other defaults")
    func addCarClearsDefaults() {
        let store = makeStore()
        let car1 = TestDataFactory.makeCar(name: "Car 1", isDefault: true)
        store.addCar(car1)
        #expect(store.cars.first?.isDefault == true)

        let car2 = TestDataFactory.makeCar(name: "Car 2", isDefault: true)
        store.addCar(car2)

        let defaults = store.cars.filter { $0.isDefault }
        #expect(defaults.count == 1)
        #expect(defaults.first?.name == "Car 2")
    }

    @Test("updateCar modifies existing car")
    func updateCar() {
        let store = makeStore()
        var car = TestDataFactory.makeCar(name: "Old Name")
        store.addCar(car)

        car.name = "New Name"
        store.updateCar(car)

        #expect(store.cars.first?.name == "New Name")
    }

    @Test("deleteCar removes car from array")
    func deleteCar() {
        let store = makeStore()
        let car = TestDataFactory.makeCar(name: "To Delete")
        store.addCar(car)
        #expect(store.cars.count == 1)

        store.deleteCar(car)
        #expect(store.cars.isEmpty)
    }

    @Test("defaultCar returns the car with isDefault flag")
    func defaultCar() {
        let store = makeStore()
        store.addCar(TestDataFactory.makeCar(name: "Regular", isDefault: false))
        store.addCar(TestDataFactory.makeCar(name: "Default", isDefault: true))

        #expect(store.defaultCar?.name == "Default")
    }
}

// MARK: - Car-Trip Matching Tests

@Suite("Car-Trip Matching")
@MainActor
struct CarTripMatchingTests {

    private func makeStore() -> DataStore {
        DataStore(preview: true)
    }

    @Test("carForTrip matches by explicit carID")
    func matchByCarID() {
        let store = makeStore()
        let car = TestDataFactory.makeCar(id: "car-123", name: "Explicit Car")
        store.addCar(car)

        let trip = TestDataFactory.makeTrip(
            transportMode: .driving,
            carID: "car-123"
        )
        let matched = store.carForTrip(trip)
        #expect(matched?.id == "car-123")
    }

    @Test("carForTrip matches by date range when no carID")
    func matchByDateRange() {
        let store = makeStore()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let carStart = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let carEnd = cal.date(from: DateComponents(year: 2024, month: 12, day: 31))!
        let tripDate = cal.date(from: DateComponents(year: 2024, month: 6, day: 15))!

        let car = TestDataFactory.makeCar(startDate: carStart, endDate: carEnd)
        store.addCar(car)

        let trip = TestDataFactory.makeTrip(
            departureDate: tripDate,
            transportMode: .driving
        )
        let matched = store.carForTrip(trip)
        #expect(matched?.id == car.id)
    }

    @Test("carForTrip prefers default car among date-range candidates")
    func prefersDefaultCar() {
        let store = makeStore()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let tripDate = cal.date(from: DateComponents(year: 2024, month: 6, day: 15))!

        let car1 = TestDataFactory.makeCar(name: "Regular", startDate: start, isDefault: false)
        let car2 = TestDataFactory.makeCar(name: "Default", startDate: start, isDefault: true)
        store.cars = [car1, car2]  // Direct set to avoid isDefault clearing logic

        let trip = TestDataFactory.makeTrip(
            departureDate: tripDate,
            transportMode: .driving
        )
        let matched = store.carForTrip(trip)
        #expect(matched?.name == "Default")
    }

    @Test("carForTrip returns nil when no cars match")
    func noMatch() {
        let store = makeStore()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let carStart = cal.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let tripDate = cal.date(from: DateComponents(year: 2024, month: 6, day: 15))!

        let car = TestDataFactory.makeCar(startDate: carStart)
        store.addCar(car)

        let trip = TestDataFactory.makeTrip(
            departureDate: tripDate,
            transportMode: .driving
        )
        #expect(store.carForTrip(trip) == nil)
    }
}

// MARK: - Retroactive CO2 Recalculation Tests

@Suite("Retroactive CO2 Recalculation")
@MainActor
struct RetroactiveCO2Tests {

    private func makeStore() -> DataStore {
        DataStore(preview: true)
    }

    @Test("recalculateDrivingTripsCO2 updates driving trips with car-specific rate")
    func recalculateWithCar() {
        let store = makeStore()
        let car = TestDataFactory.makeCar(
            fuelType: .gas,
            mpg: 20.0, // 19.6/20 = 0.98 lbs/mile
            isDefault: true
        )
        store.addCar(car)

        var trip = TestDataFactory.makeTrip(
            distance: 100,
            transportMode: .driving
        )
        store.trips = [trip]

        store.recalculateDrivingTripsCO2()

        let expected = 100.0 * (19.6 / 20.0) // 98.0 lbs
        #expect(abs(store.trips[0].co2Emissions - expected) < 0.01)
    }

    @Test("recalculateDrivingTripsCO2 skips non-driving trips")
    func skipsNonDriving() {
        let store = makeStore()
        let car = TestDataFactory.makeCar(isDefault: true)
        store.addCar(car)

        let flyingTrip = TestDataFactory.makeTrip(
            distance: 1000,
            transportMode: .flying
        )
        let originalCO2 = flyingTrip.co2Emissions
        store.trips = [flyingTrip]

        store.recalculateDrivingTripsCO2()

        // Flying trip should be unchanged
        #expect(store.trips[0].co2Emissions == originalCO2)
    }
}

// MARK: - Import Backward Compatibility Tests

@Suite("Import Backward Compatibility for Cars")
struct ImportBackwardCompatTests {

    @Test("Export decodes correctly without cars field (legacy backup)")
    func legacyBackupWithoutCars() throws {
        // Legacy backup has no "cars" key
        let json = TestDataFactory.legacyV13BackupJSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(Export.self, from: json)

        #expect(export.cars.isEmpty)
    }

    @Test("Export decodes correctly with cars field")
    func backupWithCars() throws {
        let json = Data("""
        {
            "locations": [],
            "events": [],
            "activities": [],
            "affirmations": [],
            "trips": [],
            "eventTypes": [],
            "exerciseEntries": [],
            "cars": [
                {
                    "id": "car-1",
                    "name": "2024 Camry",
                    "year": 2024,
                    "make": "Toyota",
                    "model": "Camry",
                    "fuelType": "Gas",
                    "mpg": 28.0,
                    "startDate": "2024-01-01T00:00:00Z",
                    "isDefault": true,
                    "notes": ""
                }
            ]
        }
        """.utf8)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(Export.self, from: json)

        #expect(export.cars.count == 1)
        #expect(export.cars[0].name == "2024 Camry")
        #expect(export.cars[0].fuelType == "Gas")
        #expect(export.cars[0].mpg == 28.0)
        #expect(export.cars[0].isDefault == true)
    }

    @Test("Trip carID is optional and defaults to nil in legacy backups")
    func tripCarIDBackwardCompat() throws {
        // Trip without carID field
        let json = TestDataFactory.fixtureBackupJSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(Export.self, from: json)

        // The fixture trip should have nil carID
        #expect(export.trips.first?.carID == nil)
    }
}

// MARK: - UserProfile Public Transit Exclusion Tests

@Suite("UserProfile Public Transit Exclusion")
struct PublicTransitExclusionTests {

    @Test("excludePublicTransitFromEnvironment defaults to false")
    func defaultsFalse() {
        let profile = UserProfile(displayName: "Test")
        #expect(profile.excludePublicTransitFromEnvironment == false)
    }

    @Test("excludePublicTransitFromEnvironment roundtrips through Codable")
    func codableRoundtrip() throws {
        var profile = UserProfile(displayName: "Test")
        profile.excludePublicTransitFromEnvironment = true

        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)

        #expect(decoded.excludePublicTransitFromEnvironment == true)
    }

    @Test("Legacy profile JSON without excludePublicTransit decodes with default false")
    func legacyDecode() throws {
        // Minimal profile JSON without the new field
        let json = Data("""
        {
            "id": "test-id",
            "displayName": "Test User",
            "email": "",
            "signInMethod": "none",
            "createdAt": "2026-01-01T00:00:00Z",
            "lastLoginAt": "2026-01-01T00:00:00Z"
        }
        """.utf8)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(UserProfile.self, from: json)

        #expect(profile.excludePublicTransitFromEnvironment == false)
    }
}
