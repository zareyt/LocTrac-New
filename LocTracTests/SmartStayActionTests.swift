import Testing
@testable import LocTrac

@Suite("SmartStayAction Logic Tests")
struct SmartStayActionTests {

    // MARK: - Helpers

    private static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    /// Creates a UTC date for the given year/month/day
    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Creates a minimal test event on the given date
    private static func makeEvent(date: Date, id: String = UUID().uuidString) -> Event {
        let location = Location(
            id: "loc1", name: "Test", city: nil, state: nil,
            latitude: 0, longitude: 0, country: nil, theme: .blue
        )
        return Event(
            id: id,
            eventTypeRaw: "stay",
            date: date,
            location: location,
            city: "",
            latitude: 0,
            longitude: 0,
            note: ""
        )
    }

    // MARK: - Priority 1: No event today -> addToday

    @Test("Empty events returns addToday")
    func emptyEventsReturnsAddToday() {
        let result = SmartStayAction.determine(events: [], today: makeDate(year: 2026, month: 4, day: 22))
        #expect(result == .addToday)
    }

    @Test("No event on today returns addToday")
    func noEventTodayReturnsAddToday() {
        let today = Self.makeDate(year: 2026, month: 4, day: 22)
        let yesterday = Self.makeDate(year: 2026, month: 4, day: 21)
        let events = [Self.makeEvent(date: yesterday)]

        let result = SmartStayAction.determine(events: events, today: today)
        #expect(result == .addToday)
    }

