//
//
//  USStateCodeMapper.swift
//  LocTrac
//
//  ✅ CORRECT FILE - KEEP THIS ONE
//  ⏰ Last Updated: 2026-04-12 18:30
//  Maps US state codes (e.g., "CA", "NY") to full state names
//

import Foundation

struct USStateCodeMapper {
    private static let codes: [String: String] = [
        "AL": "Alabama",
        "AK": "Alaska",
        "AZ": "Arizona",
        "AR": "Arkansas",
        "CA": "California",
        "CO": "Colorado",
        "CT": "Connecticut",
        "DE": "Delaware",
        "FL": "Florida",
        "GA": "Georgia",
        "HI": "Hawaii",
        "ID": "Idaho",
        "IL": "Illinois",
        "IN": "Indiana",
        "IA": "Iowa",
        "KS": "Kansas",
        "KY": "Kentucky",
        "LA": "Louisiana",
        "ME": "Maine",
        "MD": "Maryland",
        "MA": "Massachusetts",
        "MI": "Michigan",
        "MN": "Minnesota",
        "MS": "Mississippi",
        "MO": "Missouri",
        "MT": "Montana",
        "NE": "Nebraska",
        "NV": "Nevada",
        "NH": "New Hampshire",
        "NJ": "New Jersey",
        "NM": "New Mexico",
        "NY": "New York",
        "NC": "North Carolina",
        "ND": "North Dakota",
        "OH": "Ohio",
        "OK": "Oklahoma",
        "OR": "Oregon",
        "PA": "Pennsylvania",
        "RI": "Rhode Island",
        "SC": "South Carolina",
        "SD": "South Dakota",
        "TN": "Tennessee",
        "TX": "Texas",
        "UT": "Utah",
        "VT": "Vermont",
        "VA": "Virginia",
        "WA": "Washington",
        "WV": "West Virginia",
        "WI": "Wisconsin",
        "WY": "Wyoming",
        "DC": "District of Columbia"
    ]
    
    /// Get full state name from two-letter code
    /// - Parameter code: Two-letter state code (case-insensitive)
    /// - Returns: Full state name, or nil if code is invalid
    static func stateName(for code: String) -> String? {
        codes[code.uppercased()]
    }
    
    /// Check if a code is a valid US state code
    /// - Parameter code: Two-letter code to check
    /// - Returns: True if code is valid
    static func isValidCode(_ code: String) -> Bool {
        codes[code.uppercased()] != nil
    }
}
