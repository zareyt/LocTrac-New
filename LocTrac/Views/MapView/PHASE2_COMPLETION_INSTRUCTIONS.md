# Phase 2 Completion Instructions

## Summary
Phase 2 requires adding city/state/country fields to event forms for "Other" location events.

## Files That Need Updates

### 1. EventFormViewModel.swift
**Add missing country field:**

```swift
@Published var city: String?
@Published var state: String?  // ✅ Already has this
@Published var country: String?  // ❌ ADD THIS

// In init(_ event: Event):
city = event.city
state = event.state
country = event.country  // ❌ ADD THIS

// In custom init:
self.country = country  // ❌ ADD parameter and assignment
```

### 2. ModernEventFormView.swift
**Add city/state/country fields in coordinatesSection (after the coordinates, before the warning):**

```swift
Divider()

// City
HStack {
    Label("City", systemImage: "building.2.fill")
        .foregroundColor(.orange)
    Spacer()
    TextField("e.g., Denver", text: Binding<String>(
        get: { viewModel.city ?? "" },
        set: { viewModel.city = $0.isEmpty ? nil : $0 }
    ))
    .textInputAutocapitalization(.words)
    .multilineTextAlignment(.trailing)
}

Divider()

// State
HStack {
    Label("State", systemImage: "map.fill")
        .foregroundColor(.green)
    Spacer()
    TextField("e.g., Colorado", text: Binding<String>(
        get: { viewModel.state ?? "" },
        set: { viewModel.state = $0.isEmpty ? nil : $0 }
    ))
    .textInputAutocapitalization(.words)
    .multilineTextAlignment(.trailing)
}

Divider()

// Country
HStack {
    Label("Country", systemImage: "globe")
        .foregroundColor(.purple)
    Spacer()
    TextField("e.g., United States", text: Binding<String>(
        get: { viewModel.country ?? "" },
        set: { viewModel.country = $0.isEmpty ? nil : $0 }
    ))
    .textInputAutocapitalization(.words)
    .multilineTextAlignment(.trailing)
}
```

**Update reverseGeocodeAndSetCity to also set state and country:**

```swift
@MainActor
private func reverseGeocodeAndSetCity(for location: CLLocation) async {
    geocodeError = nil
    do {
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        if let placemark = placemarks.first {
            // City
            let cityName = placemark.locality ?? placemark.administrativeArea ?? ""
            if !cityName.isEmpty {
                viewModel.city = cityName
            }
            
            // State
            if let stateName = placemark.administrativeArea {
                viewModel.state = stateName
            }
            
            // Country
            if let countryName = placemark.country {
                viewModel.country = countryName
            }
        }
    } catch {
        geocodeError = "Could not determine location details"
    }
}
```

**Update save logic to include all fields:**

```swift
// When creating/updating event, ensure all fields are passed:
let newEvent = Event(
    id: viewModel.id ?? UUID().uuidString,
    eventType: viewModel.eventType,
    date: viewModel.date,
    location: selectedLocation,
    city: viewModel.city,      // ✅
    latitude: viewModel.latitude,
    longitude: viewModel.longitude,
    country: viewModel.country,  // ✅
    state: viewModel.state,      // ✅
    note: viewModel.note,
    people: viewModel.people,
    activityIDs: Array(viewModel.activityIDs),
    affirmationIDs: Array(viewModel.affirmationIDs)
)
```

### 3. EventFormView.swift (if still used)
Same changes as ModernEventFormView - add city/state/country fields.

## Testing After Changes

1. **Create "Other" location event:**
   - Select "Other" location
   - Tap "Get Current Location"
   - ✅ Verify: City, State, Country auto-fill
   - Manually edit city to "Boulder"
   - Save event
   - ✅ Verify: Event shows "Boulder, Colorado, United States"

2. **Edit existing event:**
   - Edit an "Other" location event
   - ✅ Verify: City, State, Country fields populated
   - Change state to "CO"
   - Save
   - ✅ Verify: Changes persist

3. **Export and Import:**
   - Create event with city/state/country
   - Export backup
   - Import backup
   - ✅ Verify: All fields preserved

## Phase 2 Complete When:
- [ ] EventFormViewModel has country field
- [ ] ModernEventFormView shows city/state/country fields for "Other"
- [ ] Reverse geocoding populates all three fields
- [ ] Save creates events with all fields
- [ ] All tests pass

---

**Status**: Ready for implementation
**Priority**: HIGH
**Files**: 2-3 files to update
**Estimated Time**: 15-20 minutes
