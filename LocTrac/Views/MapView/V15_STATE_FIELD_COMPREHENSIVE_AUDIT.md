# v1.5 State Field Comprehensive Audit & Upgrade Plan

## Executive Summary

The state/province field was added to the Location and Event models but is **not fully integrated** across the codebase. This document provides a comprehensive audit of all areas that need updates and a phased implementation plan.

## Critical Finding

✅ **Models are correct** - Location and Event have `state` field  
✅ **DataStore.update()** - Now saves state field  
⚠️ **Import/Export** - MISSING state field handling  
⚠️ **Event Forms** - Need to add state field  
⚠️ **Views** - Most views don't display/use state  
⚠️ **Infographics** - Doesn't include state  

---

## Phase 1: Data Layer (CRITICAL - Do First)

### 1.1 ImportExport.swift ⚠️ HIGH PRIORITY

**Current Status**: Import/Export structs likely missing state field

**Required Changes**:
```swift
// Import.swift
struct Import: Codable {
    struct Event: Codable {
        var locationID: String
        var city: String?
        var state: String?  // ← ADD THIS
        var country: String?
        // ...
    }
    
    struct Location: Codable {
        var city: String?
        var state: String?  // ← ADD THIS
        var country: String?
        var countryCode: String?  // ← ADD THIS if missing
        // ...
    }
}

// Export.swift - Same additions
struct Export: Codable {
    struct LocationData: Codable {
        let state: String?  // ← ADD THIS
        let countryCode: String?  // ← ADD THIS if missing
    }
    
    struct EventData: Codable {
        let state: String?  // ← ADD THIS
    }
}
```

**Testing Required**:
- [ ] Export current data → Verify state appears in JSON
- [ ] Import old backup (without state) → Should work (optional field)
- [ ] Import new backup (with state) → State should be restored
- [ ] Round-trip test: Export → Import → Verify all state data preserved

### 1.2 TimelineRestoreView.swift ✅ PARTIALLY DONE

**Status**: Already fixed for Event, may need Location check

**Verify**:
```swift
// Line ~925 - Should have this:
let event = Event(
    // ...
    city: eventData.city,  // ✅ Already fixed
    state: eventData.state,  // ← VERIFY THIS EXISTS
    // ...
)

// Location conversion - VERIFY:
let location = Location(
    // ...
    state: locationData.state,  // ← VERIFY THIS EXISTS
    // ...
)
```

---

## Phase 2: Event Creation/Editing Forms (HIGH PRIORITY)

### 2.1 ModernEventFormView.swift ⚠️ NEEDS STATE FIELD

**Current Status**: Likely missing state field UI

**Required Changes**:
1. Add `@State private var state: String = ""`
2. Add state TextField in form (after city, before country)
3. Pass state to Event initializer when creating/updating

**Implementation**:
```swift
// Add state variable
@State private var state: String = ""

// In form, add section (after city):
Section {
    HStack {
        Label("State", systemImage: "map.fill")
            .foregroundColor(.green)
        Spacer()
        TextField("e.g., Colorado", text: $state)
            .textInputAutocapitalization(.words)
            .multilineTextAlignment(.trailing)
    }
} header: {
    Text("State / Province")
} footer: {
    Text("State, province, or territory")
}

// When creating/updating event:
let newEvent = Event(
    // ...
    city: city,
    state: state.isEmpty ? nil : state,  // ← ADD THIS
    // ...
    country: country.isEmpty ? nil : country
)
```

### 2.2 EventFormView.swift ⚠️ NEEDS STATE FIELD

**Same changes as ModernEventFormView**

---

## Phase 3: Display Views (MEDIUM PRIORITY)

### 3.1 HomeView.swift ⚠️ NEEDS UPDATE

**Current Status**: Likely displays only city, country

**Required Changes**:
- Recent events should show: "City, State" or "City, State, Country"
- Use `event.effectiveCity`, `event.effectiveState`, `event.effectiveCountry`

