# Location UI Fixes & Master-Detail Architecture Change

## Summary
Fixed label display issues and implemented master-detail relationship for location data in events.

## Issues Fixed

### 1. ✅ Label Text Missing (Only Icons Showing)
**Problem**: Using `.fixedSize()` on Labels caused text to disappear, only showing icons

**Solution**: Removed `.fixedSize()` and `.frame(maxWidth:)` modifiers
- Labels now show full text with icons
- Natural SwiftUI layout handles sizing
- Spacer() still provides proper alignment

**Files Changed**:
- LocationsManagementView.swift (LocationEditorSheet)
- LocationFormView.swift
- TravelHistoryView.swift (StayDetailSheet)

### 2. ✅ Master-Detail Relationship for Location Data
**Problem**: Events showed **stale/old** location data after editing a location

**Root Cause**: 
- Events store an **embedded snapshot** of Location at creation time
- When you update a Location in the master list, existing Events still have old embedded data
- `event.effectiveCity` was returning `location.city` from the OLD snapshot

**Solution**: Implemented live lookup in TravelHistoryView's StayDetailSheet
```swift
// NEW: Live lookup of current location data
private var currentLocation: Location? {
    store.locations.first(where: { $0.id == event.location.id })
}

private var displayCity: String {
    if event.location.name == "Other" {
        return event.city ?? "Unknown"  // Event-specific for "Other"
    } else {
        // Use current location data (live lookup from DataStore)
        return currentLocation?.city ?? event.location.city ?? "Unknown"
    }
}
```

**Behavior**:
- ✅ "Other" location events → Show event-specific city/state/country
- ✅ Named location events → Show **current** location data from DataStore (live lookup)
- ✅ When you edit a location, ALL events at that location now show updated data
- ✅ If location is deleted, falls back to embedded snapshot

### 3. ✅ Travel History List Jumping (Future Fix)
**Issue Identified**: When tapping an event in Travel History, the list may reorder
**Likely Cause**: List is being re-sorted on state changes
**Status**: Needs investigation - may require stable sort keys or id-based selection

## Architecture Change: Embedded Snapshot vs Live Lookup

### Previous Design (CLAUDE.md line 521)
> `Event.location` is an **embedded snapshot**, not a live reference. When a location is updated, existing events are NOT auto-updated — this is intentional (historical record).

### New Design (Hybrid Approach)
**Storage**: Still embedded snapshot (no changes to data model)
**Display**: Live lookup in read-only views

| View | Strategy | Reasoning |
|------|----------|-----------|
| Event Storage | Embedded snapshot | Preserves historical data if location is deleted |
| Travel History (read) | **Live lookup** | Shows current location info for better UX |
| Event Edit Forms | Embedded snapshot | Works with current data model |
| Charts/Analytics | Embedded snapshot | Historical accuracy for time-series analysis |

**Benefits**:
1. ✅ Users see current location data when viewing events
2. ✅ Edit location once, all events update automatically (in views)
3. ✅ Still have fallback if location is deleted (embedded data)
4. ✅ No migration needed - data model unchanged

**Trade-offs**:
- Historical accuracy: If a location truly moved cities, old events now show new city
- Performance: Small O(n) lookup per event display (negligible for typical data sizes)

## Code Changes

### LocationsManagementView.swift
```swift
// Before (broken - no text labels)
HStack(spacing: 12) {
    Label("Name", systemImage: "mappin.circle.fill")
        .fixedSize()  // ❌ Hides text
    Spacer()
    TextField("Required", text: $editor.name)
        .frame(maxWidth: 200)  // ❌ Too constraining
}

// After (working - full labels)
HStack {
    Label("Name", systemImage: "mappin.circle.fill")
        .foregroundColor(.blue)
    Spacer()
    TextField("Required", text: $editor.name)
        .multilineTextAlignment(.trailing)
}
```

