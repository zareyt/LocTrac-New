//
// Created for UICalendarView_SwiftUI
// by Stewart Lynch on 2022-06-28
// Using Swift 5.0
//
// Follow me on Twitter: @StewartLynch
// Subscribe on YouTube: https://youTube.com/StewartLynch
//

import Foundation

extension Date {
    func diff(numDays: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: numDays, to: self)!
    }
    
    var startOfDay: Date {
        var calendar = Calendar.current
        //Set Timezone to GMT for all entries, regardless of where the entry is added from
        calendar.timeZone = TimeZone(secondsFromGMT: 0)! // GMT/UTC
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        let startOfDate = calendar.date(from: components)!
        return startOfDate
    }

}

extension Date {
    var startOfMonth: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)! // GMT/UTC
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)!
    }
}

extension Date {
    /// UTC-safe date string for display. Prevents +/-1 day drift caused by
    /// local-timezone formatting of dates stored as UTC midnight.
    /// Use this instead of `.formatted(date:time:)` for any event date display.
    private static let _utcMediumFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.timeZone = TimeZone(secondsFromGMT: 0)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        df.calendar = cal
        return df
    }()

    private static let _utcLongFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .none
        df.timeZone = TimeZone(secondsFromGMT: 0)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        df.calendar = cal
        return df
    }()

    /// Medium date format in UTC (e.g., "Dec 25, 2025")
    var utcMediumDateString: String {
        Self._utcMediumFormatter.string(from: self)
    }

    /// Long date format in UTC (e.g., "December 25, 2025")
    var utcLongDateString: String {
        Self._utcLongFormatter.string(from: self)
    }
}
