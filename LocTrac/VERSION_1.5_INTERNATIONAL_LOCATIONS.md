# LocTrac v1.5 — International Location Support

**Feature**: Enhanced location data model with proper international support for countries, states/provinces, and cities  
**Status**: Planning  
**Priority**: High  
**Complexity**: High (data migration + UI updates)

---

## 📋 Executive Summary

Current LocTrac data model stores location information as free-form text fields (`city`, `country`), which leads to:
- **Inconsistent data**: "Denver, CO" vs "Denver" vs "Denver, Colorado"
- **No regional granularity**: Can't distinguish states, provinces, territories, etc.
- **Limited analytics**: Can't easily group by state/province
- **Poor international support**: Country handling is basic string matching

**v1.5 Goals**:
1. Add proper `state`/`province` field to Location and Event models
2. Implement smart geocoding to populate country, state/province, city
3. Create data migration utility to clean and populate existing user data
4. Support manual entry with intelligent parsing
5. Maintain backward compatibility with existing backups

---

## 🗺️ Current Data Model Analysis

### Location Model (Current)
```swift
struct Location: Identifiable, Hashable, Codable {
    var id: String
    var name: String            // User-defined name (e.g., "Loft", "Cabo")
    var city: String?           // ⚠️ Often contains "City, State" or "City, Country"
    var latitude: Double
    var longitude: Double
    var country: String?        // Added in v1.3
    var theme: Theme
    var imageIDs: [String]?
    var customColorHex: String?
}
```

### Event Model (Current)
```swift
struct Event: Identifiable {
    var eventType: String
    var location: Location      // Embedded snapshot
    var id: String
    var date: Date
    var city: String?           // ⚠️ Often duplicates or contradicts location.city
    var latitude: Double        // Event-specific coords (for "Other" location)
    var longitude: Double
    var country: String?        // Added in v1.3
    var note: String
    var people: [Person]
    var activityIDs: [String]
    var affirmationIDs: [String]
}
```

### Problems Identified

| Issue | Example | Impact |
|-------|---------|--------|
| **Mixed formats** | `city: "Denver, CO"` vs `city: "Denver"` | Inconsistent grouping in analytics |
| **Redundant data** | Event has `city` and `location.city` | Sync issues, confusion |
| **No state field** | State encoded in city string | Can't filter/group by state |
| **Limited geocoding** | Only country is geocoded | Missing regional data |
| **Manual entry parsing** | User types "Paris, France" → no parsing | Messy data |

---

## 🎯 Proposed Solution

### New Data Model (v1.5)

```swift
struct Location: Identifiable, Hashable, Codable {
    var id: String
    var name: String                    // User-defined name
    var city: String?                   // ✅ City name ONLY (no state/country)
    var state: String?                  // ✨ NEW: State, province, territory, etc.
    var latitude: Double
    var longitude: Double
    var country: String?                // ✅ Country name (geocoded or manual)
    var countryCode: String?            // ✨ NEW: ISO country code (e.g., "US", "CA", "FR")
    var theme: Theme
    var imageIDs: [String]?
    var customColorHex: String?
    
    // ✨ NEW: Computed property for full address display
    var fullAddress: String {
        var components: [String] = []
        if let city = city { components.append(city) }
        if let state = state { components.append(state) }
        if let country = country { components.append(country) }
        return components.joined(separator: ", ")
    }
    
    // ✨ NEW: Computed property for short address (city, state)
    var shortAddress: String {
        var components: [String] = []
        if let city = city { components.append(city) }
        if let state = state { components.append(state) }
        return components.isEmpty ? (country ?? "Unknown") : components.joined(separator: ", ")
    }
}
```

