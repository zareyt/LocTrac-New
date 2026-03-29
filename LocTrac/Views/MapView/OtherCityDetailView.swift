//
//  OtherCityDetailView.swift
//  LocTrac
//
//  View for displaying all events at a specific "Other" city
//

import SwiftUI
import MapKit

struct OtherCityDetailView: View {
    @EnvironmentObject var store: DataStore
    
    let events: [Event] // All events at this city, sorted by date
    
    private var cityName: String {
        events.first?.city ?? "Unknown City"
    }
    
    private var country: String? {
        events.first?.country
    }
    
    private var coordinate: CLLocationCoordinate2D {
        let first = events.first!
        return CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with city info
                headerSection
                
                Divider()
                
                // Map showing location
                mapSection
                
                Divider()
                
                // List of all stays at this city
                staysSection
            }
            .padding()
        }
        .navigationTitle(cityName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension OtherCityDetailView {
    private var headerSection: some View {
        VStack(spacing: 12) {
            // City name
            Text(cityName)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Country
            if let country = country, !country.isEmpty {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.blue)
                    Text(country)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // Total stays count
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("\(events.count) \(events.count == 1 ? "stay" : "stays")")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical)
    }
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.title3)
                .fontWeight(.semibold)
            
            Map(initialPosition: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
            )) {
                Annotation(cityName, coordinate: coordinate) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        )
                        .shadow(radius: 4)
                }
            }
            .frame(height: 250)
            .cornerRadius(12)
            
            // Coordinates
            VStack(alignment: .leading, spacing: 2) {
                Text("Latitude: \(coordinate.latitude, specifier: "%.6f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Longitude: \(coordinate.longitude, specifier: "%.6f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
    
    private var staysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Stays")
                .font(.title3)
                .fontWeight(.semibold)
            
            ForEach(events) { event in
                stayCard(event)
            }
        }
    }
    
    private func stayCard(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text(event.date.formatted(date: .long, time: .omitted))
                    .font(.headline)
            }
            
            // Event Type
            if let eventType = Event.EventType(rawValue: event.eventType) {
                HStack {
                    Text(eventType.icon)
                        .font(.title3)
                    Text(eventType.rawValue.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Activities
            if !event.activityIDs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Activities:")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    ForEach(activityNames(for: event), id: \.self) { activity in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption2)
                            Text(activity)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 16)
                    }
                }
            }
            
            // People
            if !event.people.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("People:")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    ForEach(event.people) { person in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption2)
                            Text(person.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 16)
                    }
                }
            }
            
            // Note
            if !event.note.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Note:")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Text(event.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private func activityNames(for event: Event) -> [String] {
        let map = Dictionary(uniqueKeysWithValues: store.activities.map { ($0.id, $0.name) })
        return event.activityIDs.compactMap { map[$0] }
    }
}

// MARK: - Preview

struct OtherCityDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            OtherCityDetailView(events: [Event.sampleData[0]])
                .environmentObject(DataStore())
        }
    }
}
