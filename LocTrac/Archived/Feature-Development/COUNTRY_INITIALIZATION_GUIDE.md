# Country Field Initialization Guide

## Overview
This document explains how the country field is automatically populated for all locations, including "Other" locations, using reverse geocoding.

## Problem
"Other" locations use latitude/longitude coordinates that can change with each event. Previously, these locations didn't have their country field populated, which caused them to be excluded from the US vs. Outside US filtering in the donut chart view.

## Solution

### 1. **Automatic Migration on App Launch** (DataStore.swift)
When the app loads data, it automatically checks all locations for missing country fields:

```swift
func loadData() {
    // ... load locations and events ...
    
    // Start migration **after** loading data:
    Task { @MainActor in
        await self.migrateCountriesIfNeeded()
    }
}

@MainActor
func migrateCountriesIfNeeded() async {
    // Finds all locations with nil country field
    // Reverse geocodes their coordinates using CLGeocoder
    // Updates and saves the locations with country data
}
```

**What it does:**
- Runs automatically on app launch
- Processes only locations that don't have a country set
- Uses CoreLocation's reverse geocoding to determine country from coordinates
- Saves the updated data automatically

### 2. **Real-Time Updates When Creating/Editing Events** (EventFormView.swift)
When you create or update an event, the location's country field is automatically updated:

```swift
private func performSave() {
    Task { @MainActor in
        if viewModel.updating {
            // Update existing event
            await store.updateEventLocationCountry(event)
            store.update(event)
        } else {
            // Create new events
            await store.updateLocationCountry(
                locationID: selectedLocation.id,
                latitude: viewModel.latitude,
                longitude: viewModel.longitude
            )
            // ... create events ...
        }
    }
}
```

**What it does:**
- Automatically updates the location's country when event coordinates change
- Especially useful for "Other" locations that can have different coordinates per event
- Updates happen before the event is saved, ensuring data consistency

### 3. **Helper Methods in DataStore**

#### `updateLocationCountry(locationID:latitude:longitude:)`
- Updates a specific location's country field
- Checks if coordinates changed or country is missing
- Only performs reverse geocoding when necessary

#### `updateEventLocationCountry(_:)`
- Convenience method that takes an Event
- Automatically extracts location ID and coordinates
- Calls `updateLocationCountry` with the right parameters

## How It Works

### The Reverse Geocoding Process
1. Takes latitude and longitude coordinates
2. Creates a `CLLocation` object
3. Uses `CLGeocoder` to perform reverse geocoding
4. Extracts the country name from the returned placemark
5. Updates the location's country field
6. Saves the data

### ReverseGeocoderHelper (ReverseGeocoderHelper.swift)
```swift
enum ReverseGeocoderHelper {
    static let shared = CLGeocoder()
    
    static func countryString(latitude: Double, longitude: Double) async throws -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let placemarks = try await shared.reverseGeocodeLocation(location)
        return placemarks.first?.country
    }
}
```

## Impact on Donut Chart View

With country fields properly populated, the donut chart now correctly:
- Filters events by US vs. Outside US regions
- Shows accurate totals in the center of the chart
- Displays proper breakdowns in the summary section

### The totals calculation (DonutChartView.swift):
```swift
private var totals: (total: Int, us: Int, outsideUS: Int) {
    // Filters events by year
    // Counts US events (country == "United States" || "USA")
    // Counts Outside US events (country != "United States" && != "USA")
    // Returns all three counts
}
```

## Testing the Feature

### To verify it's working:

1. **Check existing data:**
   - Launch the app
   - Look for console output: "Starting country migration for X locations"
   - Check if "Other" locations now have country data

2. **Create new "Other" event:**
   - Create an event with the "Other" location
   - Set coordinates (latitude/longitude)
   - Save the event
   - Check the location's country field is populated

3. **View in Donut Chart:**
   - Go to the charts view
   - Filter by "US" or "Outside US"
   - Verify "Other" location events appear in the correct category

## Error Handling

The system includes error handling for:
- Network failures during reverse geocoding
- Invalid coordinates
- Missing or nil values

Errors are logged to the console but don't crash the app. If reverse geocoding fails, the location's country field remains nil and can be retried on the next event save or app launch.

## Performance Considerations

- **On Launch:** Migration only runs once for locations missing country data
- **On Save:** Only reverse geocodes if coordinates changed or country is missing
- **Async/Await:** All geocoding happens asynchronously to avoid blocking the UI
- **Rate Limiting:** CLGeocoder automatically handles Apple's rate limits

## Future Enhancements

Possible improvements:
1. Add a manual "Refresh Country Data" button in settings
2. Cache reverse geocoding results to reduce API calls
3. Add a progress indicator during bulk migration
4. Support for state/province level filtering
5. Handle special cases like territories or disputed regions
