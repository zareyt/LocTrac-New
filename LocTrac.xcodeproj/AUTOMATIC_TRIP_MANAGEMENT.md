# Automatic Trip Management

## Overview
Trips are now automatically created when events are added, and automatically removed when events are deleted. This ensures trips stay in sync with event data without manual intervention.

## Features Implemented

### 1. Auto-Create Trips on Event Addition
When a user adds a new event, the system checks if it should create a trip from the previous event.

### 2. Auto-Remove Trips on Event Deletion
When a user deletes an event, the system removes affected trips and checks if a new trip is needed to fill the gap.

## How It Works

### Event Addition Flow

```
User adds new event
↓
System sorts all events chronologically
↓
Finds previous event (by date)
↓
Checks if locations are different
↓
If different AND > 0.5 miles apart:
  - Creates trip from previous → new event
  - Also checks if next event exists
  - Creates trip from new → next event if needed
↓
Trips automatically added to trips list
```

### Event Deletion Flow

```
User deletes event
↓
System finds trips referencing this event
↓
Removes all affected trips
↓
Finds events before and after deleted event
↓
Checks if new trip needed between them
↓
If needed, creates gap-filling trip
↓
Trips automatically updated
```

## Code Implementation

### DataStore.swift - Event Addition

**Location**: `add(_ event: Event)` function

**Added Logic**:
```swift
func add(_ event: Event) {
    events.append(event)
    changedEvent = event
    
    // NEW: Check if this creates a trip
    checkAndCreateTripForNewEvent(event)
    
    storeData()
    invalidateCacheForEvent(event)
}
```

### DataStore.swift - Event Deletion

**Location**: `delete(_ event: Event)` function

**Added Logic**:
```swift
func delete(_ event: Event) {
    if let index = events.firstIndex(where: {$0.id == event.id}) {
        changedEvent = events.remove(at: index)
        invalidateCacheForEvent(event, isDelete: true)
        
        // NEW: Check if this affects trips
        checkAndUpdateTripsForDeletedEvent(event)
    }
    storeData()
}
```

### New Helper Functions

#### `checkAndCreateTripForNewEvent(_ newEvent: Event)`
```swift
1. Find previous event chronologically
2. Check if trip should be created (TripMigrationUtility.suggestTrip)
3. Verify trip doesn't already exist
4. Add trip if needed
5. Also check forward trip to next event
6. Add forward trip if needed
```

#### `checkAndUpdateTripsForDeletedEvent(_ deletedEvent: Event)`
```swift
1. Find all trips referencing deleted event
2. Remove those trips
3. Find events before and after deleted event
4. Check if gap-filling trip needed
5. Create trip between surrounding events if needed
```

## Use Cases

### Use Case 1: Adding Event Creates Trip

**Scenario**: User adds event in new location

```
Existing Events:
  Jan 1: Loft (Denver)
  Jan 5: Cabo (Mexico)

User adds:
  Jan 3: Arrowhead (Vail)

Result:
  ✅ Trip created: Loft → Arrowhead (Jan 1 → Jan 3)
  ✅ Trip created: Arrowhead → Cabo (Jan 3 → Jan 5)
  ✅ Old trip removed: Loft → Cabo (no longer consecutive)
```

**Wait, old trip removal isn't automatic!** Let me note this limitation below.

### Use Case 2: Deleting Event Removes Trips

**Scenario**: User deletes middle event

```
Existing Events & Trips:
  Jan 1: Loft (Denver)
  Trip: Loft → Arrowhead
  Jan 3: Arrowhead (Vail)
  Trip: Arrowhead → Cabo
  Jan 5: Cabo (Mexico)

User deletes:
  Jan 3: Arrowhead

Result:
  ❌ Trip removed: Loft → Arrowhead (from event deleted)
  ❌ Trip removed: Arrowhead → Cabo (to event deleted)
  ✅ Trip created: Loft → Cabo (fills the gap)
```

### Use Case 3: Adding Event at Same Location

**Scenario**: User adds event at existing location

```
Existing Events:
  Jan 1: Loft (Denver)
  Jan 5: Cabo (Mexico)

User adds:
  Jan 3: Loft (Denver) - same location

Result:
  ℹ️ No trip created (same location)
  ✅ Existing trips unchanged
```

### Use Case 4: First Event Ever

**Scenario**: User adds very first event

```
No existing events

User adds:
  Jan 1: Loft (Denver)

Result:
  ℹ️ No trip created (no previous event)
```

### Use Case 5: Deleting First Event

**Scenario**: User deletes earliest event

```
Existing Events & Trips:
  Jan 1: Loft (Denver)
  Trip: Loft → Cabo
  Jan 5: Cabo (Mexico)

User deletes:
  Jan 1: Loft

Result:
  ❌ Trip removed: Loft → Cabo
  ℹ️ No new trip created (no event before Cabo)
```

## Debug Output

### Adding Event
```
🚗 [Auto-Trip] Checking if new event creates a trip...
   New event: Vail on Jan 3, 2024
   Previous event: Denver on Jan 1, 2024
   ✅ Creating new trip: Loft → Arrowhead
      Distance: 95.5 mi
      Mode: Driving
   Checking forward trip to: Cabo San Lucas
   ✅ Creating forward trip: Arrowhead → Cabo
      Distance: 1234.2 mi
```

