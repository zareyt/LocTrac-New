import Testing
import Foundation
@testable import LocTrac

@Suite("Stay Reminder UTC Tests")
struct StayReminderTests {

    // MARK: - Helpers

    private static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    /// Creates a UTC midnight date for the given year/month/day
    private static func makeUTCDate(year: Int, month: Int, day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Creates a minimal Event with the given date (UTC midnight)
    private static func makeEvent(date: Date) -> Event {
        let otherLocation = Location(
            id: "other-id",
            name: "Other",
            city: nil,
            latitude: 0,
            longitude: 0,
            country: nil,
            theme: .gray
        )
        return Event(
            id: UUID().uuidString,
            eventType: "Stay",
            date: date,
            location: otherLocation,
            city: "Test City",
            latitude: 39.0,
            longitude: -105.0,
            country: "United States",
            note: "",
            people: [],
            activityIDs: [],
            affirmationIDs: []
        )
    }

    /// Counts missing days in the last 7 days using UTC calendar (mirrors fixed NotificationManager logic)
    private static func countMissingDays(events: [Event], referenceDate: Date) -> (missingCount: Int, hasStayToday: Bool) {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!

        let today = utcCal.startOfDay(for: referenceDate)
        let hasStayToday = events.contains { event in
            utcCal.isDate(event.date, inSameDayAs: today)
        }

        let sevenDaysAgo = utcCal.date(byAdding: .day, value: -7, to: today)!
        let daysWithStays = Set(events.compactMap { event -> Date? in
            let eventDay = utcCal.startOfDay(for: event.date)
            guard eventDay >= sevenDaysAgo && eventDay <= today else { return nil }
            return eventDay
        })

        var missingCount = 0
        var currentDate = sevenDaysAgo
        while currentDate <= today {
            if !daysWithStays.contains(currentDate) {
                missingCount += 1
            }
            currentDate = utcCal.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return (missingCount, hasStayToday)
    }

    /// Counts missing days using local calendar (the old buggy approach)
    private static func countMissingDaysLocal(events: [Event], referenceDate: Date) -> (missingCount: Int, hasStayToday: Bool) {
        let localCal = Calendar.current

        let today = localCal.startOfDay(for: referenceDate)
        let hasStayToday = events.contains { event in
            localCal.isDate(event.date, inSameDayAs: today)
        }

        let sevenDaysAgo = localCal.date(byAdding: .day, value: -7, to: today)!
        let daysWithStays = Set(events.compactMap { event -> Date? in
            let eventDay = localCal.startOfDay(for: event.date)
            guard eventDay >= sevenDaysAgo && eventDay <= today else { return nil }
            return eventDay
        })

        var missingCount = 0
        var currentDate = sevenDaysAgo
        while currentDate <= today {
            if !daysWithStays.contains(currentDate) {
                missingCount += 1
            }
            currentDate = localCal.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return (missingCount, hasStayToday)
    }

    // MARK: - UTC hasStayToday Detection

    @Test("UTC correctly detects today's stay when event date is UTC midnight")
    func utcDetectsTodaysStay() {
        let today = Self.utcCalendar.startOfDay(for: Date())
        let event = Self.makeEvent(date: today)

        let result = Self.countMissingDays(events: [event], referenceDate: Date())
        #expect(result.hasStayToday == true)
    }

    @Test("No events means today has no stay")
    func noEventsNoStay() {
        let result = Self.countMissingDays(events: [], referenceDate: Date())
        #expect(result.hasStayToday == false)
    }

    @Test("Yesterday's event is not detected as today's stay")
    func yesterdayNotToday() {
        let yesterday = Self.utcCalendar.date(byAdding: .day, value: -1, to: Self.utcCalendar.startOfDay(for: Date()))!
        let event = Self.makeEvent(date: yesterday)

        let result = Self.countMissingDays(events: [event], referenceDate: Date())
        #expect(result.hasStayToday == false)
    }

    // MARK: - Missing Days Counting

    @Test("All 8 days missing when no events in past week")
    func allDaysMissingNoEvents() {
        // 7 days ago through today = 8 days total
        let result = Self.countMissingDays(events: [], referenceDate: Date())
        #expect(result.missingCount == 8)
    }

    @Test("Full week of events means zero missing days")
    func fullWeekNoMissing() {
        let today = Self.utcCalendar.startOfDay(for: Date())
        var events: [Event] = []
        for dayOffset in -7...0 {
            let date = Self.utcCalendar.date(byAdding: .day, value: dayOffset, to: today)!
            events.append(Self.makeEvent(date: date))
        }

        let result = Self.countMissingDays(events: events, referenceDate: Date())
        #expect(result.missingCount == 0)
        #expect(result.hasStayToday == true)
    }

    @Test("Only today's event means 7 missing days")
    func onlyTodayMeans7Missing() {
        let today = Self.utcCalendar.startOfDay(for: Date())
        let event = Self.makeEvent(date: today)

        let result = Self.countMissingDays(events: [event], referenceDate: Date())
        #expect(result.missingCount == 7)
        #expect(result.hasStayToday == true)
    }

    @Test("Events outside the 7-day window are not counted")
    func eventsOutsideWindowIgnored() {
        let today = Self.utcCalendar.startOfDay(for: Date())
        let twoWeeksAgo = Self.utcCalendar.date(byAdding: .day, value: -14, to: today)!
        let event = Self.makeEvent(date: twoWeeksAgo)

        let result = Self.countMissingDays(events: [event], referenceDate: Date())
        #expect(result.missingCount == 8)
    }

    // MARK: - UTC vs Local Calendar Comparison

    @Test("UTC calendar correctly matches event stored as UTC midnight")
    func utcMatchesUTCMidnight() {
        // Create a specific date: April 25 at UTC midnight
        let apr25 = Self.makeUTCDate(year: 2026, month: 4, day: 25)
        let event = Self.makeEvent(date: apr25)

        // Reference time: April 25 at 3pm UTC (same day)
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 25
        components.hour = 15
        let referenceTime = Self.utcCalendar.date(from: components)!

        let result = Self.countMissingDays(events: [event], referenceDate: referenceTime)
        #expect(result.hasStayToday == true)
    }

    @Test("UTC and local may disagree on hasStayToday for negative-UTC timezones")
    func utcVsLocalDisagreement() {
        // This documents the bug that was fixed.
        // April 25 UTC midnight = April 24 in US timezones.
        // If user checks at April 25 2pm local (which is April 25 evening UTC),
        // local calendar sees event as April 24 and says no stay today.
        let apr25utc = Self.makeUTCDate(year: 2026, month: 4, day: 25)
        let event = Self.makeEvent(date: apr25utc)

        // Reference: April 25 at 8pm UTC (afternoon in US timezones)
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 25
        components.hour = 20
        let referenceTime = Self.utcCalendar.date(from: components)!

        let utcResult = Self.countMissingDays(events: [event], referenceDate: referenceTime)
        // UTC always finds the stay on the correct day
        #expect(utcResult.hasStayToday == true)

        // Local result depends on the device timezone - we just verify UTC is stable
        let localResult = Self.countMissingDaysLocal(events: [event], referenceDate: referenceTime)
        // In UTC+ timezones, local also finds it. In UTC- timezones (US), local misses it.
        // The key assertion is that UTC always works correctly regardless.
        _ = localResult // Consumed to avoid unused warning
    }

    // MARK: - Edge: Year and Month Boundaries

    @Test("Missing days counted correctly across month boundary")
    func monthBoundary() {
        // Reference: March 3
        let mar3 = Self.makeUTCDate(year: 2026, month: 3, day: 3)

        // Events on Feb 27 and Mar 3 (6 days apart, with gap Feb 28 - Mar 2)
        let feb27 = Self.makeUTCDate(year: 2026, month: 2, day: 27)
        let events = [
            Self.makeEvent(date: feb27),
            Self.makeEvent(date: mar3)
        ]

        // 7 days before Mar 3 = Feb 24. Range: Feb 24-Mar 3 = 8 days.
        // Events on Feb 27 and Mar 3 = 2 days covered, 6 missing.
        let result = Self.countMissingDays(events: events, referenceDate: mar3)
        #expect(result.missingCount == 6)
        #expect(result.hasStayToday == true)
    }

    @Test("Missing days counted correctly across year boundary")
    func yearBoundary() {
        // Reference: Jan 2, 2026
        let jan2 = Self.makeUTCDate(year: 2026, month: 1, day: 2)

        // Event on Dec 28 and Jan 2
        let dec28 = Self.makeUTCDate(year: 2025, month: 12, day: 28)
        let events = [
            Self.makeEvent(date: dec28),
            Self.makeEvent(date: jan2)
        ]

        // 7 days before Jan 2 = Dec 26. Range: Dec 26 - Jan 2 = 8 days.
        // Events on Dec 28 and Jan 2 = 2 days, 6 missing.
        let result = Self.countMissingDays(events: events, referenceDate: jan2)
        #expect(result.missingCount == 6)
        #expect(result.hasStayToday == true)
    }
}
