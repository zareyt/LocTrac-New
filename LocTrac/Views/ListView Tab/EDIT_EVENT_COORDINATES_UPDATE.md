# Edit Event Coordinates Update

## Summary
Added latitude/longitude fields and "Get Current Location" functionality to the Edit Event sheet when "Other" location is selected, matching the behavior of the New Event form.

## Changes Made

### File: `ModernEventsCalendarView.swift`

#### 1. Added Imports
- Added `import CoreLocation` to support location services and geocoding

#### 2. Updated `ModernEventEditorSheet` State Properties
Added new state properties to manage coordinates:
```swift
@State private var latitude: Double
@State private var longitude: Double
@State private var latitudeText: String
@State private var longitudeText: String
@StateObject private var locationManager = LocationManager()
@State private var geocodeError: String?
```

#### 3. Added `isOtherSelected` Computed Property
```swift
private var isOtherSelected: Bool {
    guard let other = store.locations.first(where: { $0.name == "Other" }) else { return false }
    return selectedLocation.id == other.id
}
```

#### 4. Updated Initializer
Initialize the new coordinate-related state properties from the event:
```swift
_latitude = State(initialValue: event.latitude)
_longitude = State(initialValue: event.longitude)
_latitudeText = State(initialValue: String(event.latitude))
_longitudeText = State(initialValue: String(event.longitude))
```

#### 5. Added Coordinates Section to Form
Conditionally displays coordinates section when "Other" location is selected:
```swift
// Coordinates Section (only for "Other" location)
if isOtherSelected {
    coordinatesSection
}
```

#### 6. Implemented `coordinatesSection` View
Complete coordinates section matching the New Event form implementation:
- **Get Current Location button** with loading state
- **Status indicators** (success/error messages)
- **Latitude field** with numeric keyboard
- **Longitude field** with numeric keyboard
- **Warning message** when coordinates are 0.0
- **Automatic city geocoding** when location is fetched
- **Manual coordinate entry** support

Key features:
- Uses `LocationManager` to request current location
- Shows loading spinner while fetching location
- Displays success/error states
- Reverse geocodes coordinates to populate city field
- Text fields bound to both string and double values
- Warning banner if coordinates are missing (0.0, 0.0)

#### 7. Added Reverse Geocoding Helper
```swift
@MainActor
private func reverseGeocodeAndSetCity(for location: CLLocation) async {
    geocodeError = nil
    do {
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        if let placemark = placemarks.first {
            let cityName = placemark.locality ?? placemark.administrativeArea ?? ""
            if !cityName.isEmpty {
                city = cityName
            }
        }
    } catch {
        geocodeError = "Could not determine city"
    }
}
```

#### 8. Updated `saveChanges()` Method
Changed to save the event's latitude/longitude instead of the location's:
```swift
// Before:
updatedEvent.latitude = selectedLocation.latitude
updatedEvent.longitude = selectedLocation.longitude

// After:
updatedEvent.latitude = latitude
updatedEvent.longitude = longitude
```

This allows "Other" location events to have their own unique coordinates.

## User Experience

### When Editing a Named Location Event
- No coordinates section is displayed
- Behavior unchanged from before

### When Editing an "Other" Location Event
1. Coordinates section appears below Location section
2. User sees current latitude/longitude values from the event
3. User can:
   - Tap "Get Current Location" to fetch device location
   - Manually enter/edit latitude and longitude values
   - See automatic city name population via reverse geocoding
4. Warning appears if coordinates are 0.0, 0.0
5. All coordinate changes are saved with the event

## Implementation Details

### State Management
- Uses `@StateObject` for `LocationManager` to persist across view updates
- Separate `latitudeText` and `longitudeText` for TextField binding
- Converts between String and Double for proper numeric input

### Location Services Integration
- Reuses existing `LocationManager` class
- Shows loading state while requesting location
- Displays success/error messages with appropriate icons
- Handles permission states automatically

### Geocoding
- Uses `CLGeocoder` for reverse geocoding
- Populates city field automatically when location is fetched
- Gracefully handles geocoding errors

### UI/UX Consistency
- Matches exact styling and behavior from `ModernEventFormView`
- Uses same icons, colors, and spacing
- Maintains form section organization
- Provides clear visual feedback for all states

## Testing Checklist

- [ ] Verify coordinates section appears for "Other" location events
- [ ] Verify coordinates section hidden for named location events
- [ ] Test "Get Current Location" button functionality
- [ ] Test manual latitude/longitude entry
- [ ] Verify reverse geocoding populates city field
- [ ] Verify coordinate values are saved correctly
- [ ] Test with location permissions denied
- [ ] Test with location permissions granted
- [ ] Verify warning appears for 0.0, 0.0 coordinates
- [ ] Test switching between "Other" and named locations

## Related Files
- `ModernEventFormView.swift` - Reference implementation for new events
- `LocationManager.swift` - Location services manager
- `Event.swift` - Event model with latitude/longitude fields

---

**Date**: 2026-04-11
**Related Issue**: CLAUDE.md task - Edit event should show coordinates for "Other" location
