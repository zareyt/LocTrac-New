//
//  LocationFormViewModel.swift
//  Locations
//
//  Created by Tim Arey on 2/1/23.
//

import Foundation
import SwiftUI

class LocationFormViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var city: String = ""
    @Published var state: String = ""        // v1.5: State/province
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var country: String = "" // NEW: Country field
    @Published var date: [Date] = []
    @Published var theme: Theme = .navy
    @Published var customColorHex: String? // NEW: optional custom color

    var id: String?
    var updating: Bool { id != nil }

    
    init() {}


    init(_ location: Location) {
        name = location.name
        city = location.city ?? "none"
        state = location.state ?? ""         // v1.5: Load state
        latitude = location.latitude
        longitude = location.longitude
        country = location.country ?? "" // NEW: Load country
        id = location.id
        theme = location.theme
        customColorHex = location.customColorHex // NEW: Load custom color
    }
    
    // NEW: Computed property for effective display color
    var effectiveColor: Color {
        if let hex = customColorHex {
            return Color(hex: hex)
        }
        return theme.mainColor
    }
}
