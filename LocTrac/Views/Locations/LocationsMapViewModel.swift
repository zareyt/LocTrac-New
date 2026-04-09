//
//  LocationsMapViewModel.swift
//  SwiftMapApp
//  Based on vtube Swiftful Thinking
//  Created by Tim Arey on 3/22/23.
//

import Foundation
import SwiftUI
import MapKit

class LocationsMapViewModel: ObservableObject{
    
    //All Loaded locations
    @Published var locations: [Location]
    
    //Current location on map (optional - only when user selects one)
    @Published var mapLocation: Location? {
        didSet {
            if let location = mapLocation {
                updateMapRegion(location: location)
            }
        }
    }
    
    //Current region on map - starts with US view
    @Published var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),  // Center of USA
        span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 60) // USA view
    )
    let mapSpan = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    
    // Show list of location
    @Published var showLocationsList: Bool = false
    
    // Show location detail via sheet
    @Published var sheetLocation: Location? = nil
    
    // Year filter - nil means "All Years"
    @Published var selectedYear: Int? = nil
    
    // Store reference to sync with DataStore
    private var store: DataStore?
    
    init() {
        // Initialize with empty, will be updated when store is set
        self.locations = []
        self.mapLocation = nil  // No default location
    }
    
    // Call this after creating the view model to sync with DataStore
    func setStore(_ store: DataStore) {
        self.store = store
        self.locations = store.locations
        // Don't set a default location - keep world view
    }
    
    // Refresh locations from store (call when locations might have changed)
    func refreshLocations() {
        guard let store = store else { return }
        self.locations = store.locations
        // If current location was deleted, reset to nil (world view)
        if let currentLocation = mapLocation,
           !locations.contains(where: { $0.id == currentLocation.id }) {
            mapLocation = nil
        }
    }
    
    private func updateMapRegion(location: Location) {
        withAnimation(.easeInOut){
            mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: location.latitude,longitude: location.longitude), span: mapSpan)
        }
    }
    
    func toggleLocationsList() {
        withAnimation(.easeInOut) {
            showLocationsList = !showLocationsList
        }
    }
    
    func showNextLocation(location: Location){
        withAnimation(.easeInOut){
            mapLocation = location
            showLocationsList = false
        }
    }
    
    // Get available years from events in the store
    func availableYears() -> [Int] {
        guard let store = store else { return [] }
        let years = Set(store.events.map { Calendar.current.component(.year, from: $0.date) })
        return years.sorted(by: >) // Most recent first
    }
    
    // Check if a location has events in the selected year
    func locationHasEventsInYear(_ location: Location) -> Bool {
        guard let store = store else { return false }
        guard let year = selectedYear else { return true } // Show all if no filter
        
        let locationEvents = store.events.filter { $0.location.id == location.id }
        return locationEvents.contains { event in
            Calendar.current.component(.year, from: event.date) == year
        }
    }
    
    // Get the number of events at a location (filtered by year if applicable)
    func eventCount(for location: Location) -> Int {
        guard let store = store else { return 0 }
        
        var locationEvents = store.events.filter { $0.location.id == location.id }
        
        // Apply year filter if selected
        if let year = selectedYear {
            locationEvents = locationEvents.filter { event in
                Calendar.current.component(.year, from: event.date) == year
            }
        }
        
        return locationEvents.count
    }
    
    // Get maximum event count across all locations (respects year filter)
    func maxEventCount() -> Int {
        guard let store = store else { return 1 }
        
        // Get max from regular locations
        let locationMax = store.locations.map { location in
            eventCount(for: location)
        }.max() ?? 0
        
        // Get max from "Other" cities
        guard let otherLocation = store.locations.first(where: { $0.name == "Other" }) else {
            return max(locationMax, 1)
        }
        
        var otherEvents = store.events.filter { event in
            event.location.id == otherLocation.id &&
            event.latitude != 0.0 &&
            event.longitude != 0.0
        }
        
        // Apply year filter if selected
        if let year = selectedYear {
            otherEvents = otherEvents.filter { event in
                Calendar.current.component(.year, from: event.date) == year
            }
        }
        
        // Group by city and get max count
        let grouped = Dictionary(grouping: otherEvents) { event -> String in
            event.city ?? "Unknown"
        }
        
        let otherMax = grouped.values.map { $0.count }.max() ?? 0
        
        // Return overall max, at least 1
        return max(max(locationMax, otherMax), 1)
    }
    
    // Calculate scale factor based on event count
    // Returns a smooth scale between minScale and maxScale based on proportion to max
    func scaleForEventCount(_ count: Int) -> CGFloat {
        let minScale: CGFloat = 0.7
        let maxScale: CGFloat = 2.0
        
        guard count > 0 else { return minScale }
        
        let maxCount = maxEventCount()
        
        // Calculate proportion (0.0 to 1.0)
        let proportion = CGFloat(count) / CGFloat(maxCount)
        
        // Apply smooth interpolation with slight curve for better distribution
        // Using square root to make smaller values more visible
        let smoothProportion = sqrt(proportion)
        
        // Map to scale range
        let scale = minScale + (smoothProportion * (maxScale - minScale))
        
        return scale
    }
    
    // Get font size based on scale factor
    func fontSizeForScale(_ scale: CGFloat) -> Font {
        switch scale {
        case 0..<0.9:
            return .caption
        case 0.9..<1.1:
            return .caption
        case 1.1..<1.3:
            return .subheadline
        case 1.3..<1.5:
            return .body
        case 1.5..<1.7:
            return .callout
        case 1.7..<1.85:
            return .title3
        case 1.85..<2.0:
            return .title2
        default:
            return .title
        }
    }
}
