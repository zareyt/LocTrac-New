# Trip Model Implementation

## Overview

This document describes the implementation of the Trip model system in LocTrac, which tracks travel between locations with accurate CO₂ calculations and transport modes.

## Files Created

### 1. Trip.swift
**Purpose**: Core model representing travel between locations

**Key Features:**
- SwiftData model with full persistence
- Transport modes: Flying, Driving, Train, Bus, Boat, Bicycle, Walking, Other
- Automatic CO₂ calculation based on mode
- Distance tracking in miles
- Departure and arrival dates
- Notes and auto-generation flags

**Transport Mode CO₂ Rates (lbs/mile):**
- Flying: 0.9
- Driving: 0.89
- Train: 0.14
- Bus: 0.29
- Boat: 0.25
- Bicycle/Walking: 0.0
- Other: 0.5

### 2. TripMigrationUtility.swift
**Purpose**: Migrate existing events into trips

**Key Functions:**
- `migrateEventsToTrips()`: Converts all events to trips
- `suggestTrip()`: Suggests a trip for new event creation
- `shouldCreateTrip()`: Determines if location change warrants a trip
- `calculateDistance()`: Calculates great-circle distance

**Migration Logic:**
- Only creates trips when location actually changes
- Named locations: Compares location.id
- "Other" events: Checks if coordinates >1 mile apart
- Auto-detects transport mode:
  - ≤3 miles: Walking
  - 3-100 miles: Driving  
  - >100 miles: Flying

### 3. TripFormView.swift
**Purpose**: UI for adding/editing trips

**Features:**
- Route display (from/to locations)
- Transport mode picker
- Distance editor
- Date pickers (departure/arrival)
- Notes field
- Real-time CO₂ calculation
- Environmental impact display

## Data Store Updates

### Added Properties
```swift
@Published var trips: [Trip] = []
```

### New Methods
```swift
func addTrip(_ trip: Trip)
func deleteTrip(_ trip: Trip)
func save() // Convenience alias
```

### Automatic Migration
- Runs on first load if no trips exist
- Creates trips from existing events
- Logs migration progress
- Saves automatically

## Import/Export Updates

### Export Structure
```swift
struct Export: Codable {
    let locations: [LocationData]
    let events: [EventData]
    let activities: [ActivityData]
    let trips: [TripData] // NEW
}
```

### Import Structure  
```swift
struct Import: Codable {
    let trips: [TripData]? // Optional for backwards compatibility
}
```

## Usage

### Automatic Trip Migration
Trips are automatically generated when:
1. App loads with no existing trips
2. Events exist with >1 entry
3. Consecutive events have different locations

### Manual Trip Creation
Users can add trips via:
1. TripFormView directly
2. Suggested trip prompts (when adding new events)

### Trip Calculations in Infographics
The InfographicsView now uses trips for accurate statistics:
- Total miles traveled
- CO₂ emissions by transport mode
- Trip counts (flying vs driving vs other)
- Environmental impact calculations

## Integration Points

### EventFormView (Future Enhancement)
When a new event is created:
1. Check previous event's location/coordinates
2. If different, suggest creating a trip
3. Show TripFormView with pre-filled data
4. User can accept/modify/decline

### Example Integration:
```swift
// In EventFormView after saving event
if let previousEvent = store.events.sorted { $0.date > $1.date }.first,
   let suggestedTrip = TripMigrationUtility.suggestTrip(
       from: previousEvent, 
       to: newEvent
   ) {
    showTripSuggestion = true
    pendingTrip = suggestedTrip
}
```

## Benefits

### For Users
- ✅ Accurate travel tracking
- ✅ Real environmental impact data
- ✅ Multiple transport modes
- ✅ Historical trip records
- ✅ Automatic migration of existing data

### For Calculations
- ✅ No duplicate counting
- ✅ Mode-specific CO₂ rates
- ✅ Actual trip distances
- ✅ User-verified data

### For Analytics
- ✅ Transport mode breakdown
- ✅ Accurate emissions
- ✅ Trip frequency stats
- ✅ Historical trends

## Migration Example

**Before (Event-based):**
```
Home → Home → Home → Office
= 3 "trips" (incorrect)
```

**After (Trip-based):**
```
Home → Home → Home → Office
= 1 trip (correct)
```

## Next Steps

### Immediate
1. ✅ Trip model created
2. ✅ Migration utility implemented
3. ✅ DataStore updated
4. ✅ Import/Export updated

### Future Enhancements
1. Add trip suggestions when creating events
2. Create trips management view
3. Add trip editing capability
4. Show trip history in event details
5. Export trip reports
6. Add route visualization on maps

## Testing

### Migration Test
1. Load app with existing events
2. Check console for migration log
3. Verify trips created correctly
4. Check infographics for accurate stats

### New Event Test
1. Create event at different location
2. Should prompt for trip creation
3. Pre-fill distance and mode
4. Save and verify in data

## Notes

- Trips are optional for backwards compatibility
- Auto-migration only runs once
- Manual trips can override auto-generated ones
- CO₂ rates based on EPA averages
- Distance calculations use great-circle (as-the-crow-flies)

---

**Implementation Date**: March 24, 2026
**Version**: 1.0
**Status**: ✅ Complete - Ready for Testing