```swift
struct Event: Identifiable {
    var eventType: String
    var location: Location              // Embedded snapshot
    var id: String
    var date: Date
    // ❌ REMOVED: var city: String?   // Redundant with location.city
    var latitude: Double                // Only for "Other" location
    var longitude: Double               // Only for "Other" location
    var country: String?                // ⚠️ Keep for backward compat, derive from location
    var state: String?                  // ✨ NEW: State/province (for "Other" events)
    var note: String
    var people: [Person]
    var activityIDs: [String]
    var affirmationIDs: [String]
    
    // ✨ NEW: Computed property for effective state
    var effectiveState: String? {
        if location.name == "Other" {
            return state  // Use event-specific state for "Other"
        } else {
            return location.state  // Use location's state for named locations
        }
    }
    
    // ✅ UPDATED: Effective coordinates (already exists)
    var effectiveCoordinates: (latitude: Double, longitude: Double) {
        if location.name == "Other" {
            return (latitude: latitude, longitude: longitude)
        } else {
            return (latitude: location.latitude, longitude: location.longitude)
        }
    }
    
    // ✨ NEW: Full address for event
    var effectiveAddress: String {
        if location.name == "Other" {
            var components: [String] = []
            // For "Other", we need to geocode or use stored data
            // This would come from reverse geocoding the event coordinates
            if let country = country { components.append(country) }
            if let state = state { components.append(state) }
            return components.joined(separator: ", ")
        } else {
            return location.fullAddress
        }
    }
}
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Add `state` field** | Proper regional granularity for US states, Canadian provinces, etc. |
| **Add `countryCode`** | ISO codes enable better internationalization, flag emojis, etc. |
| **Keep `country` as String** | User-friendly display name (e.g., "United States" not "US") |
| **Remove `Event.city`** | Redundant with `location.city`, causes sync issues |
| **Computed properties** | Clean API for UI without duplicating stored data |
| **Separate "Other" logic** | Events at "Other" location need their own geocoded data |

---

## 🔧 Implementation Plan

### Phase 1: Model Updates (Week 1)

#### 1.1 Update Location Model
```swift
// In Locations.swift

struct Location: Identifiable, Hashable, Codable {
    // ... existing fields ...
    var state: String?          // NEW
    var countryCode: String?    // NEW
    
    init(id: String = UUID().uuidString,
         name: String,
         city: String?,
         state: String? = nil,      // NEW
         latitude: Double,
         longitude: Double,
         country: String? = nil,
         countryCode: String? = nil, // NEW
         theme: Theme,
         imageIDs: [String]? = nil,
         customColorHex: String? = nil) {
        self.id = id
        self.name = name
        self.city = city
        self.state = state          // NEW
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.countryCode = countryCode // NEW
        self.theme = theme
        self.imageIDs = imageIDs
        self.customColorHex = customColorHex
    }
    
    // Computed properties...
}
```

#### 1.2 Update Event Model
```swift
// In Event.swift

struct Event: Identifiable {
    // ... existing fields ...
    var state: String?  // NEW: For "Other" location events
    // Remove: var city: String?  (handled by location.city)
    
    init(id: String = UUID().uuidString,
         eventType: EventType = .unspecified,
         date: Date,
         location: Location,
         latitude: Double,
         longitude: Double,
         country: String? = nil,
         state: String? = nil,      // NEW
         note: String,
         people: [Person] = [],
         activityIDs: [String] = [],
         affirmationIDs: [String] = []) {
        self.eventType = eventType.rawValue
        self.date = date
        self.id = id
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.state = state          // NEW
        self.note = note
        self.people = people
        self.activityIDs = activityIDs
        self.affirmationIDs = affirmationIDs
    }
    
    // Computed properties...
}
```

#### 1.3 Update ImportExport Models
```swift
// In ImportExport.swift

extension ImportExport {
    struct LocationData: Codable {
        // ... existing fields ...
        var state: String?         // NEW - optional for backward compat
        var countryCode: String?   // NEW - optional for backward compat
    }
    
    struct EventData: Codable {
        // ... existing fields ...
        var state: String?         // NEW - optional for backward compat
        // city: String? remains optional but will be migrated
    }
}
```

**Backward Compatibility**: All new fields are optional in the `Import` struct, ensuring existing `backup.json` files load correctly.

---

### Phase 2: Enhanced Geocoding Service (Week 2)

#### 2.1 Create GeocodeResult Model
```swift
// New file: Models/GeocodeResult.swift

import CoreLocation

struct GeocodeResult {
    let city: String?
    let state: String?          // administrativeArea
    let country: String?
    let countryCode: String?    // isoCountryCode
    let latitude: Double
    let longitude: Double
    
    init(from placemark: CLPlacemark) {
        self.city = placemark.locality
        self.state = placemark.administrativeArea
        self.country = placemark.country
        self.countryCode = placemark.isoCountryCode
        self.latitude = placemark.location?.coordinate.latitude ?? 0.0
        self.longitude = placemark.location?.coordinate.longitude ?? 0.0
    }
}
```

#### 2.2 Enhanced Geocoding Service
```swift
// New file: Services/EnhancedGeocoder.swift

