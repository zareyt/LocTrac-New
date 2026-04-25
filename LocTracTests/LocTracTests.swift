//
//  LocTracTests.swift
//  LocTracTests
//
//  Additional coverage tests: effectiveAddress, effectiveShortAddress,
//  ensureOtherLocationExists idempotence, and multi-trip cascade delete.
//

import Testing
import Foundation
@testable import LocTrac

// MARK: - Effective Address Tests

@Suite("Event Effective Address")
struct EventEffectiveAddressTests {

    // MARK: - effectiveAddress

    @Test("Named location event effectiveAddress returns location shortAddress")
    func namedLocationEffectiveAddress() {
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
        // Named location: effectiveAddress delegates to location.shortAddress
        #expect(event.effectiveAddress == "Denver, Colorado")
    }

    @Test("Other event with city, state, country returns full joined address")
    func otherEventFullAddress() {
        let event = TestDataFactory.makeOtherEvent(
            city: "Paris",
            country: "France",
            state: "Ile-de-France"
        )
        #expect(event.effectiveAddress == "Paris, Ile-de-France, France")
    }

    @Test("Other event with only city returns city")
    func otherEventCityOnly() {
        let other = TestDataFactory.makeOtherLocation()
        let event = TestDataFactory.makeEvent(
            location: other,
            city: "Tokyo",
            country: nil,
            state: nil
        )
        #expect(event.effectiveAddress == "Tokyo")
    }

    @Test("Other event with no city, state, or country returns 'Other'")
    func otherEventEmptyAddress() {
        let other = TestDataFactory.makeOtherLocation()
        let event = TestDataFactory.makeEvent(
            location: other,
            city: nil,
            country: nil,
            state: nil
        )
        #expect(event.effectiveAddress == "Other")
    }

    @Test("Other event with city and country but no state returns city, country")
    func otherEventCityAndCountry() {
        let event = TestDataFactory.makeOtherEvent(
            city: "Cabo San Lucas",
            country: "Mexico"
        )
        #expect(event.effectiveAddress == "Cabo San Lucas, Mexico")
    }

    // MARK: - effectiveShortAddress

    @Test("Named location event effectiveShortAddress returns location shortAddress")
    func namedLocationShortAddress() {
        let location = TestDataFactory.makeLocation(
            name: "Beach House",
            city: "Malibu",
            state: "California",
            country: "United States"
        )
        let event = TestDataFactory.makeEvent(
            location: location,
            city: nil,
            country: nil,
            state: nil
        )
        #expect(event.effectiveShortAddress == "Malibu, California")
    }

    @Test("Other event effectiveShortAddress includes city and state only")
    func otherEventShortAddress() {
        let event = TestDataFactory.makeOtherEvent(
            city: "Denver",
            country: "United States",
            state: "Colorado"
        )
        // effectiveShortAddress for Other: city + state only (no country)
        #expect(event.effectiveShortAddress == "Denver, Colorado")
    }

    @Test("Other event effectiveShortAddress with no city or state returns 'Other'")
    func otherEventEmptyShortAddress() {
        let other = TestDataFactory.makeOtherLocation()
        let event = TestDataFactory.makeEvent(
            location: other,
            city: nil,
            country: nil,
            state: nil
        )
        #expect(event.effectiveShortAddress == "Other")
    }

    @Test("Other event with only state returns state")
    func otherEventStateOnly() {
        let other = TestDataFactory.makeOtherLocation()
        let event = TestDataFactory.makeEvent(
            location: other,
            city: nil,
            country: nil,
            state: "Queensland"
        )
        #expect(event.effectiveShortAddress == "Queensland")
    }

