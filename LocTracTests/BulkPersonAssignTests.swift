import Testing
import Foundation
@testable import LocTrac

@Suite("BulkPersonAssign Logic Tests")
struct BulkPersonAssignTests {

    // MARK: - Helpers

    private static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static let testLocation = Location(
        id: "loc1", name: "TestPlace", city: nil, state: nil,
        latitude: 0, longitude: 0, country: nil, theme: .navy
    )

    private static func makeEvent(
        date: Date,
        people: [Person] = [],
        id: String = UUID().uuidString
    ) -> Event {
        Event(
            id: id,
            eventTypeRaw: "stay",
            date: date,
            location: testLocation,
            city: "",
            latitude: 0,
            longitude: 0,
            note: "",
            people: people
        )
    }

    // MARK: - contactIdentifier matching

    @Test("Matches person by contactIdentifier even if displayName differs")
    func matchByContactIdentifier() {
        let contactID = "CNContact-123"
        let existingPerson = Person(displayName: "John", contactIdentifier: contactID)
        let newPerson = Person(displayName: "John Smith", contactIdentifier: contactID)
        let event = Self.makeEvent(
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            people: [existingPerson]
        )

        let alreadyExists = personAlreadyExists(in: event, person: newPerson)
        #expect(alreadyExists == true)
    }

    @Test("Does not match when contactIdentifiers differ")
    func noMatchDifferentContactIdentifier() {
        let existingPerson = Person(displayName: "John Smith", contactIdentifier: "CNContact-123")
        let newPerson = Person(displayName: "John Smith", contactIdentifier: "CNContact-456")
        let event = Self.makeEvent(
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            people: [existingPerson]
        )

        let alreadyExists = personAlreadyExists(in: event, person: newPerson)
        #expect(alreadyExists == false)
    }

    // MARK: - displayName fallback matching

    @Test("Falls back to displayName match when no contactIdentifier on new person")
    func matchByDisplayNameFallback() {
        let existingPerson = Person(displayName: "Jane Doe", contactIdentifier: nil)
        let newPerson = Person(displayName: "jane doe", contactIdentifier: nil)
        let event = Self.makeEvent(
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            people: [existingPerson]
        )

        let alreadyExists = personAlreadyExists(in: event, person: newPerson)
        #expect(alreadyExists == true)
    }

    @Test("DisplayName match is case-insensitive")
    func displayNameCaseInsensitive() {
        let existingPerson = Person(displayName: "TIM AREY", contactIdentifier: nil)
        let newPerson = Person(displayName: "Tim Arey", contactIdentifier: nil)
        let event = Self.makeEvent(
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            people: [existingPerson]
        )

        let alreadyExists = personAlreadyExists(in: event, person: newPerson)
        #expect(alreadyExists == true)
    }

    @Test("No match when displayName differs and no contactIdentifier")
    func noMatchDifferentDisplayName() {
        let existingPerson = Person(displayName: "John", contactIdentifier: nil)
        let newPerson = Person(displayName: "Jane", contactIdentifier: nil)
        let event = Self.makeEvent(
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            people: [existingPerson]
        )

        let alreadyExists = personAlreadyExists(in: event, person: newPerson)
        #expect(alreadyExists == false)
    }

    // MARK: - Empty people array

    @Test("No match when event has no people")
    func noMatchEmptyPeople() {
        let newPerson = Person(displayName: "John", contactIdentifier: "CNContact-123")
        let event = Self.makeEvent(
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            people: []
        )

        let alreadyExists = personAlreadyExists(in: event, person: newPerson)
        #expect(alreadyExists == false)
    }

    // MARK: - Mixed scenario

    @Test("ContactIdentifier takes priority over displayName mismatch")
    func contactIdPriorityOverName() {
        let contactID = "CNContact-999"
        let existingPerson = Person(displayName: "Bob", contactIdentifier: contactID)
        let newPerson = Person(displayName: "Robert Johnson", contactIdentifier: contactID)
        let event = Self.makeEvent(
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            people: [existingPerson]
        )

        let alreadyExists = personAlreadyExists(in: event, person: newPerson)
        #expect(alreadyExists == true)
    }

    @Test("Empty contactIdentifier string does not match")
    func emptyContactIdDoesNotMatch() {
        let existingPerson = Person(displayName: "John", contactIdentifier: "")
        let newPerson = Person(displayName: "Jane", contactIdentifier: "")
        let event = Self.makeEvent(
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            people: [existingPerson]
        )

        let alreadyExists = personAlreadyExists(in: event, person: newPerson)
        #expect(alreadyExists == false)
    }

    // MARK: - Helper (mirrors BulkPersonAssignView logic)

    private func personAlreadyExists(in event: Event, person: Person) -> Bool {
        if let newContactID = person.contactIdentifier, !newContactID.isEmpty {
            if event.people.contains(where: { $0.contactIdentifier == newContactID }) {
                return true
            }
        }
        return event.people.contains(where: {
            $0.displayName.lowercased() == person.displayName.lowercased()
        })
    }
}
