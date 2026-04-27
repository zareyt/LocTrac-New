//
//  DataStoreCRUDTests.swift
//  LocTracTests
//
//  Unit tests for DataStore CRUD operations using Swift Testing.
//

import Testing
import Foundation
@testable import LocTrac

@Suite("DataStore CRUD Operations")
@MainActor
struct DataStoreCRUDTests {

    // MARK: - Helper

    /// Creates a fresh DataStore in preview mode for isolated testing.
    private func makeStore() -> DataStore {
        DataStore(preview: true)
    }

    // MARK: - Events: Add

    @Test("Adding an event increases the events count")
    func addEventIncreasesCount() {
        let store = makeStore()
        let initialCount = store.events.count
        let event = TestDataFactory.makeEvent(date: Date().startOfDay)
        store.events.append(event) // direct append for count test (no side-effects needed)
        #expect(store.events.count == initialCount + 1)
    }

    @Test("add(_ event:) appends event and sets changedEvent")
    func addEventSetsChangedEvent() {
        let store = makeStore()
        let event = TestDataFactory.makeEvent(date: Date().startOfDay)
        store.add(event)
        #expect(store.changedEvent?.id == event.id)
        #expect(store.events.contains(where: { $0.id == event.id }))
    }

    @Test("Added event is findable by ID")
    func addedEventFindableByID() {
        let store = makeStore()
        let event = TestDataFactory.makeEvent(date: Date().startOfDay)
        store.add(event)
        let found = store.events.first(where: { $0.id == event.id })
        #expect(found != nil)
        #expect(found?.note == event.note)
    }

    @Test("Updating an event changes its note")
    func updateEventChangesNote() {
        let store = makeStore()
        var event = TestDataFactory.makeEvent(date: Date().startOfDay, note: "Original")
        store.add(event)

        event.note = "Updated note"
        // update expects eventType as String already stored
        store.update(event)

        let updated = store.events.first(where: { $0.id == event.id })
        #expect(updated?.note == "Updated note")
    }

    @Test("Updating an event changes its eventType")
    func updateEventChangesEventType() {
        let store = makeStore()
        var event = TestDataFactory.makeEvent(
            eventType: .stay,
            date: Date().startOfDay
        )
        store.add(event)

        // Change to vacation type
        event.eventType = Event.EventType.vacation.rawValue
        store.update(event)

        let updated = store.events.first(where: { $0.id == event.id })
        #expect(updated?.eventType == "vacation")
    }

    @Test("Deleting an event removes it from the store")
    func deleteEventRemovesFromStore() {
        let store = makeStore()
        let event = TestDataFactory.makeEvent(date: Date().startOfDay)
        store.add(event)
        #expect(store.events.contains(where: { $0.id == event.id }))

        store.delete(event)
        #expect(!store.events.contains(where: { $0.id == event.id }))
    }

    @Test("Deleting an event sets changedEvent")
    func deleteEventSetsChangedEvent() {
        let store = makeStore()
        let event = TestDataFactory.makeEvent(date: Date().startOfDay)
        store.add(event)
        store.delete(event)
        #expect(store.changedEvent?.id == event.id)
    }

    @Test("Multiple events can exist for the same date (store does not enforce one-per-day)")
    func multipleEventsPerDate() {
        let store = makeStore()
        let date = Date().startOfDay
        let event1 = TestDataFactory.makeEvent(date: date, note: "First")
        let event2 = TestDataFactory.makeEvent(date: date, note: "Second")

        store.add(event1)
        store.add(event2)

        let eventsOnDate = store.events.filter { $0.date.startOfDay == date }
        // DataStore.add does NOT enforce one-stay-per-day; that rule is in the form views
        #expect(eventsOnDate.count >= 2)
    }

    @Test("Preview-mode store starts with 'Other' location seeded")
    func previewStoreHasOtherLocation() {
        let store = makeStore()
        let hasOther = store.locations.contains { $0.name.caseInsensitiveCompare("Other") == .orderedSame }
        #expect(hasOther)
    }

    // MARK: - Locations: Add / Update / Delete

    @Test("Adding a location increases the locations count")
    func addLocationIncreasesCount() {
        let store = makeStore()
        let initialCount = store.locations.count
        let location = TestDataFactory.makeLocation(name: "Beach House")
        store.add(location)
        #expect(store.locations.count == initialCount + 1)
    }

