# Event Country Field Implementation

## Overview
This document explains the implementation of the `country` field on the `Event` model, which allows each event to store its own country based on its specific coordinates. This is particularly important for "Other" location events, where each event can be in a different country.

## Why This Approach?

The "Other" location is a placeholder for events that don't belong to predefined locations. Since "Other" events can be anywhere in the world, storing the country on the Location object doesn't work. Instead, we store the country on each individual Event, similar to how we store `city`.

### Before (Location-based country):
- ❌ "Other" location had coordinates (0.0, 0.0)
- ❌ All "Other" events shared the same (invalid) location country
- ❌ 150+ "Other" events were excluded from US/Outside US filtering

### After (Event-based country):
- ✅ Each event stores its own country
- ✅ "Other" events use their specific coordinates to determine country
- ✅ All events can be properly categorized by country

## Changes Made

### 1. **Event Model** (Event.swift)
Added `country` field to the Event struct:

```swift
struct Event: Identifiable {
    var eventType: String
    var location: Location
    var id: String
    var date: Date
    var city: String?
    var latitude: Double
    var longitude: Double
    var country: String?  // NEW: Each event stores its own country
    var note: String
    var people: [Person] = []
    var activityIDs: [String] = []
}
```

### 2. **Import/Export** (ImportExport.swift)
Updated Import and Export structures to include event country:

```swift
struct Import: Codable {
    struct Event: Codable {
        var locationID: String
        let id: String
        var eventType: String
        let date: Date
        var city: String
        var latitude: Double
        var longitude: Double
        var country: String?  // NEW: Optional for backward compatibility
        var note: String
        var people: [Person]?
        var activityIDs: [String]?
    }
}

struct Export: Codable {
    struct EventData: Codable {
        let locationID: String
        let id: String
        var eventType: String
        let date: Date
        let city: String
        let latitude: Double
        let longitude: Double
        let country: String?  // NEW: Export event's country
        let note: String
        let people: [Person]?
        let activityIDs: [String]
    }
}
```

### 3. **DataStore** (DataStore.swift)

#### Loading Events:
```swift
self.events = decodedImport.events.map({ event in
    Event(id: event.id,
          eventType: Event.EventType(rawValue: event.eventType)!,
          date: event.date,
          location: locations.first(where: {$0.id == event.locationID})!,
          city: event.city,
          latitude: event.latitude,
          longitude: event.longitude,
          country: event.country,  // Load country from import
          note: event.note,
          people: event.people ?? [],
          activityIDs: event.activityIDs ?? [])
})
```

#### Updating Events:
```swift
func update(_ event: Event) {
    if let index = events.firstIndex(where: {$0.id == event.id}) {
        // ... other updates ...
        events[index].country = event.country  // Update country
        storeData()
    }
}
```

#### Migration:
```swift
@MainActor
func migrateCountriesIfNeeded() async {
    // Migrate locations (for non-"Other" locations)
    // ...
    
    // Migrate events (especially "Other" events)
    let eventsNeedingCountry = events.filter { 
        $0.country == nil && 
        $0.latitude != 0.0 && 
        $0.longitude != 0.0 
    }
    
    for event in eventsNeedingCountry {
        if let country = try await ReverseGeocoderHelper.countryString(
            latitude: event.latitude,
            longitude: event.longitude
        ) {
            event.country = country
        }
    }
}
```

#### Helper Method:
```swift
@MainActor
func updateEventCountry(_ event: Event) async -> String? {
    guard event.latitude != 0.0 || event.longitude != 0.0 else {
        return nil
    }
    
    return try? await ReverseGeocoderHelper.countryString(
        latitude: event.latitude,
        longitude: event.longitude
    )
}
```

### 4. **EventFormView** (EventFormView.swift)
When creating or updating events, get the country and set it on the event:

