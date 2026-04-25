//
//  RegressionTests.swift
//  LocTracTests
//
//  Phase 4B regression tests covering "Other" location survival,
//  date drift prevention, event-location relationships, trip integrity,
//  and DataStore CRUD integrity.
//

import Testing
import Foundation
@testable import LocTrac

// MARK: - Top-Level Suite

@Suite("Regression Tests")
struct RegressionTests {

    // MARK: - Shared Helpers

    private static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private static func makeUTCDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    // MARK: - 1. "Other" Location Survival

    @Suite("Other Location Survival")
    struct OtherLocationSurvival {

        @Test("Other location event has its own city via effectiveCity")
        func testOtherLocationEventHasOwnCity() {
            let event = TestDataFactory.makeOtherEvent(city: "Paris", country: "France")
            #expect(event.effectiveCity == "Paris")
        }

        @Test("Other location event has its own country via effectiveCountry")
        func testOtherLocationEventHasOwnCountry() {
            let event = TestDataFactory.makeOtherEvent(city: "Paris", country: "France")
            #expect(event.effectiveCountry == "France")
        }

        @Test("Named location event uses location's city for effectiveCity")
        func testNamedLocationEventUsesLocationCity() {
            let location = TestDataFactory.makeLocation(
                name: "Downtown Loft",
                city: "Denver",
                state: "Colorado",
                country: "United States"
            )
            let event = TestDataFactory.makeEvent(
                location: location,
                city: nil,
                country: nil,
                state: nil
            )
            #expect(event.effectiveCity == "Denver")
        }

        @Test("Multiple Other events maintain independent city and country")
        func testMultipleOtherEventsIndependent() {
            let parisEvent = TestDataFactory.makeOtherEvent(
                city: "Paris",
                country: "France",
                latitude: 48.8566,
                longitude: 2.3522
            )
            let tokyoEvent = TestDataFactory.makeOtherEvent(
                city: "Tokyo",
                country: "Japan",
                latitude: 35.6762,
                longitude: 139.6503
            )

            #expect(parisEvent.effectiveCity == "Paris")
            #expect(parisEvent.effectiveCountry == "France")
            #expect(tokyoEvent.effectiveCity == "Tokyo")
            #expect(tokyoEvent.effectiveCountry == "Japan")
        }

        @Test("makeOtherLocation has lat=0 and lon=0")
        func testOtherLocationCoordinatesAreZero() {
            let other = TestDataFactory.makeOtherLocation()
            #expect(other.latitude == 0)
            #expect(other.longitude == 0)
        }
    }

    // MARK: - 2. Date Drift Prevention

    @Suite("Date Drift Prevention")
    struct DateDriftPrevention {

        @Test("startOfDay produces UTC midnight (hour, minute, second all zero)")
        func testStartOfDayIsUTCMidnight() {
            let normalized = Date().startOfDay
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!
            let components = cal.dateComponents([.hour, .minute, .second], from: normalized)

            #expect(components.hour == 0)
            #expect(components.minute == 0)
            #expect(components.second == 0)
        }

        @Test("startOfDay is idempotent")
        func testStartOfDayIdempotent() {
            let first = Date().startOfDay
            let second = first.startOfDay
            #expect(first == second)
        }

        @Test("Event dates preserve UTC components")
        func testEventDatesPreserveUTC() {
            let specificDate = RegressionTests.makeUTCDate(year: 2026, month: 3, day: 15)
            let event = TestDataFactory.makeEvent(date: specificDate)

            let components = RegressionTests.utcCalendar.dateComponents([.year, .month, .day], from: event.date)
            #expect(components.year == 2026)
            #expect(components.month == 3)
            #expect(components.day == 15)
        }

        @Test("Two dates on the same day but different times have equal startOfDay")
        func testDateComparisonUsesStartOfDay() {
            let morning = RegressionTests.makeUTCDate(year: 2026, month: 6, day: 10, hour: 8, minute: 30)
            let evening = RegressionTests.makeUTCDate(year: 2026, month: 6, day: 10, hour: 21, minute: 45)

            #expect(morning.startOfDay == evening.startOfDay)
        }

