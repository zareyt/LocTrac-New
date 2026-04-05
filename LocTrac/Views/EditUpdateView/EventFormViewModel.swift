import Foundation

class EventFormViewModel: ObservableObject {
    @Published var date = Date()
    @Published var eventType: Event.EventType = Event.EventType.allCases.first ?? .unspecified
    @Published var location: Location?
    @Published var city: String?
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var note = ""
    @Published var showingAlert = false
    var dateSelected: Date?
    
    @Published var people: [Person] = []
    @Published var activityIDs: [String] = [] // NEW
    @Published var affirmationIDs: [String] = [] // NEW: Affirmations support

    var id: String?
    var updating: Bool { id != nil }

    init() {}

    init(_ event: Event) {
        date = event.date.startOfDay
        eventType = Event.EventType(rawValue: event.eventType) ?? .unspecified
        id = event.id
        location = event.location
        city = event.city
        latitude = event.latitude
        longitude = event.longitude
        note = event.note
        people = event.people
        activityIDs = event.activityIDs // NEW
        affirmationIDs = event.affirmationIDs // NEW: Load affirmations
    }

    init(date: Date? = nil,
         eventType: Event.EventType = .unspecified,
         location: Location? = nil,
         id: String? = nil,
         city: String?,
         latitude: Double,
         longitude: Double,
         note: String) {
        if let date = date {
            self.date = date.startOfDay
        }
        self.eventType = eventType
        self.location = location
        self.id = id
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
    }

    init(dateSelected: Date? = nil) {
        self.dateSelected = dateSelected
    }

    var incomplete: Bool {
        location == nil
    }
}

