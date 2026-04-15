# Location Coordinate Propagation System

## Overview
Automatically updates event coordinates when location coordinates change, with manual review for large changes.

## Problem Solved
Previously, when a user updated a location's GPS coordinates, the existing events that referenced that location kept their old copied coordinates. This caused:
- Incorrect trip distances
- Maps showing events at wrong locations
- Country detection failures

## Solution Architecture

### User-Informed Approach

**ALWAYS shows review UI when coordinates change** - User is informed of impact and makes the decision.

**Flow**:
1. User edits location coordinates
2. User taps "Update Location"
3. System analyzes impact (distance, affected events)
4. **Review UI appears** showing:
   - Old vs new coordinates
   - Distance moved
   - Number of events affected
   - Map comparison
   - List of all affected events
5. User decides:
   - **Update Events** - Apply new coordinates to selected events
   - **Keep Original** - Leave events at old coordinates
6. User choice is applied

**Visual Indicators**:
- **Small changes (< 5 miles)**: Blue info icon, informational tone
- **Large changes (≥ 5 miles)**: Orange warning icon, cautionary tone

**Key Benefit**: User is **always** in control and fully informed of the impact

## Implementation Files

### 1. **LocationCoordinateUpdater.swift** (NEW)
Core logic for coordinate change analysis and propagation.

#### Key Components:

**`UpdateAnalysis` struct**
```swift
struct UpdateAnalysis {
    var affectedEvents: [Event]
    var oldCoordinates: CLLocationCoordinate2D
    var newCoordinates: CLLocationCoordinate2D
    var distanceChange: Double // miles
    var shouldAutoUpdate: Bool
}
```

**`analyzeCoordinateChange()`**
- Calculates distance between old and new coordinates
- Finds all events using the location
- Determines if auto-update or review is needed
- Returns detailed analysis

**`autoUpdateEventCoordinates()`**
- Updates event coordinates
- Updates city and country if provided
- Calls `store.update()` for each event
- Logs progress

**`findEventsNeedingSync()`**
- Utility to find events with outdated coordinates
- Useful for fixing historical data
- Checks coordinate differences > 0.0001° (~36 feet)

### 2. **LocationCoordinateReviewView.swift** (NEW)
SwiftUI interface for manual coordinate change review.

#### Features:

**Warning Header**
- Blue info icon (< 5 mi) or Orange warning icon (≥ 5 mi)
- Distance change display
- Number of affected events
- Context explanation

**Coordinate Comparison**
- Side-by-side old vs new coordinates
- Visual color coding (red = old, green = new)
- Precision to 6 decimal places

**Map Comparison**
- Interactive map showing both locations
- Old location: Red pin
- New location: Green pin
- Distance measurement

**Event Selection**
- List of all affected events
- Checkboxes for selective update
- Event details: date, city, current coordinates
- Sort by date (newest first)

**Actions**
- "Update X Events" - Apply selected changes
- "Keep Original Coordinates" - Cancel update

### 3. **DataStore Extension** (in LocationCoordinateUpdater.swift)

**`updateLocationWithCoordinatePropagation()`**
Enhanced location update method with automatic coordinate handling.

```swift
func updateLocationWithCoordinatePropagation(
    _ location: Location,
    requiresReview: ((UpdateAnalysis) -> Void)? = nil
)
```

**Flow**:
1. Compare new vs existing coordinates
2. If unchanged → standard update
3. If changed:
   - Analyze impact
   - Update location
   - If ≤ 5 miles → auto-update events
   - If > 5 miles → call `requiresReview` closure

### 4. **LocationFormView.swift** (UPDATED)
Integrated coordinate propagation into location editing.

**Changes**:
- Added state for review UI: `showCoordinateReview`, `coordinateReviewAnalysis`, `pendingLocation`
- Replaced `store.update(location)` with `store.updateLocationWithCoordinatePropagation(location)`
- Added sheet presentation for `LocationCoordinateReviewView`
- Dismiss only if no review needed

## Usage Workflow

### Review Scenario (All Coordinate Changes)

```
1. User edits "Loft" location
2. Changes coordinates (any amount - 0.2 miles or 20 miles)
3. Taps "Update Location"
4. System analyzes impact
5. Review sheet appears showing:
   - Icon: Blue info (< 5 mi) or Orange warning (≥ 5 mi)
   - Old vs new coordinates on map
   - Distance: "0.5 miles" or "20.3 miles"
   - List of 50 affected events
6. User reviews and selects which events to update
7. User chooses:
   Option A: "Update 50 Events" → Coordinates updated
   Option B: "Keep Original Coordinates" → Events unchanged
8. Both sheets dismiss
9. Console logs all changes
```

### No Impact Scenario

```
1. User edits "Loft" location
2. Changes coordinates
3. Taps "Update Location"
4. System detects: 0 events affected
5. Form dismisses immediately
6. Console: "✅ No events to update"
```

