# Charts Tab & Unknown Locations Fix

## Issues Fixed

### 1. ✅ Charts Tab (Stays Overview) Color Not Updating
**File**: `Charts.swift`
**Method**: `calc(selectedYear:filteredEvents:)`

**Problem**: Chart was using `location.theme.mainColor` instead of `location.effectiveColor`

**Fix**:
```swift
// BEFORE:
let color = location.theme.mainColor

// AFTER:
let color = location.effectiveColor
```

---

### 2. ✅ Charts Tab Not Refreshing on Location Update  
**File**: `DonutChartView.swift`

**Problem**: Chart wasn't listening to `dataUpdateToken` changes

**Fix**: Added onChange listener and refresh mechanism:
```swift
@State private var refreshID = UUID()

var body: some View {
    VStack { ... }
        .id(refreshID)
        .onChange(of: store.dataUpdateToken) { _, _ in
            refreshID = UUID()  // Force view refresh
        }
}
```

---

### 3. ✅ "Unknown" Locations Appearing in Infographics
**File**: `InfographicsView.swift`
**Method**: `computeTopLocations(from events:)`

**Problem**: Using event's embedded location which could be stale or mismatched. When events had location IDs that didn't exist in the current `store.locations` array, they would show as "Unknown".

**Root Cause**: 
- Events store a snapshot of the location at the time they were created
- If a location was deleted or its ID changed, the event still has the old location
- The old code used `firstEvent.location` which could be outdated

**Fix**: Look up current location from store by ID:
```swift
// BEFORE:
guard let firstEvent = value.first else { return nil }
let location = firstEvent.location  // Using embedded location

// AFTER:
guard let currentLocation = store.locations.first(where: { $0.id == locationID }) else {
    return nil  // Skip if location no longer exists in store
}
// Use currentLocation (from store)
```

**Benefits**:
- ✅ Only shows locations that actually exist in store
- ✅ Always uses current location name and color
- ✅ Eliminates "Unknown" entries from orphaned location IDs
- ✅ Debug logging shows which location IDs are orphaned

---

## Debug Output

### Charts Tab:
```
📊 [Charts] Location: [Name]
   Theme: [Theme]
   CustomColorHex: [#RRGGBB or nil]
   Using effectiveColor
```

### Infographics Tab:
```
📊 [Infographics] Computing color for location: [Name]
   Theme: [Theme]
   CustomColorHex: [#RRGGBB or nil]
   Using effectiveColor
```

**If orphaned location:**
```
⚠️ [Infographics] Location ID [UUID] not found in store
   Events count: [N]
   Event location name: [Old Name]
```

---

## Why "Unknown" Locations Appeared

### Scenario 1: Deleted Locations
1. Location "Beach House" existed with ID `ABC-123`
2. User created 10 events at "Beach House"
3. Events stored with embedded location (ID: `ABC-123`, name: "Beach House")
4. User deleted "Beach House" from locations
5. Events still reference `ABC-123` but location doesn't exist in store
6. Old code used `firstEvent.location` → showed "Beach House" (orphaned)
7. **New code**: Returns `nil` → location not shown in top locations ✅

### Scenario 2: Mismatched Location IDs
1. Import from backup with different location IDs
2. Events reference old IDs
3. Locations in store have new IDs
4. Old code: Used embedded location → duplicate/mismatched entries
5. **New code**: Looks up by ID → only shows if ID matches ✅

### Scenario 3: Data Corruption
1. Database inconsistency
2. Event's location.id doesn't match any store.locations[].id
3. Old code: Showed whatever was in event.location
4. **New code**: Skips these events → cleaner data ✅

---

## Testing Results Expected

### Before Fix:
```
Top Locations:
- Unknown (4 events)      ← Orphaned from deleted location
- Unknown (2 events)      ← Different orphaned location
- Loft (45 events)
- Cabo (20 events)
- Unknown (3 events)      ← Another orphaned location
```

### After Fix:
```
Top Locations:
- Loft (45 events)        ← Only valid locations shown
- Cabo (20 events)
- Arrowhead (15 events)
```

**Note**: The orphaned events still exist but aren't shown in "Top Locations" since their location doesn't exist in the store. This is correct behavior.

---

## Optional Cleanup: Finding Orphaned Events

If you want to find and fix orphaned events, you can add this utility:

```swift
func findOrphanedEvents() -> [Event] {
    let validLocationIDs = Set(store.locations.map { $0.id })
    return store.events.filter { event in
        !validLocationIDs.contains(event.location.id)
    }
}
```

Then either:
1. **Reassign** them to "Other" location
2. **Delete** them (if they're truly invalid)
3. **Recreate** the missing locations

---

## Complete Flow Now

1. **User changes location color**
   ```
   🎨 LOCATION UPDATE START
   🎨 Calling bumpDataUpdate()
   ```

2. **Charts Tab responds**
   ```
   📊 [DonutChartView] Data update token changed
   → Force chart refresh
   → Recompute with new colors
   ```

3. **Charts recompute**
   ```
   📊 [Charts] Using effectiveColor
   → Custom colors applied
   ```

4. **Infographics responds**
   ```
   🔄 Data updated - clearing memoization cache
   → Recompute derived data
   ```

5. **Infographics recompute**
   ```
   📊 [Infographics] Using effectiveColor
   → Only valid locations shown
   → Custom colors applied
   ```

---

## Files Modified

1. **Charts.swift**
   - ✅ Changed `theme.mainColor` → `effectiveColor`
   - ✅ Added `#if DEBUG` logging

2. **DonutChartView.swift**
   - ✅ Added `refreshID` state
   - ✅ Added `.id(refreshID)` modifier
   - ✅ Added `.onChange(of: store.dataUpdateToken)` listener

3. **InfographicsView.swift**
   - ✅ Changed to look up location from store by ID
   - ✅ Added `guard` to skip orphaned locations
   - ✅ Added `#if DEBUG` logging for orphaned locations
   - ✅ Using `effectiveColor` instead of `theme.mainColor`

---

## Testing Checklist

- [ ] Change location color in Manage Locations
- [ ] Go to Charts tab → color updated immediately ✅
- [ ] Go to Infographics tab → color updated immediately ✅
- [ ] Check "Top Locations" → no "Unknown" entries ✅
- [ ] Filter by year in Infographics → no "Unknown" entries ✅
- [ ] Check debug console for orphaned location warnings

---

## Debug Console Check

If you see this warning:
```
⚠️ [Infographics] Location ID ABC-123 not found in store
   Events count: 4
   Event location name: Old Location Name
```

**This means**: You have 4 events referencing a deleted location "Old Location Name". These events are excluded from Top Locations (which is correct), but you may want to:

1. Reassign them to another location, or
2. Delete them if they're invalid

---

## Summary

**What Was Broken**:
- ❌ Charts tab used `theme.mainColor` (no custom colors)
- ❌ Charts tab didn't refresh on location updates
- ❌ Infographics showed "Unknown" for orphaned locations
- ❌ Infographics used embedded location (could be stale)

**What Now Works**:
- ✅ Charts tab uses `effectiveColor` (custom colors work)
- ✅ Charts tab refreshes immediately on location updates
- ✅ Infographics skips orphaned locations (no "Unknown")
- ✅ Infographics uses current location from store (always fresh)
- ✅ All `#if DEBUG` logging follows claude.md guidelines

---

**Status**: 🟢 Fixed and Ready for Testing  
**Impact**: Charts and Infographics now properly update with location colors  
**Side Effect**: Orphaned events no longer show in Top Locations (correct behavior)
