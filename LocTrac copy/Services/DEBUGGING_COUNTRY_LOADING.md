# Debugging Country Loading for "Other" Locations

## Overview
Comprehensive debugging has been added throughout the country loading process to help diagnose why "Other" locations may not be getting their country field populated correctly.

## What to Look For in Console Output

### 1. **On App Launch** (DataStore.swift)

When the app starts, you'll see:

```
=== LOCATION COUNTRY STATUS ===
  - Loft: United States (lat: 39.75331, lon: 104.9992)
  - Arrowhead: United States (lat: 39.632961, lon: 106.562472)
  - Other: ❌ MISSING (lat: 39.75331, lon: 104.9992)
================================
```

**What to check:**
- Does "Other" show `❌ MISSING` for the country?
- Are the lat/lon coordinates correct for "Other"?
- Are they the same as another location (might be using default coords)?

### 2. **During Migration** (DataStore.swift)

After loading, you'll see the migration process:

```
🌍 === STARTING COUNTRY MIGRATION ===
📍 Found 1 location(s) needing country data:
  - Other (ID: abc-123-def)

🔍 Reverse geocoding: Other
   Coordinates: (39.75331, 104.9992)
      🗺️ ReverseGeocoderHelper: Starting reverse geocode
         Latitude: 39.75331
         Longitude: 104.9992
         ✅ Received 1 placemark(s)
         Placemark details:
           - Country: United States
           - ISO Country Code: US
           - Locality: Denver
           - Admin Area: Colorado
   ✅ SUCCESS: Found country 'United States'

💾 Country migration complete and saved!

=== UPDATED LOCATION COUNTRY STATUS ===
  - Loft: United States
  - Arrowhead: United States
  - Other: United States
=====================================
=== MIGRATION COMPLETE ===
```

**What to check:**
- Does migration start at all?
- Does it find "Other" as needing country data?
- Does reverse geocoding succeed or fail?
- If it fails, what's the error message?
- After migration, does "Other" have a country?

### 3. **When Creating/Updating Events** (EventFormView.swift)

When you save an event:

```
💾 === EVENT FORM SAVE TRIGGERED ===
   Updating: false
   Location: Other
   Coordinates: (35.6762, 139.6503)

   ➕ Creating 1 new event(s)
   🌍 Updating location country before creating events...

🔄 === UPDATE LOCATION COUNTRY ===
   Location ID: abc-123-def
   New coordinates: (35.6762, 139.6503)
   Location name: Other
   Current country: United States
   Current coords: (39.75331, 104.9992)
   Coordinates changed: true
   Needs country: false
   🔍 Performing reverse geocoding...
      🗺️ ReverseGeocoderHelper: Starting reverse geocode
         Latitude: 35.6762
         Longitude: 139.6503
         ✅ Received 1 placemark(s)
         Placemark details:
           - Country: Japan
           - ISO Country Code: JP
           - Locality: Tokyo
           - Admin Area: Tokyo
   ✅ SUCCESS: Found country 'Japan'
   📍 Updating coordinates to (35.6762, 139.6503)
   💾 Changes saved!
=== UPDATE COMPLETE ===

   ✅ 1 event(s) created
=== SAVE COMPLETE ===
```

**What to check:**
- Does the save trigger at all?
- Are the coordinates being passed correctly?
- Does it detect coordinates have changed?
- Does reverse geocoding succeed?
- What country is returned?

### 4. **In Donut Chart View** (DonutChartView.swift)

When viewing the chart:

```
📊 === DONUT CHART TOTALS CALCULATION ===
   Year selection: Total
   Total events for year: 15
   Unique locations: ["Arrowhead", "Loft", "Other"]
   Event location countries:
      [OTHER] Date: 2025-03-15, Country: Japan, Coords: (35.6762, 139.6503)
      [OTHER] Date: 2025-03-16, Country: Japan, Coords: (35.6762, 139.6503)
   Country breakdown:
      - Japan: 2 event(s)
      - United States: 13 event(s)
      ✅ Including US event: Loft (united states)
      ✅ Including US event: Arrowhead (united states)
      🌎 Including Outside-US event: Other (japan)
   RESULTS:
      Total: 15
      US: 13
      Outside US: 2
      Unaccounted: 0
=== CALCULATION COMPLETE ===
```

