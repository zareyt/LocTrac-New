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
    @Published var trips: [Trip] = [] // NEW: travel trips between locations
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
        if let index = locations.firstIndex(where: {$0.id == location.id}) {
            changedLocation = locations.remove(at: index)
        }
        storeData()
    }
    
    func delete(_ event: Event) {
        print("🗑️ delete(Event) called for id=\(event.id)")
        if let index = events.firstIndex(where: {$0.id == event.id}) {
            changedEvent = events.remove(at: index)
            invalidateCacheForEvent(event, isDelete: true)
            
            // Check if this event's deletion affects any trips
            checkAndUpdateTripsForDeletedEvent(event)
        } else {
            print("⚠️ delete(Event): event not found in store")
        }
        storeData()
    }
    
    func add(_ location: Location) {
        locations.append(location)
        changedLocation = location
        storeData()
    }

    func add(_ event: Event) {
        print("➕ add(Event) called for id=\(event.id), date=\(event.date), location='\(event.location.name)'")
        events.append(event)
        changedEvent = event
        
        // Check if this new event creates a trip from the previous day
        checkAndCreateTripForNewEvent(event)
        
        storeData()
        invalidateCacheForEvent(event)
    }

    func update(_ location: Location) {
        if let index = locations.firstIndex(where: {$0.id == location.id}) {
            movedLocation = locations[index]
            locations[index].name = location.name
            locations[index].city = location.city
            locations[index].latitude = location.latitude
            locations[index].longitude = location.longitude
            locations[index].country = location.country
            locations[index].theme = location.theme
            locations[index].imageIDs = location.imageIDs
            changedLocation = location
            invalidateCacheForLocation(location)
        }
        storeData()
    }
    
    func update(_ event: Event) {
        if let index = events.firstIndex(where: {$0.id == event.id}) {
            movedEvent = events[index]
            events[index].date = event.date
            events[index].eventType = event.eventType
            events[index].location = event.location
            events[index].city = event.city
            events[index].latitude = event.latitude
            events[index].longitude = event.longitude
            events[index].country = event.country // NEW: Update country
            events[index].note = event.note
            events[index].people = event.people
            events[index].activityIDs = event.activityIDs // NEW
            changedEvent = event
            storeData()
            invalidateCacheForEvent(event)
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
    
    // MARK: - Persistence
    
    func storeData() -> Void {
        let export = Export(locations: self.locations, events: self.events, activities: self.activities, trips: self.trips)
        do {
            let encodedData = try JSONEncoder().encode(export)
            if let filepath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("backup.json") {
                do {
                    try encodedData.write(to: filepath)
                    print(filepath)
                    print("💾 Data saved successfully")
                    bumpDataUpdate() // Notify that data has changed
                } catch {
                    print(error.localizedDescription)
                    print("❌ Could not save data")
                }
            } else {
                print("❌ Could not create filepath")
            }
        } catch {
            print(error.localizedDescription)
            print("❌ Could not encode data")
        }
    }

    func loadData() {
        let backupURL = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("backup.json")
        
        // Check if backup.json exists
        if !FileManager().fileExists(atPath: backupURL.path) {
            print("📝 No backup.json found - this appears to be first launch")
            print("🎯 Initializing with empty data for wizard")
            // Initialize with empty data - wizard will populate
            self.locations = []
            self.events = []
            self.activities = []
            return
        }
        
        print("📂 Loading from backup.json")
        loadFromURL(backupURL)
    }
    
    private func loadFromURL(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            print("❌ Unable to load data from \(url)")
            // Initialize with empty data rather than crashing
            self.locations = []
            self.events = []
            self.activities = []
            return
        }
        
        guard let decodedImport = try? JSONDecoder().decode(Import.self, from: data) else {
            print("❌ Failed to decode JSON from \(url)")
            // Initialize with empty data rather than crashing
            self.locations = []
            self.events = []
            self.activities = []
            return
        }
        self.locations = decodedImport.locations.map({ location in
            Location(id: location.id,
                     name: location.name,
                     city: location.city,
                     latitude: location.latitude,
                     longitude: location.longitude,
                     country: location.country,
                     theme: Theme(rawValue: location.theme) ?? .purple,
                     imageIDs: location.imageIDs)
        })
        self.events = decodedImport.events.map({ event in
            Event(id: event.id,
                  eventType: Event.EventType(rawValue: event.eventType) ?? .unspecified,
                  date: event.date,
                  location: locations.first(where: {$0.id == event.locationID}) ?? Location(name: "Unknown", city: nil, latitude: 0, longitude: 0, theme: .purple),
                  city: event.city,
                  latitude: event.latitude,
                  longitude: event.longitude,
                  country: event.country,
                  note: event.note,
                  people: event.people ?? [],
                  activityIDs: event.activityIDs ?? [])
        })
        // Activities may or may not be present in older seeds; seed defaults if empty
        if let importedActivities = decodedImport.activities {
            self.activities = importedActivities.map { Activity(id: $0.id, name: $0.name) }
        } else {
            self.activities = []
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
                    isAutoGenerated: tripData.isAutoGenerated
                )
            }
            print("✅ Loaded Trips: \(trips.count)")
        } else {
            self.trips = []
            print("📝 No trips in backup - will run migration if needed")
        }
        
        if self.activities.isEmpty {
            seedDefaultActivities()
        }
        
        // Run trip migration if no trips exist and we have events
        if self.trips.isEmpty && self.events.count > 1 {
            print("🚗 Running trip migration...")
            runTripMigration()
        }
        
        print("✅ Loaded Locations: \(locations.count)")
        print("✅ Loaded Events: \(events.count)")
        print("✅ Loaded Activities: \(activities.count)")
        print("✅ Loaded Trips: \(trips.count)")
        
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
    
    // MARK: - Automatic Trip Management
    
    /// Check if a new event should create a trip from the previous event
    private func checkAndCreateTripForNewEvent(_ newEvent: Event) {
        print("\n🚗 [Auto-Trip] Checking if new event creates a trip...")
        print("   New event: \(newEvent.city ?? "nil") at location '\(newEvent.location.name)' on \(newEvent.date.formatted(date: .abbreviated, time: .omitted))")
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
        print("   Previous event: \(previousEvent.city ?? "nil") at location '\(previousEvent.location.name)' on \(previousEvent.date.formatted(date: .abbreviated, time: .omitted))")
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
            print("   Checking forward trip to: \(nextEvent.city ?? "Unknown")")
            
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
        print("   Deleted event: \(deletedEvent.city ?? "Unknown") on \(deletedEvent.date.formatted(date: .abbreviated, time: .omitted))")
        
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
            print("   - Before: \(beforeEvent.city ?? "Unknown")")
            print("   - After: \(afterEvent.city ?? "Unknown")")
            
            if let newTrip = TripMigrationUtility.suggestTrip(from: beforeEvent, to: afterEvent) {
                let tripExists = trips.contains { trip in
                    trip.fromEventID == beforeEvent.id && trip.toEventID == afterEvent.id
                }
                
                if !tripExists {
                    print("   ✅ Creating new trip to fill gap: \(beforeEvent.location.name) → \(afterEvent.location.name)")
                    trips.append(newTrip)
                    print("   📊 Total trips now: \(trips.count)")
                } else {
                    print("   ℹ️ Trip already exists")
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
            var geocodedFromCity = 0
            
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
                        // Event has (0.0, 0.0) - try to geocode from city name
                        if let cityName = event.city, !cityName.isEmpty {
                            if let result = await geocodeCity(cityName) {
                                updatedEvents[idx].latitude = result.latitude
                                updatedEvents[idx].longitude = result.longitude
                                updatedEvents[idx].country = result.country
                                geocodedFromCity += 1
                                
                                // Longer delay to avoid rate limiting (50 requests per 60 seconds = ~1.2 seconds each)
                                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                            } else if let locationCountry = event.location.country {
                                // Geocoding failed, use location country
                                updatedEvents[idx].country = locationCountry
                                usedLocationCountry += 1
                            }
                        } else {
                            // No city name - use location's country if available, otherwise leave empty
                            if let locationCountry = event.location.country {
                                updatedEvents[idx].country = locationCountry
                                usedLocationCountry += 1
                            }
                            // If no location country, event will remain without country data
                        }
                    }
                }
            }
            
            self.events = updatedEvents
            print("   ✅ Geocoded from coords: \(processedCount), From city: \(geocodedFromCity), Used location country: \(usedLocationCountry)")
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
}
