//
// Created for UICalendarView_SwiftUI
// by Stewart Lynch on 2022-06-30
// Using Swift 5.0
//
// Follow me on Twitter: @StewartLynch
// Subscribe on YouTube: https://youTube.com/StewartLynch
//

import SwiftUI

struct DaysEventsListView: View {
    @EnvironmentObject var store: DataStore
    @Binding var dateSelected: DateComponents?
    @State private var formType: EventFormType?
    
    var body: some View {
        NavigationStack {
            Group {
                if let dateSelected {
                    let foundEvents = store.events
                        .filter { $0.date.startOfDay == dateSelected.date!.startOfDay }
                    List {
                        ForEach(foundEvents) { event in
                            ListViewRow(event: event, formType: $formType)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        store.delete(event)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                        }
                    }
                } else {
                    Text("No date selected")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(dateSelected?.date?.utcLongDateString ?? "")
        }
        // Present the event form from a single, stable place
        .sheet(item: $formType) { form in
            form
        }
    }
}

struct DaysEventsListView_Previews: PreviewProvider {
    static var dateComponents: DateComponents {
        var dateComponents = Calendar.current.dateComponents(
            [.month, .day, .year, .hour, .minute],
            from: Date()
        )
        dateComponents.timeZone = TimeZone.gmt
        dateComponents.calendar = Calendar(identifier: .gregorian)
        return dateComponents
    }
    static var previews: some View {
        DaysEventsListView(dateSelected: .constant(dateComponents))
            .environmentObject(DataStore(preview: true))
    }
}

