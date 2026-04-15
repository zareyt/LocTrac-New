import Foundation

struct Event: Identifiable {
    enum EventType: String, Identifiable, Codable, CaseIterable {
        case stay, host, vacation, family, business, unspecified
        var id: String { self.rawValue }
        var icon: String {
            switch self {
            case .stay: return "🟥"
            case .host: return "🟦"
            case .vacation: return "🟩"
            case .family: return "🟪"
            case .business: return "🟫"
            case .unspecified: return "🔲"
            }
        }
    }
    
    var eventType: String
    var location: Location
    var id: String
    var date: Date
    var city: String?               // v1.5: City for "Other" location events only
    var latitude: Double            // For "Other" location events only
    var longitude: Double           // For "Other" location events only
    var country: String?            // Keep for backward compat, derive from location
    var state: String?              // v1.5: State/province for "Other" location events
    var note: String
    var people: [Person] = []
    var activityIDs: [String] = [] // references Activity.id
    var affirmationIDs: [String] = [] // references Affirmation.id
    var isGeocoded: Bool = false    // v1.5: Flag to prevent re-geocoding successfully processed events
    
    init(id: String = UUID().uuidString,
         eventType: EventType = .unspecified,
         date: Date,
         location: Location,
         city: String? = nil,       // v1.5: City for "Other" events
         latitude: Double,
         longitude: Double,
         country: String? = nil,
         state: String? = nil,      // v1.5: State/province
         note: String,
         people: [Person] = [],
         activityIDs: [String] = [],
         affirmationIDs: [String] = [],
         isGeocoded: Bool = false) {  // v1.5: Default to false for new events
        self.eventType = eventType.rawValue
        self.date = date
        self.id = id
        self.location = location
        self.city = city            // v1.5
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.state = state          // v1.5
        self.note = note
        self.people = people
        self.activityIDs = activityIDs
        self.affirmationIDs = affirmationIDs
        self.isGeocoded = isGeocoded  // v1.5
    }
    
    var dateComponents: DateComponents {
        var dateComponents = Calendar.current.dateComponents(
            [.month, .day, .year, .hour, .minute],
            from: date)
        dateComponents.timeZone = TimeZone.current
        dateComponents.calendar = Calendar(identifier: .gregorian)
        return dateComponents
    }
}

extension Event {
    func getLocationIndex(locations: [Location], location: Location) -> Int? {
        return locations.firstIndex { $0.id == location.id }
    }
    
    /// Get effective coordinates based on location type
    /// - Named locations: Use location's coordinates
    /// - "Other" location: Use event's own coordinates
    var effectiveCoordinates: (latitude: Double, longitude: Double) {
        if location.name == "Other" {
            // For "Other", use event's own coordinates
            return (latitude: latitude, longitude: longitude)
        } else {
            // For named locations, use the location's coordinates
            return (latitude: location.latitude, longitude: location.longitude)
        }
    }
    
    // v1.5: Computed property for effective city
    var effectiveCity: String? {
        if location.name == "Other" {
            return city  // Use event-specific city for "Other"
        } else {
            return location.city  // Use location's city for named locations
        }
    }
    
    // v1.5: Computed property for effective state
    var effectiveState: String? {
        if location.name == "Other" {
            return state  // Use event-specific state for "Other"
        } else {
            return location.state  // Use location's state for named locations
        }
    }
    
    // v1.5: Computed property for effective country
    var effectiveCountry: String? {
        if location.name == "Other" {
            return country  // Use event-specific country for "Other"
        } else {
            return location.country  // Use location's country for named locations
        }
    }
    
    // v1.5: Full address for event display
    var effectiveAddress: String {
        if location.name == "Other" {
            var components: [String] = []
            if let city = city { components.append(city) }
            if let state = state { components.append(state) }
            if let country = country { components.append(country) }
            return components.isEmpty ? "Other" : components.joined(separator: ", ")
        } else {
            return location.shortAddress
        }
    }
    
    // v1.5: Short address (city, state only)
    var effectiveShortAddress: String {
        if location.name == "Other" {
            var components: [String] = []
            if let city = city { components.append(city) }
            if let state = state { components.append(state) }
            return components.isEmpty ? "Other" : components.joined(separator: ", ")
        } else {
            return location.shortAddress
        }
    }
}

extension Event {
    static let sampleData: [Event] =
    [
        Event(date: Date(),
              location: Location.sampleData[0],
              city: Location.sampleData[0].city,
              latitude: Location.sampleData[0].latitude,
              longitude: Location.sampleData[0].longitude,
              country: Location.sampleData[0].country,
              state: Location.sampleData[0].state,
              note: "Note Field ",
              people: [],
              activityIDs: [],
              affirmationIDs: [])
    ]
}

