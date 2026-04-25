import Testing
import Foundation
@testable import LocTrac

@Suite("Date Edge Case Tests")
struct DateEdgeCaseTests {

    // MARK: - Helpers

    private static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    /// Creates a UTC date with specific hour/minute/second components
    private static func makeUTCDate(
        year: Int, month: Int, day: Int,
        hour: Int = 0, minute: Int = 0, second: Int = 0
    ) -> Date {
        let comps = DateComponents(
            year: year, month: month, day: day,
            hour: hour, minute: minute, second: second
        )
        return utcCalendar.date(from: comps)!
    }

    // MARK: - UTC Midnight: startOfDay always zeroes time components

    @Test("startOfDay produces hour=0, minute=0, second=0 in UTC")
    func startOfDayZeroesTimeComponents() {
        let afternoon = Self.makeUTCDate(year: 2026, month: 3, day: 15, hour: 14, minute: 45, second: 33)
        let start = afternoon.startOfDay

        let comps = Self.utcCalendar.dateComponents([.hour, .minute, .second], from: start)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 0)
    }

    @Test("startOfDay of 23:59:59 UTC stays on the same day")
    func startOfDayNearMidnightEnd() {
        let lateNight = Self.makeUTCDate(year: 2026, month: 7, day: 4, hour: 23, minute: 59, second: 59)
        let start = lateNight.startOfDay

        let day = Self.utcCalendar.component(.day, from: start)
        let month = Self.utcCalendar.component(.month, from: start)
        #expect(day == 4)
        #expect(month == 7)
    }

    @Test("startOfDay of 00:00:01 UTC gives the same day")
    func startOfDayJustAfterMidnight() {
        let justAfter = Self.makeUTCDate(year: 2026, month: 7, day: 4, hour: 0, minute: 0, second: 1)
        let start = justAfter.startOfDay

        let day = Self.utcCalendar.component(.day, from: start)
        #expect(day == 4)
        // startOfDay should equal exact midnight
        let exactMidnight = Self.makeUTCDate(year: 2026, month: 7, day: 4)
        #expect(start == exactMidnight)
    }

    // MARK: - Date Comparison via startOfDay

    @Test("Two dates on the same UTC day have equal startOfDay")
    func sameDayEqualStartOfDay() {
        let morning = Self.makeUTCDate(year: 2026, month: 5, day: 20, hour: 8, minute: 30)
        let evening = Self.makeUTCDate(year: 2026, month: 5, day: 20, hour: 21, minute: 15)

        #expect(morning.startOfDay == evening.startOfDay)
    }

    @Test("Two dates on different UTC days have different startOfDay")
    func differentDayDifferentStartOfDay() {
        let endOfDay = Self.makeUTCDate(year: 2026, month: 5, day: 20, hour: 23, minute: 59, second: 59)
        let startOfNext = Self.makeUTCDate(year: 2026, month: 5, day: 21, hour: 0, minute: 0, second: 0)

        #expect(endOfDay.startOfDay != startOfNext.startOfDay)
    }

    @Test("Date created via non-UTC timezone normalizes correctly with startOfDay")
    func nonUTCTimezoneNormalizesToUTC() {
        // Create a date using a PST calendar (UTC-8):
        // Jan 15 at 20:00 PST = Jan 16 at 04:00 UTC
        var pstCalendar = Calendar(identifier: .gregorian)
        pstCalendar.timeZone = TimeZone(secondsFromGMT: -8 * 3600)!
        let pstDate = pstCalendar.date(from: DateComponents(
            year: 2026, month: 1, day: 15, hour: 20, minute: 0
        ))!

        // In UTC this is Jan 16, so startOfDay (UTC) should be Jan 16 midnight
        let start = pstDate.startOfDay
        let utcDay = Self.utcCalendar.component(.day, from: start)
        let utcMonth = Self.utcCalendar.component(.month, from: start)
        #expect(utcDay == 16)
        #expect(utcMonth == 1)
    }

    // MARK: - One Stay Per Day

    @Test("Events on the same startOfDay are considered same-day")
    func eventsOnSameDayAreSameDay() {
        let event1 = TestDataFactory.makeEvent(
            date: Self.makeUTCDate(year: 2026, month: 6, day: 10, hour: 9)
        )
        let event2 = TestDataFactory.makeEvent(
            date: Self.makeUTCDate(year: 2026, month: 6, day: 10, hour: 18)
        )

        #expect(event1.date.startOfDay == event2.date.startOfDay)
    }

    @Test("Events one second apart crossing UTC midnight are different days")
    func eventsCrossingMidnightAreDifferentDays() {
        let beforeMidnight = TestDataFactory.makeEvent(
            date: Self.makeUTCDate(year: 2026, month: 6, day: 10, hour: 23, minute: 59, second: 59)
        )
        let afterMidnight = TestDataFactory.makeEvent(
            date: Self.makeUTCDate(year: 2026, month: 6, day: 11, hour: 0, minute: 0, second: 0)
        )

        #expect(beforeMidnight.date.startOfDay != afterMidnight.date.startOfDay)
    }

    // MARK: - Date Formatting Consistency

    @Test("utcMediumDateString and utcLongDateString produce consistent day for UTC midnight")
    func formattingConsistencyAtMidnight() {
        let date = Self.makeUTCDate(year: 2026, month: 8, day: 15)

        let medium = date.utcMediumDateString
        let long = date.utcLongDateString

        // Both should reference day 15 and August
        #expect(medium.contains("15"))
        #expect(long.contains("15"))
        #expect(long.contains("August"))
        #expect(medium.contains("Aug") || medium.contains("August"))
    }

    @Test("UTC formatting does not shift day compared to UTC calendar components")
    func formattingMatchesUTCCalendarComponents() {
        // Use a date that would drift in local timezone (UTC midnight)
        let date = Self.makeUTCDate(year: 2026, month: 12, day: 1)

        let utcDay = Self.utcCalendar.component(.day, from: date)
        let utcMonth = Self.utcCalendar.component(.month, from: date)
        let utcYear = Self.utcCalendar.component(.year, from: date)

        let formatted = date.utcMediumDateString

        #expect(utcDay == 1)
        #expect(utcMonth == 12)
        #expect(utcYear == 2026)
        // The formatted string must agree with UTC components
        #expect(formatted.contains("1"))
        #expect(formatted.contains("Dec") || formatted.contains("December"))
        #expect(formatted.contains("2026"))
    }

    // MARK: - Calendar Operations

    @Test("UTC calendar date components match expected year, month, day across year boundary")
    func utcCalendarComponentsAtYearBoundary() {
        // Dec 31 23:59:59 UTC — still 2025
        let endOf2025 = Self.makeUTCDate(year: 2025, month: 12, day: 31, hour: 23, minute: 59, second: 59)
        let comps2025 = Self.utcCalendar.dateComponents([.year, .month, .day], from: endOf2025)
        #expect(comps2025.year == 2025)
        #expect(comps2025.month == 12)
        #expect(comps2025.day == 31)

        // Jan 1 00:00:00 UTC — already 2026
        let startOf2026 = Self.makeUTCDate(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        let comps2026 = Self.utcCalendar.dateComponents([.year, .month, .day], from: startOf2026)
        #expect(comps2026.year == 2026)
        #expect(comps2026.month == 1)
        #expect(comps2026.day == 1)
    }
}