        @Test("Dates just before and after UTC midnight produce different startOfDay")
        func testCrossMidnightUTC() {
            let beforeMidnight = RegressionTests.makeUTCDate(year: 2026, month: 1, day: 14, hour: 23, minute: 59, second: 59)
            let afterMidnight = RegressionTests.makeUTCDate(year: 2026, month: 1, day: 15, hour: 0, minute: 0, second: 1)

            #expect(beforeMidnight.startOfDay != afterMidnight.startOfDay)
        }
    }

    // MARK: - 3. Event-Location Relationship

    @Suite("Event-Location Relationship")
    struct EventLocationRelationship {

        @Test("Event embeds a location snapshot that is independent of original")
        func testEventEmbedsLocationSnapshot() {
            var location = TestDataFactory.makeLocation(name: "Beach House", city: "Malibu")
            let event = TestDataFactory.makeEvent(location: location)

            // Mutate the original location struct after event creation
            location.name = "Mountain Cabin"

            // Event still holds the original snapshot
            #expect(event.location.name == "Beach House")
        }

        @Test("Named location event effectiveCoordinates uses location coordinates")
        func testEffectiveCoordinatesNamedLocation() {
            let location = TestDataFactory.makeLocation(
                name: "Loft",
                latitude: 39.7392,
                longitude: -104.9903
            )
            // Event with zeroed-out lat/lon; effectiveCoordinates should use location's
            let event = TestDataFactory.makeEvent(
                location: location,
                latitude: 0,
                longitude: 0
            )

            let coords = event.effectiveCoordinates
            #expect(coords.latitude == 39.7392)
            #expect(coords.longitude == -104.9903)
        }

        @Test("Other event effectiveCoordinates uses event's stored coordinates")
        func testEffectiveCoordinatesOtherEvent() {
            let event = TestDataFactory.makeOtherEvent(
                city: "Paris",
                country: "France",
                latitude: 48.8566,
                longitude: 2.3522
            )

            let coords = event.effectiveCoordinates
            #expect(coords.latitude == 48.8566)
            #expect(coords.longitude == 2.3522)
        }

        @Test("isGeocoded defaults to false and can be set to true")
        func testIsGeocodedDefaultsFalse() {
            let eventDefault = TestDataFactory.makeEvent(isGeocoded: false)
            #expect(eventDefault.isGeocoded == false)

            let eventGeocoded = TestDataFactory.makeEvent(isGeocoded: true)
            #expect(eventGeocoded.isGeocoded == true)
        }
    }

    // MARK: - 4. Trip Integrity

    @Suite("Trip Integrity")
    struct TripIntegrity {

        @Test("Trip references the correct event IDs")
        func testTripReferencesValidEventIDs() {
            let fromID = UUID().uuidString
            let toID = UUID().uuidString
            let trip = TestDataFactory.makeTrip(
                fromEventID: fromID,
                toEventID: toID
            )
            #expect(trip.fromEventID == fromID)
            #expect(trip.toEventID == toID)
        }

        @Test("Deleting an event removes associated trips from DataStore")
        @MainActor
        func testDeleteEventRemovesAssociatedTrips() {
            let store = DataStore(preview: true)
            let event1 = TestDataFactory.makeEvent(date: Date().startOfDay, note: "Departure")
            let event2 = TestDataFactory.makeEvent(date: Date().startOfDay.diff(numDays: 1), note: "Arrival")
            store.add(event1)
            store.add(event2)

            let trip = TestDataFactory.makeTrip(
                fromEventID: event1.id,
                toEventID: event2.id
            )
            store.addTrip(trip)
            #expect(store.trips.contains(where: { $0.id == trip.id }))

            // Delete the departure event
            store.delete(event1)

            // Trip referencing deleted event should be removed
            #expect(!store.trips.contains(where: { $0.id == trip.id }))
        }

