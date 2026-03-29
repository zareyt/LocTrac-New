//
//  LocationFormViewModel.swift
//  Locations
//
//  Created by Tim Arey on 2/1/23.
//

import Foundation

class LocationFormViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var city: String = ""
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var country: String = "" // NEW: Country field
    @Published var date: [Date] = []
    @Published var theme: Theme = .navy

    var id: String?
    var updating: Bool { id != nil }

    
    init() {}


    init(_ location: Location) {
        name = location.name
        city = location.city ?? "none"
        latitude = location.latitude
        longitude = location.longitude
        country = location.country ?? "" // NEW: Load country
        id = location.id
        theme = location.theme
    }

}
