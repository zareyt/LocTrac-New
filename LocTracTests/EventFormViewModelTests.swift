import Testing
import Foundation
@testable import LocTrac

@Suite("EventFormViewModel Tests")
struct EventFormViewModelTests {

    // MARK: - Initialization

    @Test("Default init has nil location, empty note, unspecified eventType, updating false, incomplete true")
    @MainActor
    func testDefaultInit() {
        let vm = EventFormViewModel()

        #expect(vm.location == nil)
        #expect(vm.note == "")
        // eventType defaults to UserDefaults value or "unspecified"
        let expectedType = UserDefaults.standard.string(forKey: "defaultEventType") ?? "unspecified"
        #expect(vm.eventType == expectedType)
        #expect(vm.updating == false)
        #expect(vm.incomplete == true)
    }

    @Test("Init from Event copies all fields correctly")
    @MainActor
    func testInitFromEvent() {
        let location = TestDataFactory.makeLocation(name: "Beach House", city: "Malibu", state: "California")
        let people = [TestDataFactory.makePerson(displayName: "Alice"), TestDataFactory.makePerson(displayName: "Bob")]
        let activityIDs = ["act-1", "act-2"]
        let imageIDs = ["img-1", "img-2"]

        let event = TestDataFactory.makeEvent(
            id: "evt-test-123",
            eventType: .vacation,
            date: Date(),
            location: location,
            city: "Malibu",
            latitude: 34.0259,
            longitude: -118.7798,
            country: "United States",
            state: "California",
            note: "Beach trip",
            people: people,
            activityIDs: activityIDs,
            imageIDs: imageIDs
        )

        let vm = EventFormViewModel(event)

        #expect(vm.date == event.date.startOfDay)
        #expect(vm.eventType == event.eventType)
        #expect(vm.id == event.id)
        #expect(vm.location?.id == location.id)
        #expect(vm.city == event.city)
        #expect(vm.state == event.state)
        #expect(vm.country == event.country)
        #expect(vm.latitude == event.latitude)
        #expect(vm.longitude == event.longitude)
        #expect(vm.note == event.note)
        #expect(vm.people.count == 2)
        #expect(vm.people[0].displayName == "Alice")
        #expect(vm.people[1].displayName == "Bob")
        #expect(vm.activityIDs == activityIDs)
        #expect(vm.affirmationIDs == event.affirmationIDs)
        #expect(vm.imageIDs == imageIDs)
    }

    @Test("Init from Event sets updating to true")
    @MainActor
    func testInitFromEventSetsUpdating() {
        let event = TestDataFactory.makeEvent(id: "evt-updating-test")
        let vm = EventFormViewModel(event)

        #expect(vm.updating == true)
        #expect(vm.id == "evt-updating-test")
    }

    @Test("Init with explicit parameters sets them correctly")
    @MainActor
    func testInitWithParameters() {
        let location = TestDataFactory.makeLocation(name: "Office")
        let date = Date().startOfDay

        let vm = EventFormViewModel(
            date: date,
            eventType: "business",
            location: location,
            id: "evt-param-test",
            city: "Denver",
            state: "Colorado",
            country: "United States",
            latitude: 39.7392,
            longitude: -104.9903,
            note: "Work meeting"
        )

        #expect(vm.date == date)
        #expect(vm.eventType == "business")
        #expect(vm.location?.id == location.id)
        #expect(vm.id == "evt-param-test")
        #expect(vm.city == "Denver")
        #expect(vm.state == "Colorado")
        #expect(vm.country == "United States")
        #expect(vm.latitude == 39.7392)
        #expect(vm.longitude == -104.9903)
        #expect(vm.note == "Work meeting")
    }

    @Test("Init with dateSelected and toDateSelected stores them")
    @MainActor
    func testInitWithDateSelected() {
        let dateSelected = Date()
        let toDateSelected = Date().addingTimeInterval(86400 * 3)

        let vm = EventFormViewModel(dateSelected: dateSelected, toDateSelected: toDateSelected)

        #expect(vm.dateSelected == dateSelected)
        #expect(vm.toDateSelected == toDateSelected)
    }

