# Location Data Migration Fixes

## Issues Fixed

### 1. **City Names Still Had "City, Country" Format**

**Problem:** After migration, many events still showed:
```
City: Calgary, Canada
Country: Canada
```

**Root Cause:** The migration logic only updated fields when they were `nil`, but didn't clean up existing city fields that contained commas (like "Calgary, Canada").

**Fix:** 
- Changed the parsing logic to **always** update the city field to the cleaned version when commas are detected
- Now separates "Calgary, Canada" into:
  - City: "Calgary"
  - Country: "Canada"

**Code Changes in `LocationDataMigrator.swift`:**
```swift
// OLD - Only updated if nil
if parsed.state != nil {
    updated.state = parsed.state ?? updated.state
}

// NEW - Always clean the city field
updated.city = parsed.city
wasModified = true

if let parsedState = parsed.state {
    updated.state = parsedState
    wasModified = true
}
```

### 2. **88 Geocoding Errors with No Details**

**Problem:** The migration reported 88 geocoding errors but didn't provide any information about what failed.

**Root Cause:** Errors were counted but not logged with details.

**Fix:**
- Added `errorDetails: [String]` array to `MigrationStats` struct
- Each failed geocoding now records specific details:
  - For locations: `"Location: 'Home' at (40.7128, -74.0060)"`
  - For events: `"Event on Jan 15, 2024 at (51.0447, -114.0719)"`
- UI now shows expandable error details section

**New Features in UI:**
- "Show Details" / "Hide Details" button when errors exist
- Lists up to 20 detailed error messages
- Shows count of additional errors if more than 20

### 3. **Events Were Being Skipped Unnecessarily**

**Problem:** Events with state data were skipped entirely, even if their city field had "City, Country" format.

**Fix:** 
- Removed the early skip condition for events with state data
- Now processes all "Other" location events to:
  1. First parse city names that contain commas
  2. Then geocode only if state/country still missing

**Code Changes:**
```swift
// OLD - Skipped if state exists
if event.state != nil {
    stats.eventsSkipped += 1
    continue
}

// NEW - Always parse city if needed, then geocode missing fields
// Step 1: Parse city field if it contains commas
if let city = event.city, city.contains(",") {
    let parsed = EnhancedGeocoder.parseManualEntry(city)
    updated.city = parsed.city
    // ... update state and country from parsing
}

// Step 2: Only geocode if still missing data
if (updated.state == nil || updated.country == nil) && (coordinates exist) {
    // geocode...
}
```

## New Features

### Re-run Capability
- After completion, if data was parsed or errors occurred, users can now "Run Again"
- Useful for:
  - Processing remaining unparsed city names
  - Retrying failed geocoding attempts
  - Ensuring all data is cleaned up

### Better Progress Feedback
- More detailed console logging shows what's happening for each location/event
- UI shows clear counts of what was processed vs. skipped

## How to Use

1. **First Run:** Run the migration from Home → Options → Enhance Location Data
2. **Check Results:** Review the statistics and any errors
3. **Re-run if Needed:** If you see errors or parsed data, click "Run Again" to process remaining items
4. **Verify Data:** Check your events in Travel History to confirm city names are clean

## Expected Results After Fix

**Before:**
```
City: Calgary, Canada
Country: Canada
```

**After:**
```
City: Calgary
State: Alberta
Country: Canada
```

## Technical Details

### Parsing Logic (EnhancedGeocoder.parseManualEntry)
- **1 component:** "Denver" → city only
- **2 components (2-char):** "Denver, CO" → city + state (assumes US)
- **2 components (long):** "Paris, France" → city + country
- **3 components:** "Toronto, ON, Canada" → city + state + country

### Rate Limiting
- 200ms delay between geocoding calls
- Prevents hitting Apple's CLGeocoder rate limits
- Progress shown in real-time during migration

### Error Scenarios
Common geocoding failures:
- Invalid/zero coordinates
- Coordinates in oceans or remote areas
- Apple Maps data not available for region
- Network timeout or rate limiting

## Testing Recommendations

1. Run migration on small dataset first
2. Check console logs for detailed progress
3. Review error details in UI
4. Verify a few events manually in different countries
5. Re-run if needed to catch remaining items
