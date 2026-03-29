import CoreLocation

enum ReverseGeocoder {
    static let shared = CLGeocoder()
    
    static func cityString(from location: CLLocation, format: Format = .cityState) async throws -> String? {
        let placemarks: [CLPlacemark] = try await shared.reverseGeocodeLocation(location)
        guard let pm = placemarks.first else { return nil }
        
        switch format {
        case .cityOnly:
            return pm.locality
        case .cityState:
            if let city = pm.locality, !city.isEmpty {
                if let state = pm.administrativeArea, !state.isEmpty {
                    return "\(city), \(state)"
                } else {
                    return city
                }
            }
            return nil
        case .full:
            let parts: [String] = [
                pm.locality,
                pm.administrativeArea,
                pm.country
            ].compactMap { $0 }
             .filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        }
    }
    
    enum Format { case cityOnly, cityState, full }
}
