//
//  DataStore.swift
//  LocTrac
//
//  Created by Tim Arey on 3/2/23.
//

import Foundation
import CoreLocation

class DataStore: ObservableObject {
    @Published var locations: [Location] = []
    @Published var events: [Event] = []
    @Published var activities: [Activity] = [] // NEW: global list of activities
    @Published var affirmations: [Affirmation] = [] // NEW: global list of affirmations
    @Published var trips: [Trip] = [] // NEW: travel trips between locations
    @Published var eventTypes: [EventTypeItem] = [] // v2.0: user-manageable event types
    @Published var exerciseEntries: [ExerciseEntry] = [] // v2.1: HealthKit exercise data
    @Published var cars: [Car] = [] // v2.1: User vehicles for environmental impact
    @Published var preview: Bool = false
    @Published var changedEvent: Event?
    @Published var movedEvent: Event?
    @Published var changedLocation: Location?
    @Published var movedLocation: Location?
    @Published var tabSelection = 1
    
    // NEW: Trip confirmation
    @Published var pendingTrip: (trip: Trip, fromEvent: Event, toEvent: Event)?
    
    // NEW: Update tracking for infographics optimization
    @Published var dataUpdateToken = UUID()

    // Token to trigger full calendar refresh for the currently visible month
    @Published var calendarRefreshToken = UUID()
    func bumpCalendarRefresh() { calendarRefreshToken = UUID() }
    
    // Bump data update token when relevant data changes
    func bumpDataUpdate() { dataUpdateToken = UUID() }
    
    // NEW: Update stay reminders when events change
    func updateStayReminders() {
        Task {
            await NotificationManager.shared.scheduleStayReminder(for: self)
        }
    }
    
    // Check if this is the first launch
    var isFirstLaunch: Bool {
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedFirstLaunch")
        let backupExists = FileManager.default.fileExists(
            atPath: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first!.appendingPathComponent("backup.json").path
        )
        return !hasCompleted && !backupExists
    }
    
    init() {
        loadData()
    }
    
    init(preview: Bool = false) {
        loadData()
    }
    
