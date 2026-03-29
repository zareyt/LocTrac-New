//
// Created for UICalendarView_SwiftUI
// by Stewart Lynch on 2022-06-28
// Using Swift 5.0
//
// Follow me on Twitter: @StewartLynch
// Subscribe on YouTube: https://youTube.com/StewartLynch
//

import SwiftUI

struct EventsCalendarView: View {
    @EnvironmentObject var store: DataStore
    @State private var dateSelected: DateComponents?
    @State private var displayEvents = false
    @State private var newEvent = false
    @State private var formType: EventFormType?
    

    var body: some View {
        NavigationStack {
            ScrollView {
                CalendarView(interval: DateInterval(start: .distantPast, end: .distantFuture),
                             store: store,
                             dateSelected: $dateSelected,
                             displayEvents: $displayEvents)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Ensure only one presentation is active
                        displayEvents = false
                        // Safely build a DateComponents. If no date selected yet, use today's date in GMT.
                        if let ds = dateSelected {
                            formType = .new(ds)
                        } else {
                            var cal = Calendar(identifier: .gregorian)
                            cal.timeZone = TimeZone(secondsFromGMT: 0)!
                            let comps = cal.dateComponents([.year, .month, .day], from: Date())
                            formType = .new(comps)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.medium)
                    }
                }
            }
            // Push the Event form instead of presenting as a sheet
            .navigationDestination(item: $formType) { formType in
                formType.body
            }
            // Keep the day's events list as a sheet; do not overlap with the form
            .sheet(isPresented: $displayEvents) {
                DaysEventsListView(dateSelected: $dateSelected)
                    .presentationDetents([.medium, .large])
            }
            .navigationTitle("Calendar View")
            .onChange(of: dateSelected) { oldValue, newValue in
            guard let date = newValue?.date else { return }

            let eventsForDate = store.events.filter { $0.date.startOfDay == date.startOfDay }

            if !eventsForDate.isEmpty {

                formType = nil

                displayEvents = true

            } else {

                displayEvents = false

                if let ds = newValue {

                    formType = .new(ds)

                }

            }

            }
        }
    }
}


struct EventsCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        EventsCalendarView()
            .environmentObject(DataStore(preview: true))
    }
}
