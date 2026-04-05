//
// Created for UICalendarView_SwiftUI
// by Stewart Lynch on 2022-07-01
// Using Swift 5.0
//
// Follow me on Twitter: @StewartLynch
// Subscribe on YouTube: https://youTube.com/StewartLynch
//

import SwiftUI

struct CalendarView: UIViewRepresentable {
    let interval: DateInterval
    @ObservedObject var store: DataStore
    @Binding var dateSelected: DateComponents?
    @Binding var displayEvents: Bool
    
    func makeUIView(context: Context) -> some UICalendarView {
        let view = UICalendarView()
        view.delegate = context.coordinator
        view.calendar = Calendar(identifier: .gregorian)
        view.availableDateRange = interval
        let dateSelection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        view.selectionBehavior = dateSelection
        context.coordinator.calendarView = view
        return view
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, store: _store)
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        // Targeted refreshes for single-day changes
        if let changedEvent = store.changedEvent {
            uiView.reloadDecorations(forDateComponents: [changedEvent.dateComponents], animated: true)
        }
        if let movedEvent = store.movedEvent {
            uiView.reloadDecorations(forDateComponents: [movedEvent.dateComponents], animated: true)
        }
        
        // Full refresh for the visible area (3-month window) only when the token actually changes
        let currentToken = store.calendarRefreshToken
        if context.coordinator.lastSeenRefreshToken != currentToken {
            context.coordinator.lastSeenRefreshToken = currentToken
            context.coordinator.reloadThreeMonthWindow()
        }
    }
    
    class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: CalendarView
        @ObservedObject var store: DataStore
        weak var calendarView: UICalendarView?
        var lastSeenRefreshToken: UUID?
        
        init(parent: CalendarView, store: ObservedObject<DataStore>) {
            self.parent = parent
            self._store = store
            self.lastSeenRefreshToken = nil
        }
        
        @MainActor
        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            
            guard let date = calendar.date(from: dateComponents) else {
                return nil
            }
            
            let GMT = TimeZone(secondsFromGMT: 0)!
            var GMTDateComponents = calendar.dateComponents(in: GMT, from: date)
            GMTDateComponents.hour = 0
            GMTDateComponents.minute = 0
            GMTDateComponents.second = 0
            
            guard let GMTDate = calendar.date(from: GMTDateComponents) else {
                return nil
            }
            
            let foundEvents = store.events.filter {
                let eventGMTDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: $0.date, matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)!
                return calendar.isDate(eventGMTDate, inSameDayAs: GMTDate)
            }
            
            if foundEvents.isEmpty { return nil }
            
            if foundEvents.count > 1 {
                return .image(UIImage(systemName: "circle.lefthalf.filled"),
                              color: .red,
                              size: .large)
            }
            let singleEvent = foundEvents.first!
            let eventColor: UIColor = self.store.locations[singleEvent.getLocationIndex(locations: self.store.locations, location: singleEvent.location) ?? 0].theme.uiColor
            return UICalendarView.Decoration.default(color: eventColor, size: .large)
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate,
                           didSelectDate dateComponents: DateComponents?) {
            parent.dateSelected = dateComponents
            guard let dateComponents else { return }
            let foundEvents = store.events
                .filter { $0.date.startOfDay == dateComponents.date?.startOfDay }
            if !foundEvents.isEmpty {
                parent.displayEvents.toggle()
            }
        }
        
        func dateSelection(_ selection: UICalendarSelectionSingleDate,
                           canSelectDate dateComponents: DateComponents?) -> Bool {
            true
        }
        
        // Reload a 3-month window (previous, current, next) to cover typical visible area
        @MainActor
        func reloadThreeMonthWindow() {
            guard let view = calendarView else { return }
            let cal = view.calendar
            
            // Use selected date if any; otherwise, use today's date in the calendar's time base
            let anchor = parent.dateSelected?.date ?? Date()
            guard let currentMonth = cal.dateInterval(of: .month, for: anchor),
                  let prevMonthStart = cal.date(byAdding: .month, value: -1, to: currentMonth.start),
                  let prevMonth = cal.dateInterval(of: .month, for: prevMonthStart),
                  let nextMonthStart = cal.date(byAdding: .month, value: 1, to: currentMonth.start),
                  let nextMonth = cal.dateInterval(of: .month, for: nextMonthStart) else { return }
            
            let totalStart = prevMonth.start
            let totalEnd = nextMonth.end
            
            var comps: [DateComponents] = []
            var cursor = totalStart
            while cursor <= totalEnd {
                comps.append(cal.dateComponents([.year, .month, .day], from: cursor))
                guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            view.reloadDecorations(forDateComponents: comps, animated: true)
        }
    }
}

