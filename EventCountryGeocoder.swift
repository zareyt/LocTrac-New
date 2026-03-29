//
//  EventCountryGeocoder.swift
//  LocTrac
//
//  Utility to geocode and update country fields for events
//

import Foundation
import CoreLocation

/// Helper to extract country from event city strings and geocode coordinates
@MainActor
class EventCountryGeocoder {
    
    /// Parse country from city string formats like "Caen, France" or "Castle Rock, CO"
    static func parseCountryFromCity(_ city: String) -> String? {
        let components = city.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard components.count >= 2 else { return nil }
        
        let lastComponent = components.last!
        
        // Check if it's a US state code (2 letters)
        if lastComponent.count == 2 && lastComponent.uppercased() == lastComponent {
            return "United States"
        }
        
        // Otherwise, assume it's a country name
        return lastComponent
    }
    
    /// Reverse geocode coordinates to get country name
    static func geocodeCountry(latitude: Double, longitude: Double) async throws -> String? {
        guard latitude != 0 || longitude != 0 else { return nil }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            return placemarks.first?.country
        } catch {
            print("Geocoding error for (\(latitude), \(longitude)): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Update country for a single event
    static func updateCountry(for event: Event, store: DataStore) async -> Event? {
        // Already has country from location or event
        if let country = event.country ?? event.location.country, !country.isEmpty {
            return nil // No update needed
        }
        
        var updatedCountry: String?
        
        // Try to parse from city string
        if let city = event.city, !city.isEmpty {
            updatedCountry = parseCountryFromCity(city)
        }
        
        // If still no country, try geocoding coordinates
        if updatedCountry == nil {
            updatedCountry = try? await geocodeCountry(latitude: event.latitude, longitude: event.longitude)
        }
        
        // Create updated event if we found a country
        guard let country = updatedCountry else { return nil }
        
        return Event(
            id: event.id,
            eventType: Event.EventType(rawValue: event.eventType) ?? .unspecified,
            date: event.date,
            location: event.location,
            city: event.city ?? "",
            latitude: event.latitude,
            longitude: event.longitude,
            country: country,
            note: event.note,
            people: event.people,
            activityIDs: event.activityIDs
        )
    }
    
    /// Batch update countries for all events missing country data
    static func updateAllMissingCountries(store: DataStore) async -> (updated: Int, failed: Int) {
        var updated = 0
        var failed = 0
        
        let eventsNeedingCountry = store.events.filter { event in
            let hasCountry = (event.country ?? event.location.country) != nil && !(event.country ?? event.location.country)!.isEmpty
            return !hasCountry
        }
        
        print("📍 Found \(eventsNeedingCountry.count) events without country data")
        
        for event in eventsNeedingCountry {
            if let updatedEvent = await updateCountry(for: event, store: store) {
                store.update(updatedEvent)
                updated += 1
                print("✅ Updated event \(event.id): \(event.city ?? "Unknown") → \(updatedEvent.country ?? "Unknown")")
            } else {
                failed += 1
            }
            
            // Rate limit to avoid geocoding API throttling
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        // Save changes
        if updated > 0 {
            store.storeData()
            print("💾 Saved \(updated) updated events")
        }
        
        return (updated: updated, failed: failed)
    }
}
