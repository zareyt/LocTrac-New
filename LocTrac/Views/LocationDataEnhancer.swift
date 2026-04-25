//
//
//  LocationDataEnhancer.swift
//  LocTrac
//
//  ✅ CORRECT FILE - KEEP THIS ONE
//  ⏰ Last Updated: 2026-04-13 (Rate limiting + long country names + retry queue)
//  ⚠️ DELETE: LocationDataEnhancer 2.swift or any duplicates
//
//  Validates and enhances location data (city, state, country, GPS)
//  using priority-based processing algorithm with Apple geocoding rate limit handling
//

import Foundation
import CoreLocation

enum LocationDataProcessingResult: Equatable, Codable {
    case success
    case error(String)
    case skipped  // For events that don't need processing
    case retryLater  // For rate-limited requests
}

@MainActor
class LocationDataEnhancer {
    
    // Rate limiting: Apple limits to 50 requests/minute
    private var requestCount = 0
    private var lastResetTime = Date()
    private let maxRequestsPerMinute = 45  // Stay under 50 to be safe
    private var rateLimitDelay: TimeInterval = 0  // Dynamic delay based on errors
    
    // MARK: - Rate Limiting
    
    /// Check if we can make a geocoding request, wait if necessary
    private func checkRateLimit() async {
        // Reset counter if minute has passed
        let now = Date()
        if now.timeIntervalSince(lastResetTime) >= 60 {
            requestCount = 0
            lastResetTime = now
            rateLimitDelay = 0
            print("   🔄 Rate limit reset - \(requestCount) requests in last minute")
        }
        
        // If we've hit the limit, wait for the minute to roll over
        if requestCount >= maxRequestsPerMinute {
            let waitTime = 60 - now.timeIntervalSince(lastResetTime) + 1  // +1 sec buffer
            print("   ⏸️ Rate limit reached (\(requestCount)/\(maxRequestsPerMinute)) - waiting \(Int(waitTime))s")
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            requestCount = 0
            lastResetTime = Date()
        }
        
        // Add any dynamic delay from previous rate limit errors
        if rateLimitDelay > 0 {
            print("   ⏸️ Rate limit cooldown - waiting \(Int(rateLimitDelay))s")
            try? await Task.sleep(nanoseconds: UInt64(rateLimitDelay * 1_000_000_000))
            rateLimitDelay = 0
        }
        
        requestCount += 1
    }
    
    /// Handle rate limit error from geocoder
    private func handleRateLimitError(_ resetTime: TimeInterval?) {
        if let resetTime = resetTime, resetTime > 0 {
            rateLimitDelay = resetTime + 1  // Add 1 sec buffer
            print("   ⚠️ Rate limited by Apple - will wait \(Int(rateLimitDelay))s before retry")
        } else {
            rateLimitDelay = 10  // Default 10 sec wait
            print("   ⚠️ Rate limited by Apple - will wait \(Int(rateLimitDelay))s")
        }
    }
    
    // MARK: - Location Processing
    
    /// Process a master Location's data through priority-based validation
    /// - Parameter location: Location to process (will be modified)
    /// - Returns: Processing result (success, error, or skipped)
    func processLocation(_ location: inout Location) async -> LocationDataProcessingResult {
        
        // SKIP: "Other" location - it's just a placeholder, events store their own data
        if location.name == "Other" {
            return .skipped  // Silent skip
        }

        // SKIP: Already successfully geocoded locations - no need to process again
        if location.isGeocoded {
            print("⏭️ Skipping already geocoded location '\(location.name)'")
            return .skipped
        }

        // PROCESS: Named locations (Loft, Cabo, etc.) - clean up master data
        print("🔍 Processing Location: \(location.name)")
        print("   📍 Before: city=\(location.city ?? "nil"), state=\(location.state ?? "nil"), country=\(location.country ?? "nil")")
        
        // Step 1: All data exists - just clean format
        if hasCompleteLocationData(location) {
            cleanLocationCityFormat(&location)
            location.isGeocoded = true
            print("   ✅ Step 1: Cleaned format")
            print("   📍 After: city=\(location.city ?? "nil"), state=\(location.state ?? "nil"), country=\(location.country ?? "nil")")
            return .success
        }

        // Step 2: Valid GPS - use reverse geocoding
        if hasValidLocationGPS(location) {
            print("   🌐 Step 2: Using GPS reverse geocoding")
            let result = await processLocationWithGPS(&location)
            if case .success = result {
                location.isGeocoded = true
            }
            print("   📍 After: city=\(location.city ?? "nil"), state=\(location.state ?? "nil"), country=\(location.country ?? "nil")")
            if case .error(let msg) = result {
                print("   ❌ Error: \(msg)")
            }
            return result
        }

        // Step 3: No GPS - parse city format
        if !hasValidLocationGPS(location) {
            print("   📝 Step 3: Parsing city format (no GPS)")
            let result = await processLocationWithoutGPS(&location)
            if case .success = result {
                location.isGeocoded = true
            }
            print("   📍 After: city=\(location.city ?? "nil"), state=\(location.state ?? "nil"), country=\(location.country ?? "nil")")
            if case .error(let msg) = result {
                print("   ❌ Error: \(msg)")
            }
            return result
        }
        
        // Step 4: Insufficient data
        let errorMsg = "Insufficient data to validate location"
        print("   ❌ Error: \(errorMsg)")
        return .error(errorMsg)
    }
    
