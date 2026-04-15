# v1.5 Location Reference Architecture Migration

## Overview
Converting Event.location from embedded Location object to locationID reference string.

## Motivation
1. **Data Efficiency**: Reduce storage - each event currently duplicates full Location data
2. **Master-Detail Integrity**: Single source of truth for location data
3. **Data Cleanup**: Easier to maintain and update location data
4. **Consistency**: Aligns with how Activities and Affirmations are referenced (by ID)

## Breaking Changes

### Event Model
```swift
// BEFORE (v1.4)
struct Event {
    var location: Location  // Full embedded object
    var city: String?       // For "Other" only
    var state: String?      // For "Other" only
    var country: String?    // For "Other" only
    var latitude: Double    // For "Other" only
    var longitude: Double   // For "Other" only
}

// AFTER (v1.5)
struct Event {
    var locationID: String  // Reference to Location.id
    var city: String?       // For "Other" location only
    var state: String?      // For "Other" location only
    var country: String?    // For "Other" location only
    var latitude: Double    // For "Other" location only
    var longitude: Double   // For "Other" location only
}
```

### Helper Methods Needed
```swift
// Event extension to get location from DataStore
extension Event {
    func location(from locations: [Location]) -> Location? {
        locations.first(where: { $0.id == locationID })
    }
    
    func locationOrOther(from locations: [Location]) -> Location {
        location(from: locations) ?? Location.other
    }
}
```

### Views Requiring Updates
All views that access `event.location` must change to:
```swift
// BEFORE
Text(event.location.name)
Circle().fill(event.location.theme.mainColor)

// AFTER (with DataStore/locations array available)
if let location = event.location(from: store.locations) {
    Text(location.name)
    Circle().fill(location.theme.mainColor)
}
```

## Migration Strategy

### Phase 1: Create Migration Utility
```swift
struct EventLocationMigrator {
    /// Converts old events with embedded locations to new locationID format
    static func migrate(events: [Event]) -> [Event] {
        events.map { oldEvent in
            Event(
                id: oldEvent.id,
                eventType: oldEvent.eventType,
                date: oldEvent.date,
                locationID: oldEvent.location.id,  // Extract ID
                city: oldEvent.city,
                latitude: oldEvent.latitude,
                longitude: oldEvent.longitude,
                country: oldEvent.country,
                state: oldEvent.state,
                note: oldEvent.note,
                people: oldEvent.people,
                activityIDs: oldEvent.activityIDs,
                affirmationIDs: oldEvent.affirmationIDs
            )
        }
    }
}
```

### Phase 2: Update Import/Export Structures
```swift
// ImportExport.swift already uses locationID in Event struct
struct Import: Codable {
    struct Event: Codable {
        var locationID: String  // ✅ Already correct!
        // ... other fields
    }
}
```

### Phase 3: Update DataStore Load Logic
```swift
// DataStore.swift
func loadData() {
    // ... existing load code
    
    // AUTO-MIGRATION: Check if first event has old format
    if let firstEvent = events.first,
       // TODO: Detect old format somehow
    {
        print("🔄 Migrating events from embedded Location to locationID...")
        events = EventLocationMigrator.migrate(events: events)
        storeData()  // Save migrated data
        print("✅ Migration complete - saved \(events.count) events")
    }
}
```

### Phase 4: Update All Views

#### High-Impact Views (Must Update)
1. **ModernEventsCalendarView.swift**
   - `ModernCalendarView.Coordinator.calendarView(_:decorationFor:)`
   - `ModernEventRow`
   - `ModernDaysEventsListView`

2. **TravelHistoryView.swift**
   - `StayDetailSheet`
   - All list rows showing location data

3. **Event Form Views**
   - `ModernEventFormView.swift`
   - `EventFormView.swift`
   - Need location picker instead of embedded data

4. **Charts & Analytics**
   - `DonutChartView`
   - `InfographicsView`
   - Any chart grouping by location

5. **HomeView.swift**
   - Recent events display

## Implementation Checklist

### Step 1: Model Changes
- [ ] Update Event struct to use `locationID: String`
- [ ] Remove `location: Location` property
- [ ] Add helper methods: `location(from:)`, `locationOrOther(from:)`
- [ ] Update effectiveCoordinates to take locations parameter
- [ ] Update effectiveCity/State/Country to take locations parameter
- [ ] Update init() to take locationID instead of Location

