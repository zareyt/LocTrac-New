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
