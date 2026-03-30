//
//  EventCountryGeocoder.swift
//  LocTrac
//
//  Utility to geocode and update country fields for events
//

import Foundation
import CoreLocation

/// Result of analyzing an event for country update
struct EventCountryPreview: Identifiable {
    let id: String
    let eventID: String
    let city: String
    let currentCountry: String?
    let proposedCountry: String?
    let source: CountrySource
    let latitude: Double
    let longitude: Double
    
    enum CountrySource {
        case cityParsing
        case geocoding
        case noChange
        case failed
    }
}

/// Progress callback for country updates
typealias CountryUpdateProgress = (current: Int, total: Int, eventCity: String)

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
    
    /// Reverse geocode coordinates to get country name (runs off main thread)
    nonisolated static func geocodeCountry(latitude: Double, longitude: Double) async throws -> String? {
        print("🌍 [Geocoding] Starting for coordinates (\(latitude), \(longitude))")
        
        guard latitude != 0 || longitude != 0 else {
            print("⚠️ [Geocoding] Skipping zero coordinates")
            return nil
        }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let country = placemarks.first?.country
            print("✅ [Geocoding] Success: \(country ?? "nil") for (\(latitude), \(longitude))")
            return country
        } catch {
            print("❌ [Geocoding] Error for (\(latitude), \(longitude)): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Preview what would be updated for a single event
    static func previewCountryUpdate(for event: Event) async -> EventCountryPreview {
        let currentCountry = event.country ?? event.location.country
        
        // Already has country
        if let country = currentCountry, !country.isEmpty {
            return EventCountryPreview(
                id: event.id,
                eventID: event.id,
                city: event.city ?? "Unknown",
                currentCountry: country,
                proposedCountry: country,
                source: .noChange,
                latitude: event.latitude,
                longitude: event.longitude
            )
        }
        
        var proposedCountry: String?
        var source: EventCountryPreview.CountrySource = .failed
        
        // Try to parse from city string
        if let city = event.city, !city.isEmpty {
            print("🔍 [Preview] Parsing city: \(city)")
            if let parsed = parseCountryFromCity(city) {
                proposedCountry = parsed
                source = .cityParsing
                print("✅ [Preview] Parsed country: \(parsed)")
            }
        }
        
        // If still no country, try geocoding coordinates (off main thread)
        if proposedCountry == nil {
            print("🌍 [Preview] Attempting geocoding for event \(event.id)")
            do {
                if let geocoded = try await geocodeCountry(latitude: event.latitude, longitude: event.longitude) {
                    proposedCountry = geocoded
                    source = .geocoding
                    print("✅ [Preview] Geocoded country: \(geocoded)")
                }
            } catch {
                print("❌ [Preview] Geocoding failed: \(error.localizedDescription)")
            }
        }
        
        return EventCountryPreview(
            id: event.id,
            eventID: event.id,
            city: event.city ?? "Unknown",
            currentCountry: currentCountry,
            proposedCountry: proposedCountry,
            source: source,
            latitude: event.latitude,
            longitude: event.longitude
        )
    }
    
    /// Generate preview for all events that need country updates
    static func generatePreview(store: DataStore, progressCallback: @escaping (CountryUpdateProgress) -> Void) async -> [EventCountryPreview] {
        let eventsNeedingCountry = store.events.filter { event in
            let hasCountry = (event.country ?? event.location.country) != nil && !(event.country ?? event.location.country)!.isEmpty
            return !hasCountry
        }
        
        print("📋 [Preview] Analyzing \(eventsNeedingCountry.count) events...")
        var previews: [EventCountryPreview] = []
        
        for (index, event) in eventsNeedingCountry.enumerated() {
            let preview = await previewCountryUpdate(for: event)
            previews.append(preview)
            
            // Report progress
            progressCallback((current: index + 1, total: eventsNeedingCountry.count, eventCity: event.city ?? "Unknown"))
            
            // Rate limit to avoid geocoding API throttling
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
        
        print("✅ [Preview] Analysis complete: \(previews.filter { $0.source != .failed && $0.source != .noChange }.count) can be updated")
        return previews
    }
    
    /// Update country for a single event
    static func updateCountry(for event: Event, store: DataStore) async -> Event? {
        print("🔄 [Update] Processing event \(event.id): \(event.city ?? "Unknown")")
        
        // Already has country from location or event
        if let country = event.country ?? event.location.country, !country.isEmpty {
            print("⏭️ [Update] Event already has country: \(country)")
            return nil // No update needed
        }
        
        var updatedCountry: String?
        
        // Try to parse from city string
        if let city = event.city, !city.isEmpty {
            updatedCountry = parseCountryFromCity(city)
            if updatedCountry != nil {
                print("✅ [Update] Parsed country from city: \(updatedCountry!)")
            }
        }
        
        // If still no country, try geocoding coordinates
        if updatedCountry == nil {
            print("🌍 [Update] Attempting geocoding...")
            updatedCountry = try? await geocodeCountry(latitude: event.latitude, longitude: event.longitude)
            if updatedCountry != nil {
                print("✅ [Update] Geocoded country: \(updatedCountry!)")
            }
        }
        
        // Create updated event if we found a country
        guard let country = updatedCountry else {
            print("❌ [Update] Could not determine country for event \(event.id)")
            return nil
        }
        
        let updatedEvent = Event(
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
        
        print("✅ [Update] Created updated event with country: \(country)")
        return updatedEvent
    }
    
    /// Batch update countries for events from preview results
    static func applyUpdates(previews: [EventCountryPreview], store: DataStore, progressCallback: @escaping (CountryUpdateProgress) -> Void) async -> (updated: Int, failed: Int) {
        var updated = 0
        var failed = 0
        
        // Filter to only events that can be updated
        let updatableEvents = previews.filter { preview in
            preview.proposedCountry != nil && preview.source != .noChange && preview.source != .failed
        }
        
        print("📍 [Apply] Updating \(updatableEvents.count) events with new country data")
        
        for (index, preview) in updatableEvents.enumerated() {
            guard let event = store.events.first(where: { $0.id == preview.eventID }),
                  let country = preview.proposedCountry else {
                failed += 1
                continue
            }
            
            // Create updated event
            let updatedEvent = Event(
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
            
            store.update(updatedEvent)
            updated += 1
            
            print("✅ [Apply] Updated event \(event.id): \(event.city ?? "Unknown") → \(country)")
            
            // Report progress
            progressCallback((current: index + 1, total: updatableEvents.count, eventCity: preview.city))
        }
        
        // Save changes
        if updated > 0 {
            print("💾 [Apply] Saving \(updated) updated events to disk...")
            store.storeData()
            print("✅ [Apply] Save complete")
        }
        
        return (updated: updated, failed: failed)
    }
}
