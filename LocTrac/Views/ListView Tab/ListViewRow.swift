//
// Created for UICalendarView_SwiftUI
// by Stewart Lynch on 2022-06-29
// Using Swift 5.0
//
// Follow me on Twitter: @StewartLynch
// Subscribe on YouTube: https://youTube.com/StewartLynch
//

import SwiftUI

struct ListViewRow: View {
    let event: Event
    @EnvironmentObject var store: DataStore
    @Binding var formType: EventFormType?
    
    // Resolve activity names from event.activityIDs
    private var activityNames: [String] {
        let map = Dictionary(uniqueKeysWithValues: store.activities.map { ($0.id, $0.name) })
        return event.activityIDs.compactMap { map[$0] }
    }
    
    // Resolve people display names
    private var peopleNames: [String] {
        event.people.map { $0.displayName }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    // City to display only when location is "Other"
    private var otherCityText: String? {
        guard event.location.name == "Other" else { return nil }
        let city = (event.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return city.isEmpty ? nil : city
    }
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                // Location name with color dot
                HStack {
                    Circle()
                        .fill(store.locations[event.getLocationIndex(locations: store.locations, location: event.location) ?? 0].theme.mainColor)
                        .frame(width: 20, height: 20)
                    Text(store.locations[event.getLocationIndex(locations: store.locations, location: event.location) ?? 0].name)
                }
                
                // Event type
                HStack {
                    Text(event.eventType.capitalized)
                }
                
                // If location is "Other", show the event's city (if present)
                if let city = otherCityText {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle")
                            .foregroundColor(.accentColor)
                        Text(city)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Note, if any
                if !event.note.isEmpty {
                    HStack {
                        Text(event.note)
                    }
                }
                
                // Activities line, if any
                if !activityNames.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk.circle")
                            .foregroundColor(.accentColor)
                        Text(activityNames.joined(separator: ", "))
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // People line, if any
                if !peopleNames.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.accentColor)
                        Text(peopleNames.joined(separator: ", "))
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                formType = .update(event)
            } label: {
                Text("Edit")
            }
            .buttonStyle(.bordered)
        }
    }
}