    @Test("Event exists on different day, not today, returns addToday")
    func eventOnDifferentDayReturnsAddToday() {
        let today = Self.makeDate(year: 2026, month: 4, day: 22)
        let events = [Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: 15))]

        let result = SmartStayAction.determine(events: events, today: today)
        #expect(result == .addToday)
    }

    // MARK: - Priority 2: Today has event, gaps exist -> fillGap

    @Test("Single gap day returns fillGap with that date")
    func singleGapDay() {
        let today = Self.makeDate(year: 2026, month: 4, day: 22)
        // Events on Apr 20, Apr 22 (today) - missing Apr 21
        let events = [
            Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: 20)),
            Self.makeEvent(date: today),
        ]

        let result = SmartStayAction.determine(events: events, today: today)
        let expected = Self.makeDate(year: 2026, month: 4, day: 21)
        #expect(result == .fillGap(from: expected, to: expected, missingCount: 1))
    }

    @Test("Multi-day gap returns fillGap with correct range")
    func multiDayGap() {
        let today = Self.makeDate(year: 2026, month: 4, day: 22)
        // Events on Apr 18, Apr 22 (today) - missing Apr 19, 20, 21
        let events = [
            Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: 18)),
            Self.makeEvent(date: today),
        ]

        let result = SmartStayAction.determine(events: events, today: today)
        let gapFrom = Self.makeDate(year: 2026, month: 4, day: 19)
        let gapTo = Self.makeDate(year: 2026, month: 4, day: 21)
        #expect(result == .fillGap(from: gapFrom, to: gapTo, missingCount: 3))
    }

    @Test("Most recent gap is found first when multiple gaps exist")
    func mostRecentGapFoundFirst() {
        let today = Self.makeDate(year: 2026, month: 4, day: 22)
        // Events: Apr 10, Apr 15, Apr 22 - gaps at Apr 11-14 AND Apr 16-21
        // Should find Apr 16-21 (most recent)
        let events = [
            Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: 10)),
            Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: 15)),
            Self.makeEvent(date: today),
        ]

        let result = SmartStayAction.determine(events: events, today: today)
        let gapFrom = Self.makeDate(year: 2026, month: 4, day: 16)
        let gapTo = Self.makeDate(year: 2026, month: 4, day: 21)
        #expect(result == .fillGap(from: gapFrom, to: gapTo, missingCount: 6))
    }

    @Test("Gap at the very beginning (oldest event + 1 day) is found")
    func gapAtBeginning() {
        let today = Self.makeDate(year: 2026, month: 4, day: 5)
        // Events: Apr 1, Apr 3, Apr 4, Apr 5 - gap at Apr 2
        let events = [
            Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: 1)),
            Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: 3)),
            Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: 4)),
            Self.makeEvent(date: today),
        ]

        let result = SmartStayAction.determine(events: events, today: today)
        let gapDate = Self.makeDate(year: 2026, month: 4, day: 2)
        #expect(result == .fillGap(from: gapDate, to: gapDate, missingCount: 1))
    }

    // MARK: - Priority 3: Today has event, no gaps -> editToday

    @Test("Today has event with no gaps returns editToday")
    func noGapsReturnsEditToday() {
        let today = Self.makeDate(year: 2026, month: 4, day: 22)
        // Continuous: Apr 20, 21, 22
        let events = [
            Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: 20)),
            Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: 21)),
            Self.makeEvent(date: today, id: "today-event"),
        ]

        let result = SmartStayAction.determine(events: events, today: today)
        if case .editToday(let event) = result {
            #expect(event.id == "today-event")
        } else {
            #expect(Bool(false), "Expected editToday but got \(result)")
        }
    }

    @Test("Single event on today with no other events returns editToday")
    func singleEventTodayReturnsEditToday() {
        let today = Self.makeDate(year: 2026, month: 4, day: 22)
        let events = [Self.makeEvent(date: today, id: "only-event")]

        let result = SmartStayAction.determine(events: events, today: today)
        if case .editToday(let event) = result {
            #expect(event.id == "only-event")
        } else {
            #expect(Bool(false), "Expected editToday but got \(result)")
        }
    }

    // MARK: - Edge Cases

    @Test("Events only in the future still checks today")
    func futureEventsOnly() {
        let today = Self.makeDate(year: 2026, month: 4, day: 22)
        let events = [Self.makeEvent(date: Self.makeDate(year: 2026, month: 5, day: 1))]

        let result = SmartStayAction.determine(events: events, today: today)
        #expect(result == .addToday)
    }

    @Test("Consecutive days with today covered returns editToday")
    func consecutiveDaysFullCoverage() {
        let today = Self.makeDate(year: 2026, month: 4, day: 5)
        let events = (1...5).map { day in
            Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: day))
        }

        let result = SmartStayAction.determine(events: events, today: today)
        if case .editToday = result {
            // pass
        } else {
            #expect(Bool(false), "Expected editToday for full coverage")
        }
    }

    // MARK: - Display Helpers

    @Test("addToday button label contains Add and Today")
    func addTodayLabel() {
        let label = SmartStayAction.addToday.buttonLabel
        #expect(label.contains("Add"), "Label should contain 'Add', got: \(label)")
        #expect(label.contains("Today"), "Label should contain 'Today', got: \(label)")
    }

    @Test("fillGap single day label shows date")
    func fillGapSingleDayLabel() {
        let date = Self.makeDate(year: 2026, month: 4, day: 15)
        let label = SmartStayAction.fillGap(from: date, to: date, missingCount: 1).buttonLabel
        #expect(label.contains("Apr 15"))
        #expect(!label.contains("days"))
    }

    @Test("fillGap multi day label shows range and count")
    func fillGapMultiDayLabel() {
        let from = Self.makeDate(year: 2026, month: 4, day: 10)
        let to = Self.makeDate(year: 2026, month: 4, day: 15)
        let label = SmartStayAction.fillGap(from: from, to: to, missingCount: 6).buttonLabel
        #expect(label.contains("Apr 10"))
        #expect(label.contains("Apr 15"))
        #expect(label.contains("6 days"))
    }

    @Test("editToday button label contains Edit and Today")
    func editTodayLabel() {
        let event = Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: 22))
        let label = SmartStayAction.editToday(event).buttonLabel
        #expect(label.contains("Edit"), "Label should contain 'Edit', got: \(label)")
        #expect(label.contains("Today"), "Label should contain 'Today', got: \(label)")
    }

    @Test("buttonIcon is calendar.badge.plus for add actions")
    func addActionIcons() {
        #expect(SmartStayAction.addToday.buttonIcon == "calendar.badge.plus")
        let date = Self.makeDate(year: 2026, month: 4, day: 15)
        #expect(SmartStayAction.fillGap(from: date, to: date, missingCount: 1).buttonIcon == "calendar.badge.plus")
    }

    @Test("buttonIcon is pencil.circle for edit action")
    func editActionIcon() {
        let event = Self.makeEvent(date: Self.makeDate(year: 2026, month: 4, day: 22))
        #expect(SmartStayAction.editToday(event).buttonIcon == "pencil.circle")
    }
}
