//
//  Locations.swift
//  Locations
//
//  Created by Tim Arey on 1/8/23.
//

import Foundation
import SwiftUI

struct Location: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var city: String?
    var latitude: Double
    var longitude: Double
    var country: String?         // NEW: Country field
    var theme: Theme
    var imageIDs: [String]? // optional, absent means no photos
    var customColorHex: String? // NEW: optional custom color (full spectrum)

    init(id: String = UUID().uuidString,
         name: String,
         city: String?,
         latitude: Double,
         longitude: Double,
         country: String? = nil, // NEW: Add country to init
         theme: Theme,
         imageIDs: [String]? = nil,
         customColorHex: String? = nil) { // NEW: Add customColorHex to init
        self.id = id
        self.name = name
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.theme = theme
        self.imageIDs = imageIDs
        self.customColorHex = customColorHex
    }
    
    // NEW: Computed property for effective display color
    var effectiveColor: Color {
        if let hex = customColorHex {
            return Color(hex: hex)
        }
        return theme.mainColor
    }
    
    // NEW: Helper to set custom color from ColorPicker
    mutating func setCustomColor(_ color: Color) {
        self.customColorHex = color.toHex()
    }
}

extension Location {
    static let sampleData: [Location] =
    [
        Location(name: "Loft", city: "Denver",latitude: 39.75331, longitude: 104.99920, country: "United States", theme: .magenta),
        Location(name: "Arrowhead", city: "Edwards", latitude: 39.6329611, longitude: 106.5624717, country: "United States", theme: .purple),
        Location(name: "Cabo", city: "San Jose", latitude: 23.01786, longitude: 109.73016, country: "Mexico", theme: .navy),
        Location(name: "Ravenna", city: "Littleton", latitude: 39.47834, longitude: 105.09497, country: "United States", theme: .purple),
        Location(name: "Other", city: "None", latitude: 39.75331, longitude: 104.99920, country: "United States", theme: .yellow)
    ]
}

// MARK: - Color ↔ Hex Conversion
extension Color {
    /// Initialize a Color from a hex string (e.g., "#FF5733" or "FF5733")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (no alpha)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0) // fallback to black
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Convert this Color to a hex string (e.g., "#FF5733")
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        let r = components[0]
        let g = components[1]
        let b = components[2]
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(Float(r * 255)),
                      lroundf(Float(g * 255)),
                      lroundf(Float(b * 255)))
    }
}