**What to check:**
- Are "Other" events showing up?
- Do they have a country value or `❌ NO COUNTRY`?
- Are they being included in US or Outside US counts?
- Is the "Unaccounted" number greater than 0? (Means events without countries)

## Common Issues and Diagnostics

### Issue 1: "Other" location not showing in migration
**Symptoms:**
```
✅ All locations already have country data. No migration needed.
```
But you know "Other" doesn't have a country.

**Diagnosis:**
- Check the initial location status printout
- "Other" might already have a country from seed data
- The location might not be loaded properly

### Issue 2: Reverse geocoding fails
**Symptoms:**
```
❌ ERROR: The operation couldn't be completed. (kCLErrorDomain error 2.)
CLError code: 2
```

**Common causes:**
- **Error Code 2**: Network error - device not connected to internet
- **Error Code 8**: Geocoding request was cancelled
- **Error Code 1**: Location services permission denied

**Solutions:**
- Check internet connectivity
- Verify location permissions in Settings
- Check if too many requests (Apple rate limits geocoding)

### Issue 3: Events show "❌ NO COUNTRY"
**Symptoms:**
```
Country breakdown:
  - ❌ NO COUNTRY: 5 event(s)
```

**Diagnosis:**
- The location's country field is nil
- Migration might have failed
- Events might have been created before migration completed

**Solutions:**
- Try creating a new event to trigger country update
- Check if migration actually ran and completed
- Look for errors in the migration logs

### Issue 4: "Other" coordinates don't change
**Symptoms:**
```
Coordinates changed: false
Needs country: false
ℹ️ No update needed - coordinates unchanged and country exists
```

**Diagnosis:**
- The event's coordinates match the location's stored coordinates
- This is expected if you're not changing the location
- The location should already have the correct country from previous events

### Issue 5: Events not counted in US/Outside US
**Symptoms:**
```
Unaccounted: 5
```

**Diagnosis:**
- 5 events have no country data
- They're being filtered out by the nil check

**Solutions:**
- Look at which locations have `❌ NO COUNTRY`
- Create new events for those locations to trigger country update
- Or wait for next app restart to trigger migration

## Important Notes

### Rate Limiting
Apple's CLGeocoder has rate limits. The migration includes a 0.5 second delay between requests:
```swift
try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
```

If you have many locations, this prevents hitting the rate limit.

### "Other" Location Behavior
The "Other" location is special because:
1. It's intended to be used for multiple different places
2. Each event can have different coordinates
3. The location's coordinates get updated with each new event
4. The country field reflects the last event's location

**This means:** If you create an event in Tokyo, then one in Paris, the "Other" location will have France as its country and Paris coordinates. Previous events in Tokyo still maintain their Tokyo coordinates but reference the same "Other" location object.

### Events Store Their Own Coordinates
Importantly, events store their own latitude, longitude, and city. They just reference the location by ID. So even though the "Other" location's coordinates change, each event remembers where it actually happened.

## Debugging Checklist

When "Other" locations aren't working:

1. ✅ Check initial location status on app launch
2. ✅ Verify migration runs and finds "Other"
3. ✅ Confirm reverse geocoding succeeds
4. ✅ Check saved country after migration
5. ✅ Create new "Other" event with different coordinates
6. ✅ Verify country updates when saving event
7. ✅ Check donut chart shows correct country for events
8. ✅ Verify events are counted in correct category

## Disabling Debug Logging

Once you've resolved the issue, you may want to remove or reduce the verbose logging. The print statements are in:
- `DataStore.swift` - `loadData()`, `migrateCountriesIfNeeded()`, `updateLocationCountry()`, `updateEventLocationCountry()`
- `EventFormView.swift` - `performSave()`
- `DonutChartView.swift` - `totals` computed property
- `ReverseGeocoderHelper.swift` - `countryString()`

You can comment out or remove the print statements, or wrap them in a debug flag:
```swift
#if DEBUG
print("Debug message")
#endif
```