        @Test("TripMigrationUtility.suggestTrip returns trip with positive distance")
        func testTripDistanceIsPositive() {
            let denver = TestDataFactory.makeEvent(
                location: TestDataFactory.makeLocation(
                    name: "Denver",
                    latitude: 39.7392,
                    longitude: -104.9903
                ),
                latitude: 39.7392,
                longitude: -104.9903
            )
            let la = TestDataFactory.makeEvent(
                location: TestDataFactory.makeLocation(
                    name: "LA",
                    latitude: 34.0522,
                    longitude: -118.2437
                ),
                latitude: 34.0522,
                longitude: -118.2437
            )

            let trip = TripMigrationUtility.suggestTrip(from: denver, to: la)
            #expect(trip != nil)
            if let trip = trip {
                #expect(trip.distance > 0)
            }
        }

        @Test("Trip recalculateCO2 produces positive emissions for driving trips")
        func testTripCO2Recalculation() {
            let trip = TestDataFactory.makeTrip(
                distance: 500,
                transportMode: .driving
            )
            trip.recalculateCO2()
            #expect(trip.co2Emissions > 0)
        }
    }

    // MARK: - 5. DataStore CRUD Integrity

    @Suite("DataStore CRUD Integrity")
    @MainActor
    struct DataStoreCRUDIntegrity {

        @Test("Adding an event increases the events count by 1")
        func testAddEventIncreasesCount() {
            let store = DataStore(preview: true)
            let initialCount = store.events.count
            let event = TestDataFactory.makeEvent(date: Date().startOfDay)
            store.add(event)
            #expect(store.events.count == initialCount + 1)
        }

        @Test("Deleting an event decreases the events count by 1")
        func testDeleteEventDecreasesCount() {
            let store = DataStore(preview: true)
            let event = TestDataFactory.makeEvent(date: Date().startOfDay)
            store.add(event)
            let countAfterAdd = store.events.count

            store.delete(event)
            #expect(store.events.count == countAfterAdd - 1)
        }

        @Test("Updating an event preserves its ID but changes its note")
        func testUpdateEventPreservesID() {
            let store = DataStore(preview: true)
            var event = TestDataFactory.makeEvent(date: Date().startOfDay, note: "Original note")
            store.add(event)
            let originalID = event.id

            event.note = "Updated note"
            store.update(event)

            let updated = store.events.first(where: { $0.id == originalID })
            #expect(updated != nil)
            #expect(updated?.id == originalID)
            #expect(updated?.note == "Updated note")
        }

        @Test("Adding a location increases the locations count by 1")
        func testAddLocationIncreasesCount() {
            let store = DataStore(preview: true)
            let initialCount = store.locations.count
            let location = TestDataFactory.makeLocation(name: "New Place")
            store.add(location)
            #expect(store.locations.count == initialCount + 1)
        }

        @Test("Deleting a location removes it from the store")
        func testDeleteLocationRemovesIt() {
            let store = DataStore(preview: true)
            let location = TestDataFactory.makeLocation(name: "Temporary Location")
            store.add(location)
            #expect(store.locations.contains(where: { $0.id == location.id }))

            store.delete(location)
            #expect(!store.locations.contains(where: { $0.id == location.id }))
        }

        @Test("Updating one event does not affect another event")
        func testDuplicateEventIDHandling() {
            let store = DataStore(preview: true)
            let event1 = TestDataFactory.makeEvent(date: Date().startOfDay, note: "Event One")
            let event2 = TestDataFactory.makeEvent(date: Date().startOfDay.diff(numDays: 1), note: "Event Two")
            store.add(event1)
            store.add(event2)

            // Update event1 only
            var modified = event1
            modified.note = "Modified Event One"
            store.update(modified)

            // event2 should be unchanged
            let unchanged = store.events.first(where: { $0.id == event2.id })
            #expect(unchanged?.note == "Event Two")
        }
    }
}
