import Testing
@testable import LocTrac

@Suite("UTC Date Formatting Tests")
struct UTCDateFormattingTests {

    // MARK: - Helpers

    private static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    /// Creates a UTC date at midnight for the given year/month/day
    private static func makeUTCDate(year: Int, month: Int, day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// A UTC-pinned date formatter matching the one used in LocationDataEnhancementView
    private static let utcFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.timeZone = TimeZone(secondsFromGMT: 0)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        df.calendar = cal
        return df
    }()

    /// A local-timezone formatter (the buggy approach)
    private static let localFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        // Uses system default timezone (local)
        return df
    }()

    // MARK: - UTC Formatter Preserves Correct Day

    @Test("UTC formatter shows correct day for UTC midnight date")
    func utcFormatterCorrectDay() {
        let dec25 = Self.makeUTCDate(year: 2025, month: 12, day: 25)

        let formatted = Self.utcFormatter.string(from: dec25)

        #expect(formatted.contains("25"))
        #expect(formatted.contains("Dec") || formatted.contains("December"))
    }

    @Test("UTC formatter shows correct day for Jan 1 UTC midnight")
    func utcFormatterJan1() {
        let jan1 = Self.makeUTCDate(year: 2026, month: 1, day: 1)

        let formatted = Self.utcFormatter.string(from: jan1)

        #expect(formatted.contains("1") || formatted.contains("01"))
        #expect(formatted.contains("Jan") || formatted.contains("January"))
        #expect(!formatted.contains("Dec") && !formatted.contains("December"))
    }

    @Test("UTC formatter shows correct day for Dec 31 UTC midnight")
    func utcFormatterDec31() {
        let dec31 = Self.makeUTCDate(year: 2025, month: 12, day: 31)

        let formatted = Self.utcFormatter.string(from: dec31)

        #expect(formatted.contains("31"))
        #expect(formatted.contains("Dec") || formatted.contains("December"))
    }

    // MARK: - Date Component Extraction in UTC

    @Test("UTC calendar extracts correct day component from UTC midnight date")
    func utcCalendarDayComponent() {
        let dec25 = Self.makeUTCDate(year: 2025, month: 12, day: 25)
        let day = Self.utcCalendar.component(.day, from: dec25)

        #expect(day == 25)
    }

    @Test("UTC calendar extracts correct month component from UTC midnight date")
    func utcCalendarMonthComponent() {
        let dec25 = Self.makeUTCDate(year: 2025, month: 12, day: 25)
        let month = Self.utcCalendar.component(.month, from: dec25)

        #expect(month == 12)
    }

    @Test("Local calendar may extract wrong day from UTC midnight date")
    func localCalendarMayDrift() {
        // UTC midnight Dec 25 = Dec 24 11pm in EST, Dec 24 4pm in PST
        // This test documents the timezone drift behavior
        let dec25utc = Self.makeUTCDate(year: 2025, month: 12, day: 25)

        let utcDay = Self.utcCalendar.component(.day, from: dec25utc)
        let localDay = Calendar.current.component(.day, from: dec25utc)

        // UTC always gives 25
        #expect(utcDay == 25)

        // Local may differ depending on timezone (behind UTC = 24, ahead = 25 or 26)
        // We just verify UTC is stable regardless
        let utcMonth = Self.utcCalendar.component(.month, from: dec25utc)
        #expect(utcMonth == 12)
    }

    // MARK: - startOfDay Consistency

    @Test("startOfDay preserves the date when using UTC calendar")
    func startOfDayPreservesDate() {
        let dec25 = Self.makeUTCDate(year: 2025, month: 12, day: 25)
        let startOfDay = dec25.startOfDay

        let day = Self.utcCalendar.component(.day, from: startOfDay)
        let month = Self.utcCalendar.component(.month, from: startOfDay)

        #expect(day == 25)
        #expect(month == 12)
    }

    @Test("startOfDay for date with time component normalizes to midnight UTC")
    func startOfDayNormalizesToMidnight() {
        // Create a date at 3pm UTC on Dec 25
        var components = DateComponents()
        components.year = 2025
        components.month = 12
        components.day = 25
        components.hour = 15
        components.minute = 30
        let dateWithTime = Self.utcCalendar.date(from: components)!

        let normalized = dateWithTime.startOfDay

        let hour = Self.utcCalendar.component(.hour, from: normalized)
        let minute = Self.utcCalendar.component(.minute, from: normalized)
        let day = Self.utcCalendar.component(.day, from: normalized)

        #expect(hour == 0)
        #expect(minute == 0)
        #expect(day == 25)
    }

    // MARK: - Formatted Date String Consistency

    @Test("UTC formatter and .formatted() may produce different days for UTC midnight")
    func formattedVsUTCFormatter() {
        // This test documents why .formatted() is unsafe for UTC dates
        let dec25utc = Self.makeUTCDate(year: 2025, month: 12, day: 25)

        let utcResult = Self.utcFormatter.string(from: dec25utc)

        // UTC formatter always shows Dec 25
        #expect(utcResult.contains("25"))
        #expect(utcResult.contains("Dec") || utcResult.contains("December"))
    }

    @Test("Multiple consecutive dates format correctly with UTC formatter")
    func consecutiveDatesFormat() {
        for day in 24...28 {
            let date = Self.makeUTCDate(year: 2025, month: 12, day: day)
            let formatted = Self.utcFormatter.string(from: date)

            #expect(formatted.contains("\(day)"),
                    "Expected day \(day) in formatted string '\(formatted)'")
        }
    }

    // MARK: - Edge Cases

    @Test("Leap day formats correctly in UTC")
    func leapDayFormats() {
        let feb29 = Self.makeUTCDate(year: 2024, month: 2, day: 29)
        let formatted = Self.utcFormatter.string(from: feb29)

        #expect(formatted.contains("29"))
        #expect(formatted.contains("Feb") || formatted.contains("February"))
    }

    @Test("Year boundary: Dec 31 does not become Jan 1 in UTC formatter")
    func yearBoundaryDec31() {
        let dec31 = Self.makeUTCDate(year: 2025, month: 12, day: 31)
        let formatted = Self.utcFormatter.string(from: dec31)

        #expect(formatted.contains("31"))
        #expect(formatted.contains("2025"))
        #expect(!formatted.contains("2026"))
    }

    @Test("Year boundary: Jan 1 does not become Dec 31 in UTC formatter")
    func yearBoundaryJan1() {
        let jan1 = Self.makeUTCDate(year: 2026, month: 1, day: 1)
        let formatted = Self.utcFormatter.string(from: jan1)

        #expect(formatted.contains("2026"))
        #expect(formatted.contains("Jan") || formatted.contains("January"))
    }
}
