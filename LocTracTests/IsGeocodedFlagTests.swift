import Testing
import Foundation
@testable import LocTrac

@Suite("isGeocoded Flag Tests")
struct IsGeocodedFlagTests {

    // MARK: - Helpers

    private static func makeLocation(id: String = "loc-1", name: String = "Loft") -> Location {
        Location(id: id, name: name, city: "Denver", state: "Colorado",
                 latitude: 39.7392, longitude: -104.9903, country: "United States",
                 theme: .navy)
    }

    private static func makeEvent(
        id: String = "evt-1",
        location: Location? = nil,
        isGeocoded: Bool = false
    ) -> Event {
        let loc = location ?? makeLocation()
        return Event(id: id, eventType: .stay, date: Date().startOfDay,
                     location: loc, latitude: loc.latitude, longitude: loc.longitude,
                     note: "", isGeocoded: isGeocoded)
    }

    // MARK: - Default Value

    @Test("New events default isGeocoded to false")
    func newEventDefaultsToFalse() {
        let event = Self.makeEvent()
        #expect(event.isGeocoded == false)
    }

    @Test("Event can be created with isGeocoded true")
    func eventCreatedWithGeocodedTrue() {
        let event = Self.makeEvent(isGeocoded: true)
        #expect(event.isGeocoded == true)
    }

    // MARK: - Location Change Detection Logic

    @Test("Same location preserves isGeocoded true")
    func sameLocationPreservesGeocoded() {
        let location = Self.makeLocation(id: "loc-A")
        let originalEvent = Self.makeEvent(location: location, isGeocoded: true)

        let selectedLocation = Self.makeLocation(id: "loc-A")
        let locationChanged = originalEvent.location.id != selectedLocation.id
        let shouldKeepGeocoded = !locationChanged && originalEvent.isGeocoded

        #expect(locationChanged == false)
        #expect(shouldKeepGeocoded == true)
    }

    @Test("Different location resets isGeocoded to false")
    func differentLocationResetsGeocoded() {
        let originalLocation = Self.makeLocation(id: "loc-A", name: "Loft")
        let newLocation = Self.makeLocation(id: "loc-B", name: "Cabo")
        let originalEvent = Self.makeEvent(location: originalLocation, isGeocoded: true)

        let locationChanged = originalEvent.location.id != newLocation.id
        let shouldKeepGeocoded = !locationChanged && originalEvent.isGeocoded

        #expect(locationChanged == true)
        #expect(shouldKeepGeocoded == false)
    }

    @Test("Same location preserves isGeocoded false (no false positive)")
    func sameLocationKeepsFalse() {
        let location = Self.makeLocation(id: "loc-A")
        let originalEvent = Self.makeEvent(location: location, isGeocoded: false)

        let locationChanged = originalEvent.location.id != location.id
        let shouldKeepGeocoded = !locationChanged && originalEvent.isGeocoded

        #expect(locationChanged == false)
        #expect(shouldKeepGeocoded == false)
    }

    @Test("Location change from named to Other resets isGeocoded")
    func namedToOtherResetsGeocoded() {
        let namedLocation = Self.makeLocation(id: "loc-named", name: "Loft")
        let otherLocation = Self.makeLocation(id: "loc-other", name: "Other")
        let originalEvent = Self.makeEvent(location: namedLocation, isGeocoded: true)

        let locationChanged = originalEvent.location.id != otherLocation.id
        let shouldKeepGeocoded = !locationChanged && originalEvent.isGeocoded

        #expect(locationChanged == true)
        #expect(shouldKeepGeocoded == false)
    }

    // MARK: - Nil Original Event (safety)

    @Test("Missing original event defaults isGeocoded to false")
    func missingOriginalEventDefaultsFalse() {
        let originalEvent: Event? = nil
        let selectedLocation = Self.makeLocation(id: "loc-A")

        let locationChanged = originalEvent?.location.id != selectedLocation.id
        let shouldKeepGeocoded = !locationChanged && (originalEvent?.isGeocoded ?? false)

        // When original is nil, location.id comparison is nil != "loc-A" = true (changed)
        #expect(locationChanged == true)
        #expect(shouldKeepGeocoded == false)
    }

    // Note: Event is not Codable (serialization uses Export/Import pipeline).
    // isGeocoded is a runtime-only flag not persisted in backup.json.
}