    // MARK: - Computed Properties

    @Test("incomplete is true when location is nil")
    @MainActor
    func testIncompleteWhenNoLocation() {
        let vm = EventFormViewModel()
        #expect(vm.location == nil)
        #expect(vm.incomplete == true)
    }

    @Test("incomplete is false when location is set")
    @MainActor
    func testNotIncompleteWhenLocationSet() {
        let vm = EventFormViewModel()
        vm.location = TestDataFactory.makeLocation()
        #expect(vm.incomplete == false)
    }

    @Test("updating is false for new event (default init)")
    @MainActor
    func testUpdatingIsFalseForNewEvent() {
        let vm = EventFormViewModel()
        #expect(vm.id == nil)
        #expect(vm.updating == false)
    }

    @Test("updating is true when id is set manually")
    @MainActor
    func testUpdatingIsTrueWhenIDSet() {
        let vm = EventFormViewModel()
        vm.id = "some-event-id"
        #expect(vm.updating == true)
    }

    // MARK: - Date Handling

    @Test("Init from Event normalizes date to startOfDay")
    @MainActor
    func testInitFromEventNormalizesDate() {
        // Create an event with a date that has a time component
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dateWithTime = calendar.date(bySettingHour: 14, minute: 30, second: 45, of: Date())!

        let event = TestDataFactory.makeEvent(date: dateWithTime)
        let vm = EventFormViewModel(event)

        let components = calendar.dateComponents([.hour, .minute, .second], from: vm.date)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("dateSelected init does not normalize date to startOfDay")
    @MainActor
    func testDateSelectedInitDoesNotNormalizeDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dateWithTime = calendar.date(bySettingHour: 14, minute: 30, second: 45, of: Date())!

        let vm = EventFormViewModel(dateSelected: dateWithTime, toDateSelected: nil)

        // dateSelected should be stored as-is, not normalized
        #expect(vm.dateSelected == dateWithTime)
    }

    // MARK: - Event Type

    @Test("eventType defaults to unspecified or stored UserDefaults value")
    @MainActor
    func testEventTypeDefaultsToUnspecified() {
        let vm = EventFormViewModel()
        let expectedType = UserDefaults.standard.string(forKey: "defaultEventType") ?? "unspecified"
        #expect(vm.eventType == expectedType)
    }

    // MARK: - People and Activities

    @Test("Init from Event copies people array")
    @MainActor
    func testInitFromEventCopiesPeople() {
        let people = [
            TestDataFactory.makePerson(displayName: "Alice"),
            TestDataFactory.makePerson(displayName: "Bob"),
            TestDataFactory.makePerson(displayName: "Charlie")
        ]
        let event = TestDataFactory.makeEvent(people: people)
        let vm = EventFormViewModel(event)

        #expect(vm.people.count == 3)
        #expect(vm.people[0].displayName == "Alice")
        #expect(vm.people[1].displayName == "Bob")
        #expect(vm.people[2].displayName == "Charlie")
    }

    @Test("Init from Event copies activityIDs")
    @MainActor
    func testInitFromEventCopiesActivityIDs() {
        let activityIDs = ["act-golf", "act-hiking", "act-dining"]
        let event = TestDataFactory.makeEvent(activityIDs: activityIDs)
        let vm = EventFormViewModel(event)

        #expect(vm.activityIDs == activityIDs)
        #expect(vm.activityIDs.count == 3)
    }

    @Test("Init from Event copies imageIDs")
    @MainActor
    func testInitFromEventCopiesImageIDs() {
        let imageIDs = ["photo-001", "photo-002"]
        let event = TestDataFactory.makeEvent(imageIDs: imageIDs)
        let vm = EventFormViewModel(event)

        #expect(vm.imageIDs == imageIDs)
        #expect(vm.imageIDs.count == 2)
    }
}
