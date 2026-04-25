//
//  LocationCoordinateUpdater.swift
//  LocTrac
//
//  Utility to update event coordinates when location coordinates change
//

import Foundation
import CoreLocation

/// Helper to manage coordinate updates across events when locations change
struct LocationCoordinateUpdater {
    
    /// Threshold for "small" vs "large" coordinate changes (in miles)
    static let autoUpdateThresholdMiles: Double = 5.0
    
    /// Result of analyzing coordinate changes
    struct UpdateAnalysis {
        var affectedEvents: [Event]
        var oldCoordinates: CLLocationCoordinate2D
        var newCoordinates: CLLocationCoordinate2D
        var distanceChange: Double // miles
        var shouldAutoUpdate: Bool
        
        var description: String {
            if shouldAutoUpdate {
                return "Small change (\(String(format: "%.1f", distanceChange)) mi) - will auto-update \(affectedEvents.count) events"
            } else {
                return "Large change (\(String(format: "%.1f", distanceChange)) mi) - requires review for \(affectedEvents.count) events"
            }
        }
    }
    
    /// Analyze the impact of changing a location's coordinates
    static func analyzeCoordinateChange(
        location: Location,
        newLatitude: Double,
        newLongitude: Double,
        events: [Event]
    ) -> UpdateAnalysis {
        print("\n📍 [Coordinate Analysis] Location: \(location.name)")
        print("   Old: (\(location.latitude), \(location.longitude))")
        print("   New: (\(newLatitude), \(newLongitude))")
        
        let oldCoord = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        let newCoord = CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude)
        
        // Calculate distance change
        let oldLocation = CLLocation(latitude: oldCoord.latitude, longitude: oldCoord.longitude)
        let newLocation = CLLocation(latitude: newCoord.latitude, longitude: newCoord.longitude)
        let distanceInMeters = oldLocation.distance(from: newLocation)
        let distanceInMiles = distanceInMeters * 0.000621371
        
        print("   Distance change: \(String(format: "%.2f", distanceInMiles)) miles")
        
        // Find events that:
        // 1. Use this location
        // 2. Have coordinates that match the OLD location coordinates (or are close to them)
        //    This handles the case where location starts with (0,0) or nil values
        let affectedEvents = events.filter { event in
            guard event.location.id == location.id else { return false }
            
            // Check if event coordinates are close to the old location coordinates
            // Using 0.01° threshold (~0.7 miles) to catch coordinates that match the old location
            let latDiff = abs(event.latitude - location.latitude)
            let lonDiff = abs(event.longitude - location.longitude)
            
            // Event is affected if its coordinates are within 0.01° of old location
            // OR if both old and event are at (0, 0) - the "not set" case
            let coordsMatchOld = (latDiff < 0.01 && lonDiff < 0.01)
            let bothAtZero = (location.latitude == 0.0 && location.longitude == 0.0 && 
                            event.latitude == 0.0 && event.longitude == 0.0)
            
            return coordsMatchOld || bothAtZero
        }
        
        print("   Affected events: \(affectedEvents.count)")
        
        // Determine if auto-update is appropriate
        let shouldAutoUpdate = distanceInMiles <= autoUpdateThresholdMiles
        print("   Auto-update: \(shouldAutoUpdate ? "YES" : "NO (requires review)")")
        
        return UpdateAnalysis(
            affectedEvents: affectedEvents,
            oldCoordinates: oldCoord,
            newCoordinates: newCoord,
            distanceChange: distanceInMiles,
            shouldAutoUpdate: shouldAutoUpdate
        )
    }
    
    /// Automatically update events with new coordinates (for small changes)
    static func autoUpdateEventCoordinates(
        events: [Event],
        newLatitude: Double,
        newLongitude: Double,
        newCity: String?,
        newCountry: String?,
        store: DataStore
    ) {
        print("\n🔄 [Auto-Update] Updating \(events.count) events with new coordinates")
        
        var updatedCount = 0
        for event in events {
            let updatedEvent = Event(
                id: event.id,
                eventType: Event.EventType(rawValue: event.eventType) ?? .unspecified,
                date: event.date,
                location: event.location,
                city: newCity ?? event.city ?? "",
                latitude: newLatitude,
                longitude: newLongitude,
                country: newCountry ?? event.country,
                note: event.note,
                people: event.people,
                activityIDs: event.activityIDs
            )
            
            store.update(updatedEvent)
            updatedCount += 1
            
            print("   ✅ Updated event \(event.id): \(event.date.utcMediumDateString)")
        }
        
        print("✅ [Auto-Update] Complete: \(updatedCount) events updated")
    }
    
    /// Check if any events need coordinate updates (for existing data)
    static func findEventsNeedingSync(location: Location, events: [Event]) -> [Event] {
        // Special case: "Other" location should NOT sync events
        // because each event has its own individual coordinates
        if location.name == "Other" {
            print("   ℹ️ Skipping 'Other' location - events have individual coordinates")
            return []
        }
        
        return events.filter { event in
            guard event.location.id == location.id else { return false }
            
            // Check if event coordinates differ from location coordinates
            let latDiff = abs(event.latitude - location.latitude)
            let lonDiff = abs(event.longitude - location.longitude)
            
            // Consider different if off by more than 0.0001 degrees (~36 feet)
            return latDiff > 0.0001 || lonDiff > 0.0001
        }
    }
}

// MARK: - DataStore Extension

extension DataStore {
    
    /// Update a location and propagate coordinate changes to events
    /// ALWAYS shows review UI when coordinates change to inform user of impact
    func updateLocationWithCoordinatePropagation(
        _ location: Location,
        requiresReview: ((LocationCoordinateUpdater.UpdateAnalysis) -> Void)? = nil
    ) {
        print("\n🏠 [Location Update] Starting update for: \(location.name)")
        
        // Get the existing location to compare
        guard let existingLocation = locations.first(where: { $0.id == location.id }) else {
            print("   ⚠️ Location not found, performing standard update")
            update(location)
            return
        }
        
        // Check if coordinates changed
        let coordsChanged = existingLocation.latitude != location.latitude ||
                           existingLocation.longitude != location.longitude
        
        if !coordsChanged {
            print("   ℹ️ Coordinates unchanged, performing standard update")
            update(location)
            return
        }
        
        // Analyze the impact
        let analysis = LocationCoordinateUpdater.analyzeCoordinateChange(
            location: existingLocation,
            newLatitude: location.latitude,
            newLongitude: location.longitude,
            events: events
        )
        
        // Update the location first
        update(location)
        
        if analysis.affectedEvents.isEmpty {
            print("   ✅ No events to update")
            return
        }
        
        // ALWAYS request review when coordinates change and events are affected
        // This ensures user is informed of the impact and can make the decision
        print("   ℹ️ Coordinate change detected - requesting user review")
        print("   📊 Impact: \(analysis.affectedEvents.count) events, \(String(format: "%.2f", analysis.distanceChange)) miles")
        requiresReview?(analysis)
    }
}
