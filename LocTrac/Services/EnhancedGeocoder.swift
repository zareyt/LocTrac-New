//
//  EnhancedGeocoder.swift
//  LocTrac
//
//  Created by Tim Arey on 4/9/26.
//  v1.5: Enhanced geocoding service with forward/reverse geocoding and smart parsing
//

import Foundation
import CoreLocation

@MainActor
class EnhancedGeocoder {
    
    // MARK: - Reverse Geocoding
    
    /// Geocode a coordinate to get full location details (city, state, country, etc.)
    /// - Parameters:
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: GeocodeResult with location details, or nil if geocoding fails
    static func reverseGeocode(latitude: Double, longitude: Double) async -> GeocodeResult? {
        guard latitude != 0.0 || longitude != 0.0 else {
            print("⚠️ [EnhancedGeocoder] Cannot reverse geocode zero coordinates")
            return nil
        }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                print("⚠️ [EnhancedGeocoder] No placemark found for coordinates: (\(latitude), \(longitude))")
                return nil
            }
            
            let result = GeocodeResult(from: placemark)
            print("✅ [EnhancedGeocoder] Reverse geocoded: \(result.city ?? "nil"), \(result.state ?? "nil"), \(result.country ?? "nil")")
            return result
        } catch {
            print("❌ [EnhancedGeocoder] Reverse geocoding failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Forward Geocoding
    
    /// Geocode an address string to get coordinates and location details
    /// - Parameter address: Address string (e.g., "Denver, CO" or "1600 Amphitheatre Parkway, Mountain View, CA")
    /// - Returns: GeocodeResult with coordinates and location details, or nil if geocoding fails
    static func forwardGeocode(address: String) async -> GeocodeResult? {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            print("⚠️ [EnhancedGeocoder] Cannot geocode empty address")
            return nil
        }
        
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(trimmedAddress)
            guard let placemark = placemarks.first else {
                print("⚠️ [EnhancedGeocoder] No placemark found for address: '\(trimmedAddress)'")
                return nil
            }
            
            let result = GeocodeResult(from: placemark)
            print("✅ [EnhancedGeocoder] Forward geocoded '\(trimmedAddress)': \(result.city ?? "nil"), \(result.state ?? "nil"), \(result.country ?? "nil")")
            return result
        } catch {
            print("❌ [EnhancedGeocoder] Forward geocoding failed for '\(trimmedAddress)': \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Manual Entry Parsing
    
    /// Parse a manual entry like "Denver, CO" or "Paris, France" into separate components
    /// Uses heuristics to determine if components are city/state or city/country
    /// - Parameter input: User-entered location string
    /// - Returns: Tuple of (city, state, country) with nil for unknown components
    ///
    /// Examples:
    /// - "Denver" → (city: "Denver", state: nil, country: nil)
    /// - "Denver, CO" → (city: "Denver", state: "CO", country: "United States")
    /// - "Paris, France" → (city: "Paris", state: nil, country: "France")
    /// - "Toronto, ON, Canada" → (city: "Toronto", state: "ON", country: "Canada")
    static func parseManualEntry(_ input: String) -> (city: String?, state: String?, country: String?) {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            return (city: nil, state: nil, country: nil)
        }
        
        let components = trimmedInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        switch components.count {
        case 1:
            // Just city: "Denver"
            print("📝 [EnhancedGeocoder] Parsed '\(input)' as city only")
            return (city: components[0], state: nil, country: nil)
            
        case 2:
            // City, State OR City, Country
            // Heuristic: If second part is 2 characters, assume US/CA state/province code
            if components[1].count == 2 {
                // Assume US state code (could also be Canadian province)
                print("📝 [EnhancedGeocoder] Parsed '\(input)' as city, state (assuming US)")
                return (city: components[0], state: components[1], country: "United States")
            } else {
                // Assume country name
                print("📝 [EnhancedGeocoder] Parsed '\(input)' as city, country")
                return (city: components[0], state: nil, country: components[1])
            }
            
        case 3:
            // City, State, Country: "Denver, CO, United States"
            print("📝 [EnhancedGeocoder] Parsed '\(input)' as city, state, country")
            return (city: components[0], state: components[1], country: components[2])
            
        default:
            // Too many components - just use the whole thing as city
            print("⚠️ [EnhancedGeocoder] Too many components in '\(input)', using as city only")
            return (city: trimmedInput, state: nil, country: nil)
        }
    }
    
    // MARK: - Combined Parse + Geocode
    
    /// Parse manual entry and optionally geocode to fill in missing details
    /// - Parameters:
    ///   - input: User-entered location string
    ///   - geocode: Whether to geocode the parsed address to get coordinates and fill missing fields
    /// - Returns: GeocodeResult with as much information as possible
    static func parseAndGeocode(_ input: String, geocode: Bool = true) async -> GeocodeResult? {
        let parsed = parseManualEntry(input)
        
        // If we choose not to geocode, return what we have
        guard geocode else {
            return GeocodeResult(
                city: parsed.city,
                state: parsed.state,
                country: parsed.country,
                countryCode: nil,
                latitude: 0.0,
                longitude: 0.0
            )
        }
        
        // Try to geocode the original input to get coordinates and more complete data
        if let geocoded = await forwardGeocode(address: input) {
            // Merge: prefer geocoded data, but use parsed data if geocoded is missing something
            return GeocodeResult(
                city: geocoded.city ?? parsed.city,
                state: geocoded.state ?? parsed.state,
                country: geocoded.country ?? parsed.country,
                countryCode: geocoded.countryCode,
                latitude: geocoded.latitude,
                longitude: geocoded.longitude
            )
        } else {
            // Geocoding failed, return parsed data only
            print("⚠️ [EnhancedGeocoder] Geocoding failed, using parsed data only")
            return GeocodeResult(
                city: parsed.city,
                state: parsed.state,
                country: parsed.country,
                countryCode: nil,
                latitude: 0.0,
                longitude: 0.0
            )
        }
    }
}