    // MARK: - Event Processing
    
    /// Process an event's location data through priority-based validation
    /// - Parameter event: Event to process (will be modified)
    /// - Returns: Processing result (success, error, or skipped)
    func processEvent(_ event: inout Event) async -> LocationDataProcessingResult {
        
        // SKIP: Events with named locations (not "Other") - they inherit from master location
        // Silent skip - no log spam for the ~1200 named-location events
        if event.location.name != "Other" {
            return .skipped
        }
        
        // SKIP: Already successfully geocoded events - no need to process again
        if event.isGeocoded {
            print("⏭️ Skipping already geocoded event on \(event.date.utcMediumDateString)")
            return .skipped
        }
        
        // PROCESS: "Other" events - each stores its own city/state/country/GPS
        print("🔍 Processing 'Other' Event on \(event.date.utcMediumDateString)")
        print("   📍 Before: city=\(event.city ?? "nil"), state=\(event.state ?? "nil"), country=\(event.country ?? "nil"), lat=\(event.latitude), lon=\(event.longitude)")
        
        // Step 1: All data exists - just clean format
        if hasCompleteEventData(event) {
            cleanEventCityFormat(&event)
            event.isGeocoded = true  // Mark as geocoded
            print("   ✅ Step 1: Cleaned format")
            print("   📍 After: city=\(event.city ?? "nil"), state=\(event.state ?? "nil"), country=\(event.country ?? "nil")")
            return .success
        }
        
        // Step 2: Valid GPS - use reverse geocoding
        if hasValidEventGPS(event) {
            print("   🌐 Step 2: Using GPS reverse geocoding")
            let result = await processEventWithGPS(&event)
            if case .success = result {
                event.isGeocoded = true  // Mark as geocoded on success
            }
            print("   📍 After: city=\(event.city ?? "nil"), state=\(event.state ?? "nil"), country=\(event.country ?? "nil")")
            if case .error(let msg) = result {
                print("   ❌ Error: \(msg)")
            }
            return result
        }
        
        // Step 3: No GPS - parse city format
        if !hasValidEventGPS(event) {
            print("   📝 Step 3: Parsing city format (no GPS)")
            let result = await processEventWithoutGPS(&event)
            if case .success = result {
                event.isGeocoded = true  // Mark as geocoded on success
            }
            print("   📍 After: city=\(event.city ?? "nil"), state=\(event.state ?? "nil"), country=\(event.country ?? "nil")")
            if case .error(let msg) = result {
                print("   ❌ Error: \(msg)")
            }
            return result
        }
        
        // Step 4: Insufficient data
        let errorMsg = "Insufficient data to validate location"
        print("   ❌ Error: \(errorMsg)")
        return .error(errorMsg)
    }
    
    // MARK: - Location Step Checks
    
    private func hasCompleteLocationData(_ location: Location) -> Bool {
        guard let city = location.city, !city.isEmpty else { return false }
        guard let state = location.state, !state.isEmpty else { return false }
        guard let country = location.country, !country.isEmpty else { return false }
        return location.latitude != 0.0 && location.longitude != 0.0
    }
    
    private func hasValidLocationGPS(_ location: Location) -> Bool {
        return location.latitude != 0.0 && location.longitude != 0.0
    }
    
    // MARK: - Event Step Checks
    
    private func hasCompleteEventData(_ event: Event) -> Bool {
        guard let city = event.city, !city.isEmpty else { return false }
        guard let state = event.state, !state.isEmpty else { return false }
        guard let country = event.country, !country.isEmpty else { return false }
        return event.latitude != 0.0 && event.longitude != 0.0
    }
    
    private func hasValidEventGPS(_ event: Event) -> Bool {
        return event.latitude != 0.0 && event.longitude != 0.0
    }
    
    // MARK: - Location Processing Steps
    
