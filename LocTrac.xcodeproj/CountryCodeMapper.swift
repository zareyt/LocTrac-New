//
//  CountryCodeMapper.swift
//  LocTrac
//
//  Maps ISO 3166-1 alpha-2 country codes to full country names
//

import Foundation

struct CountryCodeMapper {
    // ISO 3166-1 alpha-2 codes
    private static let codes: [String: String] = [
        "US": "United States",
        "CA": "Canada",
        "GB": "United Kingdom",
        "FR": "France",
        "DE": "Germany",
        "IT": "Italy",
        "ES": "Spain",
        "MX": "Mexico",
        "JP": "Japan",
        "CN": "China",
        "AU": "Australia",
        "NZ": "New Zealand",
        "BR": "Brazil",
        "AR": "Argentina",
        "IN": "India",
        "ZA": "South Africa",
        "KR": "South Korea",
        "TH": "Thailand",
        "SG": "Singapore",
        "NL": "Netherlands",
        "BE": "Belgium",
        "CH": "Switzerland",
        "AT": "Austria",
        "SE": "Sweden",
        "NO": "Norway",
        "DK": "Denmark",
        "FI": "Finland",
        "IE": "Ireland",
        "PT": "Portugal",
        "GR": "Greece",
        "PL": "Poland",
        "CZ": "Czech Republic",
        "HU": "Hungary",
        "RO": "Romania",
        "RU": "Russia",
        "TR": "Turkey",
        "EG": "Egypt",
        "IL": "Israel",
        "AE": "United Arab Emirates",
        "SA": "Saudi Arabia",
        "QA": "Qatar",
        "KW": "Kuwait",
        "OM": "Oman",
        "JO": "Jordan",
        "LB": "Lebanon",
        "PH": "Philippines",
        "MY": "Malaysia",
        "ID": "Indonesia",
        "VN": "Vietnam",
        "TW": "Taiwan",
        "HK": "Hong Kong",
        "MO": "Macau",
        "IS": "Iceland",
        "EE": "Estonia",
        "LV": "Latvia",
        "LT": "Lithuania",
        "SK": "Slovakia",
        "SI": "Slovenia",
        "HR": "Croatia",
        "RS": "Serbia",
        "BG": "Bulgaria",
        "UA": "Ukraine",
        "BY": "Belarus",
        "KZ": "Kazakhstan",
        "UZ": "Uzbekistan",
        "AM": "Armenia",
        "GE": "Georgia",
        "AZ": "Azerbaijan"
    ]
    
    /// Get full country name from two-letter ISO code
    /// - Parameter code: Two-letter ISO 3166-1 alpha-2 code (case-insensitive)
    /// - Returns: Full country name, or nil if code is invalid
    static func countryName(for code: String) -> String? {
        codes[code.uppercased()]
    }
    
    /// Check if a code is a valid country code
    /// - Parameter code: Two-letter code to check
    /// - Returns: True if code is valid
    static func isValidCode(_ code: String) -> Bool {
        codes[code.uppercased()] != nil
    }
}
