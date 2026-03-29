//
//  LocationSheetEditorModel.swift
//  LocTrac
//
//  Editor model for location editing sheet
//

import Foundation
import Combine

final class LocationSheetEditorModel: ObservableObject {
    @Published var name: String
    @Published var city: String
    @Published var country: String
    @Published var latitude: Double
    @Published var longitude: Double
    @Published var selectedTheme: Theme
    @Published var isDefault: Bool
    
    init(location: Location, isDefault: Bool) {
        self.name = location.name
        self.city = location.city ?? ""
        self.country = location.country ?? ""
        self.latitude = location.latitude
        self.longitude = location.longitude
        self.selectedTheme = location.theme
        self.isDefault = isDefault
    }
}