    func delete(_ location: Location) {
        // Clean up associated image files from disk
        if let imageIDs = location.imageIDs, !imageIDs.isEmpty {
            for imageID in imageIDs {
                ImageStore.delete(filename: imageID)
            }
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.dataStore, "📸 [Delete Location] Cleaned up \(imageIDs.count) image(s) for '\(location.name)'")
            }
            #endif
        }
        if let index = locations.firstIndex(where: {$0.id == location.id}) {
            changedLocation = locations.remove(at: index)
        }
        storeData()
    }
    
    func delete(_ event: Event) {
        #if DEBUG
        Task { @MainActor in
            DebugConfig.shared.log(.dataStore, "delete(Event) called for id=\(event.id)")
        }
        #endif
        // Clean up associated image files from disk
        if !event.imageIDs.isEmpty {
            for imageID in event.imageIDs {
                ImageStore.delete(filename: imageID)
            }
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.dataStore, "📸 [Delete Event] Cleaned up \(event.imageIDs.count) image(s) for event on \(event.date.utcMediumDateString)")
            }
            #endif
        }
        if let index = events.firstIndex(where: {$0.id == event.id}) {
            changedEvent = events.remove(at: index)
            invalidateCacheForEvent(event, isDelete: true)
            
            // Check if this event's deletion affects any trips
            checkAndUpdateTripsForDeletedEvent(event)
        } else {
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.dataStore, "delete(Event): event not found in store")
            }
            #endif
        }
        storeData()
        
        // NEW: Force calendar refresh after deleting event
        bumpCalendarRefresh()
        
        // NEW: Update stay reminders after deleting event
        updateStayReminders()
    }
    
    func add(_ location: Location) {
        locations.append(location)
        changedLocation = location
        storeData()
    }

    func add(_ event: Event) {
        #if DEBUG
        Task { @MainActor in
            DebugConfig.shared.log(.dataStore, "add(Event) called for id=\(event.id), date=\(event.date), location='\(event.location.name)'")
        }
        #endif
        events.append(event)
        changedEvent = event
        
        // Check if this new event creates a trip from the previous day
        checkAndCreateTripForNewEvent(event)
        
        storeData()
        invalidateCacheForEvent(event)
        
        // NEW: Force calendar refresh after adding event
        bumpCalendarRefresh()
        
        // NEW: Update stay reminders after adding event
        updateStayReminders()
    }

    func update(_ location: Location) {
        #if DEBUG
        Task { @MainActor in
            DebugConfig.shared.log(.dataStore, "========== LOCATION UPDATE START ==========")
            DebugConfig.shared.log(.dataStore, "Updating location: \(location.name)")
            DebugConfig.shared.log(.dataStore, "Location ID: \(location.id)")
            DebugConfig.shared.log(.dataStore, "New theme: \(location.theme.rawValue)")
            DebugConfig.shared.log(.dataStore, "New customColorHex: \(location.customColorHex ?? "nil")")
        }
        #endif
        
        if let index = locations.firstIndex(where: {$0.id == location.id}) {
            #if DEBUG
            let oldTheme = locations[index].theme.rawValue
            let oldColorHex = locations[index].customColorHex
            Task { @MainActor in
                DebugConfig.shared.log(.dataStore, "Found location at index \(index) in locations array")
            }
            #endif
            
            movedLocation = locations[index]
            locations[index].name = location.name
            locations[index].city = location.city
            locations[index].state = location.state  // v1.5: Update state
            locations[index].latitude = location.latitude
            locations[index].longitude = location.longitude
            locations[index].country = location.country
            locations[index].countryCode = location.countryCode  // v1.5: Update country code
            locations[index].theme = location.theme
            locations[index].imageIDs = location.imageIDs
            locations[index].customColorHex = location.customColorHex // NEW: Update custom color
            locations[index].isGeocoded = location.isGeocoded // v2.0: Preserve geocoded flag
            changedLocation = location
            
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.dataStore, "Location updated in array:")
                DebugConfig.shared.log(.dataStore, "  Old theme: \(oldTheme) → New theme: \(locations[index].theme.rawValue)")
                DebugConfig.shared.log(.dataStore, "  Old colorHex: \(oldColorHex ?? "nil") → New colorHex: \(locations[index].customColorHex ?? "nil")")
            }
            #endif
            
            invalidateCacheForLocation(location)
            
            // CRITICAL: Update all events that reference this location
            // Events store a copy of the location, so we need to update them too
            let updatedLocation = locations[index]
            
            #if DEBUG
            var eventsUpdated = 0
            Task { @MainActor in
                DebugConfig.shared.log(.dataStore, "Searching for events with location ID: \(location.id)")
                DebugConfig.shared.log(.dataStore, "Total events in store: \(events.count)")
            }
            #endif
            
            for i in events.indices {
                if events[i].location.id == location.id {
                    #if DEBUG
                    let oldEventLocationTheme = events[i].location.theme.rawValue
                    let oldEventLocationColorHex = events[i].location.customColorHex
                    #endif
                    
                    events[i].location = updatedLocation
                    
                    #if DEBUG
                    eventsUpdated += 1
                    let eventID = events[i].id
                    let eventDate = events[i].date.utcMediumDateString
                    let newTheme = events[i].location.theme.rawValue
                    let newColorHex = events[i].location.customColorHex
                    Task { @MainActor in
                        DebugConfig.shared.log(.dataStore, "Updated event \(i): \(eventID)")
                        DebugConfig.shared.log(.dataStore, "  Event date: \(eventDate)")
                        DebugConfig.shared.log(.dataStore, "  Old location theme: \(oldEventLocationTheme)")
                        DebugConfig.shared.log(.dataStore, "  New location theme: \(newTheme)")
                        DebugConfig.shared.log(.dataStore, "  Old location colorHex: \(oldEventLocationColorHex ?? "nil")")
                        DebugConfig.shared.log(.dataStore, "  New location colorHex: \(newColorHex ?? "nil")")
                    }
                    #endif
                }
            }
            
            #if DEBUG
            let finalEventsUpdated = eventsUpdated
            let finalCalendarToken = UUID()
            Task { @MainActor in
                DebugConfig.shared.log(.dataStore, "Total events updated: \(finalEventsUpdated)")
                DebugConfig.shared.log(.dataStore, "Calling bumpCalendarRefresh()")
            }
            #endif
            bumpCalendarRefresh()
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.dataStore, "Calendar refresh token bumped to: \(calendarRefreshToken)")
                DebugConfig.shared.log(.dataStore, "Calling bumpDataUpdate()")
            }
            #endif
            bumpDataUpdate()
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.dataStore, "Data update token bumped to: \(dataUpdateToken)")
            }
            #endif
        } else {
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.dataStore, "Location not found in locations array!")
            }
            #endif
        }
        
        #if DEBUG
        Task { @MainActor in
            DebugConfig.shared.log(.dataStore, "Saving data to disk...")
        }
        #endif
        storeData()
        #if DEBUG
        Task { @MainActor in
            DebugConfig.shared.log(.dataStore, "========== LOCATION UPDATE END ==========")
        }
        #endif
    }
    
    func update(_ event: Event) {
        if let index = events.firstIndex(where: {$0.id == event.id}) {
            movedEvent = events[index]
            events[index].date = event.date
            events[index].eventType = event.eventType
            events[index].location = event.location
            events[index].city = event.city        // v1.5: Update city
            events[index].latitude = event.latitude
            events[index].longitude = event.longitude
            events[index].country = event.country
            events[index].state = event.state  // v1.5: Update state
            events[index].note = event.note
            events[index].people = event.people
            events[index].activityIDs = event.activityIDs
            events[index].affirmationIDs = event.affirmationIDs
            events[index].isGeocoded = event.isGeocoded
            events[index].imageIDs = event.imageIDs
            changedEvent = event
            storeData()
            invalidateCacheForEvent(event)
            
            // NEW: Force calendar refresh after updating event
            bumpCalendarRefresh()
            
            // NEW: Update stay reminders after updating event
            updateStayReminders()
        }
    }

    func eventCount(_ location: Location, events: [Event]) -> Int {
        events.filter { $0.location.id == location.id }.count
    }

    func eventPercentByLocation(_ location: Location, events: [Event]) -> (percent: Float, count: Int) {
        let locationEvents = events.filter { $0.location.id == location.id }
        guard !events.isEmpty else { return (0, 0) }
        let totalCount = locationEvents.count
        let per = Float(totalCount) / Float(events.count)
        let roundedPer = (per * 100).rounded() / 100
        return (roundedPer, totalCount)
    }
    
    // MARK: - Activities CRUD
    
    func addActivity(_ activity: Activity) {
        activities.append(activity)
        storeData()
    }
    
    func updateActivity(_ activity: Activity) {
        if let idx = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[idx] = activity
            storeData()
            invalidateCacheForActivity(activity)
        }
    }
    
    func deleteActivity(_ activity: Activity) {
        // Remove activity from global list
        activities.removeAll { $0.id == activity.id }
        // Also remove from any events that reference it
        for i in events.indices {
            events[i].activityIDs.removeAll { $0 == activity.id }
        }
        storeData()
        invalidateCacheForActivity(activity)
    }
    
    // MARK: - Event Types CRUD

    func addEventType(_ eventType: EventTypeItem) {
        eventTypes.append(eventType)
        storeData()
    }

    func updateEventType(_ eventType: EventTypeItem) {
        if let idx = eventTypes.firstIndex(where: { $0.id == eventType.id }) {
            let oldName = eventTypes[idx].name
            eventTypes[idx] = eventType
            // If the name changed, update all events that reference the old name
            if oldName != eventType.name {
                for i in events.indices {
                    if events[i].eventType == oldName {
                        events[i].eventType = eventType.name
                    }
                }
            }
            storeData()
        }
    }

    func deleteEventType(_ eventType: EventTypeItem) {
        guard !eventType.isBuiltIn else { return } // Prevent deleting built-in types
        eventTypes.removeAll { $0.id == eventType.id }
        // Reset events using this type to "unspecified"
        for i in events.indices {
            if events[i].eventType == eventType.name {
                events[i].eventType = "unspecified"
            }
        }
        storeData()
    }

    /// Look up a stored EventTypeItem by its raw name, falling back to built-in defaults
    func eventTypeItem(for rawValue: String) -> EventTypeItem {
        if let stored = eventTypes.first(where: { $0.name == rawValue }) {
            return stored
        }
        // Fallback to built-in defaults
        if let builtIn = EventTypeItem.defaults.first(where: { $0.name == rawValue }) {
            return builtIn
        }
        // Ultimate fallback
        return EventTypeItem(name: rawValue, displayName: rawValue.capitalized, sfSymbol: "questionmark.circle", colorName: "gray")
    }

    private func seedDefaultEventTypes() {
        self.eventTypes = EventTypeItem.defaults
        storeData()
    }

    // MARK: - Affirmations CRUD
    
    func addAffirmation(_ affirmation: Affirmation) {
        affirmations.append(affirmation)
        storeData()
    }
    
    func updateAffirmation(_ affirmation: Affirmation) {
        if let idx = affirmations.firstIndex(where: { $0.id == affirmation.id }) {
            affirmations[idx] = affirmation
            storeData()
        }
    }
    
    func deleteAffirmation(_ affirmation: Affirmation) {
        // Remove affirmation from global list
        affirmations.removeAll { $0.id == affirmation.id }
        // Also remove from any events that reference it
        for i in events.indices {
            events[i].affirmationIDs.removeAll { $0 == affirmation.id }
        }
        storeData()
    }
    
    func toggleFavorite(_ affirmation: Affirmation) {
        if let idx = affirmations.firstIndex(where: { $0.id == affirmation.id }) {
            affirmations[idx].isFavorite.toggle()
            storeData()
        }
    }
    
    // Load preset affirmations on first launch
    func seedDefaultAffirmations() {
        if affirmations.isEmpty {
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.dataStore, "Seeding default affirmations")
            }
            #endif
            affirmations = Affirmation.presets
            storeData()
        }
    }
    
    // MARK: - Persistence
    
    func storeData() -> Void {
        let export = Export(locations: self.locations, events: self.events, activities: self.activities, affirmations: self.affirmations, trips: self.trips, eventTypes: self.eventTypes, exerciseEntries: self.exerciseEntries, cars: self.cars)
        
        #if DEBUG
        // Debug: Check affirmation IDs in events before export
        let eventsWithAffirmations = self.events.filter { !$0.affirmationIDs.isEmpty }
        Task { @MainActor in
            DebugConfig.shared.log(.persistence, "Events with affirmations: \(eventsWithAffirmations.count) out of \(self.events.count) total")
            if let firstWithAffirmations = eventsWithAffirmations.first {
                DebugConfig.shared.log(.persistence, "  Example: Event '\(firstWithAffirmations.location.name)' has \(firstWithAffirmations.affirmationIDs.count) affirmation IDs")
            }
        }
        #endif
        
        do {
            let encodedData = try JSONEncoder().encode(export)
            if let filepath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("backup.json") {
                do {
                    try encodedData.write(to: filepath)
                    #if DEBUG
                    Task { @MainActor in
                        DebugConfig.shared.log(.persistence, "Data saved to: \(filepath.path)")
                        DebugConfig.shared.log(.persistence, "Data saved successfully")
                    }
                    #endif
                    bumpDataUpdate() // Notify that data has changed
                    updateWidgetData() // Write snapshot for widgets
                } catch {
                    #if DEBUG
                    Task { @MainActor in
                        DebugConfig.shared.log(.persistence, "Error: \(error.localizedDescription)")
                        DebugConfig.shared.log(.persistence, "Could not save data")
                    }
                    #endif
                }
            } else {
                #if DEBUG
                Task { @MainActor in
                    DebugConfig.shared.log(.persistence, "Could not create filepath")
                }
                #endif
            }
        } catch {
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.persistence, "Error: \(error.localizedDescription)")
                DebugConfig.shared.log(.persistence, "Could not encode data")
            }
            #endif
        }
    }

    func loadData() {
        let backupURL = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("backup.json")
        
        // Check if backup.json exists
        if !FileManager().fileExists(atPath: backupURL.path) {
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.persistence, "No backup.json found - this appears to be first launch")
                DebugConfig.shared.log(.persistence, "Initializing with empty data for wizard")
            }
            #endif
            // Initialize with empty data - wizard will populate
            self.locations = []
            self.events = []
            self.activities = []
            self.affirmations = []
            self.exerciseEntries = []
            // Ensure "Other" exists even before wizard completes (for any flows that expect it)
            ensureOtherLocationExists(saveIfAdded: false) // don't immediately persist; wizard completion will save
            return
        }
        
        #if DEBUG
        Task { @MainActor in
            DebugConfig.shared.log(.persistence, "Loading from backup.json")
        }
        #endif
        loadFromURL(backupURL)
        
        // Repair older backups that might be missing the "Other" location
        ensureOtherLocationExists(saveIfAdded: true)
    }
    
    private func loadFromURL(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.persistence, "Unable to load data from \(url)")
            }
            #endif
            // Initialize with empty data rather than crashing
            self.locations = []
            self.events = []
            self.activities = []
            self.affirmations = []
            self.exerciseEntries = []
            // Ensure "Other" exists in empty state
            ensureOtherLocationExists(saveIfAdded: false)
            return
        }

        guard let decodedImport = try? JSONDecoder().decode(Import.self, from: data) else {
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.persistence, "Failed to decode JSON from \(url)")
            }
            #endif
            // Initialize with empty data rather than crashing
            self.locations = []
            self.events = []
            self.activities = []
            self.affirmations = []
            self.exerciseEntries = []
            // Ensure "Other" exists in empty state
            ensureOtherLocationExists(saveIfAdded: false)
            return
        }
        self.locations = decodedImport.locations.map({ location in
            Location(id: location.id,
                     name: location.name,
                     city: location.city,
                     state: location.state,        // v1.5
                     latitude: location.latitude,
                     longitude: location.longitude,
                     country: location.country,
                     countryCode: location.countryCode, // v1.5
                     theme: Theme(rawValue: location.theme) ?? .purple,
                     imageIDs: location.imageIDs,
                     customColorHex: location.customColorHex)
        })
        self.events = decodedImport.events.map({ event in
            Event(id: event.id,
                  eventType: Event.EventType(rawValue: event.eventType) ?? .unspecified,
                  date: event.date,
                  location: locations.first(where: {$0.id == event.locationID}) ?? Location(
                      name: "Unknown",
                      city: "Unknown",
                      state: nil,
                      latitude: 0,
                      longitude: 0,
                      country: nil,
                      countryCode: nil,
                      theme: .purple
                  ),
                  city: event.city,             // v1.5: Load city for "Other" events
                  latitude: event.latitude,
                  longitude: event.longitude,
                  country: event.country,
                  state: event.state,  // v1.5: Load state if available
                  note: event.note,
                  people: event.people ?? [],
                  activityIDs: event.activityIDs ?? [],
                  affirmationIDs: event.affirmationIDs ?? [],
                  imageIDs: event.imageIDs ?? [])
        })
        // Activities may or may not be present in older seeds; seed defaults if empty
        if let importedActivities = decodedImport.activities {
            self.activities = importedActivities.map { Activity(id: $0.id, name: $0.name) }
        } else {
            self.activities = []
        }
        
        // Affirmations may or may not be present in older backups
        if let importedAffirmations = decodedImport.affirmations {
            self.affirmations = importedAffirmations.map {
                Affirmation(
                    id: $0.id,
                    text: $0.text,
                    category: Affirmation.Category(rawValue: $0.category) ?? .custom,
                    createdDate: $0.createdDate,
                    color: $0.color,
                    isFavorite: $0.isFavorite
                )
            }
        } else {
            self.affirmations = []
        }
        
        // Trips may or may not be present in older backups
        if let importedTrips = decodedImport.trips {
            self.trips = importedTrips.map { tripData in
                Trip(
                    id: tripData.id,
                    fromEventID: tripData.fromEventID,
                    toEventID: tripData.toEventID,
                    departureDate: tripData.departureDate,
                    arrivalDate: tripData.arrivalDate,
                    distance: tripData.distance,
                    transportMode: Trip.TransportMode(rawValue: tripData.transportMode) ?? .other,
                    co2Emissions: tripData.co2Emissions,
                    notes: tripData.notes,
                    isAutoGenerated: tripData.isAutoGenerated,
                    carID: tripData.carID
                )
            }
            print("✅ Loaded Trips: \(trips.count)")
        } else {
            self.trips = []
            print("📝 No trips in backup - will run migration if needed")
        }
        
        // Event types — optional in older backups, seed defaults if missing
        if let importedEventTypes = decodedImport.eventTypes {
            self.eventTypes = importedEventTypes.map {
                EventTypeItem(id: $0.id, name: $0.name, displayName: $0.displayName, sfSymbol: $0.sfSymbol, colorName: $0.colorName, isBuiltIn: $0.isBuiltIn)
            }
        } else {
            self.eventTypes = []
        }

        if self.eventTypes.isEmpty {
            seedDefaultEventTypes()
        }

        // Exercise entries — v2.1 optional for backward compat
        if let importedExercise = decodedImport.exerciseEntries {
            self.exerciseEntries = importedExercise.map {
                ExerciseEntry(
                    id: $0.id,
                    date: $0.date,
                    workoutType: ExerciseEntry.WorkoutType(rawValue: $0.workoutType) ?? .otherWorkout,
                    durationMinutes: $0.durationMinutes,
                    distanceMiles: $0.distanceMiles,
                    caloriesBurned: $0.caloriesBurned,
                    sourceWorkoutID: $0.sourceWorkoutID
                )
            }
        } else {
            self.exerciseEntries = []
        }

        // Cars — v2.1 optional for backward compat
        if let importedCars = decodedImport.cars {
            self.cars = importedCars.map {
                Car(
                    id: $0.id,
                    name: $0.name,
                    year: $0.year,
                    make: $0.make,
                    model: $0.model,
                    fuelType: Car.FuelType(rawValue: $0.fuelType) ?? .gas,
                    mpg: $0.mpg,
                    kWhPer100Miles: $0.kWhPer100Miles,
                    co2PerMileOverride: $0.co2PerMileOverride,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    isDefault: $0.isDefault,
                    notes: $0.notes
                )
            }
        } else {
            self.cars = []
        }

        if self.activities.isEmpty {
            seedDefaultActivities()
        }

        if self.affirmations.isEmpty {
            seedDefaultAffirmations()
        }

        // Run trip migration if no trips exist and we have events
        if self.trips.isEmpty && self.events.count > 1 {
            print("🚗 Running trip migration...")
            runTripMigration()
        }

        print("✅ Loaded Locations: \(locations.count)")
        print("✅ Loaded Events: \(events.count)")
        print("✅ Loaded Activities: \(activities.count)")
        print("✅ Loaded Affirmations: \(affirmations.count)")
        print("✅ Loaded Trips: \(trips.count)")
        print("✅ Loaded Exercise Entries: \(exerciseEntries.count)")
        print("✅ Loaded Cars: \(cars.count)")
        
        // MIGRATION COMMENTED OUT: Country data has been migrated.
        // Uncomment if you need to re-run migration.
        // Task { @MainActor in
        //     await self.migrateCountriesIfNeeded()
        // }
    }
    
    private func seedDefaultActivities() {
        let defaults = ["Golfing", "Skiing", "Biking", "Yoga", "Exercise", "Pickleball"]
        self.activities = defaults.map { Activity(name: $0) }
        storeData()
    }
    
    // MARK: - Trip Migration
    
    /// Migrate existing events to create trips
    private func runTripMigration() {
        let migratedTrips = TripMigrationUtility.migrateEventsToTrips(events: self.events)
        self.trips = migratedTrips
        storeData()
        print("✅ Migration complete: Created \(migratedTrips.count) trips")
    }
    
    /// Add a trip to the data store
    func addTrip(_ trip: Trip) {
        print("🛫 addTrip called: \(trip.fromEventID) → \(trip.toEventID), mode=\(trip.mode.rawValue), notes='\(trip.notes)'")
        trips.append(trip)
        storeData()
    }
    
    /// Delete a trip from the data store
    func deleteTrip(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        storeData()
    }
    
    /// Convenience method to save data (alias for storeData)
    func save() {
        storeData()
    }

    // MARK: - Exercise Entries (v2.1 HealthKit)

    func addExerciseEntry(_ entry: ExerciseEntry) {
        exerciseEntries.append(entry)
        storeData()
        #if DEBUG
        Task { @MainActor in
            DebugConfig.shared.log(.healthKit, "Added exercise: \(entry.workoutType.displayName) on \(entry.date.utcMediumDateString)")
        }
        #endif
    }

    func deleteExerciseEntry(_ entry: ExerciseEntry) {
        exerciseEntries.removeAll { $0.id == entry.id }
        storeData()
        #if DEBUG
        Task { @MainActor in
            DebugConfig.shared.log(.healthKit, "Deleted exercise entry: \(entry.id)")
        }
        #endif
    }

    func deleteExerciseEntries(for date: Date) {
        exerciseEntries.removeAll { $0.date.startOfDay == date.startOfDay }
        storeData()
    }

    /// Exercise entries for a specific date
    func exerciseEntries(for date: Date) -> [ExerciseEntry] {
        exerciseEntries.filter { $0.date.startOfDay == date.startOfDay }
    }

    // MARK: - Cars (v2.1 Environmental Factors)

    func addCar(_ car: Car) {
        var newCar = car
        // If marking as default, clear other defaults
        if newCar.isDefault {
            for i in cars.indices { cars[i].isDefault = false }
        }
        cars.append(newCar)
        storeData()
        #if DEBUG
        Task { @MainActor in
            DebugConfig.shared.log(.dataStore, "Added car: \(newCar.name) (\(newCar.fuelType.displayName), \(newCar.formattedCO2PerMile))")
        }
        #endif
    }

    func updateCar(_ car: Car) {
        guard let idx = cars.firstIndex(where: { $0.id == car.id }) else { return }
        // If marking as default, clear other defaults
        if car.isDefault {
            for i in cars.indices { cars[i].isDefault = false }
        }
        cars[idx] = car
        storeData()
        #if DEBUG
        Task { @MainActor in
            DebugConfig.shared.log(.dataStore, "Updated car: \(car.name)")
        }
        #endif
    }

    func deleteCar(_ car: Car) {
        cars.removeAll { $0.id == car.id }
        storeData()
        #if DEBUG
        Task { @MainActor in
            DebugConfig.shared.log(.dataStore, "Deleted car: \(car.name)")
        }
        #endif
    }

    /// Find the car that applies to a trip based on carID, date range, or default
    func carForTrip(_ trip: Trip) -> Car? {
        // 1. If trip has explicit carID, use that
        if let carID = trip.carID, let car = cars.first(where: { $0.id == carID }) {
            return car
        }
        // 2. Find cars whose date range covers the trip departure date
        let candidates = cars.filter { $0.coversDate(trip.departureDate) }
        // 3. Prefer the default car among candidates
        if let defaultCar = candidates.first(where: { $0.isDefault }) {
            return defaultCar
        }
        // 4. Return first matching candidate
        return candidates.first
    }

    /// The current default car (isDefault flag)
    var defaultCar: Car? {
        cars.first(where: { $0.isDefault })
    }

    /// Recalculate CO2 for all driving trips using car-specific rates
    func recalculateDrivingTripsCO2() {
        var count = 0
        for i in trips.indices {
            guard trips[i].mode == .driving else { continue }
            if let car = carForTrip(trips[i]) {
                trips[i].co2Emissions = trips[i].distance * car.co2PerMile
            } else {
                // No car found, use default rate
                trips[i].co2Emissions = trips[i].distance * Trip.TransportMode.driving.co2PerMile
            }
            trips[i].modifiedAt = Date()
            count += 1
        }
        if count > 0 {
            storeData()
            #if DEBUG
            Task { @MainActor in
                DebugConfig.shared.log(.dataStore, "Recalculated CO2 for \(count) driving trips")
            }
            #endif
        }
    }

    // MARK: - Widget Data

    /// Compute and write a lightweight snapshot for widget display.
    /// Called automatically after each successful save.
    func updateWidgetData() {
        let now = Date()
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let currentYear = utcCal.component(.year, from: now)

        // Travel stats
        let allCountries = Set(
            events.compactMap { $0.effectiveCountry }.filter { !$0.isEmpty }
        )
        let allCities = Set(
            events.compactMap { $0.effectiveCity }.filter { !$0.isEmpty }
        )
        let thisYearEvents = events.filter {
            utcCal.component(.year, from: $0.date) == currentYear
        }
        let homeLocationNames = Set(["Home", "Loft"]) // common home names
        let daysAway = thisYearEvents.filter {
            !homeLocationNames.contains($0.location.name)
        }.count

        // Top countries (top 3)
        let countryGroups = Dictionary(grouping: events) { $0.effectiveCountry ?? "Unknown" }
        let topCountries = countryGroups
            .map { WidgetData.CountryStat(name: $0.key, stayCount: $0.value.count) }
            .sorted { $0.stayCount > $1.stayCount }
            .prefix(3)

        // Most recent event location
        let recentLocation = events.sorted { $0.date > $1.date }.first?.location.name

        // Trip stats this year
        let yearTrips = trips.filter { utcCal.component(.year, from: $0.departureDate) == currentYear }
        let totalMiles = trips.reduce(0.0) { $0 + $1.distance }

        // Exercise stats — this week
        let weekStart = utcCal.date(from: utcCal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let weekEntries = exerciseEntries.filter { $0.date >= weekStart }
        let activeMinutes = weekEntries.reduce(0.0) { $0 + $1.durationMinutes }
        let activeDays = Set(weekEntries.map { $0.date.startOfDay }).count
        let weekCalories = weekEntries.reduce(0.0) { $0 + ($1.caloriesBurned ?? 0) }
        let topType = Dictionary(grouping: weekEntries, by: { $0.workoutType })
            .max(by: { $0.value.count < $1.value.count })?
            .key.displayName

        // Environment stats
        let cyclingMiles = exerciseEntries
            .filter { $0.workoutType == .cycling }
            .reduce(0.0) { $0 + ($1.distanceMiles ?? 0) }
        let co2Saved = cyclingMiles * ExerciseSummary.co2PerMile

        let monthStart = utcCal.date(from: utcCal.dateComponents([.year, .month], from: now)) ?? now
        let monthDrivingTrips = trips.filter {
            $0.mode == .driving && $0.departureDate >= monthStart
        }
        let drivingCO2 = monthDrivingTrips.reduce(0.0) { $0 + $1.co2Emissions }

        // Affirmation — same rotation as widget used to do
        let dayOfYear = utcCal.ordinality(of: .day, in: .year, for: now) ?? 1
        let affirmation: Affirmation? = {
            guard !affirmations.isEmpty else {
                let presets = Affirmation.presets
                guard !presets.isEmpty else { return nil }
                return presets[(dayOfYear - 1) % presets.count]
            }
            return affirmations[(dayOfYear - 1) % affirmations.count]
        }()

        let widgetData = WidgetData(
            lastUpdated: now,
            totalCountries: allCountries.count,
            totalCities: allCities.count,
            totalStays: events.count,
            daysAwayFromHomeThisYear: daysAway,
            topCountries: Array(topCountries),
            recentLocationName: recentLocation,
            currentYearTripCount: yearTrips.count,
            totalMilesTraveled: totalMiles,
            activeMinutesThisWeek: activeMinutes,
            activeDaysThisWeek: activeDays,
            totalCaloriesThisWeek: weekCalories,
            workoutCountThisWeek: weekEntries.count,
            topWorkoutTypeThisWeek: topType,
            cyclingCO2SavedLbsAllTime: co2Saved,
            drivingCO2ThisMonthLbs: drivingCO2,
            totalMilesCycledAllTime: cyclingMiles,
            todaysAffirmationText: affirmation?.text,
            todaysAffirmationCategory: affirmation?.category.rawValue,
            todaysAffirmationColor: affirmation?.color
        )
        widgetData.save()
    }

    // MARK: - Automatic Trip Management
    
    /// Check if a new event should create a trip from the previous event
    private func checkAndCreateTripForNewEvent(_ newEvent: Event) {
        print("\n🚗 [Auto-Trip] Checking if new event creates a trip...")
        print("   New event: at location '\(newEvent.location.name)' on \(newEvent.date.utcMediumDateString)")
        print("   New event STORED coords: (\(newEvent.latitude), \(newEvent.longitude))")
        print("   New event EFFECTIVE coords: (\(newEvent.effectiveCoordinates.latitude), \(newEvent.effectiveCoordinates.longitude))")
        
        // Find the chronologically previous event
        let sortedEvents = events.sorted { $0.date < $1.date }
        guard let newEventIndex = sortedEvents.firstIndex(where: { $0.id == newEvent.id }),
              newEventIndex > 0 else {
            print("   ℹ️ No previous event found - this is the first event")
            return
        }
        
        let previousEvent = sortedEvents[newEventIndex - 1]
        print("   Previous event: at location '\(previousEvent.location.name)' on \(previousEvent.date.utcMediumDateString)")
        print("   Previous event STORED coords: (\(previousEvent.latitude), \(previousEvent.longitude))")
        print("   Previous event EFFECTIVE coords: (\(previousEvent.effectiveCoordinates.latitude), \(previousEvent.effectiveCoordinates.longitude))")
        print("   Location comparison: '\(previousEvent.location.id)' vs '\(newEvent.location.id)' (same: \(previousEvent.location.id == newEvent.location.id))")
        
        // Check if they're at different locations (would create a trip)
        if let suggestedTrip = TripMigrationUtility.suggestTrip(from: previousEvent, to: newEvent) {
            // Check if this trip already exists
            let tripExists = trips.contains { trip in
                trip.fromEventID == previousEvent.id && trip.toEventID == newEvent.id
            }
            
            if !tripExists {
                print("   ✅ Creating new trip: \(previousEvent.location.name) → \(newEvent.location.name)")
                print("      Distance: \(suggestedTrip.formattedDistance) mi")
                print("      Mode: \(suggestedTrip.mode.rawValue)")
                
                // Set as pending trip for user confirmation
                pendingTrip = (trip: suggestedTrip, fromEvent: previousEvent, toEvent: newEvent)
                print("   ⏳ Trip pending user confirmation...")
            } else {
                print("   ℹ️ Trip already exists, skipping")
            }
        } else {
            print("   ℹ️ No trip suggested by TripMigrationUtility")
            print("      Checking why:")
            
            // Debug: check coordinates
            let hasPrevCoords = (previousEvent.latitude != 0.0 || previousEvent.longitude != 0.0) || (previousEvent.location.latitude != 0.0 || previousEvent.location.longitude != 0.0)
            let hasNewCoords = (newEvent.latitude != 0.0 || newEvent.longitude != 0.0) || (newEvent.location.latitude != 0.0 || newEvent.location.longitude != 0.0)
            print("      Has prev coords: \(hasPrevCoords), has new coords: \(hasNewCoords)")
            
            // Debug: check if same location
            let sameLocation = previousEvent.location.id == newEvent.location.id
            print("      Same location ID: \(sameLocation)")
            
            // Debug: calculate distance (if possible)
            let currentCoord = previousEvent.effectiveCoordinates
            let nextCoord = newEvent.effectiveCoordinates
            let location1 = CLLocation(latitude: currentCoord.latitude, longitude: currentCoord.longitude)
            let location2 = CLLocation(latitude: nextCoord.latitude, longitude: nextCoord.longitude)
            let distanceInMeters = location1.distance(from: location2)
            let distanceInMiles = distanceInMeters * 0.000621371
            print("      Calculated distance: \(String(format: "%.2f", distanceInMiles)) miles (minimum: 0.5 mi)")
        }
        
        // Also check if there's a NEXT event that would need a trip TO it
        if newEventIndex < sortedEvents.count - 1 {
            let nextEvent = sortedEvents[newEventIndex + 1]
            print("   Checking forward trip to: \(nextEvent.location.name)")
            
            if let suggestedTrip = TripMigrationUtility.suggestTrip(from: newEvent, to: nextEvent) {
                let tripExists = trips.contains { trip in
                    trip.fromEventID == newEvent.id && trip.toEventID == nextEvent.id
                }
                
                if !tripExists {
                    print("   ✅ Creating forward trip: \(newEvent.location.name) → \(nextEvent.location.name)")
                    print("      Distance: \(suggestedTrip.formattedDistance) mi")
                    
                    // Use confirmation flow for forward trip as well
                    pendingTrip = (trip: suggestedTrip, fromEvent: newEvent, toEvent: nextEvent)
                    print("   ⏳ Forward trip pending user confirmation...")
                } else {
                    print("   ℹ️ Forward trip already exists, skipping")
                }
            } else {
                print("   ℹ️ No forward trip needed")
            }
        }
    }
    
    /// Check if deleting an event affects any trips and remove them
    private func checkAndUpdateTripsForDeletedEvent(_ deletedEvent: Event) {
        print("\n🗑️ [Auto-Trip] Checking if deleted event affects trips...")
        print("   Deleted event: \(deletedEvent.location.name) on \(deletedEvent.date.utcMediumDateString)")
        
        // Find trips that reference this event
        let affectedTrips = trips.filter { trip in
            trip.fromEventID == deletedEvent.id || trip.toEventID == deletedEvent.id
        }
        
        if affectedTrips.isEmpty {
            print("   ℹ️ No trips affected")
            return
        }
        
        print("   Found \(affectedTrips.count) trip(s) affected:")
        for trip in affectedTrips {
            print("   - Trip from \(trip.fromEventID) to \(trip.toEventID)")
        }
        
        // Remove affected trips
        let removedCount = affectedTrips.count
        trips.removeAll { trip in
            trip.fromEventID == deletedEvent.id || trip.toEventID == deletedEvent.id
        }
        
        print("   ✅ Removed \(removedCount) trip(s)")
        print("   📊 Total trips now: \(trips.count)")
        
        // Check if we need to create a NEW trip between the previous and next events
        // (filling the gap left by the deleted event)
        let remainingEvents = events.sorted { $0.date < $1.date }
        
        // Find events before and after the deleted event's date
        let eventsBeforeDeleted = remainingEvents.filter { $0.date < deletedEvent.date }
        let eventsAfterDeleted = remainingEvents.filter { $0.date > deletedEvent.date }
        
        if let beforeEvent = eventsBeforeDeleted.last,
           let afterEvent = eventsAfterDeleted.first {
            print("   Checking if new trip needed between remaining events:")
            print("   - Before: \(beforeEvent.location.name)")
            print("   - After: \(afterEvent.location.name)")
            
            if let newTrip = TripMigrationUtility.suggestTrip(from: beforeEvent, to: afterEvent) {
                let tripExists = trips.contains { trip in
                    trip.fromEventID == beforeEvent.id && trip.toEventID == afterEvent.id
                }
                
                if !tripExists {
                    print("   ✅ Creating new trip to fill gap: \(beforeEvent.location.name) → \(afterEvent.location.name)")
                    trips.append(newTrip)
                    print("   📊 Total trips now: \(trips.count)")
                } else {
                    print("   ℹ️ Trip already exists, skipping")
                }
            } else {
                print("   ℹ️ No trip needed - same location or too close")
            }
        } else {
            print("   ℹ️ No surrounding events to create a gap-filling trip")
        }
    }

    // MARK: - Country Migration

    /// Migrates all locations and events without a country field by reverse geocoding their coordinates
    @MainActor
    func migrateCountriesIfNeeded() async {
        print("\n🌍 === STARTING COUNTRY MIGRATION ===")
        
        // Migrate locations first (only non-zero coordinates)
        let locationsNeedingCountry = locations.filter { $0.country == nil && $0.latitude != 0.0 && $0.longitude != 0.0 }
        
        if !locationsNeedingCountry.isEmpty {
            print("📍 Migrating \(locationsNeedingCountry.count) location(s)...")
            
            var updatedLocations = locations
            
            for idx in updatedLocations.indices {
                if updatedLocations[idx].country == nil && 
                   updatedLocations[idx].latitude != 0.0 && 
                   updatedLocations[idx].longitude != 0.0 {
                    let location = updatedLocations[idx]
                    
                    do {
                        if let country = try await ReverseGeocoderHelper.countryString(
                            latitude: location.latitude,
                            longitude: location.longitude
                        ) {
                            updatedLocations[idx].country = country
                        }
                    } catch {
                        // Silently continue on error
                    }
                    
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
            }
            
            self.locations = updatedLocations
        }
        
        // Migrate events - handle both valid coordinates AND use location country as fallback
        let eventsNeedingCountry = events.filter { $0.country == nil }
        
        if !eventsNeedingCountry.isEmpty {
            print("📅 Migrating \(eventsNeedingCountry.count) event(s)...")
            
            var updatedEvents = events
            var processedCount = 0
            var usedLocationCountry = 0
            
            for idx in updatedEvents.indices {
                if updatedEvents[idx].country == nil {
                    let event = updatedEvents[idx]
                    
                    // Progress indicator every 100 events
                    if processedCount % 100 == 0 && processedCount > 0 {
                        print("   Processed: \(processedCount)/\(eventsNeedingCountry.count)")
                    }
                    
                    // If event has valid coordinates, use them
                    if event.latitude != 0.0 || event.longitude != 0.0 {
                        do {
                            if let country = try await ReverseGeocoderHelper.countryString(
                                latitude: event.latitude,
                                longitude: event.longitude
                            ) {
                                updatedEvents[idx].country = country
                                processedCount += 1
                            }
                        } catch {
                            // On error, fall back to location country
                            if let locationCountry = event.location.country {
                                updatedEvents[idx].country = locationCountry
                                usedLocationCountry += 1
                            }
                        }
                        
                        // Delay to avoid rate limiting
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    } else {
                        // Event has (0.0, 0.0) - can't geocode without coordinates
                        // Use location's country if available
                        if let locationCountry = event.location.country {
                            updatedEvents[idx].country = locationCountry
                            usedLocationCountry += 1
                        }
                        // If no location country, event will remain without country data
                    }
                }
            }
            
            self.events = updatedEvents
            print("   ✅ Geocoded from coords: \(processedCount), Used location country: \(usedLocationCountry)")
        }
        
        // Save everything
        storeData()
        
        // Print summary
        let eventsWithCountry = events.filter { $0.country != nil }.count
        let eventsWithoutCountry = events.count - eventsWithCountry
        print("💾 Migration complete! Events with country: \(eventsWithCountry)/\(events.count)")
        if eventsWithoutCountry > 0 {
            print("⚠️  \(eventsWithoutCountry) events still missing country data")
            print("\nEvents without country:")
            let missingEvents = events.filter { $0.country == nil }
            for event in missingEvents.prefix(10) {
                print("  - Date: \(event.date), Location: \(event.location.name), Coords: (\(event.latitude), \(event.longitude)), Location Country: \(event.location.country ?? "nil")")
            }
            if missingEvents.count > 10 {
                print("  ... and \(missingEvents.count - 10) more")
            }
        }
        print("=========================\n")
    }
    
    /// Geocodes a city name to get coordinates and country
    /// Returns (latitude, longitude, country) tuple
    @MainActor
    func geocodeCity(_ cityName: String) async -> (latitude: Double, longitude: Double, country: String?)? {
        guard !cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        do {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.geocodeAddressString(cityName)
            
            if let placemark = placemarks.first,
               let location = placemark.location {
                return (
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    country: placemark.country
                )
            }
        } catch {
            // Silently fail - errors are usually rate limiting or invalid city names
        }
        
        return nil
    }
    
    /// Updates the country field for a specific event based on its coordinates
    /// Call this when creating or updating events
    @MainActor
    func updateEventCountry(_ event: Event) async -> String? {
        // If event has valid coordinates, use them
        guard event.latitude != 0.0 || event.longitude != 0.0 else {
            // Fall back to location's country
            return event.location.country
        }
        
        do {
            if let country = try await ReverseGeocoderHelper.countryString(
                latitude: event.latitude,
                longitude: event.longitude
            ) {
                return country
            } else {
                // Fall back to location's country
                return event.location.country
            }
        } catch {
            // Fall back to location's country on error
            return event.location.country
        }
    }
    
    // MARK: - Seed "Other" Location
    
    /// Ensures a Location named "Other" exists. Returns true if it was added.
    @discardableResult
    func ensureOtherLocationExists(saveIfAdded: Bool) -> Bool {
        let exists = locations.contains { $0.name.caseInsensitiveCompare("Other") == .orderedSame }
        if exists {
            return false
        }
        let other = Location(
            name: "Other",
            city: "None",
            state: nil,
            latitude: 0.0,
            longitude: 0.0,
            country: nil,
            countryCode: nil,
            theme: .yellow
        )
        locations.append(other)
        changedLocation = other
        if saveIfAdded {
            storeData()
        }
        print("✅ Seeded required 'Other' location")
        return true
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    /// Debug helper: Print all events for a specific date
    func debugPrintEventsForDate(_ date: Date) {
        let targetDay = date.startOfDay
        let eventsForDate = events.filter { $0.date.startOfDay == targetDay }
        
        print("\n📅 DEBUG: Events for \(date.utcMediumDateString)")
        print("   Target start of day: \(targetDay)")
        print("   Total events found: \(eventsForDate.count)")
        
        let validLocationIDs = Set(locations.map { $0.id })
        
        for (index, event) in eventsForDate.enumerated() {
            let isValid = validLocationIDs.contains(event.location.id)
            print("\n   Event #\(index + 1): \(isValid ? "✅ VALID" : "❌ ORPHAN")")
            print("      ID: \(event.id)")
            print("      FULL DATE: \(event.date)")
            print("      Start of Day: \(event.date.startOfDay)")
            print("      Location: \(event.location.name)")
            print("      Location ID: \(event.location.id)")
            print("      City: '\(event.city ?? "nil")'")
            print("      State: '\(event.state ?? "nil")'")
            print("      Country: '\(event.country ?? "nil")'")
            print("      Note: '\(event.note.isEmpty ? "(empty)" : event.note)'")
            print("      Event Type: \(event.eventType)")
        }
        
        if eventsForDate.isEmpty {
            print("   ⚠️ No events found for this date")
        }
        
        print("")
    }
    #endif
}

