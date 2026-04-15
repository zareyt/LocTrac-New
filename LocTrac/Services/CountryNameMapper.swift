//
//  CountryNameMapper.swift
//  LocTrac
//
//  Created on 2026-04-13
//  Maps long country names to ISO country codes
//

import Foundation

struct CountryNameMapper {
    
    /// Map a country name (full or partial) to its ISO country code
    /// - Parameter name: Country name (e.g., "Canada", "Scotland", "United Kingdom")
    /// - Returns: ISO country code (e.g., "CA", "GB") or nil if not found
    static func countryCode(for name: String) -> String? {
        let normalized = name.trimmingCharacters(in: .whitespaces).lowercased()
        return countryNameToCode[normalized]
    }
    
    /// Map a country name to its standardized full name
    /// - Parameter name: Country name (e.g., "Canada", "Scotland")
    /// - Returns: Standardized full name or nil if not found
    static func standardizedName(for name: String) -> String? {
        let normalized = name.trimmingCharacters(in: .whitespaces).lowercased()
        return countryNameToStandardized[normalized]
    }
    
    // MARK: - Country Name → ISO Code Mapping
    
    private static let countryNameToCode: [String: String] = [
        // North America
        "canada": "CA",
        "united states": "US",
        "united states of america": "US",
        "usa": "US",
        "mexico": "MX",
        
        // Europe
        "united kingdom": "GB",
        "uk": "GB",
        "great britain": "GB",
        "england": "GB",
        "scotland": "GB",
        "wales": "GB",
        "northern ireland": "GB",
        "ireland": "IE",
        "france": "FR",
        "germany": "DE",
        "italy": "IT",
        "spain": "ES",
        "portugal": "PT",
        "netherlands": "NL",
        "belgium": "BE",
        "switzerland": "CH",
        "austria": "AT",
        "sweden": "SE",
        "norway": "NO",
        "denmark": "DK",
        "finland": "FI",
        "poland": "PL",
        "czech republic": "CZ",
        "czechia": "CZ",
        "greece": "GR",
        "iceland": "IS",
        
        // Asia
        "china": "CN",
        "japan": "JP",
        "south korea": "KR",
        "korea": "KR",
        "india": "IN",
        "thailand": "TH",
        "vietnam": "VN",
        "singapore": "SG",
        "malaysia": "MY",
        "philippines": "PH",
        "indonesia": "ID",
        "taiwan": "TW",
        "hong kong": "HK",
        
        // Oceania
        "australia": "AU",
        "new zealand": "NZ",
        
        // Middle East
        "israel": "IL",
        "united arab emirates": "AE",
        "uae": "AE",
        "saudi arabia": "SA",
        "turkey": "TR",
        
        // South America
        "brazil": "BR",
        "argentina": "AR",
        "chile": "CL",
        "colombia": "CO",
        "peru": "PE",
        
        // Africa
        "south africa": "ZA",
        "egypt": "EG",
        "morocco": "MA",
        "kenya": "KE",
    ]
    
    // MARK: - Country Name → Standardized Name Mapping
    
    private static let countryNameToStandardized: [String: String] = [
        // North America
        "canada": "Canada",
        "united states": "United States",
        "united states of america": "United States",
        "usa": "United States",
        "mexico": "Mexico",
        
        // Europe - UK Components
        "united kingdom": "United Kingdom",
        "uk": "United Kingdom",
        "great britain": "United Kingdom",
        "england": "United Kingdom",
        "scotland": "United Kingdom",
        "wales": "United Kingdom",
        "northern ireland": "United Kingdom",
        
        "ireland": "Ireland",
        "france": "France",
        "germany": "Germany",
        "italy": "Italy",
        "spain": "Spain",
        "portugal": "Portugal",
        "netherlands": "Netherlands",
        "belgium": "Belgium",
        "switzerland": "Switzerland",
        "austria": "Austria",
        "sweden": "Sweden",
        "norway": "Norway",
        "denmark": "Denmark",
        "finland": "Finland",
        "poland": "Poland",
        "czech republic": "Czech Republic",
        "czechia": "Czech Republic",
        "greece": "Greece",
        "iceland": "Iceland",
        
        // Asia
        "china": "China",
        "japan": "Japan",
        "south korea": "South Korea",
        "korea": "South Korea",
        "india": "India",
        "thailand": "Thailand",
        "vietnam": "Vietnam",
        "singapore": "Singapore",
        "malaysia": "Malaysia",
        "philippines": "Philippines",
        "indonesia": "Indonesia",
        "taiwan": "Taiwan",
        "hong kong": "Hong Kong",
        
        // Oceania
        "australia": "Australia",
        "new zealand": "New Zealand",
        
        // Middle East
        "israel": "Israel",
        "united arab emirates": "United Arab Emirates",
        "uae": "United Arab Emirates",
        "saudi arabia": "Saudi Arabia",
        "turkey": "Turkey",
        
        // South America
        "brazil": "Brazil",
        "argentina": "Argentina",
        "chile": "Chile",
        "colombia": "Colombia",
        "peru": "Peru",
        
        // Africa
        "south africa": "South Africa",
        "egypt": "Egypt",
        "morocco": "Morocco",
        "kenya": "Kenya",
    ]
}
