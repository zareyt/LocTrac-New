//
//  OtherEventDetailView.swift
//  LocTrac
//
//  View for displaying details of a specific "Other" location event
//

import SwiftUI
import MapKit

struct OtherEventDetailView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    let event: Event
    
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with city and date
                headerSection
                
                Divider()
                
                // Event details
                detailsSection
                
                Divider()
                
                // Map
                mapSection
                
                Divider()
                
                // Activities and People
                if !event.activityIDs.isEmpty || !event.people.isEmpty {
                    additionalInfoSection
                    Divider()
                }
                
                // Note
                if !event.note.isEmpty {
                    noteSection
                }
            }
            .padding()
        }
        .navigationTitle(event.city ?? "Other Location")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension OtherEventDetailView {
    private var headerSection: some View {
        VStack(spacing: 12) {
            // City name
            Text(event.city ?? "Unknown City")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Country
            if let country = event.country, !country.isEmpty {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.accentColor)
                    Text(country)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.accentColor)
                Text(event.date.formatted(date: .long, time: .omitted))
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical)
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Details")
                .font(.title3)
                .fontWeight(.semibold)
            
            // Event Type
            HStack {
                Text(eventTypeIcon)
                    .font(.title2)
                Text("Type:")
                    .foregroundColor(.secondary)
                Text(eventTypeText)
                    .fontWeight(.medium)
            }
            
            // Coordinates
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.accentColor)
                    Text("Coordinates")
                        .foregroundColor(.secondary)
                }
                Text("Latitude: \(event.latitude, specifier: "%.6f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Longitude: \(event.longitude, specifier: "%.6f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.title3)
                .fontWeight(.semibold)
            
            Map(initialPosition: .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
            )) {
                Annotation(event.city ?? "Other", coordinate: CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)) {
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
            .frame(height: 300)
            .cornerRadius(12)
        }
    }
    
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Activities
            if !event.activityIDs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.accentColor)
                        Text("Activities")
                            .font(.headline)
                    }
                    
                    ForEach(activityNames, id: \.self) { activity in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(activity)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                }
            }
            
            // People
            if !event.people.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.accentColor)
                        Text("People")
                            .font(.headline)
                    }
                    
                    ForEach(event.people) { person in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(person.displayName)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.accentColor)
                Text("Note")
                    .font(.headline)
            }
            
            Text(event.note)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Helpers
    
    private var eventTypeIcon: String {
        if let eventType = Event.EventType(rawValue: event.eventType) {
            return eventType.icon
        }
        return "🔲"
    }
    
    private var eventTypeText: String {
        if let eventType = Event.EventType(rawValue: event.eventType) {
            return eventType.rawValue.capitalized
        }
        return "Unspecified"
    }
    
    private var activityNames: [String] {
        let map = Dictionary(uniqueKeysWithValues: store.activities.map { ($0.id, $0.name) })
        return event.activityIDs.compactMap { map[$0] }
    }
}

// MARK: - Preview

struct OtherEventDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            OtherEventDetailView(event: Event.sampleData[0])
                .environmentObject(DataStore())
        }
    }
}