## Debug Logging

Comprehensive console output for tracking:

### Analysis Phase
```
📍 [Coordinate Analysis] Location: Loft
   Old: (39.753, -104.999)
   New: (39.800, -105.050)
   Distance change: 3.21 miles
   Affected events: 45

🏠 [Location Update] Starting update for: Loft
   ℹ️ Coordinate change detected - requesting user review
   📊 Impact: 45 events, 3.21 miles
```

### User Review Phase
```
(User sees review UI)
(User selects events and taps "Update 45 Events")

🔄 [Manual Review] Applying coordinate updates to 45 events
   ✅ Updated event ABC-123: Jan 15, 2024
   ✅ Updated event DEF-456: Jan 16, 2024
   ...
✅ Complete: 45 events updated
```

## Event Model Structure

Events store coordinates in two ways:

```swift
struct Event {
    var location: Location      // Reference
    var latitude: Double         // Copied at creation
    var longitude: Double        // Copied at creation
    var city: String?           // Copied at creation
    var country: String?        // May differ from location
}
```

**Before this feature**:
- Coordinates copied once at event creation
- Never updated when location changed
- Events could be miles from their location's coordinates

**After this feature**:
- Coordinates automatically sync on location update
- Small changes: seamless
- Large changes: user control

## Configuration

**Visual Threshold** (in `LocationCoordinateUpdater.swift`):
```swift
static let autoUpdateThresholdMiles: Double = 5.0
```

This value is now used for **visual indication only**:
- **< 5 miles**: Blue info icon (minor GPS adjustment)
- **≥ 5 miles**: Orange warning icon (significant relocation)

**Behavior**: Review UI **always** appears regardless of distance when events are affected.

Adjust this value to change the visual threshold:
- Lower value (e.g., 1.0) = More orange warnings
- Higher value (e.g., 10.0) = More blue info icons
- Recommended: 5.0 miles (reasonable distinction between refinement vs relocation)

## Impact on Other Features

### Trip Calculations
- Trips now use updated event coordinates
- Distances recalculated automatically
- Run "Refresh Trips" after large location changes

### Maps
- Events now appear at correct locations
- No more "ghost" event markers at old coordinates

### Country Detection
- Events inherit updated country from location
- Country field updated if provided
- Falls back to geocoding if needed

## Testing Scenarios

### Test 1: Small Change
1. Edit "Loft" location
2. Change lat from 39.753 to 39.755 (0.2 mi)
3. Save → Should show blue info icon review UI
4. Verify impact message shows 0.2 miles
5. Select events and apply updates

### Test 2: Large Change
1. Edit "Loft" location
2. Change to coordinates 10+ miles away
3. Save → Should show orange warning icon review UI
4. Verify map shows both locations clearly separated
5. Select events to update
6. Confirm updates applied

### Test 3: No Events
1. Edit location with zero events
2. Change coordinates
3. Save → Should complete instantly without review UI

### Test 4: New Location
1. Create new location
2. Save → No propagation (no existing events)
3. Should complete instantly

## Future Enhancements

Potential additions:
- Bulk coordinate sync tool for historical data
- Undo coordinate updates
- Coordinate history tracking
- Automatic reverse geocoding after updates
- Batch location coordinate updates

## Migration Guide

### For Existing Data

If you have events with outdated coordinates, use the sync utility:

```swift
for location in store.locations {
    let outdatedEvents = LocationCoordinateUpdater.findEventsNeedingSync(
        location: location,
        events: store.events
    )
    
    if !outdatedEvents.isEmpty {
        print("Location '\(location.name)' has \(outdatedEvents.count) events needing sync")
        // Apply updates manually or via review UI
    }
}
```

### Breaking Changes
None - this is additive functionality.

**Old code still works**:
```swift
store.update(location)  // Still functions, no propagation
```

**New code provides propagation**:
```swift
store.updateLocationWithCoordinatePropagation(location)  // With propagation
```

## Files Modified/Added

### Added
1. `LocationCoordinateUpdater.swift` - Core logic (~175 lines)
2. `LocationCoordinateReviewView.swift` - Review UI (~350 lines)

### Modified
1. `LocationFormView.swift` - Integration (~20 lines changed)
   - Added review UI state
   - Updated save button logic
   - Added sheet presentation

### Total Lines of Code
~545 lines added across 3 files

## Key Benefits

✅ **Automatic Sync** - Small changes update silently  
✅ **User Control** - Large changes require approval  
✅ **Visual Feedback** - Map shows old vs new locations  
✅ **Selective Updates** - Choose which events to update  
✅ **Debug Logging** - Track all coordinate changes  
✅ **Trip Accuracy** - Distances now calculated correctly  
✅ **Map Accuracy** - Events appear at correct locations  
✅ **Zero Data Loss** - Review before updating prevents mistakes  
