import Foundation

/// Determines the smart action for the Home screen "Add Stay" button.
/// Evaluates event coverage and returns the most appropriate action.
enum SmartStayAction: Equatable {
    /// No event for today - add a stay for today
    case addToday

    /// There are missing days (gaps) between oldest event and today.
    /// `from` is the start of the gap, `to` is the end of the gap.
    case fillGap(from: Date, to: Date, missingCount: Int)

    /// Today has an event and no gaps exist - edit today's event
    case editToday(Event)

    // MARK: - Equatable

    static func == (lhs: SmartStayAction, rhs: SmartStayAction) -> Bool {
        switch (lhs, rhs) {
        case (.addToday, .addToday):
            return true
        case (.fillGap(let lf, let lt, let lc), .fillGap(let rf, let rt, let rc)):
            return lf == rf && lt == rt && lc == rc
        case (.editToday(let le), .editToday(let re)):
            return le.id == re.id
        default:
            return false
        }
    }

    // MARK: - Display Helpers

    /// The label text for the button
    var buttonLabel: String {
        switch self {
        case .addToday:
            return "Add Stay \u{2014} Today"
        case .fillGap(let from, let to, let missingCount):
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if from == to {
                return "Add Stay \u{2014} \(formatter.string(from: from))"
            } else {
                return "Add Stay \u{2014} \(formatter.string(from: from))\u{2013}\(formatter.string(from: to)) (\(missingCount) days)"
            }
        case .editToday:
            return "Edit Today\u{2019}s Stay"
        }
    }

    /// The SF Symbol for the button
    var buttonIcon: String {
        switch self {
        case .addToday, .fillGap:
            return "calendar.badge.plus"
        case .editToday:
            return "pencil.circle"
        }
    }

    // MARK: - Logic

    /// Determines the smart stay action based on the current events.
    /// - Parameters:
    ///   - events: All events in the data store
    ///   - today: The current date (injectable for testing)
    /// - Returns: The appropriate SmartStayAction
    static func determine(events: [Event], today: Date = Date()) -> SmartStayAction {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let todayStart = utcCalendar.startOfDay(for: today)

        // Build set of all event dates (normalized to start of day)
        let eventDates = Set(events.map { utcCalendar.startOfDay(for: $0.date) })

        // Priority 1: No event for today -> add stay for today
        if !eventDates.contains(todayStart) {
            return .addToday
        }

        // Priority 2: Today has an event - check for gaps working backwards from yesterday
        guard let oldestDate = events.map({ utcCalendar.startOfDay(for: $0.date) }).min() else {
            return .addToday
        }

        // Find the most recent gap (contiguous block of missing days), searching backwards from yesterday
        let yesterday = utcCalendar.date(byAdding: .day, value: -1, to: todayStart)!

        if yesterday >= oldestDate {
            // Walk backwards from yesterday to find the first missing day
            var gapEnd: Date? = nil
            var gapStart: Date? = nil
            var checkDate = yesterday

            while checkDate >= oldestDate {
                if !eventDates.contains(checkDate) {
                    if gapEnd == nil {
                        gapEnd = checkDate
                    }
                    gapStart = checkDate
                } else if gapEnd != nil {
                    // We hit an existing event, so the gap ends here
                    break
                }
                guard let prev = utcCalendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            }

            if let start = gapStart, let end = gapEnd {
                let days = (utcCalendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
                return .fillGap(from: start, to: end, missingCount: days)
            }
        }

        // Priority 3: Today has event and no gaps - edit today's event
        if let todayEvent = events.first(where: { utcCalendar.startOfDay(for: $0.date) == todayStart }) {
            return .editToday(todayEvent)
        }

        return .addToday
    }
}