### Step 2: Migration Utility
- [ ] Create EventLocationMigrator struct
- [ ] Implement migrate() method
- [ ] Add auto-detection logic
- [ ] Test with sample data

### Step 3: DataStore Updates
- [ ] Update loadData() with migration check
- [ ] Update add/update/delete methods if needed
- [ ] Ensure storeData() works with new format

### Step 4: View Updates (High Priority)
- [ ] ModernEventsCalendarView
- [ ] TravelHistoryView  
- [ ] ModernEventFormView
- [ ] EventFormView
- [ ] HomeView
- [ ] DonutChartView
- [ ] InfographicsView

### Step 5: View Updates (Medium Priority)
- [ ] LocationsManagementView (location deletion check)
- [ ] TripsListView
- [ ] Any custom event list views

### Step 6: Testing
- [ ] Test with existing backup.json (migration)
- [ ] Test creating new events
- [ ] Test editing events
- [ ] Test deleting locations with events (should fail)
- [ ] Test import/export with new format
- [ ] Test all charts and analytics

### Step 7: Documentation
- [ ] Update CLAUDE.md Known Gotchas section
- [ ] Update VERSION_1.5_SUMMARY.md
- [ ] Update VERSION_1.5_INTERNATIONAL_LOCATIONS.md
- [ ] Create MIGRATION_GUIDE_V1.5.md

## Computed Properties Pattern

### Old Pattern (v1.4)
```swift
var effectiveCity: String? {
    if location.name == "Other" {
        return city
    } else {
        return location.city
    }
}
```

### New Pattern (v1.5)
```swift
func effectiveCity(from locations: [Location]) -> String? {
    if let location = location(from: locations) {
        if location.name == "Other" {
            return city
        } else {
            return location.city
        }
    }
    return city  // Fallback if location not found
}
```

## Breaking Export/Import Compatibility

**IMPORTANT**: Old backups will need migration when imported.

### Import.Event Structure (Already Correct)
```swift
struct Import: Codable {
    struct Event: Codable {
        var locationID: String  // ✅ Already uses ID
        // ... fields
    }
}
```

### Migration on Import
```swift
// When decoding Import.Event → Event
let event = Event(
    id: eventData.id,
    eventType: eventData.eventType,
    date: eventData.date,
    locationID: eventData.locationID,  // ✅ Direct mapping
    city: eventData.city,
    // ...
)
```

## Risk Mitigation

### 1. Orphaned Events
**Risk**: Event references locationID that doesn't exist

**Mitigation**:
- Ensure "Other" location always exists
- Fallback to "Other" if locationID not found
- Add validation in DataStore.add/update

```swift
func add(_ event: Event) {
    guard locations.contains(where: { $0.id == event.locationID }) else {
        print("⚠️ Event references unknown locationID: \(event.locationID)")
        // Create missing location or use "Other"
        return
    }
    events.append(event)
    save()
}
```

### 2. Location Deletion
**Risk**: Deleting location that has events

**Current Protection**: Already exists
```swift
func delete(_ location: Location) {
    let hasEvents = events.contains { $0.locationID == location.id }
    guard !hasEvents else {
        // Show error - can't delete location with events
        return
    }
    // ... delete
}
```

### 3. Performance
**Risk**: Looking up location for every event display

**Mitigation**:
- Use Dictionary for O(1) lookup
- Cache location lookups in views
- Pre-compute for lists

```swift
// Efficient pattern for lists
let locationDict = Dictionary(uniqueKeysWithValues: store.locations.map { ($0.id, $0) })

ForEach(events) { event in
    if let location = locationDict[event.locationID] {
        EventRow(event: event, location: location)
    }
}
```

## Timeline

**Estimated Effort**: 8-12 hours
- Model changes: 1 hour
- Migration utility: 1 hour  
- View updates: 4-6 hours
- Testing: 2-3 hours
- Documentation: 1 hour

**Recommended Approach**: 
1. Create new git branch
2. Implement in phases
3. Test thoroughly with backup data
4. Merge when stable

## Success Criteria

- [ ] All existing backup.json files import correctly
- [ ] New events save with locationID
- [ ] All views display location data correctly
- [ ] Charts and analytics work as before
- [ ] No crashes or force-unwraps
- [ ] Documentation updated
- [ ] Data size reduced (verify backup.json file size)

---

**Status**: Planning Complete - Ready for Implementation  
**Priority**: High - Foundational change for v1.5  
**Risk Level**: High - Affects core data model  
**Reversibility**: Medium - Migration needed to rollback

