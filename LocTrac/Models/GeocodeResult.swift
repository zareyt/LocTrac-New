//
//  GeocodeResult.swift
//  LocTrac
//
//  Created by Tim Arey on 4/9/26.
//  v1.5: Structured result from geocoding operations
//

import Foundation
import CoreLocation

/// Structured result from forward or reverse geocoding
struct GeocodeResult {
    let city: String?
    let state: String?          // administrativeArea (state, province, region, etc.)
    let country: String?        // Full country name
    let countryCode: String?    // ISO country code (e.g., "US", "CA", "FR")
    let latitude: Double
    let longitude: Double
    
    /// Initialize from a CLPlacemark
    init(from placemark: CLPlacemark) {
        self.city = placemark.locality
        self.state = placemark.administrativeArea
        self.country = placemark.country
        self.countryCode = placemark.isoCountryCode
        self.latitude = placemark.location?.coordinate.latitude ?? 0.0
        self.longitude = placemark.location?.coordinate.longitude ?? 0.0
    }
    
    /// Initialize with explicit values (for testing or manual creation)
    init(city: String?, 
         state: String?, 
         country: String?, 
         countryCode: String?, 
         latitude: Double, 
         longitude: Double) {
        self.city = city
        self.state = state
        self.country = country
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
    }
}