**Example**:
```swift
// Before
Text(event.city ?? event.location.city ?? "Unknown")

// After
if let city = event.effectiveCity, let state = event.effectiveState {
    Text("\(city), \(state)")
} else if let city = event.effectiveCity {
    Text(city)
}
```

### 3.2 InfographicsView.swift ⚠️ NEEDS UPDATE

**Current Status**: Likely groups by city/country only

**Required Changes**:
- Stats should include state grouping
- Map markers could show state
- Journey paths should use state in labels

**Example Groupings**:
```swift
// Add state-based grouping
let stateGroups = events.compactMap { $0.effectiveState }.unique()
Text("States Visited: \(stateGroups.count)")

// Update city display to include state
Text("\(city), \(state ?? country)")
```

### 3.3 DonutChartView.swift ⚠️ NEEDS UPDATE

**Current Status**: Likely charts by location/country only

**Required Changes**:
- Option to group by state
- Show state in labels/legends

### 3.4 TravelHistoryView.swift ✅ ALREADY DONE

**Status**: Uses `displayState` with master-detail lookup - GOOD!

### 3.5 ModernEventsCalendarView.swift ⚠️ CHECK NEEDED

**Required**: Verify event details show state field

---

## Phase 4: Location Management (PARTIALLY DONE)

### 4.1 LocationFormView.swift ✅ DONE
- State field added
- Saves correctly

### 4.2 LocationsManagementView.swift ✅ DONE
- State field added
- Saves correctly

### 4.3 LocationDetailView.swift (MapView) ⚠️ CHECK NEEDED
- Should display state in titleSection

---

## Phase 5: Analytics & Reports

### 5.1 Charts & Statistics
All chart views should support state-based grouping:
- [ ] DonutChartView
- [ ] InfographicsView
- [ ] TravelHistoryView stats (already done)

### 5.2 Export/Share Features
- [ ] CSV export should include state column
- [ ] PDF export should show state
- [ ] Share text should include state in addresses

---

## Implementation Checklist by File

### CRITICAL (Do First)
- [ ] **ImportExport.swift**
  - [ ] Add `state` to Import.Event
  - [ ] Add `state` to Import.Location
  - [ ] Add `state` to Export.EventData
  - [ ] Add `state` to Export.LocationData
  - [ ] Test import/export round-trip

- [ ] **TimelineRestoreView.swift**
  - [ ] Verify Event conversion includes state
  - [ ] Verify Location conversion includes state
  - [ ] Test importing old backup (no state) works
  - [ ] Test importing new backup (with state) works

### HIGH PRIORITY
- [ ] **ModernEventFormView.swift**
  - [ ] Add @State var state
  - [ ] Add state TextField
  - [ ] Initialize from event when editing
  - [ ] Save state when creating/updating
  - [ ] Add icon label for consistency

- [ ] **EventFormView.swift** (if still used)
  - [ ] Same changes as ModernEventFormView

- [ ] **HomeView.swift**
  - [ ] Update recent events to show state
  - [ ] Use effectiveState property

### MEDIUM PRIORITY
- [ ] **InfographicsView.swift**
  - [ ] Add state to city/country display
  - [ ] Add state-based statistics
  - [ ] Update journey labels

- [ ] **DonutChartView.swift**
  - [ ] Add state grouping option
  - [ ] Show state in labels

- [ ] **ModernEventsCalendarView.swift**
  - [ ] Verify event details show state

- [ ] **LocationDetailView.swift** (MapView)
  - [ ] Add state to title section

### LOW PRIORITY
- [ ] Search/Filter features to support state
- [ ] CSV export with state column
- [ ] PDF export with state field

---

## Testing Strategy

### Unit Tests Needed
```swift
@Test("State field persists through save/load")
func testStatePersistence() async throws {
    let store = DataStore()
    var location = Location(
        name: "Test",
        city: "Denver",
        state: "Colorado",
        latitude: 0,
        longitude: 0,
        country: "United States",
        theme: .blue
    )
    
    store.add(location)
    store.save()
    
    // Reload
    let newStore = DataStore()
    let loaded = newStore.locations.first(where: { $0.name == "Test" })
    
    #expect(loaded?.state == "Colorado")
}

@Test("State field survives import/export")
func testImportExport() async throws {
    // Create event with state
    let event = Event(
        date: Date(),
        location: location,
        city: "Boulder",
        state: "Colorado",
        // ...
    )
    
    // Export
    let exported = Export(/* ... */)
    let json = try JSONEncoder().encode(exported)
    
    // Import
    let imported = try JSONDecoder().decode(Import.self, from: json)
    
    #expect(imported.events.first?.state == "Colorado")
}
```

