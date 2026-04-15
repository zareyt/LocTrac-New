//
//  LocationDataEnhancer.swift
//  LocTrac
//
//  ⚠️ CORRECT FILE - DO NOT DELETE
//  This is the active location enhancement logic.
//  If you see another LocationDataEnhancer.swift in the Views folder, DELETE THAT ONE.
//
//  Validates and enhances location data (city, state, country, GPS)
//  using priority-based processing algorithm
//

import Foundation
import CoreLocation

enum LocationDataProcessingResult: Equatable {
    case success
    case error(String)
}

@MainActor
class LocationDataEnhancer {
    
    /// Process an event's location data through priority-based validation
    /// - Parameter event: Event to process (will be modified)
    /// - Returns: Processing result (success or error with message)
    func processEvent(_ event: inout Event) async -> LocationDataProcessingResult {
        
        // SKIP: Events with named locations (not "Other") - they inherit from master location
        if event.location.name != "Other" {
            return .success  // Skip, not an error
        }
        
        // Step 1: All data exists - just clean format
        if hasCompleteData(event) {
            cleanCityFormat(&event)
            return .success
        }
        
        // Step 2: Valid GPS - use reverse geocoding
        if hasValidGPS(event) {
            return await processWithGPS(&event)
        }
        
        // Step 3: No GPS - parse city format
        if !hasValidGPS(event) {
            return await processWithoutGPS(&event)
        }
        
        // Step 4: Insufficient data
        return .error("Insufficient data to validate location")
    }
    
    // MARK: - Step Checks
    
    private func hasCompleteData(_ event: Event) -> Bool {
        guard let city = event.city, !city.isEmpty else { return false }
        guard let state = event.state, !state.isEmpty else { return false }
        guard let country = event.country, !country.isEmpty else { return false }
        return event.latitude != 0.0 && event.longitude != 0.0
    }
    
    private func hasValidGPS(_ event: Event) -> Bool {
        return event.latitude != 0.0 && event.longitude != 0.0
    }
    
    // MARK: - Processing Steps
    
    /// Step 1: Clean city format when all data exists
    private func cleanCityFormat(_ event: inout Event) {
        guard var city = event.city,
              let commaIndex = city.firstIndex(of: ",") else { return }
        
        let cleanCity = String(city[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        event.city = cleanCity
    }
    
    /// Step 2: Process with valid GPS using reverse geocoding
    private func processWithGPS(_ event: inout Event) async -> LocationDataProcessingResult {
        let location = CLLocation(latitude: event.latitude, longitude: event.longitude)
        
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                return .error("Reverse geocoding returned no results")
            }
            
            // Update state and country from GPS
            if let state = placemark.administrativeArea {
                event.state = state
            }
            if let country = placemark.country {
                event.country = country
            }
            
            // Also update city if it's missing
            if event.city == nil || event.city?.isEmpty == true {
                if let city = placemark.locality {
                    event.city = city
                }
            }
            
            // Clean city format if needed
            cleanCityFormat(&event)
            
            return .success
            
        } catch {
            return .error("Geocoding failed: \(error.localizedDescription)")
        }
    }
    
    /// Step 3: Process without GPS by parsing city format
    private func processWithoutGPS(_ event: inout Event) async -> LocationDataProcessingResult {
        guard let city = event.city, !city.isEmpty else {
            return .error("Missing city name")
        }
        
        // Must have format "City, XX"
        guard let commaIndex = city.firstIndex(of: ",") else {
            return .error("City doesn't contain code and GPS is missing")
        }
        
        let cleanCity = String(city[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        let code = String(city[city.index(after: commaIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                    .uppercased()
        
        // FIRST: Try US state code
        if let stateName = USStateCodeMapper.stateName(for: code) {
            event.city = cleanCity
            event.state = stateName
            event.country = "United States"
            return .success
        }
        
        // SECOND: Try country code
        if let countryName = CountryCodeMapper.countryName(for: code) {
            event.city = cleanCity
            event.country = countryName
            
            // Use forward geocoding to get state and GPS coordinates
            return await forwardGeocode(city: cleanCity, country: countryName, event: &event)
        }
        
        // THIRD: If code doesn't match state or country, return specific error
        return .error("Unknown code '\(code)' in '\(city)' - not a valid state or country code")
    }
    
    /// Forward geocode a city and country to get state and GPS coordinates
    private func forwardGeocode(city: String, country: String, event: inout Event) async -> LocationDataProcessingResult {
        let query = "\(city), \(country)"
        
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(query)
            guard let placemark = placemarks.first else {
                return .error("Could not find location for '\(query)'")
            }
            
            // Update state
            if let state = placemark.administrativeArea {
                event.state = state
            }
            
            // Update GPS coordinates
            if let location = placemark.location {
                event.latitude = location.coordinate.latitude
                event.longitude = location.coordinate.longitude
            }
            
            return .success
            
        } catch {
            return .error("Forward geocoding failed for '\(query)': \(error.localizedDescription)")
        }
    }
}
