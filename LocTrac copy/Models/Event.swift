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
    var city: String?
    var latitude: Double
    var longitude: Double
    var country: String? // NEW: Country field for each event
    var note: String
    var people: [Person] = []
    var activityIDs: [String] = [] // NEW: references Activity.id
    
    init(id: String = UUID().uuidString,
         eventType: EventType = .unspecified,
         date: Date,
         location: Location,
         city: String,
         latitude: Double,
         longitude: Double,
         country: String? = nil, // NEW: Country parameter
         note: String,
         people: [Person] = [],
         activityIDs: [String] = []) {
        self.eventType = eventType.rawValue
        self.date = date
        self.id = id
        self.location = location
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.note = note
        self.people = people
        self.activityIDs = activityIDs
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
}

extension Event {
    static let sampleData: [Event] =
    [
        Event(date: Date(),
              location: Location.sampleData[0],
              city: Location.sampleData[0].city ?? "city",
              latitude: Location.sampleData[0].latitude,
              longitude: Location.sampleData[0].longitude,
              note: "Note Field ",
              people: [],
              activityIDs: [])
    ]
}

