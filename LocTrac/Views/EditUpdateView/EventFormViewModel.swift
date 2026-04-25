import Foundation

class EventFormViewModel: ObservableObject {
    @Published var date = Date()
    @Published var eventType: String = UserDefaults.standard.string(forKey: "defaultEventType") ?? "unspecified"
    @Published var location: Location?
    @Published var city: String?
    @Published var state: String?  // v1.5: State/province
    @Published var country: String?  // v1.5: Country (auto-populated but can be overridden)
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var note = ""
    @Published var showingAlert = false
    var dateSelected: Date?
    var toDateSelected: Date?
    
    @Published var people: [Person] = []
    @Published var activityIDs: [String] = [] // NEW
    @Published var affirmationIDs: [String] = [] // NEW: Affirmations support
    @Published var imageIDs: [String] = [] // v2.0: Event-level photos

    var id: String?
    var updating: Bool { id != nil }

    init() {}

    init(_ event: Event) {
        date = event.date.startOfDay
        eventType = event.eventType
        id = event.id
        location = event.location
        city = event.city
        state = event.state  // v1.5: Load state
        country = event.country  // v1.5: Load country
        latitude = event.latitude
        longitude = event.longitude
        note = event.note
        people = event.people
        activityIDs = event.activityIDs // NEW
        affirmationIDs = event.affirmationIDs // NEW: Load affirmations
        imageIDs = event.imageIDs // v2.0: Load event images
    }

    init(date: Date? = nil,
         eventType: String = "unspecified",
         location: Location? = nil,
         id: String? = nil,
         city: String?,
         state: String? = nil,  // v1.5: State parameter
         country: String? = nil,  // v1.5: Country parameter
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
        self.state = state  // v1.5: Initialize state
        self.country = country  // v1.5: Initialize country
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
    }

    init(dateSelected: Date? = nil, toDateSelected: Date? = nil) {
        self.dateSelected = dateSelected
        self.toDateSelected = toDateSelected
    }

    var incomplete: Bool {
        location == nil
    }
}