    @Test("Updating a location changes its properties")
    func updateLocationChangesProperties() {
        let store = makeStore()
        var location = TestDataFactory.makeLocation(name: "Old Name", city: "Denver")
        store.add(location)

        location.name = "New Name"
        location.city = "Boulder"
        store.update(location)

        let updated = store.locations.first(where: { $0.id == location.id })
        #expect(updated?.name == "New Name")
        #expect(updated?.city == "Boulder")
    }

    @Test("Deleting a location removes it from the store")
    func deleteLocationRemovesIt() {
        let store = makeStore()
        let location = TestDataFactory.makeLocation(name: "Temporary")
        store.add(location)
        #expect(store.locations.contains(where: { $0.id == location.id }))

        store.delete(location)
        #expect(!store.locations.contains(where: { $0.id == location.id }))
    }

    @Test("ensureOtherLocationExists re-creates 'Other' if deleted")
    func otherLocationIsReCreatedIfMissing() {
        let store = makeStore()
        // Remove all locations including Other
        store.locations.removeAll()
        #expect(!store.locations.contains(where: { $0.name == "Other" }))

        let wasAdded = store.ensureOtherLocationExists(saveIfAdded: false)
        #expect(wasAdded)
        #expect(store.locations.contains(where: { $0.name == "Other" }))
    }

    @Test("Location with imageIDs preserves them through add and retrieval")
    func locationImageIDsPreserved() {
        let store = makeStore()
        let imageIDs = ["img_001.jpg", "img_002.jpg"]
        let location = TestDataFactory.makeLocation(name: "Photo Spot", imageIDs: imageIDs)
        store.add(location)

        let found = store.locations.first(where: { $0.id == location.id })
        #expect(found?.imageIDs == imageIDs)
    }

    // MARK: - Trips: Add / Delete

    @Test("addTrip increases the trips count")
    func addTripIncreasesCount() {
        let store = makeStore()
        let initialCount = store.trips.count
        let trip = TestDataFactory.makeTrip()
        store.addTrip(trip)
        #expect(store.trips.count == initialCount + 1)
    }

    @Test("deleteTrip removes the trip from the store")
    func deleteTripRemovesIt() {
        let store = makeStore()
        let trip = TestDataFactory.makeTrip()
        store.addTrip(trip)
        #expect(store.trips.contains(where: { $0.id == trip.id }))

        store.deleteTrip(trip)
        #expect(!store.trips.contains(where: { $0.id == trip.id }))
    }

    @Test("Trip references events using String IDs")
    func tripReferencesStringEventIDs() {
        let store = makeStore()
        let event1 = TestDataFactory.makeEvent(date: Date().startOfDay, note: "From")
        let event2 = TestDataFactory.makeEvent(date: Date().startOfDay, note: "To")
        store.add(event1)
        store.add(event2)

        let trip = TestDataFactory.makeTrip(
            fromEventID: event1.id,
            toEventID: event2.id
        )
        store.addTrip(trip)

        let found = store.trips.first(where: { $0.id == trip.id })
        #expect(found?.fromEventID == event1.id)
        #expect(found?.toEventID == event2.id)
        // Confirm the referenced events actually exist
        #expect(store.events.contains(where: { $0.id == found?.fromEventID }))
        #expect(store.events.contains(where: { $0.id == found?.toEventID }))
    }

    @Test("Deleting an event removes associated trips")
    func deletingEventRemovesAssociatedTrips() {
        let store = makeStore()
        let event1 = TestDataFactory.makeEvent(date: Date().startOfDay, note: "From")
        let event2 = TestDataFactory.makeEvent(date: Date().startOfDay, note: "To")
        store.add(event1)
        store.add(event2)

        let trip = TestDataFactory.makeTrip(
            fromEventID: event1.id,
            toEventID: event2.id
        )
        store.addTrip(trip)
        #expect(store.trips.count >= 1)

        store.delete(event1)
        // Trip referencing deleted event should be removed
        let tripStillExists = store.trips.contains(where: { $0.id == trip.id })
        #expect(!tripStillExists)
    }

    // MARK: - Activities

    @Test("addActivity increases the activities count")
    func addActivityIncreasesCount() {
        let store = makeStore()
        let initialCount = store.activities.count
        let activity = TestDataFactory.makeActivity(name: "Surfing")
        store.addActivity(activity)
        #expect(store.activities.count == initialCount + 1)
    }

