//
//  TripMigrationTests.swift
//  LocTracTests
//
//  Tests for Trip model, TripMigrationUtility distance calculation,
//  transport mode suggestion, and CO2 calculation.
//  Uses Swift Testing framework (@Test, #expect).
//

import Testing
import CoreLocation
@testable import LocTrac

@Suite("Trip Migration Tests")
struct TripMigrationTests {

    // MARK: - Helpers

    /// Creates an event at a specific coordinate with a unique location
    private func makeEventAt(
        latitude: Double,
        longitude: Double,
        locationName: String = "Test",
        locationID: String? = nil,
        date: Date = Date().startOfDay
    ) -> Event {
        let loc = TestDataFactory.makeLocation(
            id: locationID ?? UUID().uuidString,
            name: locationName,
            latitude: latitude,
            longitude: longitude
        )
        return TestDataFactory.makeEvent(
            location: loc,
            latitude: latitude,
            longitude: longitude
        )
    }

    // MARK: - Distance Calculation Tests

    @Test("Denver to LA distance is approximately 800-1000 miles")
    func denverToLADistance() {
        let denver = makeEventAt(latitude: 39.7392, longitude: -104.9903, locationName: "Denver", locationID: "denver")
        let la = makeEventAt(latitude: 34.0522, longitude: -118.2437, locationName: "LA", locationID: "la")

        let trip = TripMigrationUtility.suggestTrip(from: denver, to: la)

        #expect(trip != nil, "Trip should be suggested between Denver and LA")
        if let trip = trip {
            #expect(trip.distance >= 800 && trip.distance <= 1000,
                    "Denver to LA should be ~830 miles, got \(trip.distance)")
        }
    }

    @Test("Nearby points within 50 miles calculate correctly")
    func nearbyPointsDistance() {
        // Denver to Boulder (~25 miles)
        let denver = makeEventAt(latitude: 39.7392, longitude: -104.9903, locationName: "Denver", locationID: "denver")
        let boulder = makeEventAt(latitude: 40.0150, longitude: -105.2705, locationName: "Boulder", locationID: "boulder")

        let trip = TripMigrationUtility.suggestTrip(from: denver, to: boulder)

        #expect(trip != nil, "Trip should be suggested between Denver and Boulder")
        if let trip = trip {
            #expect(trip.distance >= 20 && trip.distance <= 30,
                    "Denver to Boulder should be ~25 miles, got \(trip.distance)")
        }
    }

    @Test("Denver to Tokyo distance is approximately 5800-6200 miles")
    func denverToTokyoDistance() {
        let denver = makeEventAt(latitude: 39.7392, longitude: -104.9903, locationName: "Denver", locationID: "denver")
        let tokyo = makeEventAt(latitude: 35.6762, longitude: 139.6503, locationName: "Tokyo", locationID: "tokyo")

        let trip = TripMigrationUtility.suggestTrip(from: denver, to: tokyo)

        #expect(trip != nil, "Trip should be suggested between Denver and Tokyo")
        if let trip = trip {
            #expect(trip.distance >= 5700 && trip.distance <= 6200,
                    "Denver to Tokyo should be ~5900 miles, got \(trip.distance)")
        }
    }

    // MARK: - Transport Mode Suggestion Tests

    @Test("Short distance under 3 miles suggests walking")
    func shortDistanceSuggestsWalking() {
        let mode = Trip.TransportMode.detectMode(distance: 2.0)
        #expect(mode == .walking, "Distance <= 3 miles should suggest walking, got \(mode)")
    }

    @Test("Medium distance 3-100 miles suggests driving")
    func mediumDistanceSuggestsDriving() {
        let mode50 = Trip.TransportMode.detectMode(distance: 50.0)
        #expect(mode50 == .driving, "50 miles should suggest driving, got \(mode50)")

        let mode99 = Trip.TransportMode.detectMode(distance: 99.0)
        #expect(mode99 == .driving, "99 miles should suggest driving, got \(mode99)")
    }

    @Test("Long distance over 100 miles suggests flying")
    func longDistanceSuggestsFlying() {
        let mode200 = Trip.TransportMode.detectMode(distance: 200.0)
        #expect(mode200 == .flying, "200 miles should suggest flying, got \(mode200)")

        let mode5000 = Trip.TransportMode.detectMode(distance: 5000.0)
        #expect(mode5000 == .flying, "5000 miles should suggest flying, got \(mode5000)")
    }

    // MARK: - CO2 Calculation Tests

    @Test("recalculateCO2 produces non-zero value for non-zero distance")
    func co2NonZeroForNonZeroDistance() {
        let trip = Trip(
            fromEventID: "evt-a",
            toEventID: "evt-b",
            departureDate: Date().startOfDay,
            arrivalDate: Date().startOfDay,
            distance: 500,
            transportMode: .driving,
            notes: "Test CO2"
        )
        trip.recalculateCO2()

        #expect(trip.co2Emissions > 0, "CO2 should be > 0 for 500 mile driving trip, got \(trip.co2Emissions)")
        // Driving CO2 = 500 * 0.89 = 445
        #expect(trip.co2Emissions >= 440 && trip.co2Emissions <= 450,
                "500 miles driving CO2 should be ~445 lbs, got \(trip.co2Emissions)")
    }

    @Test("Different transport modes produce different CO2 values for same distance")
    func differentModesDifferentCO2() {
        let flyingTrip = Trip(
            fromEventID: "evt-a",
            toEventID: "evt-b",
            departureDate: Date().startOfDay,
            arrivalDate: Date().startOfDay,
            distance: 1000,
            transportMode: .flying,
            notes: ""
        )

        let trainTrip = Trip(
            fromEventID: "evt-c",
            toEventID: "evt-d",
            departureDate: Date().startOfDay,
            arrivalDate: Date().startOfDay,
            distance: 1000,
            transportMode: .train,
            notes: ""
        )

        // Flying: 1000 * 0.9 = 900, Train: 1000 * 0.14 = 140
        #expect(flyingTrip.co2Emissions != trainTrip.co2Emissions,
                "Flying and train should produce different CO2 for same distance")
        #expect(flyingTrip.co2Emissions > trainTrip.co2Emissions,
                "Flying CO2 (\(flyingTrip.co2Emissions)) should exceed train CO2 (\(trainTrip.co2Emissions))")
    }

    // MARK: - Trip Model Tests

    @Test("Trip fromEventID and toEventID are String type")
    func tripEventIDsAreStrings() {
        let fromID = "evt-from-123"
        let toID = "evt-to-456"

        let trip = Trip(
            fromEventID: fromID,
            toEventID: toID,
            departureDate: Date().startOfDay,
            arrivalDate: Date().startOfDay,
            distance: 100,
            transportMode: .driving,
            notes: ""
        )

        #expect(trip.fromEventID == fromID)
        #expect(trip.toEventID == toID)
        // Verify they are String type by assignment
        let _: String = trip.fromEventID
        let _: String = trip.toEventID
    }

    // MARK: - shouldCreateTrip Logic (via suggestTrip / migrateEventsToTrips)

    @Test("Other-Other same city with valid coords does NOT create trip")
    func otherOtherSameCityNoTrip() {
        let baseDate = Date().startOfDay
        let other = TestDataFactory.makeOtherLocation()

        let event1 = TestDataFactory.makeEvent(
            location: other,
            city: "Crested Butte",
            latitude: 38.8697,
            longitude: -106.9878,
            country: "United States",
            state: "Colorado",
            note: "CB day 1"
        )
        let event2 = TestDataFactory.makeEvent(
            date: baseDate.diff(numDays: 1),
            location: other,
            city: "Crested Butte",
            latitude: 38.8697,
            longitude: -106.9878,
            country: "United States",
            state: "Colorado",
            note: "CB day 2"
        )

        let trip = TripMigrationUtility.suggestTrip(from: event1, to: event2)
        #expect(trip == nil, "Same city 'Crested Butte' Other events should NOT create a trip")
    }

    @Test("Other-Other same city with bad coords (0,0) does NOT create trip")
    func otherOtherSameCityBadCoordsNoTrip() {
        let other = TestDataFactory.makeOtherLocation()

        // Event with valid coords
        let event1 = TestDataFactory.makeEvent(
            location: other,
            city: "Crested Butte",
            latitude: 38.8697,
            longitude: -106.9878,
            country: "United States",
            state: "Colorado"
        )
        // Event with 0,0 coords (the bug scenario)
        let event2 = TestDataFactory.makeEvent(
            location: other,
            city: "Crested Butte",
            latitude: 0.0,
            longitude: 0.0,
            country: "United States",
            state: "Colorado"
        )

        let trip = TripMigrationUtility.suggestTrip(from: event1, to: event2)
        #expect(trip == nil, "Same city Other events should NOT create trip even with bad coords")
    }

    @Test("Other-Other different cities creates trip")
    func otherOtherDifferentCitiesCreatesTrip() {
        let other = TestDataFactory.makeOtherLocation()

        let event1 = TestDataFactory.makeEvent(
            location: other,
            city: "Denver",
            latitude: 39.7392,
            longitude: -104.9903,
            country: "United States",
            state: "Colorado"
        )
        let event2 = TestDataFactory.makeEvent(
            location: other,
            city: "Paris",
            latitude: 48.8566,
            longitude: 2.3522,
            country: "France"
        )

        let trip = TripMigrationUtility.suggestTrip(from: event1, to: event2)
        #expect(trip != nil, "Different city Other events should create a trip")
    }

    @Test("Other-Named same city with close coords does NOT create trip")
    func otherNamedSameCityCloseNoTrip() {
        let other = TestDataFactory.makeOtherLocation()
        let arrowhead = TestDataFactory.makeLocation(
            name: "Arrowhead",
            city: "Edwards",
            latitude: 39.6308,
            longitude: -106.5947,
            country: "United States"
        )

        let event1 = TestDataFactory.makeEvent(
            location: other,
            city: "Edwards",
            latitude: 39.6310,
            longitude: -106.5950,
            country: "United States"
        )
        let event2 = TestDataFactory.makeEvent(
            location: arrowhead,
            latitude: 39.6308,
            longitude: -106.5947,
            country: "United States"
        )

        let trip = TripMigrationUtility.suggestTrip(from: event1, to: event2)
        #expect(trip == nil, "Other 'Edwards' to named 'Arrowhead' in Edwards should NOT create trip when < 1 mile")
    }

    @Test("Event with 0,0 coords at Other location is excluded from migration")
    func zeroCoordOtherEventExcluded() {
        let baseDate = Date().startOfDay
        let other = TestDataFactory.makeOtherLocation()
        let home = TestDataFactory.makeLocation(name: "Home", city: "Denver")

        let event1 = TestDataFactory.makeEvent(
            date: baseDate,
            location: home,
            latitude: 39.7392,
            longitude: -104.9903
        )
        // This Other event has 0,0 coords and the Other location also has 0,0
        let event2 = TestDataFactory.makeEvent(
            date: baseDate.diff(numDays: 1),
            location: other,
            city: "Crested Butte",
            latitude: 0.0,
            longitude: 0.0,
            country: "United States"
        )
        let event3 = TestDataFactory.makeEvent(
            date: baseDate.diff(numDays: 2),
            location: home,
            latitude: 39.7392,
            longitude: -104.9903
        )

        let trips = TripMigrationUtility.migrateEventsToTrips(events: [event1, event2, event3])
        // event2 should be filtered out (0,0 coords), so no trip through it
        // event1 and event3 are same location (Home) so no trip either
        #expect(trips.isEmpty, "0,0 coord Other event should be excluded, leaving no trips. Got \(trips.count)")
    }

    @Test("Trip id is UUID type and formattedDistance produces readable string")
    func tripIDIsUUIDAndFormattedDistance() {
        let trip = Trip(
            fromEventID: "evt-a",
            toEventID: "evt-b",
            departureDate: Date().startOfDay,
            arrivalDate: Date().startOfDay,
            distance: 1234.5,
            transportMode: .flying,
            notes: ""
        )

        // Verify id is UUID
        let _: UUID = trip.id

        // formattedDistance should produce a readable string like "1,234.5"
        let formatted = trip.formattedDistance
        #expect(!formatted.isEmpty, "formattedDistance should not be empty")
        #expect(formatted.contains("1") && formatted.contains("234"),
                "formattedDistance for 1234.5 should contain '1' and '234', got '\(formatted)'")
    }
}