    @Test("Named location with no city uses country in shortAddress")
    func namedLocationNoCityUsesCountry() {
        let location = TestDataFactory.makeLocation(
            name: "Remote Cabin",
            city: nil,
            state: nil,
            country: "Norway"
        )
        let event = TestDataFactory.makeEvent(
            location: location,
            city: nil,
            country: nil,
            state: nil
        )
        // Location.shortAddress: no city or state -> falls back to country
        #expect(event.effectiveShortAddress == "Norway")
    }
}

// MARK: - ensureOtherLocationExists Idempotence

@Suite("ensureOtherLocationExists Idempotence")
@MainActor
struct EnsureOtherLocationTests {

    @Test("Calling ensureOtherLocationExists twice does not create duplicates")
    func idempotenceCheck() {
        let store = DataStore(preview: true)
        let initialOtherCount = store.locations.filter {
            $0.name.caseInsensitiveCompare("Other") == .orderedSame
        }.count
        #expect(initialOtherCount == 1, "Preview store should have exactly 1 Other location")

        // Call again — should return false (not added)
        let added = store.ensureOtherLocationExists(saveIfAdded: false)
        #expect(added == false, "Should not add when Other already exists")

        let afterCount = store.locations.filter {
            $0.name.caseInsensitiveCompare("Other") == .orderedSame
        }.count
        #expect(afterCount == 1, "Should still have exactly 1 Other location")
    }

    @Test("ensureOtherLocationExists creates Other when missing")
    func createsWhenMissing() {
        let store = DataStore(preview: true)
        // Remove all Other locations
        store.locations.removeAll {
            $0.name.caseInsensitiveCompare("Other") == .orderedSame
        }
        #expect(store.locations.contains { $0.name == "Other" } == false)

        let added = store.ensureOtherLocationExists(saveIfAdded: false)
        #expect(added == true, "Should add Other when missing")
        #expect(store.locations.contains {
            $0.name.caseInsensitiveCompare("Other") == .orderedSame
        })
    }

    @Test("Case-insensitive match prevents duplicate Other with different casing")
    func caseInsensitiveMatch() {
        let store = DataStore(preview: true)
        // Remove all Others and add one with different case
        store.locations.removeAll {
            $0.name.caseInsensitiveCompare("Other") == .orderedSame
        }
        let otherLower = Location(
            name: "other",
            city: nil, state: nil,
            latitude: 0, longitude: 0,
            country: nil, theme: .yellow
        )
        store.locations.append(otherLower)

        let added = store.ensureOtherLocationExists(saveIfAdded: false)
        #expect(added == false, "Case-insensitive 'other' should count as existing")

        let otherCount = store.locations.filter {
            $0.name.caseInsensitiveCompare("Other") == .orderedSame
        }.count
        #expect(otherCount == 1)
    }
}

// MARK: - Multi-Trip Cascade Delete

@Suite("Multi-Trip Cascade Delete")
@MainActor
struct MultiTripCascadeDeleteTests {

    @Test("Deleting event removes all trips referencing it (3+ trips)")
    func deleteEventRemovesMultipleTrips() {
        let store = DataStore(preview: true)
        let baseDate = Date().startOfDay

        let event1 = TestDataFactory.makeEvent(id: "evt-cascade-1", date: baseDate, note: "Hub")
        let event2 = TestDataFactory.makeEvent(id: "evt-cascade-2", date: baseDate.diff(numDays: 1), note: "Dest A")
        let event3 = TestDataFactory.makeEvent(id: "evt-cascade-3", date: baseDate.diff(numDays: 2), note: "Dest B")
        let event4 = TestDataFactory.makeEvent(id: "evt-cascade-4", date: baseDate.diff(numDays: 3), note: "Dest C")

        store.add(event1)
        store.add(event2)
        store.add(event3)
        store.add(event4)

        // Create 3 trips all referencing event1
        let trip1 = TestDataFactory.makeTrip(fromEventID: event1.id, toEventID: event2.id, distance: 100)
        let trip2 = TestDataFactory.makeTrip(fromEventID: event3.id, toEventID: event1.id, distance: 200)
        let trip3 = TestDataFactory.makeTrip(fromEventID: event1.id, toEventID: event4.id, distance: 300)
        // One unrelated trip
        let trip4 = TestDataFactory.makeTrip(fromEventID: event2.id, toEventID: event3.id, distance: 50)

        store.addTrip(trip1)
        store.addTrip(trip2)
        store.addTrip(trip3)
        store.addTrip(trip4)

        #expect(store.trips.count == 4)

        // Delete the hub event
        store.delete(event1)

        // All 3 trips referencing event1 should be gone
        #expect(!store.trips.contains { $0.id == trip1.id })
        #expect(!store.trips.contains { $0.id == trip2.id })
        #expect(!store.trips.contains { $0.id == trip3.id })
        // Unrelated trip should survive
        #expect(store.trips.contains { $0.id == trip4.id })
        #expect(store.trips.count == 1)
    }

