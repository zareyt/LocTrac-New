//
//  StateDetector.swift
//  LocTrac
//
//  Helper for detecting US state from coordinates
//

import CoreLocation
import Foundation

actor StateDetector {
    // Cache to avoid repeated geocoding for same coordinates
    private var cache: [String: String] = [:]
    
    /// Detect US state from coordinates
    /// Returns state abbreviation (e.g., "CO", "CA") or nil if not found/not in US
    func detectState(latitude: Double, longitude: Double) async -> String? {
        let cacheKey = "\(latitude),\(longitude)"
        
        // Check cache first
        if let cached = cache[cacheKey] {
            return cached.isEmpty ? nil : cached
        }
        
        // Use reverse geocoding
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                cache[cacheKey] = "" // Cache negative result
                return nil
            }
            
            // Check if it's in the US
            let country = placemark.country?.uppercased() ?? ""
            guard country == "UNITED STATES" || country == "US" || country == "USA" else {
                cache[cacheKey] = "" // Cache negative result (not US)
                return nil
            }
            
            // Get state abbreviation
            if let state = placemark.administrativeArea {
                cache[cacheKey] = state
                return state
            }
            
            cache[cacheKey] = "" // Cache negative result
            return nil
            
        } catch {
            print("⚠️ Geocoding error for (\(latitude), \(longitude)): \(error.localizedDescription)")
            // Don't cache errors - might work next time
            return nil
        }
    }
    
    /// Detect states for multiple events efficiently (batched)
    func detectStates(for events: [Event]) async -> [String: String] {
        var results: [String: String] = [:] // eventID -> state
        
        // Process events
        for event in events {
            // Use event coordinates if available, otherwise location coordinates
            let lat = event.latitude != 0.0 ? event.latitude : event.location.latitude
            let lon = event.longitude != 0.0 ? event.longitude : event.location.longitude
            
            if let state = await detectState(latitude: lat, longitude: lon) {
                results[event.id] = state
            }
        }
        
        return results
    }
    
    /// Extract state from city string if formatted as "City, ST"
    static func extractStateFromCity(_ city: String?) -> String? {
        guard let city = city, !city.isEmpty else { return nil }
        
        let components = city.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if components.count >= 2 {
            let stateAbbr = components[1]
            // Validate it's a 2-letter state code
            if stateAbbr.count == 2 && stateAbbr.allSatisfy({ $0.isLetter }) {
                return stateAbbr.uppercased()
            }
        }
        
        return nil
    }
    
    /// Clear the cache (useful for testing or memory management)
    func clearCache() {
        cache.removeAll()
    }
}
