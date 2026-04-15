# Location Data Enhancement - Quick Reference

## Priority Processing Order

### ✅ Step 1: Complete Data (Fast Path)
**When:** All fields exist (city, state, country, GPS)  
**Action:** Just clean "City, XX" format  
**Example:** "Denver, CO" → "Denver"  
**Speed:** Instant (no API calls)

### ✅ Step 2: Valid GPS (Reverse Geocode)
**When:** GPS coordinates exist (not 0,0)  
**Action:** Use GPS to update state & country, clean city  
**Example:** GPS(39.7,-104.9) → state="Colorado", country="United States"  
**Speed:** ~1 second per request

### ✅ Step 3: No GPS (Parse & Forward Geocode)
**When:** GPS is 0,0 or missing  
**Action:** Parse "City, XX" format  
**Sub-steps:**
1. Try XX as US state code → Success
2. Try XX as country code → Forward geocode for state
3. Neither works → Error

**Example 1 (US State):**  
"Denver, CO" → city="Denver", state="Colorado", country="United States"

**Example 2 (Country):**  
"London, GB" → Forward geocode → state="England", country="United Kingdom", GPS=(51.5,-0.1)

**Speed:** ~1-2 seconds per request

### ❌ Step 4: Insufficient Data
**When:** None of the above apply  
**Action:** Report error to user  
**Example:** Missing city name and GPS

## Implementation Status

### ✅ Already Updated
- [x] CLAUDE.md - Priority steps documented in backlog
- [x] LOCATION_DATA_ENHANCEMENT_SPEC.md - Complete technical specification
- [x] EventFormViewModel - Added country field
- [x] ModernEventFormView - Display & edit city/state/country
- [x] ModernEventEditorSheet - Display & edit city/state/country
- [x] Auto-population from parent location
- [x] Auto-population from GPS (reverse geocoding)
- [x] Manual override capability

### 🚧 To Implement
- [ ] USStateCodeMapper - US state code → full name
- [ ] CountryCodeMapper - ISO country code → full name
- [ ] LocationDataEnhancer - Main processing logic
- [ ] LocationDataEnhancementView - UI for batch processing
- [ ] Add to StartTabView menu
- [ ] Testing with real data

## Quick Start (When Implementing)

### 1. Create Support Files
```swift
// USStateCodeMapper.swift
struct USStateCodeMapper {
    static func stateName(for code: String) -> String?
    static func isValidCode(_ code: String) -> Bool
}

// CountryCodeMapper.swift  
struct CountryCodeMapper {
    static func countryName(for code: String) -> String?
    static func isValidCode(_ code: String) -> Bool
}
```

### 2. Create Processing Engine
```swift
// LocationDataEnhancer.swift
class LocationDataEnhancer {
    func processEvent(_ event: inout Event) async -> LocationDataProcessingResult
}
```

### 3. Create UI
```swift
// LocationDataEnhancementView.swift
struct LocationDataEnhancementView: View {
    // Batch processing UI with progress and error reporting
}
```

### 4. Wire to Menu
```swift
// In StartTabView
@State private var showLocationEnhancement = false

Menu {
    // ... existing items ...
    
    Button {
        showLocationEnhancement = true
    } label: {
        Label("Enhance Location Data", systemImage: "wand.and.stars")
    }
}

.sheet(isPresented: $showLocationEnhancement) {
    LocationDataEnhancementView()
        .environmentObject(store)
}
```

## Key Benefits

1. **Smart Processing** - Only geocodes when needed
2. **Rate Limited** - Won't exceed Apple's API limits
3. **Error Reporting** - Clear messages for unfixable data
4. **User Control** - Can review and fix errors manually
5. **Batch Processing** - Handles all events at once
6. **Progress UI** - Shows what's happening

## Testing Scenarios

| Input | Expected Output |
|-------|-----------------|
| city="Denver, CO", state=nil, GPS=(0,0) | city="Denver", state="Colorado", country="United States" |
| city="Denver", state="Colorado", country="US", GPS=(39.7,-104.9) | No change (complete) |
| city="Denver, CO", GPS=(39.7,-104.9) | city="Denver", state="Colorado", country="United States" (from GPS) |
| city="London, GB", GPS=(0,0) | Forward geocode → city="London", state="England", country="United Kingdom", GPS=(51.5,-0.1) |
| city="Paris, XY", GPS=(0,0) | Error: "Unknown code 'XY'" |
| city=nil, GPS=(0,0) | Error: "Insufficient data" |

## Files to Reference

- **Full Spec:** `LOCATION_DATA_ENHANCEMENT_SPEC.md`
- **Backlog:** `CLAUDE.md` (v1.5 section)
- **Example Implementation:** See spec for complete code samples

---

*Quick Reference v1.0 - 2026-04-11*