import CoreLocation

@MainActor
class EnhancedGeocoder {
    
    /// Geocode a coordinate to get full location details
    static func reverseGeocode(latitude: Double, longitude: Double) async -> GeocodeResult? {
        guard latitude != 0.0 || longitude != 0.0 else { return nil }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            return GeocodeResult(from: placemark)
        } catch {
            print("❌ Reverse geocoding failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Geocode an address string to get coordinates and location details
    static func forwardGeocode(address: String) async -> GeocodeResult? {
        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            guard let placemark = placemarks.first else { return nil }
            return GeocodeResult(from: placemark)
        } catch {
            print("❌ Forward geocoding failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Parse a manual entry like "Denver, CO" or "Paris, France"
    /// Returns separate components for city, state, country
    static func parseManualEntry(_ input: String) -> (city: String?, state: String?, country: String?) {
        let components = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        switch components.count {
        case 1:
            // Just city: "Denver"
            return (city: components[0], state: nil, country: nil)
        case 2:
            // City, State OR City, Country
            // Heuristic: If second part is 2 chars, assume US state code
            if components[1].count == 2 {
                return (city: components[0], state: components[1], country: "United States")
            } else {
                return (city: components[0], state: nil, country: components[1])
            }
        case 3:
            // City, State, Country: "Denver, CO, United States"
            return (city: components[0], state: components[1], country: components[2])
        default:
            return (city: input, state: nil, country: nil)
        }
    }
}
```

---

### Phase 3: Data Migration Utility (Week 3)

#### 3.1 Create LocationDataMigrator
```swift
// New file: Services/LocationDataMigrator.swift

import Foundation

@MainActor
class LocationDataMigrator {
    
    /// Migrate all locations to have proper city, state, country
    static func migrateLocations(_ locations: [Location]) async -> [Location] {
        var migratedLocations: [Location] = []
        
        for location in locations {
            var updated = location
            
            // Skip if already has state and clean city
            if location.state != nil && location.city?.contains(",") == false {
                migratedLocations.append(location)
                continue
            }
            
            print("🔄 Migrating location: \(location.name)")
            
            // Step 1: Parse existing city field if it contains commas
            if let city = location.city, city.contains(",") {
                let parsed = EnhancedGeocoder.parseManualEntry(city)
                updated.city = parsed.city
                updated.state = parsed.state ?? updated.state
                updated.country = parsed.country ?? updated.country
                print("   Parsed '\(city)' → city: \(parsed.city ?? "nil"), state: \(parsed.state ?? "nil"), country: \(parsed.country ?? "nil")")
            }
            
            // Step 2: If we have coordinates, reverse geocode to fill missing data
            if location.latitude != 0.0 || location.longitude != 0.0 {
                if let geocoded = await EnhancedGeocoder.reverseGeocode(
                    latitude: location.latitude,
                    longitude: location.longitude
                ) {
                    // Only update fields that are currently nil
                    if updated.city == nil { updated.city = geocoded.city }
                    if updated.state == nil { updated.state = geocoded.state }
                    if updated.country == nil { updated.country = geocoded.country }
                    if updated.countryCode == nil { updated.countryCode = geocoded.countryCode }
                    
                    print("   Geocoded: city: \(geocoded.city ?? "nil"), state: \(geocoded.state ?? "nil"), country: \(geocoded.country ?? "nil")")
                }
                
                // Rate limiting to avoid geocoding API limits
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
            
            migratedLocations.append(updated)
        }
        
        return migratedLocations
    }
    
    /// Migrate all events to have proper state data
    static func migrateEvents(_ events: [Event]) async -> [Event] {
        var migratedEvents: [Event] = []
        
        for event in events {
            var updated = event
            
            // For "Other" location events, geocode their specific coordinates
            if event.location.name == "Other" {
                if event.latitude != 0.0 || event.longitude != 0.0 {
                    if let geocoded = await EnhancedGeocoder.reverseGeocode(
                        latitude: event.latitude,
                        longitude: event.longitude
                    ) {
                        if updated.state == nil { updated.state = geocoded.state }
                        if updated.country == nil { updated.country = geocoded.country }
                        
                        print("🔄 Migrated 'Other' event on \(event.date): state: \(geocoded.state ?? "nil")")
                    }
                    
                    // Rate limiting
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                }
            }
            
            migratedEvents.append(updated)
        }
        
        return migratedEvents
    }
    
    /// Full migration - locations and events
    static func performFullMigration(dataStore: DataStore) async {
        print("\n🚀 Starting location data migration...")
        
        // Migrate locations
        let migratedLocations = await migrateLocations(dataStore.locations)
        dataStore.locations = migratedLocations
        
        // Migrate events
        let migratedEvents = await migrateEvents(dataStore.events)
        dataStore.events = migratedEvents
        
        // Save
        dataStore.storeData()
        
        print("✅ Migration complete!")
        print("   Locations: \(migratedLocations.count)")
        print("   Events: \(migratedEvents.count)")
    }
}
```

#### 3.2 Migration UI View
```swift
// New file: Views/Settings/LocationDataMigrationView.swift

import SwiftUI

struct LocationDataMigrationView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var isRunning = false
    @State private var progress: Double = 0.0
    @State private var statusMessage = "Ready to migrate location data"
    @State private var isComplete = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("Location Data Migration")
                        .font(.title2.bold())
                    
                    Text("This utility will:")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                // What it does
                VStack(alignment: .leading, spacing: 12) {
                    MigrationFeature(
                        icon: "text.badge.checkmark",
                        title: "Clean up city names",
                        description: "Separate city, state, and country from combined entries"
                    )
                    
                    MigrationFeature(
                        icon: "location.fill",
                        title: "Add state/province data",
                        description: "Populate regional information using geocoding"
                    )
                    
                    MigrationFeature(
                        icon: "flag.fill",
                        title: "Add country codes",
                        description: "ISO country codes for better internationalization"
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Status
                if isRunning {
                    VStack(spacing: 12) {
                        ProgressView(value: progress)
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Action button
                if !isComplete {
                    Button {
                        runMigration()
                    } label: {
                        Label(isRunning ? "Migrating..." : "Start Migration",
                              systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRunning ? Color.gray : Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isRunning)
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isRunning)
                }
            }
        }
    }
    
    private func runMigration() {
        isRunning = true
        progress = 0.0
        statusMessage = "Preparing..."
        
        Task {
            await LocationDataMigrator.performFullMigration(dataStore: store)
            
            await MainActor.run {
                progress = 1.0
                statusMessage = "Migration complete!"
                isComplete = true
                isRunning = false
            }
        }
    }
}

struct MigrationFeature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

---

### Phase 4: UI Updates (Week 4)

#### 4.1 Update LocationFormView
```swift
// In LocationFormView.swift - add state field

struct LocationFormView: View {
    // ... existing @State vars ...
    @State private var state: String = ""  // NEW
    
    var body: some View {
        Form {
            Section("Location Details") {
                TextField("Name", text: $name)
                TextField("City", text: $city)
                TextField("State/Province", text: $state)  // NEW
                // Country is auto-populated via geocoding
                if let country = location?.country {
                    LabeledContent("Country", value: country)
                }
            }
            
            // ... rest of form ...
        }
    }
}
```

#### 4.2 Update Event Display Views
```swift
// Show full address instead of just city

// Before:
Text(event.city ?? "Unknown")

// After:
Text(event.location.name == "Other" ? 
     "\(event.country ?? "Unknown")" : 
     event.location.shortAddress)
```

#### 4.3 Update Analytics/Grouping
```swift
// Group by state in TravelHistoryView

var eventsByState: [String: [Event]] {
    Dictionary(grouping: events) { event in
        event.effectiveState ?? "Unknown"
    }
}
```

---

## 🧪 Testing Strategy

### Manual Testing Checklist

- [ ] **New Location**: Add location with manual entry "Denver, CO"
  - Verify city = "Denver", state = "CO", country = "United States"
  
- [ ] **New Location**: Add location with coordinates
  - Verify all fields are geocoded correctly
  
- [ ] **Migration**: Run on backup with old data format
  - Verify "Denver, CO" in city field becomes city="Denver", state="CO"
  - Verify "Paris, France" becomes city="Paris", country="France"
  
- [ ] **"Other" Events**: Add event at "Other" location
  - Verify event.state is geocoded from coordinates
  
- [ ] **Backup Compatibility**: Export, then import old v1.4 backup
  - Verify loads without errors
  - Verify new fields are nil (acceptable)
  
- [ ] **International**: Test with non-US locations
  - Canada: "Toronto, ON" → city="Toronto", state="ON", country="Canada"
  - UK: "London, England" → city="London", state="England", country="United Kingdom"
  - Australia: "Sydney, NSW" → city="Sydney", state="NSW", country="Australia"

### Edge Cases

| Scenario | Expected Behavior |
|----------|------------------|
| City field is empty | Use geocoding from coordinates |
| Coordinates are 0,0 | Use manual entry only |
| City has commas | Parse and split intelligently |
| State is 2 chars | Assume US state code |
| State is >2 chars | Could be province, region, etc. |
| No internet for geocoding | Gracefully fail, keep manual entry |
| Rate limit hit | Pause and resume with backoff |

---

## 📦 Deliverables

### Code Files

1. **Models** (updated):
   - `Locations.swift` - Add `state`, `countryCode`, computed properties
   - `Event.swift` - Add `state`, remove `city`, add computed properties
   
2. **Services** (new):
   - `GeocodeResult.swift` - Model for geocoding results
   - `EnhancedGeocoder.swift` - Forward/reverse geocoding + parsing
   - `LocationDataMigrator.swift` - Migration logic
   
3. **Views** (new):
   - `LocationDataMigrationView.swift` - UI for running migration
   
4. **Views** (updated):
   - `LocationFormView.swift` - Add state field
   - `EventFormView.swift` - Update to use new address properties
   - `TravelHistoryView.swift` - Group by state option
   - `InfographicsView.swift` - Display state breakdowns

### Documentation

1. **User Guide**: How to run migration utility
2. **Migration Notes**: Document changes to data format
3. **CHANGELOG.md**: v1.5 entry with breaking changes noted
4. **CLAUDE.md**: Update data model section

---

## 🚀 Release Strategy

### Migration Path for Users

1. **On first launch of v1.5**:
   - Show alert: "New location features available! We can enhance your existing data with state/province information."
   - Options: "Migrate Now", "Remind Me Later", "Skip"
   
2. **If "Migrate Now"**:
   - Present `LocationDataMigrationView`
   - Run migration with progress indicator
   - Save backup before migration
   
3. **If "Remind Me Later"**:
   - Set UserDefaults flag
   - Show again after 7 days
   
4. **If "Skip"**:
   - New locations will have full data
   - Old locations work as-is (degraded experience)

### Backward Compatibility

- ✅ Old backups load without errors (new fields are optional)
- ✅ App works without migration (just missing state data)
- ✅ Export format includes new fields but Import handles missing fields
- ⚠️ **Breaking change**: `Event.city` removed (minor - was redundant anyway)

---

## 🎯 Success Metrics

- All existing locations migrated successfully
- Geocoding accuracy >95% for locations with coordinates
- Parsing accuracy >90% for manual entries with commas
- No data loss during migration
- Import/export round-trip successful for old and new formats

---

## 📝 Open Questions

1. **State abbreviations vs full names?**
   - Recommendation: Store full name ("Colorado" not "CO") from geocoding
   - Display abbreviated in compact UI
   
2. **How to handle non-US territories?**
   - US: "administrativeArea" = state
   - Canada: "administrativeArea" = province
   - UK: "administrativeArea" = country (England, Scotland, Wales)
   - Recommendation: Just call it "state" generically
   
3. **Should we add city-level timezone support?**
   - Future enhancement (v1.6?)
   - Would help with trip timing calculations
   
4. **What about cities with same name in different states?**
   - Display: "Portland, OR" vs "Portland, ME"
   - This is now possible with state field!

---

## 🔄 Future Enhancements (v1.6+)

- [ ] **Timezone support**: Store timezone per location
- [ ] **Postal codes**: Add ZIP/postal code field
- [ ] **Hierarchical location picker**: Country → State → City dropdowns
- [ ] **Smart suggestions**: Learn from user's most-used locations
- [ ] **Location aliases**: "Home", "Work", etc. pointing to same place
- [ ] **Region-based filters**: "Show all events in Colorado"
- [ ] **Map clustering by state**: Aggregate view on map

---

**Version**: 1.5  
**Author**: Tim Arey  
**Date**: 2026-04-09  
**Status**: Ready for Implementation