    @Test("Deleting event with no trips leaves other trips intact")
    func deleteEventWithNoTrips() {
        let store = DataStore(preview: true)
        let baseDate = Date().startOfDay

        let event1 = TestDataFactory.makeEvent(id: "evt-ntrip-1", date: baseDate)
        let event2 = TestDataFactory.makeEvent(id: "evt-ntrip-2", date: baseDate.diff(numDays: 1))
        let event3 = TestDataFactory.makeEvent(id: "evt-ntrip-3", date: baseDate.diff(numDays: 2))

        store.add(event1)
        store.add(event2)
        store.add(event3)

        let trip = TestDataFactory.makeTrip(fromEventID: event2.id, toEventID: event3.id)
        store.addTrip(trip)

        // Delete event1 which has no trips
        store.delete(event1)

        // Trip between event2 and event3 should remain
        #expect(store.trips.count == 1)
        #expect(store.trips.first?.id == trip.id)
    }
}

// MARK: - Trip Display Name Resolution

@Suite("Trip Display Name for Other Locations")
struct TripDisplayNameTests {

    /// Mirrors the tripDisplayName logic used in TripsManagementView, TripsListView, and TripRefreshView
    private func tripDisplayName(for event: Event?) -> String {
        guard let event = event else { return "Unknown" }
        if event.location.name == "Other" {
            return event.effectiveCity ?? event.effectiveCountry ?? "Unknown City"
        }
        return event.location.name
    }

    @Test("Named location event returns location name")
    func namedLocationReturnsName() {
        let location = TestDataFactory.makeLocation(name: "Denver Loft")
        let event = TestDataFactory.makeEvent(location: location)
        #expect(tripDisplayName(for: event) == "Denver Loft")
    }

    @Test("Other event with city returns city name")
    func otherWithCityReturnsCityName() {
        let event = TestDataFactory.makeOtherEvent(city: "Paris", country: "France")
        #expect(tripDisplayName(for: event) == "Paris")
    }

    @Test("Other event with no city falls back to country")
    func otherNoCityReturnsCountry() {
        let event = TestDataFactory.makeOtherEvent(city: "", country: "France")
        // effectiveCity returns empty string (not nil) for empty city, so check the fallback chain
        let other = TestDataFactory.makeOtherLocation()
        let evt = TestDataFactory.makeEvent(
            location: other,
            city: nil,
            country: "Japan",
            state: nil
        )
        #expect(tripDisplayName(for: evt) == "Japan")
    }

    @Test("Other event with no city or country returns Unknown City")
    func otherNoCityNoCountryReturnsUnknown() {
        let other = TestDataFactory.makeOtherLocation()
        let event = TestDataFactory.makeEvent(
            location: other,
            city: nil,
            country: nil,
            state: nil
        )
        #expect(tripDisplayName(for: event) == "Unknown City")
    }

    @Test("Nil event returns Unknown")
    func nilEventReturnsUnknown() {
        #expect(tripDisplayName(for: nil) == "Unknown")
    }
}
