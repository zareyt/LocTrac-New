import CoreLocation

enum ReverseGeocoderHelper {
    static let shared = CLGeocoder()
    
    static func countryString(latitude: Double, longitude: Double) async throws -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let placemarks = try await shared.reverseGeocodeLocation(location)
        return placemarks.first?.country
    }
}