### Integration Tests Needed
- [ ] Create new event with state → Verify saves
- [ ] Edit event state → Verify updates
- [ ] Export backup → Verify state in JSON
- [ ] Import backup → Verify state restored
- [ ] View event in calendar → Verify state displays
- [ ] View location details → Verify state shows

### Edge Case Tests
- [ ] Empty state field (should be nil)
- [ ] Old backup without state (should import fine)
- [ ] Mixed data (some with state, some without)
- [ ] Special characters in state (e.g., "Hawai'i")
- [ ] Long state names (e.g., "Newfoundland and Labrador")

---

## Migration Plan

### Step 1: Data Layer (Week 1)
1. Update ImportExport.swift
2. Update TimelineRestoreView.swift
3. Test all import/export scenarios
4. Create backup of current data

### Step 2: Forms (Week 1)
1. Update ModernEventFormView.swift
2. Update EventFormView.swift (if used)
3. Test creating/editing events
4. Test "Other" location events specifically

### Step 3: Display Views (Week 2)
1. Update HomeView.swift
2. Update InfographicsView.swift
3. Update DonutChartView.swift
4. Update ModernEventsCalendarView.swift

### Step 4: Polish & Testing (Week 2)
1. Update LocationDetailView (MapView)
2. Add comprehensive tests
3. Test all workflows end-to-end
4. Update documentation

---

## Risk Assessment

### HIGH RISK
⚠️ **Import/Export** - If not handled correctly, could cause data loss
- **Mitigation**: Make state optional, test with old backups

### MEDIUM RISK
⚠️ **Event Forms** - Users creating events without state
- **Mitigation**: State is optional, not required

### LOW RISK
✅ **Display Views** - Worst case: state doesn't show
- **Mitigation**: Easy to fix with updates

---

## Backward Compatibility

### Old Backups (Pre-v1.5)
Must support import of backups that don't have state field:
```swift
struct Import: Codable {
    struct Event: Codable {
        var state: String?  // ← Optional = backward compatible
    }
}
```

### Forward Compatibility
New backups with state should work:
```json
{
  "city": "Denver",
  "state": "Colorado",  // ← New field
  "country": "United States"
}
```

---

## Success Criteria

- [ ] All forms include state field
- [ ] All views display state appropriately
- [ ] Import/Export preserves state data
- [ ] Old backups still import successfully
- [ ] New backups include state data
- [ ] No data loss during upgrade
- [ ] State field is optional everywhere
- [ ] Tests pass for all scenarios

---

## Quick Reference: Files That Need Updates

### ✅ Already Done
- Location.swift
- Event.swift  
- LocationFormView.swift
- LocationFormViewModel.swift
- LocationsManagementView.swift
- LocationSheetEditorModel.swift
- DataStore.swift (update method)
- TravelHistoryView.swift

### ⚠️ Needs Updates (Priority Order)
1. **ImportExport.swift** (CRITICAL)
2. **TimelineRestoreView.swift** (Verify)
3. **ModernEventFormView.swift** (HIGH)
4. **EventFormView.swift** (HIGH)
5. **HomeView.swift** (MEDIUM)
6. **InfographicsView.swift** (MEDIUM)
7. **DonutChartView.swift** (MEDIUM)
8. **ModernEventsCalendarView.swift** (LOW)
9. **LocationDetailView.swift** (MapView) (LOW)

---

**Created**: 2026-04-11  
**Version**: v1.5  
**Status**: Planning Complete - Ready for Implementation  
**Estimated Effort**: 2-3 weeks  
**Risk Level**: Medium (Import/Export is critical)
