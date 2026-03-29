//
//  LocationsView.swift
//  SwiftMapApp
//
//  Created by Tim Arey on 3/22/23.
//

import SwiftUI
import MapKit

struct LocationsView: View {
    @EnvironmentObject private var vm: LocationsMapViewModel
    @EnvironmentObject var store: DataStore
    @State private var lformType: LocationFormType?
    @State private var selectedCityEvents: [Event]? // Events for a specific city
    @State private var showJourneyView: Bool = false // NEW: For Journey modal
    
    var body: some View {
        ZStack {
            mapLayer
            
            // Only show preview card for regular locations (not "Other")
            VStack {
                Spacer()
                if let selectedLocation = vm.mapLocation, selectedLocation.name != "Other" {
                    locationsPreviewStack
                }
            }
            
            // Journey button and year filter picker at the bottom
            VStack {
                Spacer()
                
                // NEW: Play Journey button
                playJourneyButton
                    .padding(.bottom, 8)
                
                yearFilterPicker
                    .padding(.bottom, 10) // Just above the tab bar
                    .padding(.horizontal)
            }
        }
        .sheet(item: $vm.sheetLocation, onDismiss: nil) { location in
            LocationDetailView(lformType: $lformType, locationID: location.id)
                .environmentObject(vm)
                .environmentObject(store)
        }
        .sheet(item: Binding(
            get: { selectedCityEvents?.first },
            set: { if $0 == nil { selectedCityEvents = nil } }
        )) { _ in
            // Show detail view with all events for this city
            if let events = selectedCityEvents, !events.isEmpty {
                NavigationStack {
                    OtherCityDetailView(events: events)
                        .environmentObject(store)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    selectedCityEvents = nil
                                }
                            }
                        }
                }
            }
        }
        .fullScreenCover(isPresented: $showJourneyView) {
            // NEW: Full-screen Journey view with shared view model
            TravelJourneyView()
                .environmentObject(store)
                .environmentObject(vm) // Pass the map's view model for filter sharing
        }
    }
}

struct LocationsView_Previews: PreviewProvider {
    static var previews: some View {
        LocationsView()
            .environmentObject(LocationsMapViewModel())
            .environmentObject(DataStore())
    }
}

extension LocationsView {
    // NEW: Play Journey button
    private var playJourneyButton: some View {
        Button {
            showJourneyView = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                Text("Play Journey")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
    
    private var yearFilterPicker: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.blue)
            
            Picker("Year", selection: $vm.selectedYear) {
                Text("All Years").tag(nil as Int?)
                ForEach(vm.availableYears(), id: \.self) { year in
                    Text(String(year)).tag(year as Int?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(radius: 4)
    }
    
    private var mapLayer: some View {
        Map(initialPosition: .region(vm.mapRegion)) {
            // Regular location pins with RED labels - filtered by year, sized by event count
            ForEach(filteredLocations) { location in
                let eventCount = vm.eventCount(for: location)
                let scale = vm.scaleForEventCount(eventCount)
                
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                    VStack(spacing: 4) {
                        LocationMapAnnotationView()
                            .scaleEffect(vm.mapLocation?.id == location.id ? scale * 1.2 : scale)
                            .shadow(radius: 10)
                        
                        // RED label below pin - sized based on event count
                        VStack(spacing: 2) {
                            Text(location.name)
                                .font(vm.fontSizeForScale(scale))
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            
                            // Show event count badge
                            Text("\(eventCount)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(4)
                        .shadow(radius: 1)
                    }
                    .onTapGesture {
                        // Auto-open detail view for regular locations
                        vm.sheetLocation = location
                    }
                }
            }
            
            // BLUE pins for "Other" location events with city labels - filtered by year, sized by event count
            ForEach(filteredOtherCities, id: \.city) { cityInfo in
                let scale = vm.scaleForEventCount(cityInfo.count)
                
                Annotation("", coordinate: cityInfo.coordinate) {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12 * scale, height: 12 * scale)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(radius: 4)
                        
                        // City label below blue pin - sized based on event count
                        VStack(spacing: 2) {
                            Text(cityInfo.city)
                                .font(vm.fontSizeForScale(scale))
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            // Show event count badge
                            Text("\(cityInfo.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(4)
                    }
                    .onTapGesture {
                        // Always show detail view with all events at this city
                        handleOtherCityTap(cityInfo)
                    }
                }
            }
        }
    }
    
    // Filtered regular locations based on selected year
    private var filteredLocations: [Location] {
        let regularLocations = vm.locations.filter { $0.name != "Other" }
        
        guard vm.selectedYear != nil else {
            return regularLocations // Show all if no year selected
        }
        
        return regularLocations.filter { location in
            vm.locationHasEventsInYear(location)
        }
    }
    
    // Group "Other" events by city and get unique coordinates - filtered by year
    private var filteredOtherCities: [(city: String, coordinate: CLLocationCoordinate2D, count: Int, events: [Event])] {
        guard let otherLocation = store.locations.first(where: { $0.name == "Other" }) else {
            return []
        }
        
        var otherEvents = store.events.filter { event in
            event.location.id == otherLocation.id &&
            event.latitude != 0.0 &&
            event.longitude != 0.0
        }
        
        // Apply year filter if selected
        if let year = vm.selectedYear {
            otherEvents = otherEvents.filter { event in
                Calendar.current.component(.year, from: event.date) == year
            }
        }
        
        // Group by city
        let grouped = Dictionary(grouping: otherEvents) { event -> String in
            event.city ?? "Unknown"
        }
        
        return grouped.map { (city, events) in
            // Use first event's coordinates for the city
            let firstEvent = events.first!
            return (
                city: city,
                coordinate: CLLocationCoordinate2D(latitude: firstEvent.latitude, longitude: firstEvent.longitude),
                count: events.count,
                events: events.sorted { $0.date > $1.date } // Most recent first
            )
        }.sorted { $0.city < $1.city }
    }
    
    // Handle tapping on an "Other" city pin - now always shows detail with all events
    private func handleOtherCityTap(_ cityInfo: (city: String, coordinate: CLLocationCoordinate2D, count: Int, events: [Event])) {
        // Pass all events for this city to the detail view
        selectedCityEvents = cityInfo.events
    }
    
    private var locationsPreviewStack: some View {
        ZStack {
            if let selectedLocation = vm.mapLocation {
                LocationPreviewView(location: selectedLocation)
                    .shadow(color: Color.black.opacity(0.3), radius: 20)
                    .padding()
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
    }
}