    @Test("deleteActivity removes it and cleans up event references")
    func deleteActivityCleansUpReferences() {
        let store = makeStore()
        let activity = TestDataFactory.makeActivity(name: "Kayaking")
        store.addActivity(activity)

        // Create an event that references this activity
        let event = TestDataFactory.makeEvent(
            date: Date().startOfDay,
            activityIDs: [activity.id]
        )
        store.add(event)

        store.deleteActivity(activity)
        #expect(!store.activities.contains(where: { $0.id == activity.id }))

        // Event should no longer reference the deleted activity
        let updatedEvent = store.events.first(where: { $0.id == event.id })
        #expect(updatedEvent?.activityIDs.contains(activity.id) == false)
    }

    // MARK: - Affirmations

    @Test("addAffirmation increases the affirmations count")
    func addAffirmationIncreasesCount() {
        let store = makeStore()
        let initialCount = store.affirmations.count
        let affirmation = Affirmation(
            text: "Test affirmation",
            category: .gratitude,
            color: "blue",
            isFavorite: false
        )
        store.addAffirmation(affirmation)
        #expect(store.affirmations.count == initialCount + 1)
    }

    // MARK: - Tokens

    @Test("bumpCalendarRefresh changes calendarRefreshToken")
    func bumpCalendarRefreshChangesToken() {
        let store = makeStore()
        let oldToken = store.calendarRefreshToken
        store.bumpCalendarRefresh()
        #expect(store.calendarRefreshToken != oldToken)
    }

    @Test("bumpDataUpdate changes dataUpdateToken")
    func bumpDataUpdateChangesToken() {
        let store = makeStore()
        let oldToken = store.dataUpdateToken
        store.bumpDataUpdate()
        #expect(store.dataUpdateToken != oldToken)
    }

    // MARK: - Event Types

    @Test("addEventType increases the eventTypes count")
    func addEventTypeIncreasesCount() {
        let store = makeStore()
        let initialCount = store.eventTypes.count
        let eventType = TestDataFactory.makeEventType(
            name: "camping",
            displayName: "Camping",
            sfSymbol: "tent.fill",
            colorName: "green"
        )
        store.addEventType(eventType)
        #expect(store.eventTypes.count == initialCount + 1)
    }

    @Test("deleteEventType removes it and resets events to unspecified")
    func deleteEventTypeResetsEventsToUnspecified() {
        let store = makeStore()
        let customType = TestDataFactory.makeEventType(
            name: "camping",
            displayName: "Camping",
            sfSymbol: "tent.fill",
            colorName: "green"
        )
        store.addEventType(customType)

        // Create an event using this custom type — we set eventType manually
        var event = TestDataFactory.makeEvent(
            eventType: .unspecified,
            date: Date().startOfDay,
            note: "Camping trip"
        )
        event.eventType = "camping"
        store.add(event)

        // Verify the event has the custom type
        let beforeDelete = store.events.first(where: { $0.id == event.id })
        #expect(beforeDelete?.eventType == "camping")

        // Delete the custom event type
        store.deleteEventType(customType)
        #expect(!store.eventTypes.contains(where: { $0.id == customType.id }))

        // Event should be reset to "unspecified"
        let afterDelete = store.events.first(where: { $0.id == event.id })
        #expect(afterDelete?.eventType == "unspecified")
    }

    @Test("Built-in event types cannot be deleted")
    func builtInEventTypeCannotBeDeleted() {
        let store = makeStore()
        // Find a built-in type
        guard let builtIn = store.eventTypes.first(where: { $0.isBuiltIn }) else {
            Issue.record("No built-in event types found in store")
            return
        }
        let countBefore = store.eventTypes.count
        store.deleteEventType(builtIn)
        // Should still be present
        #expect(store.eventTypes.count == countBefore)
        #expect(store.eventTypes.contains(where: { $0.id == builtIn.id }))
    }

    // MARK: - Location Update Propagates to Events

    @Test("Updating a location propagates changes to events referencing it")
    func locationUpdatePropagatesToEvents() {
        let store = makeStore()
        var location = TestDataFactory.makeLocation(name: "The Loft", city: "Denver")
        store.add(location)

        let event = TestDataFactory.makeEvent(
            date: Date().startOfDay,
            location: location,
            note: "Stay at the loft"
        )
        store.add(event)

        // Update the location name
        location.name = "The Penthouse"
        store.update(location)

        // The event's embedded location snapshot should be updated
        let updatedEvent = store.events.first(where: { $0.id == event.id })
        #expect(updatedEvent?.location.name == "The Penthouse")
    }
}