```swift
private func performSave() {
    Task { @MainActor in
        if viewModel.updating {
            // Get country for the event
            let country = await store.updateEventCountry(Event(...))
            
            let event = Event(
                id: id,
                // ... other fields ...
                country: country,  // Set country on event
                // ...
            )
            store.update(event)
        } else {
            // Get country once for all events (same coordinates)
            let country = await store.updateEventCountry(Event(...))
            
            for n in 0...days {
                let newEvent = Event(
                    // ... other fields ...
                    country: country,  // Set country on each event
                    // ...
                )
                store.add(newEvent)
            }
        }
    }
}
```

### 5. **DonutChartView** (DonutChartView.swift)
Changed filtering to use `event.country` instead of `event.location.country`:

```swift
// Filtered events by region
private var filteredEvents: [Event] {
    let eventsByYear: [Event]
    // ... year filtering ...
    
    switch regionFilter {
    case .all:
        return eventsByYear
    case .us:
        return eventsByYear.filter {
            guard let country = $0.country?.lowercased() else { return false }
            return country == "united states" || country == "usa"
        }
    case .outsideUS:
        return eventsByYear.filter {
            guard let country = $0.country?.lowercased() else { return false }
            return country != "united states" && country != "usa"
        }
    }
}

// Totals calculation
private var totals: (total: Int, us: Int, outsideUS: Int) {
    // ...
    let usEvents = yearEvents.filter {
        guard let country = $0.country?.lowercased() else { return false }
        return country == "united states" || country == "usa"
    }
    
    let outsideUSEvents = yearEvents.filter {
        guard let country = $0.country?.lowercased() else { return false }
        return country != "united states" && country != "usa"
    }
    // ...
}
```

## Migration Process

When the app launches:

1. **Locations Migration:**
   - Locations with valid coordinates (not 0.0, 0.0) get reverse geocoded
   - "Other" location keeps (0.0, 0.0) coordinates and no country (it's just a placeholder)

2. **Events Migration:**
   - All events without a country field get reverse geocoded
   - Each event uses its own latitude/longitude
   - "Other" events get their country from their specific coordinates
   - Progress shown every 50 events

3. **New Events:**
   - When creating/updating events, country is determined from coordinates
   - Country is set on the event before saving
   - For multiple events (date range), country is looked up once and applied to all

## Benefits

1. **Accurate Data:** Each event knows its own country regardless of location type
2. **Backward Compatible:** Old data without country field is migrated automatically
3. **Consistent with City:** Country field works just like city field on events
4. **Clean Separation:** "Other" location is truly just a placeholder
5. **Proper Filtering:** All events can be filtered by country in charts

## Testing

### To verify the implementation:

1. **Check Migration:**
   - Look for console output showing events being migrated
   - Check that events have country data after migration

2. **Create "Other" Event:**
   - Create an event with "Other" location
   - Set coordinates for a known location
   - Save and verify country is populated

3. **View in Charts:**
   - Open donut chart view
   - Check totals show correct US vs Outside US counts
   - Filter by "US" or "Outside US" and verify "Other" events appear correctly

4. **Export/Import:**
   - Export data to JSON
   - Verify events have country field in JSON
   - Re-import and verify countries are preserved

## Data Structure Comparison

### Location Model (Unchanged):
```swift
struct Location {
    var id: String
    var name: String
    var city: String?
    var latitude: Double
    var longitude: Double
    var country: String?  // Used for predefined locations
    var theme: Theme
    var imageIDs: [String]?
}
```

### Event Model (With New Country):
```swift
struct Event {
    var eventType: String
    var location: Location  // Reference to location
    var id: String
    var date: Date
    var city: String?       // Event's specific city
    var latitude: Double    // Event's specific coordinates
    var longitude: Double   // Event's specific coordinates
    var country: String?    // NEW: Event's specific country
    var note: String
    var people: [Person]
    var activityIDs: [String]
}
```

## Future Enhancements

Possible improvements:
1. Add state/province field to events
2. Cache reverse geocoding results to reduce API calls
3. Add manual country override in event form
4. Show country in event list views
5. Add country-based statistics and charts
