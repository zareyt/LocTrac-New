# Infographics Crash Fix - Immediate Solution

## The Problem

The crash `EXC_BREAKPOINT (code=1, subcode=0x1c78b7754)` is caused by:
1. Rapid year switching triggers multiple view updates
2. `filteredEvents` is computed property called 20+ times per render
3. State changes during view rendering cause SwiftUI breakpoints
4. Force unwraps (`!`) on empty collections

## Immediate Fix

Replace the InfographicsView state variables and add defensive coding:

### Step 1: Update State Variables

```swift
struct InfographicsView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedYear: String = "All Time"
    @State private var showShareSheet = false
    @State private var pdfData: Data?
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 180)
    )
    @State private var cachedTravelStats: TravelStatistics?
    
    // CRITICAL: Add these to prevent recalculation
    @State private var cachedFilteredEvents: [Event] = []
    @State private var cachedYear: String = ""
    @State private var isCalculating: Bool = false  // Prevent concurrent updates
```

### Step 2: Replace filteredEvents Computed Property

```swift
// MARK: - Computed Properties
extension InfographicsView {
    private var filteredEvents: [Event] {
        // Return cached if same year
        if cachedYear == selectedYear {
            return cachedFilteredEvents
        }
        
        // Calculate new
        if selectedYear == "All Time" {
            return store.events
        } else if let year = Int(selectedYear) {
            return store.events.filter { 
                Calendar.current.component(.year, from: $0.date) == year 
            }
        }
        return store.events
    }
    
    private func updateCache() {
        guard !isCalculating else { return }
        isCalculating = true
        
        Task { @MainActor in
            if selectedYear == "All Time" {
                cachedFilteredEvents = store.events
            } else if let year = Int(selectedYear) {
                cachedFilteredEvents = store.events.filter { 
                    Calendar.current.component(.year, from: $0.date) == year 
                }
            } else {
                cachedFilteredEvents = store.events
            }
            cachedYear = selectedYear
            isCalculating = false
        }
    }
}
```

### Step 3: Add onChange Modifiers (ALREADY DONE)

The onChange modifiers are already added in the previous fix.

### Step 4: Fix Force Unwraps (ALREADY DONE)

The `topLocations` force unwrap is already fixed.

### Step 5: Add More Safety to All Computed Properties

```swift
// Add guard to every computed property using filteredEvents
private var topActivities: [(name: String, count: Int)] {
    let events = filteredEvents
    guard !events.isEmpty else { return [] }  // ADD THIS
    // ... rest of code
}

private var topPeople: [(name: String, count: Int)] {
    let events = filteredEvents
    guard !events.isEmpty else { return [] }  // ADD THIS
    // ... rest of code
}

private var countriesVisited: Set<String> {
    let events = filteredEvents
    guard !events.isEmpty else { return [] }  // ADD THIS
    return Set(events.compactMap { $0.country }.filter { !$0.isEmpty })
}

private var statesVisited: Set<String> {
    let events = filteredEvents
    guard !events.isEmpty else { return [] }  // ADD THIS
    // ... rest of code
}

private var eventsWithCoordinates: [Event] {
    let events = filteredEvents
    guard !events.isEmpty else { return [] }  // ADD THIS
    return events.filter { event in
        let hasEventCoords = event.latitude != 0.0 && event.longitude != 0.0
        let hasLocationCoords = event.location.latitude != 0.0 && event.location.longitude != 0.0
        return hasEventCoords || hasLocationCoords
    }.sorted { $0.date < $1.date }
}
```

## Testing After Fix

1. Open app
2. Go to Infographics
3. Switch between years rapidly: 2024 → 2023 → 2022 → 2024 → All Time
4. Should NOT crash
5. Data should update smoothly

## If Still Crashing

If the app still crashes, check these:

1. **Check Console for exact crash line**
   - The error will show which property is failing
   - Look for force unwraps (`!`) or subscript access

2. **Check if it's a SwiftUI state mutation error**
   - Make sure no `@State` variables are being modified during view rendering
   - All state changes should be in `onChange`, `onAppear`, or button actions

3. **Check the data**
   - Verify `store.events` is not nil or empty when it shouldn't be
   - Check if any events have invalid data (nil locations, etc.)

4. **Add debug logging**
```swift
private var filteredEvents: [Event] {
    print("🔍 filteredEvents called for year: \(selectedYear)")
    print("   Cached year: \(cachedYear)")
    print("   Cache count: \(cachedFilteredEvents.count)")
    print("   Store count: \(store.events.count)")
    
    if cachedYear == selectedYear {
        print("   ✅ Returning cached")
        return cachedFilteredEvents
    }
    
    print("   ⚠️ Calculating new")
    // ... calculation
}
```

## Full Fix Applied

The files have been updated with:
- ✅ Cached filtered events state variables
- ✅ onChange modifiers to update cache
- ✅ Fixed force unwraps in topLocations
- ✅ Helper function to update cache safely

Next: Add guards to ALL computed properties that use filteredEvents.

## Quick Band-Aid (If Needed)

If you need a quick fix right now, wrap the entire ScrollView in a conditional:

```swift
var body: some View {
    NavigationStack {
        if cachedYear == selectedYear || selectedYear == "All Time" {
            ScrollView {
                // ... all content
            }
        } else {
            ProgressView("Loading...")
                .onAppear {
                    updateCache()
                }
        }
    }
}
```

This prevents rendering until cache is ready, eliminating race conditions.
