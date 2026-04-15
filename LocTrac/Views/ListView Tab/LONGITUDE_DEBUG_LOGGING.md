# Longitude Save Issue - Debugging Addition

## Issue
User reported that longitude values are not being saved when editing events with "Other" location, but latitude is saving correctly.

## Investigation
After reviewing the code, both latitude and longitude appear to be handled identically:
- Both are declared as `@State private var` 
- Both are initialized from `event.latitude` and `event.longitude` in `init()`
- Both have text field bindings that update the Double values
- Both are updated in the locationManager onChange handler
- Both are assigned to `updatedEvent` in `saveChanges()`

The code structure appears correct, suggesting the issue may be elsewhere in the data flow.

## Debug Logging Added

To help identify where the longitude value is being lost, comprehensive debug logging has been added to `ModernEventEditorSheet`:

### 1. TextField Value Updates
**Latitude TextField:**
```swift
if let doubleValue = Double(newValue) {
    latitude = doubleValue
    print("🔍 [Latitude TextField] Updated to: \(latitude)")
} else {
    print("⚠️ [Latitude TextField] Failed to parse: \(newValue)")
}
```

**Longitude TextField:**
```swift
if let doubleValue = Double(newValue) {
    longitude = doubleValue
    print("🔍 [Longitude TextField] Updated to: \(longitude)")
} else {
    print("⚠️ [Longitude TextField] Failed to parse: \(newValue)")
}
```

### 2. Location Manager Updates
```swift
.onChange(of: locationManager.location) { _, newValue in
    guard let loc = newValue else { return }
    latitude = loc.coordinate.latitude
    longitude = loc.coordinate.longitude
    latitudeText = String(latitude)
    longitudeText = String(longitude)
    
    print("🔍 [LocationManager] Got location - Latitude: \(latitude), Longitude: \(longitude)")
    
    Task {
        await reverseGeocodeAndSetCity(for: loc)
    }
}
```

### 3. Save Operation
```swift
private func saveChanges() {
    // Debug logging
    print("🔍 [ModernEventEditorSheet] Saving event:")
    print("   Latitude: \(latitude)")
    print("   Longitude: \(longitude)")
    print("   Location: \(selectedLocation.name)")
    
    // ... update event properties ...
    
    print("   Updated Event - Latitude: \(updatedEvent.latitude), Longitude: \(updatedEvent.longitude)")
    
    // Save via store
    if let index = store.events.firstIndex(where: { $0.id == event.id }) {
        store.events[index] = updatedEvent
        print("   After assignment to store - Latitude: \(store.events[index].latitude), Longitude: \(store.events[index].longitude)")
        store.save()
    }
    
    dismiss()
}
```

## How to Use the Debug Output

When testing the edit event functionality, watch the Xcode console for:

### Scenario 1: Manual Entry
1. User types in latitude field → should see: `🔍 [Latitude TextField] Updated to: X.XXX`
2. User types in longitude field → should see: `🔍 [Longitude TextField] Updated to: Y.YYY`
3. User taps Save → should see:
   ```
   🔍 [ModernEventEditorSheet] Saving event:
      Latitude: X.XXX
      Longitude: Y.YYY
      Location: Other
      Updated Event - Latitude: X.XXX, Longitude: Y.YYY
      After assignment to store - Latitude: X.XXX, Longitude: Y.YYY
   ```

### Scenario 2: Get Current Location
1. User taps "Get Current Location" → should see: 
   ```
   🔍 [LocationManager] Got location - Latitude: X.XXX, Longitude: Y.YYY
   ```
2. User taps Save → should see the same output as Scenario 1

### Identifying the Problem

**If longitude shows correctly in early logs but wrong in later logs:**
- The issue is in the save/store mechanism

**If longitude never appears in the TextField logs:**
- The text field binding isn't working correctly
- Could be a SwiftUI state update issue

**If longitude appears correctly until "After assignment to store":**
- The issue is in how `store.events[index]` is being updated
- Possible struct mutation issue or DataStore problem

**If longitude appears correctly in all logs but still doesn't persist:**
- The issue is in `DataStore.save()` or the export/encoding logic

## Next Steps

1. **Run the app and test editing an "Other" location event**
2. **Try both manual entry and "Get Current Location"**
3. **Check the Xcode console output**
4. **Compare the debug output for latitude vs longitude**
5. **Report back which step shows different values**

This will help pinpoint exactly where in the data flow the longitude value is being lost.

## Possible Issues to Investigate

Based on where the logs show a discrepancy:

1. **TextField binding issue** - Check if there's a SwiftUI view update cycle problem
2. **State mutation issue** - Event is a struct, ensure proper copy-on-write semantics
3. **DataStore.save() issue** - Check the save/export logic in DataStore
4. **Encoding issue** - Verify Export.EventData and Import.Event handle longitude correctly

## Files Modified

- `ModernEventsCalendarView.swift` - Added comprehensive debug logging

---

**Date**: 2026-04-11
**Issue**: Longitude not saving in Edit Event for "Other" location
**Status**: Debug logging added, awaiting test results
