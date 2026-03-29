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

    init(id: String = UUID().uuidString,
         name: String,
         city: String?,
         latitude: Double,
         longitude: Double,
         country: String? = nil, // NEW: Add country to init
         theme: Theme,
         imageIDs: [String]? = nil) {
        self.id = id
        self.name = name
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.theme = theme
        self.imageIDs = imageIDs
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
