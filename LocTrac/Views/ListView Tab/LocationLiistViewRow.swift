//  LocationLiistViewRow.swift
//  Locations
//
//  Created by Tim Arey on 2/2/23.
//

import SwiftUI

struct LocationLiistViewRow: View {
    let location: Location
    @EnvironmentObject var store: DataStore
    @Binding var lformType: LocationFormType?
    
    // Use a UTC calendar for all date component grouping since event.date is stored at UTC midnight
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Circle()
                    .fill(location.theme.mainColor)
                    .frame(width: 20, height: 20)
                
                if let city = location.city {
                    HStack {
                        Text(city)
                    }
                }
                
                // Total across all years
                HStack {
                    Text("Total # of Stays: \(store.eventCount(location, events: store.events))")
                }
                
                // Per-year breakdown (years computed in UTC)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(yearsSortedDescending, id: \.self) { year in
                        let (count, percent) = perYearStats(for: year)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(String(year)): \(count) (\(percentString(percent)))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // Types for this location in this year
                            let typeBreakdown = perYearTypeBreakdown(for: year)
                            ForEach(typeBreakdown, id: \.type.id) { entry in
                                HStack(spacing: 6) {
                                    Image(systemName: entry.type.sfSymbol)
                                        .font(.footnote)
                                        .foregroundStyle(entry.type.color)
                                    Text("\(entry.type.displayName): \(entry.count) (\(percentString(entry.percent)))")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.leading, 8)
                    }
                }
                
                // Extra action for "Other" locations
                if location.name == "Other" {
                    NavigationLink {
                        OtherCitiesListView(location: location)
                            .environmentObject(store)
                    } label: {
                        Label("View Cities & Dates", systemImage: "list.bullet")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 6)
                }
            }
            Spacer()
            Button {
                lformType = .update(location)
            } label: {
                Text("Edit")
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Computations (all in UTC)
    
    private var yearsSortedDescending: [Int] {
        let years = store.events.map { utcCalendar.component(.year, from: $0.date) }
        return Array(Set(years)).sorted(by: >)
    }
    
    private func perYearStats(for year: Int) -> (count: Int, percent: Float) {
        let eventsInYear = store.events.filter { utcCalendar.component(.year, from: $0.date) == year }
        let totalInYear = eventsInYear.count
        let locationEventsInYear = eventsInYear.filter { $0.location.id == location.id }
        let count = locationEventsInYear.count
        guard totalInYear > 0 else { return (0, 0) }
        let percent = Float(count) / Float(totalInYear)
        return (count, percent)
    }
    
    private func perYearTypeBreakdown(for year: Int) -> [(type: EventTypeItem, count: Int, percent: Float)] {
        let locationEventsInYear = store.events.filter {
            utcCalendar.component(.year, from: $0.date) == year && $0.location.id == location.id
        }
        let totalForLocationInYear = locationEventsInYear.count
        guard totalForLocationInYear > 0 else { return [] }
        var result: [(type: EventTypeItem, count: Int, percent: Float)] = []
        let grouped = Dictionary(grouping: locationEventsInYear) { $0.eventType }
        for (rawValue, events) in grouped {
            let item = store.eventTypeItem(for: rawValue)
            let percent = Float(events.count) / Float(totalForLocationInYear)
            result.append((item, events.count, percent))
        }
        result.sort { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.type.name < rhs.type.name
            }
            return lhs.count > rhs.count
        }
        return result
    }
    
    private func percentString(_ value: Float) -> String {
        String(format: "%.0f%%", value * 100)
    }
}

struct LocationLiistViewRow_Previews: PreviewProvider {
    static let location = Location(name: "Arrowhead", city: "Edwards", latitude: 0, longitude: 0, theme: .purple)
    static var previews: some View {
        LocationLiistViewRow(location: location, lformType: .constant(.new))
            .environmentObject(DataStore())
    }
}