    /// Step 1: Clean city format when all data exists
    private func cleanLocationCityFormat(_ location: inout Location) {
        guard let city = location.city,
              let commaIndex = city.firstIndex(of: ",") else { return }
        
        let cleanCity = String(city[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        location.city = cleanCity
    }
    
    /// Step 2: Process Location with valid GPS using reverse geocoding
    private func processLocationWithGPS(_ location: inout Location) async -> LocationDataProcessingResult {
        await checkRateLimit()
        
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(clLocation)
            guard let placemark = placemarks.first else {
                return .error("Reverse geocoding returned no results")
            }
            
            // Update state and country from GPS
            if let state = placemark.administrativeArea {
                location.state = state
            }
            if let country = placemark.country {
                location.country = country
            }
            
            // Also update city if it's missing
            if location.city == nil || location.city?.isEmpty == true {
                if let city = placemark.locality {
                    location.city = city
                }
            }
            
            // Clean city format if needed
            cleanLocationCityFormat(&location)
            
            return .success
            
        } catch let clError as CLError {
            // Check for rate limiting
            if clError.code == .network || clError.code == .geocodeFoundNoResult {
                if let errorInfo = clError.userInfo["details"] as? [[String: Any]],
                   let timeUntilReset = errorInfo.first?["timeUntilReset"] as? TimeInterval {
                    handleRateLimitError(timeUntilReset)
                    return .retryLater
                }
            }
            return .error(formatCLError(clError))
        } catch {
            return .error("Geocoding failed: \(error.localizedDescription)")
        }
    }
    
    /// Step 3: Process Location without GPS by parsing city format
    private func processLocationWithoutGPS(_ location: inout Location) async -> LocationDataProcessingResult {
        guard let city = location.city, !city.isEmpty else {
            return .error("Missing city name")
        }
        
        // Must have format "City, XX" or "City, Country Name"
        guard let commaIndex = city.firstIndex(of: ",") else {
            return .error("City doesn't contain code and GPS is missing")
        }
        
        let cleanCity = String(city[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        let rawCode = String(city[city.index(after: commaIndex)...])
        let code = rawCode.trimmingCharacters(in: .whitespaces)
        
        // FIRST: Try US state code (2 letters) - NO GEOCODING NEEDED
        if code.count == 2, let stateName = USStateCodeMapper.stateName(for: code.uppercased()) {
            print("   ✅ Matched US state code '\(code)' → \(stateName)")
            location.city = cleanCity
            location.state = stateName
            location.country = "United States"
            return .success  // ✅ Return immediately, no geocoding
        }
        
        // SECOND: Try short country code (2 letters)
        if code.count == 2, let countryName = CountryCodeMapper.countryName(for: code.uppercased()) {
            print("   🌍 Matched country code '\(code)' → \(countryName)")
            location.city = cleanCity
            location.country = countryName
            
            // Use forward geocoding to get state and GPS coordinates
            return await forwardGeocodeLocation(city: cleanCity, country: countryName, location: &location)
        }
        
        // THIRD: Try long country name (e.g., "Canada", "Scotland")
        if let standardizedName = CountryNameMapper.standardizedName(for: code) {
            print("   🌍 Matched long country name '\(code)' → \(standardizedName)")
            location.city = cleanCity
            location.country = standardizedName
            
            // Use forward geocoding to get state and GPS coordinates
            return await forwardGeocodeLocation(city: cleanCity, country: standardizedName, location: &location)
        }
        
        // FOURTH: If code doesn't match state or country, return specific error
        return .error("Unknown code '\(code)' in '\(city)' - not a valid state or country code")
    }
    
    // MARK: - Event Processing Steps
    
    /// Step 1: Clean event city format when all data exists
    private func cleanEventCityFormat(_ event: inout Event) {
        guard let city = event.city,
              let commaIndex = city.firstIndex(of: ",") else { return }
        
        let cleanCity = String(city[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        event.city = cleanCity
    }
    
    /// Step 2: Process Event with valid GPS using reverse geocoding
    private func processEventWithGPS(_ event: inout Event) async -> LocationDataProcessingResult {
        await checkRateLimit()
        
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
            cleanEventCityFormat(&event)
            
            return .success
            
        } catch let clError as CLError {
            // Check for rate limiting
            if clError.code == .network || clError.code == .geocodeFoundNoResult {
                if let errorInfo = clError.userInfo["details"] as? [[String: Any]],
                   let timeUntilReset = errorInfo.first?["timeUntilReset"] as? TimeInterval {
                    handleRateLimitError(timeUntilReset)
                    return .retryLater
                }
            }
            return .error(formatCLError(clError))
        } catch {
            return .error("Geocoding failed: \(error.localizedDescription)")
        }
    }
    
    /// Step 3: Process Event without GPS by parsing city format
    private func processEventWithoutGPS(_ event: inout Event) async -> LocationDataProcessingResult {
        guard let city = event.city, !city.isEmpty else {
            return .error("Missing city name")
        }
        
        // Must have format "City, XX" or "City, Country Name"
        guard let commaIndex = city.firstIndex(of: ",") else {
            return .error("City doesn't contain code and GPS is missing")
        }
        
        let cleanCity = String(city[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        let rawCode = String(city[city.index(after: commaIndex)...])
        let code = rawCode.trimmingCharacters(in: .whitespaces)
        
        // FIRST: Try US state code (2 letters) - NO GEOCODING NEEDED
        if code.count == 2, let stateName = USStateCodeMapper.stateName(for: code.uppercased()) {
            print("   ✅ Matched US state code '\(code)' → \(stateName)")
            event.city = cleanCity
            event.state = stateName
            event.country = "United States"
            return .success  // ✅ Return immediately, no geocoding
        }
        
        // SECOND: Try short country code (2 letters)
        if code.count == 2, let countryName = CountryCodeMapper.countryName(for: code.uppercased()) {
            print("   🌍 Matched country code '\(code)' → \(countryName)")
            event.city = cleanCity
            event.country = countryName
            
            // Use forward geocoding to get state and GPS coordinates
            return await forwardGeocodeEvent(city: cleanCity, country: countryName, event: &event)
        }
        
        // THIRD: Try long country name (e.g., "Canada", "Scotland")
        if let standardizedName = CountryNameMapper.standardizedName(for: code) {
            print("   🌍 Matched long country name '\(code)' → \(standardizedName)")
            event.city = cleanCity
            event.country = standardizedName
            
            // Use forward geocoding to get state and GPS coordinates
            return await forwardGeocodeEvent(city: cleanCity, country: standardizedName, event: &event)
        }
        
        // FOURTH: If code doesn't match state or country, return specific error
        return .error("Unknown code '\(code)' in '\(city)' - not a valid state or country code")
    }
    
    // MARK: - Geocoding Helpers
    
    /// Forward geocode a city and country to get state and GPS coordinates (for Locations)
    private func forwardGeocodeLocation(city: String, country: String, location: inout Location) async -> LocationDataProcessingResult {
        await checkRateLimit()
        
        let query = "\(city), \(country)"
        
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(query)
            guard let placemark = placemarks.first else {
                return .error("Could not find location for '\(query)'")
            }
            
            // Update state
            if let state = placemark.administrativeArea {
                location.state = state
            }
            
            // Update GPS coordinates
            if let clLocation = placemark.location {
                location.latitude = clLocation.coordinate.latitude
                location.longitude = clLocation.coordinate.longitude
            }
            
            return .success
            
        } catch let clError as CLError {
            // Check for rate limiting
            if clError.code == .network || clError.code == .geocodeFoundNoResult {
                if let errorInfo = clError.userInfo["details"] as? [[String: Any]],
                   let timeUntilReset = errorInfo.first?["timeUntilReset"] as? TimeInterval {
                    handleRateLimitError(timeUntilReset)
                    return .retryLater
                }
            }
            return .error(formatCLError(clError, context: query))
        } catch {
            return .error("Forward geocoding failed for '\(query)': \(error.localizedDescription)")
        }
    }
    
    /// Forward geocode a city and country to get state and GPS coordinates (for Events)
    private func forwardGeocodeEvent(city: String, country: String, event: inout Event) async -> LocationDataProcessingResult {
        await checkRateLimit()
        
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
            
        } catch let clError as CLError {
            // Check for rate limiting
            if clError.code == .network || clError.code == .geocodeFoundNoResult {
                if let errorInfo = clError.userInfo["details"] as? [[String: Any]],
                   let timeUntilReset = errorInfo.first?["timeUntilReset"] as? TimeInterval {
                    handleRateLimitError(timeUntilReset)
                    return .retryLater
                }
            }
            return .error(formatCLError(clError, context: query))
        } catch {
            return .error("Forward geocoding failed for '\(query)': \(error.localizedDescription)")
        }
    }
    
    /// Format CLError into human-readable message
    private func formatCLError(_ error: CLError, context: String? = nil) -> String {
        let prefix = context.map { "[\($0)] " } ?? ""
        
        switch error.code {
        case .network:
            return "\(prefix)Network error - check internet connection"
        case .geocodeFoundNoResult:
            return "\(prefix)No location found"
        case .geocodeFoundPartialResult:
            return "\(prefix)Partial result only"
        case .geocodeCanceled:
            return "\(prefix)Geocoding canceled"
        default:
            if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                return "\(prefix)Geocoding error: \(underlying.localizedDescription)"
            }
            return "\(prefix)Geocoding error: \(error.localizedDescription)"
        }
    }
}
