//
//  EventTypeCRUDTests.swift
//  LocTrac
//
//  Tests for EventTypeItem CRUD operations, lookup, and default preferences.
//  Uses Swift Testing framework (@Test, #expect).
//
//  NOTE: Requires a test target to be added in Xcode.
//  File > New > Target > Unit Testing Bundle, then move this file there.
//

import Testing
import Foundation
@testable import LocTrac

@Suite("EventType CRUD Tests")
struct EventTypeCRUDTests {

    // Helper: create a DataStore with defaults seeded
    private func makeStore() -> DataStore {
        let store = DataStore(preview: true)
        if store.eventTypes.isEmpty {
            for item in EventTypeItem.defaults {
                store.eventTypes.append(item)
            }
        }
        return store
    }

    // MARK: - Defaults

    @Test("Default event types are seeded with 6 built-in types")
    func defaultsSeeded() {
        let store = makeStore()
        #expect(store.eventTypes.count == 6)
    }

    @Test("Each default type has a unique name")
    func defaultNamesUnique() {
        let names = Set(EventTypeItem.defaults.map { $0.name })
        #expect(names.count == EventTypeItem.defaults.count)
    }

    @Test("Each default type has a unique color")
    func defaultColorsUnique() {
        let colors = Set(EventTypeItem.defaults.map { $0.colorName })
        #expect(colors.count == EventTypeItem.defaults.count)
    }

    @Test("All default types are marked as built-in")
    func defaultsAreBuiltIn() {
        for item in EventTypeItem.defaults {
            #expect(item.isBuiltIn == true, "Expected \(item.name) to be built-in")
        }
    }

    // MARK: - Add

    @Test("Adding a custom event type increases count")
    func addCustomType() {
        let store = makeStore()
        let custom = EventTypeItem(name: "camping", displayName: "Camping", sfSymbol: "tent.fill", colorName: "green")
        store.addEventType(custom)
        #expect(store.eventTypes.count == 7)
    }

    @Test("Added custom type is not built-in")
    func addedTypeNotBuiltIn() {
        let store = makeStore()
        let custom = EventTypeItem(name: "camping", displayName: "Camping", sfSymbol: "tent.fill", colorName: "green")
        store.addEventType(custom)
        let found = store.eventTypes.first(where: { $0.name == "camping" })
        #expect(found?.isBuiltIn == false)
    }

    // MARK: - Lookup

    @Test("eventTypeItem(for:) returns stored type")
    func lookupStored() {
        let store = makeStore()
        let custom = EventTypeItem(name: "camping", displayName: "Camping", sfSymbol: "tent.fill", colorName: "green")
        store.addEventType(custom)
        let found = store.eventTypeItem(for: "camping")
        #expect(found.displayName == "Camping")
        #expect(found.sfSymbol == "tent.fill")
    }

    @Test("eventTypeItem(for:) returns built-in type")
    func lookupBuiltIn() {
        let store = makeStore()
        let stay = store.eventTypeItem(for: "stay")
        #expect(stay.sfSymbol == "bed.double.fill")
        #expect(stay.colorName == "red")
    }

    @Test("eventTypeItem(for:) falls back for unknown type")
    func lookupUnknown() {
        let store = makeStore()
        let unknown = store.eventTypeItem(for: "xyz_nonexistent")
        #expect(unknown.sfSymbol == "questionmark.circle")
        #expect(unknown.colorName == "gray")
        #expect(unknown.displayName == "Xyz_nonexistent")
    }

    // MARK: - Update

    @Test("Updating a type changes its properties")
    func updateProperties() {
        let store = makeStore()
        let custom = EventTypeItem(name: "camping", displayName: "Camping", sfSymbol: "tent.fill", colorName: "green")
        store.addEventType(custom)

        var updated = custom
        updated.displayName = "Glamping"
        updated.sfSymbol = "sparkles"
        store.updateEventType(updated)

        let found = store.eventTypeItem(for: "camping")
        #expect(found.displayName == "Glamping")
        #expect(found.sfSymbol == "sparkles")
    }

    @Test("Renaming a type remaps all events using the old name")
    func updateRemapsEvents() {
        let store = makeStore()
        let custom = EventTypeItem(name: "camping", displayName: "Camping", sfSymbol: "tent.fill", colorName: "green")
        store.addEventType(custom)

        let event = Event(eventTypeRaw: "camping", date: Date(),
                          location: Location.sampleData[0],
                          latitude: 0, longitude: 0, note: "test")
        store.events = [event]

        var renamed = custom
        renamed.name = "glamping"
        renamed.displayName = "Glamping"
        store.updateEventType(renamed)

        #expect(store.events[0].eventType == "glamping")
    }

    // MARK: - Delete

    @Test("Deleting a custom type removes it from store")
    func deleteCustomType() {
        let store = makeStore()
        let custom = EventTypeItem(name: "camping", displayName: "Camping", sfSymbol: "tent.fill", colorName: "green")
        store.addEventType(custom)
        #expect(store.eventTypes.count == 7)

        store.deleteEventType(custom)
        #expect(store.eventTypes.count == 6)
        #expect(store.eventTypes.contains(where: { $0.name == "camping" }) == false)
    }

    @Test("Deleting a custom type resets events to unspecified")
    func deleteResetsEvents() {
        let store = makeStore()
        let custom = EventTypeItem(name: "camping", displayName: "Camping", sfSymbol: "tent.fill", colorName: "green")
        store.addEventType(custom)

        let event = Event(eventTypeRaw: "camping", date: Date(),
                          location: Location.sampleData[0],
                          latitude: 0, longitude: 0, note: "test")
        store.events = [event]

        store.deleteEventType(custom)
        #expect(store.events[0].eventType == "unspecified")
    }

    @Test("Cannot delete a built-in type")
    func cannotDeleteBuiltIn() {
        let store = makeStore()
        let stay = store.eventTypes.first(where: { $0.name == "stay" })!
        store.deleteEventType(stay)
        #expect(store.eventTypes.contains(where: { $0.name == "stay" }) == true)
    }

    // MARK: - Color Mapping

    @Test("All available colors resolve without error")
    func allColorsResolve() {
        for (name, _) in EventTypeItem.availableColors {
            let _ = EventTypeItem.colorFromName(name)
        }
        #expect(EventTypeItem.availableColors.count == 13)
    }

    // MARK: - Default Preference

    @Test("Default event type reads from UserDefaults")
    func defaultEventTypeFromUserDefaults() {
        UserDefaults.standard.set("vacation", forKey: "defaultEventType")
        let value = UserDefaults.standard.string(forKey: "defaultEventType")
        #expect(value == "vacation")
        UserDefaults.standard.removeObject(forKey: "defaultEventType")
    }

    @Test("Clearing default event type removes from UserDefaults")
    func clearDefaultEventType() {
        UserDefaults.standard.set("stay", forKey: "defaultEventType")
        UserDefaults.standard.removeObject(forKey: "defaultEventType")
        let value = UserDefaults.standard.string(forKey: "defaultEventType")
        #expect(value == nil)
    }

    @Test("Default event type preference stored in UserProfile")
    func defaultEventTypeInProfile() {
        var profile = UserProfile(displayName: "Test User")
        #expect(profile.defaultEventType == nil)
        profile.defaultEventType = "business"
        #expect(profile.defaultEventType == "business")
    }
}
