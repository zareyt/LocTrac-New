# City Name "Unknown" Import Issue - Fixed

## Issue
After implementing v1.5 country standardization changes, city names were being imported as "unknown" in some cases.

## Root Cause

The v1.5 changes added new parameters to the `Location` initializer:
- `state: String?` 
- `countryCode: String?`

However, two places in `DataStore.swift` were still using the old initializer signature:

### 1. Event Import Fallback Location
**File:** `DataStore.swift`  
**Line:** ~333 (in `loadFromURL`)

**Before:**
```swift
location: locations.first(where: {$0.id == event.locationID}) ?? 
    Location(name: "Unknown", city: nil, latitude: 0, longitude: 0, theme: .purple)
```

**Problem:** The initializer was using positional parameters from the old signature. This would cause a compiler error or unexpected behavior because the parameters didn't match the new signature.

**After:**
```swift
location: locations.first(where: {$0.id == event.locationID}) ?? 
    Location(
        name: "Unknown",
        city: "Unknown",
        state: nil,
        latitude: 0,
        longitude: 0,
        country: nil,
        countryCode: nil,
        theme: .purple
    )
```

### 2. "Other" Location Creation
**File:** `DataStore.swift`  
**Function:** `ensureOtherLocationExists(saveIfAdded:)`

**Before:**
```swift
let other = Location(
    name: "Other",
    city: "None",
    latitude: 0.0,
    longitude: 0.0,
    country: nil,
    theme: .yellow
)
```

**Problem:** Missing the new `state` and `countryCode` parameters.

**After:**
```swift
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
```

## Impact

### What was broken:
1. **Unknown location fallback** - When an event referenced a location ID that didn't exist, the fallback "Unknown" location was created incorrectly
2. **"Other" location creation** - When the "Other" location was auto-created on first launch or import, it was using the old initializer

### What was causing "unknown" city names:
- The fallback Location in event imports had `city: nil`
- When displayed using `Location.fullAddress` computed property, this would return "Unknown"
- Events that couldn't find their referenced location would show as "Unknown" for the city

## Fix Details

### Changes Made

1. **Updated fallback Location creation** to use named parameters with all required fields:
   - `city: "Unknown"` instead of `city: nil`
   - Added `state: nil`
   - Added `country: nil`
   - Added `countryCode: nil`

2. **Updated "Other" location creation** to include new v1.5 fields:
   - Added `state: nil`
   - Added `countryCode: nil`

### Why This Fixes the Issue

1. The fallback Location now has `city: "Unknown"` instead of `nil`
2. All Location initializer calls now use the correct v1.5 signature
3. The "Other" location is created with all expected fields

## Testing Recommendations

### Test Case 1: Import Old Backup
1. Import a backup from before v1.5
2. Verify all locations load correctly
3. Check that city names are preserved

### Test Case 2: Missing Location Reference
1. Create a backup with an event that references a non-existent location ID
2. Load the backup
3. Verify the fallback "Unknown" location displays correctly
4. Check that the city shows as "Unknown" (not blank or causing errors)

### Test Case 3: First Launch
1. Delete app data to simulate first launch
2. Go through first launch wizard
3. Verify "Other" location is created properly
4. Check that "Other" location has city: "None"

## Related Files

- `DataStore.swift` - Location initializer calls fixed
- `Locations.swift` - Location struct with v1.5 signature
- `ImportExport.swift` - Import/Export structures (unchanged, working correctly)

## v1.5 Location Initializer Signature

For reference, the correct v1.5 Location initializer:

```swift
init(id: String = UUID().uuidString,
     name: String,
     city: String?,
     state: String? = nil,      // v1.5: State/province
     latitude: Double,
     longitude: Double,
     country: String? = nil,
     countryCode: String? = nil, // v1.5: ISO country code
     theme: Theme,
     imageIDs: [String]? = nil,
     customColorHex: String? = nil)
```

## Prevention

To prevent similar issues in the future:

1. **When adding new required parameters to initializers:**
   - Search for all calls to that initializer across the codebase
   - Use named parameters instead of positional parameters when possible
   - Update all calls to include new parameters (even if nil/default)

2. **Code Review Checklist:**
   - [ ] All Location initializer calls use named parameters
   - [ ] All Location initializer calls include v1.5 fields (state, countryCode)
   - [ ] Fallback/default Locations are properly initialized
   - [ ] "Other" location creation includes all fields

---

**Date**: 2026-04-11  
**Version**: v1.5 (In Development)  
**Issue**: City names importing as "unknown"  
**Status**: ✅ Fixed