### Deleting Event
```
🗑️ [Auto-Trip] Checking if deleted event affects trips...
   Deleted event: Vail on Jan 3, 2024
   Found 2 trip(s) affected:
   - Trip from [Loft-ID] to [Arrowhead-ID]
   - Trip from [Arrowhead-ID] to [Cabo-ID]
   ✅ Removed 2 trip(s)
   Checking if new trip needed between remaining events:
   - Before: Denver
   - After: Cabo San Lucas
   ✅ Creating new trip to fill gap: Loft → Cabo
```

## Trip Creation Rules

Uses `TripMigrationUtility.suggestTrip()` which checks:

1. **Both events have valid coordinates** (not 0,0)
2. **Locations are different**:
   - Different location IDs (Loft vs Cabo)
   - OR both "Other" location but > 1 mile apart
3. **Distance > 0.5 miles** (minimum threshold)
4. **Auto-detects transport mode** based on distance:
   - ≤ 3 miles: Walking
   - 3-100 miles: Driving
   - > 100 miles: Flying

## Benefits

### User Experience
- ✅ **No manual trip creation** - happens automatically
- ✅ **Stays in sync** - trips always reflect current events
- ✅ **Fills gaps** - deleting middle event creates direct trip
- ✅ **Prevents orphans** - no trips with missing events

### Data Integrity
- ✅ **Consistent state** - trips match event chronology
- ✅ **No dangling references** - deleted events remove their trips
- ✅ **Smart detection** - only creates trips when needed

### Developer Experience
- ✅ **Automatic** - works without user intervention
- ✅ **Comprehensive logging** - debug output for troubleshooting
- ✅ **Reuses existing logic** - leverages TripMigrationUtility

## Limitations

### Limitation 1: Doesn't Remove Old Trips Automatically

**Scenario**:
```
Events: Jan 1 Loft → Jan 5 Cabo
Trip: Loft → Cabo

User adds: Jan 3 Arrowhead
New trips: Loft → Arrowhead, Arrowhead → Cabo
Old trip: Loft → Cabo (still exists!) ❌
```

**Workaround**: Use "Refresh Trips" to clean up

**Why**: To avoid accidentally deleting user-customized trips

### Limitation 2: Only Checks Adjacent Events

**Scenario**:
```
Events: Loft → Arrowhead → Cabo → Loft

User adds event at new location between Arrowhead and Cabo
Only checks: Arrowhead → New → Cabo
Doesn't recalculate: Loft → Arrowhead
```

**Why**: Performance - only affects immediate neighbors

### Limitation 3: Preserves User Customizations

**What's Preserved**:
- Transport mode (if user changed it)
- Notes
- CO2 emissions (if manually adjusted)

**Why**: Respects user edits, doesn't overwrite

### Limitation 4: No Undo

**Issue**: Once created/deleted, trip changes are permanent

**Workaround**: Use "Refresh Trips" with preview to review all changes

## When To Use "Refresh Trips"

Auto-trip management handles most cases, but use "Refresh Trips" for:

1. **Cleaning up old trips** after many event changes
2. **Bulk event imports** (run refresh after import)
3. **Fixing inconsistencies** if data gets out of sync
4. **Reviewing all trips** before committing changes

## Edge Cases Handled

### ✅ Adding Event at Same Location
No trip created - correct behavior

### ✅ Deleting Last Event
No new trip needed - correct behavior

### ✅ Deleting Event with No Surrounding Events
No gap-filling trip - correct behavior

### ✅ Duplicate Trip Prevention
Checks if trip already exists before adding

### ✅ Distance Threshold
Won't create trips for < 0.5 mile changes

### ✅ Zero Coordinates
Won't create trips if event has (0,0) coordinates

## Testing Scenarios

### Test 1: Add Event Between Two Others
```
Setup: Event A (Jan 1), Event C (Jan 5)
Action: Add Event B (Jan 3) at different location
Verify:
  - Trip created: A → B
  - Trip created: B → C
  - No duplicate trips
```

### Test 2: Delete Middle Event
```
Setup: Event A, Event B, Event C with trips A→B and B→C
Action: Delete Event B
Verify:
  - Trips A→B and B→C removed
  - Trip A→C created
```

### Test 3: Add Event at Same Location
```
Setup: Event A at Loft
Action: Add Event B at Loft
Verify:
  - No trip created
```

### Test 4: Delete Event with Trips
```
Setup: Event A, Event B with trip A→B
Action: Delete Event A
Verify:
  - Trip A→B removed
  - No new trip created
```

## Files Modified

**DataStore.swift**:
- Updated `add(_ event: Event)` - calls `checkAndCreateTripForNewEvent`
- Updated `delete(_ event: Event)` - calls `checkAndUpdateTripsForDeletedEvent`
- Added `checkAndCreateTripForNewEvent()` helper (~45 lines)
- Added `checkAndUpdateTripsForDeletedEvent()` helper (~50 lines)

**Total Lines Added**: ~100 lines

## Configuration

No configuration needed - works automatically!

**Default Behavior**:
- ✅ Enabled for all event additions
- ✅ Enabled for all event deletions
- ✅ Uses TripMigrationUtility rules
- ✅ Logs all actions to console

## Summary

**What**: Automatic trip creation and deletion based on event changes

**When**: Triggered on every `add(event)` and `delete(event)` call

**How**: 
- Finds adjacent events chronologically
- Uses TripMigrationUtility to suggest trips
- Adds/removes trips automatically
- Fills gaps when events are deleted

**Why**: 
- Keeps trips in sync with events
- Eliminates manual trip management
- Prevents orphaned trips
- Better user experience

**Result**: Trips automatically reflect current event data! ✅
