//
//  DefaultLocationHelper.swift
//  LocTrac
//
//  Helper for managing default location preference
//

import Foundation

extension DataStore {
    /// Get the default location ID set by the user
    var defaultLocationID: String? {
        UserDefaults.standard.string(forKey: "defaultLocationID")
    }
    
    /// Get the actual default Location object
    var defaultLocation: Location? {
        guard let defaultID = defaultLocationID else { return nil }
        return locations.first { $0.id == defaultID }
    }
    
    /// Set a location as the default
    func setDefaultLocation(_ location: Location) {
        UserDefaults.standard.set(location.id, forKey: "defaultLocationID")
    }
    
    /// Clear the default location
    func clearDefaultLocation() {
        UserDefaults.standard.removeObject(forKey: "defaultLocationID")
    }
    
    /// Check if a location is the default
    func isDefaultLocation(_ location: Location) -> Bool {
        return defaultLocationID == location.id
    }
}