### TravelHistoryView.swift - StayDetailSheet
```swift
// NEW: Live location lookup
private var currentLocation: Location? {
    store.locations.first(where: { $0.id == event.location.id })
}

private var displayCity: String {
    if event.location.name == "Other" {
        return event.city ?? "Unknown"
    } else {
        // Live lookup → shows current data
        return currentLocation?.city ?? event.location.city ?? "Unknown"
    }
}

// Applied to State and Country as well
```

### Footer Text Change
```swift
// Before
footer: {
    Text("Location information for this stay")
}

// After (clarifies live lookup behavior)
footer: {
    Text("Current location information (updates when location is edited)")
}
```

## Testing Checklist

### Label Display
- [ ] LocationsManagementView → Edit Location
  - [ ] Verify all labels show text + icons (Name, City, State, Country, Lat, Long)
  - [ ] Verify TextFields are appropriately sized (not too wide)

- [ ] LocationFormView → Add Location
  - [ ] Verify all labels show text + icons
  - [ ] Verify layout is clean and professional

- [ ] TravelHistoryView → View Stay Details
  - [ ] Verify all labels show text + icons
  - [ ] Verify coordinates display with monospaced font

### Master-Detail Relationship
- [ ] **Critical Test: Location Update Propagation**
  1. Open Manage Locations
  2. Edit a location (change City from "Denver" to "Boulder", State from "Colorado" to "CO")
  3. Save changes
  4. Go to Travel History
  5. Tap an event at that location
  6. ✅ **Verify**: City shows "Boulder", State shows "CO" (NEW VALUES)
  7. ✅ **Verify**: Footer says "Current location information (updates when location is edited)"

- [ ] **Test: "Other" Location Events**
  1. Find an event at "Other" location
  2. View details in Travel History
  3. ✅ **Verify**: Shows event-specific city/state/country (not shared with other "Other" events)

- [ ] **Test: Deleted Location Fallback**
  1. (Optional) Delete a location that has events
  2. View those events in Travel History
  3. ✅ **Verify**: Still shows location data (from embedded snapshot)

### Layout Quality
- [ ] All labels are fully visible (no truncation)
- [ ] Proper spacing between label and value
- [ ] Right-aligned values for clean look
- [ ] Color-coded icons help identify field types
- [ ] Forms don't feel cramped or overly wide

## Future Considerations

### Option 1: Keep Hybrid Approach (Recommended)
- Storage: Embedded snapshot
- Display: Live lookup in views
- ✅ Best UX
- ✅ No data migration
- ✅ Preserves historical data if needed

### Option 2: Full Reference IDs (Major Refactor)
- Change `Event.location` from `Location` to `locationID: String`
- Requires data migration
- Requires lookup everywhere
- Breaks export/import compatibility
- ❌ Not recommended for v1.5

### Option 3: Add Sync Button
- Keep embedded snapshots
- Add "Update All Events" button in Location edit form
- User manually chooses when to update
- ❌ Complex UX, error-prone

**Decision**: Keep Hybrid Approach (Option 1)

## Notes for CLAUDE.md Updates

Update the "Known Gotchas & Decisions" section:

```markdown
| **Location in Event** | `Event.location` is an **embedded snapshot** for storage. Display views use live lookup from DataStore to show current location data. This provides master-detail UX while preserving historical data if locations are deleted. See `TravelHistoryView.StayDetailSheet` for reference implementation. |
```

Add to "Coding Conventions":

```markdown
### Location Display Pattern

When displaying location data from events, use live lookup for better UX:

```swift
// ✅ Correct - Live lookup for display
private var currentLocation: Location? {
    store.locations.first(where: { $0.id == event.location.id })
}

private var displayCity: String {
    if event.location.name == "Other" {
        return event.city ?? "Unknown"
    } else {
        return currentLocation?.city ?? event.location.city ?? "Unknown"
    }
}

// ❌ Avoid - Shows stale data
Text(event.location.city ?? "Unknown")  // OLD snapshot

// ✅ Better - Shows current data
Text(displayCity)  // CURRENT data with fallback
```
```

---

**Date**: 2026-04-11  
**Version**: v1.5 (In Development)  
**Related**: CLAUDE.md, Event.swift, TravelHistoryView.swift
