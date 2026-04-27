import Testing
import Foundation
@testable import LocTrac

@Suite("Event Image Tests")
struct EventImageTests {

    // MARK: - Helpers

    private static let testLocation = Location(
        id: "loc1", name: "TestPlace", city: nil, state: nil,
        latitude: 0, longitude: 0, country: nil, theme: .navy
    )

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Model Tests

    @Test("Event initializes with empty imageIDs by default")
    func defaultEmptyImageIDs() {
        let event = Event(
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            location: Self.testLocation,
            latitude: 0, longitude: 0, note: ""
        )
        #expect(event.imageIDs.isEmpty)
    }

    @Test("Event preserves imageIDs when provided via enum init")
    func enumInitWithImageIDs() {
        let ids = ["photo1.jpg", "photo2.jpg"]
        let event = Event(
            eventType: .stay,
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            location: Self.testLocation,
            latitude: 0, longitude: 0, note: "",
            imageIDs: ids
        )
        #expect(event.imageIDs == ids)
    }

    @Test("Event preserves imageIDs when provided via raw string init")
    func rawInitWithImageIDs() {
        let ids = ["img_a.jpg", "img_b.jpg", "img_c.jpg"]
        let event = Event(
            eventTypeRaw: "vacation",
            date: Self.makeDate(year: 2026, month: 6, day: 15),
            location: Self.testLocation,
            latitude: 0, longitude: 0, note: "Beach trip",
            imageIDs: ids
        )
        #expect(event.imageIDs == ids)
        #expect(event.imageIDs.count == 3)
    }

    @Test("Event with no imageIDs parameter defaults to empty array")
    func rawInitDefaultsEmpty() {
        let event = Event(
            eventTypeRaw: "stay",
            date: Self.makeDate(year: 2026, month: 3, day: 10),
            location: Self.testLocation,
            latitude: 0, longitude: 0, note: ""
        )
        #expect(event.imageIDs == [])
    }

    // MARK: - Max Image Limit

    @Test("Event can hold up to 6 imageIDs")
    func maxSixImages() {
        let ids = (1...6).map { "photo\($0).jpg" }
        let event = Event(
            eventTypeRaw: "stay",
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            location: Self.testLocation,
            latitude: 0, longitude: 0, note: "",
            imageIDs: ids
        )
        #expect(event.imageIDs.count == 6)
    }

    // MARK: - ViewModel Tests

    @Test("EventFormViewModel loads imageIDs from event")
    func viewModelLoadsImageIDs() {
        let ids = ["a.jpg", "b.jpg"]
        let event = Event(
            eventTypeRaw: "stay",
            date: Self.makeDate(year: 2026, month: 4, day: 1),
            location: Self.testLocation,
            latitude: 0, longitude: 0, note: "test",
            imageIDs: ids
        )
        let vm = EventFormViewModel(event)
        #expect(vm.imageIDs == ids)
    }

    @Test("EventFormViewModel defaults to empty imageIDs")
    func viewModelDefaultsEmpty() {
        let vm = EventFormViewModel()
        #expect(vm.imageIDs.isEmpty)
    }

    @Test("EventFormViewModel loads empty when event has no images")
    func viewModelLoadsEmptyFromEvent() {
        let event = Event(
            eventTypeRaw: "host",
            date: Self.makeDate(year: 2026, month: 5, day: 20),
            location: Self.testLocation,
            latitude: 0, longitude: 0, note: ""
        )
        let vm = EventFormViewModel(event)
        #expect(vm.imageIDs.isEmpty)
    }

    // MARK: - Codable Backward Compatibility

    @Test("Event without imageIDs in JSON decodes with empty array")
    func backwardCompatDecoding() throws {
        // Simulate old backup JSON without imageIDs
        let json = """
        {
            "locationID": "loc1",
            "id": "evt1",
            "eventType": "stay",
            "date": 0,
            "latitude": 0,
            "longitude": 0,
            "note": "old event",
            "activityIDs": [],
            "affirmationIDs": []
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Export.EventData.self, from: data)
        #expect(decoded.imageIDs.isEmpty)
    }

    @Test("Event with imageIDs in JSON decodes correctly")
    func decodingWithImageIDs() throws {
        let json = """
        {
            "locationID": "loc1",
            "id": "evt2",
            "eventType": "vacation",
            "date": 0,
            "latitude": 40.0,
            "longitude": -105.0,
            "note": "trip",
            "activityIDs": [],
            "affirmationIDs": [],
            "imageIDs": ["photo1.jpg", "photo2.jpg"]
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Export.EventData.self, from: data)
        #expect(decoded.imageIDs == ["photo1.jpg", "photo2.jpg"])
    }

    @Test("Import Event without imageIDs decodes as nil")
    func importBackwardCompat() throws {
        let json = """
        {
            "locationID": "loc1",
            "id": "evt3",
            "eventType": "stay",
            "date": 0,
            "latitude": 0,
            "longitude": 0,
            "note": "",
            "activityIDs": [],
            "affirmationIDs": []
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Import.Event.self, from: data)
        #expect(decoded.imageIDs == nil)
    }

    @Test("Export roundtrip preserves imageIDs")
    func exportRoundtrip() throws {
        let ids = ["sunset.jpg", "beach.jpg"]
        let event = Event(
            eventTypeRaw: "vacation",
            date: Self.makeDate(year: 2026, month: 7, day: 4),
            location: Self.testLocation,
            latitude: 40.0, longitude: -105.0, note: "July 4th",
            imageIDs: ids
        )
        let location = Self.testLocation

        let export = Export(
            locations: [location],
            events: [event],
            activities: [],
            affirmations: [],
            trips: [],
            eventTypes: [],
            exerciseEntries: [],
            cars: []
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(export)
        let decoder = JSONDecoder()
        let reimported = try decoder.decode(Export.self, from: data)

        #expect(reimported.events.first?.imageIDs == ids)
    }
}
