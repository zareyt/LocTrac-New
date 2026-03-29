# Infographics Memoization Rebuild Guide

## Overview

This document outlines the implementation of **memoization** for the Infographics tab using a `Derived` struct that holds all precomputed, per-year data. This approach eliminates redundant calculations and provides instant UI updates when switching between years.

---

## Architecture

### Current State
You have **two caching systems**:
1. **`InfographicsCacheManager`** (persistent actor) - Disk-backed cache for long-term storage
2. **`InfographicsCache`** (in-memory ObservableObject) - Memory cache for fast access

### Recommendation: Layer Them Properly

```
┌─────────────────────────────────────────────────────────┐
│                   InfographicsView                      │
│                                                         │
│  @State derivedByYear: [String: Derived]               │
│         ↓                                               │
│  In-Memory Memoization (instant access)                │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│             InfographicsCache (ObservableObject)        │
│                                                         │
│  Warm cache for current session                        │
│  Invalidated on data changes                           │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│          InfographicsCacheManager (Actor)               │
│                                                         │
│  Persistent disk storage                               │
│  Survives app restarts                                 │
└─────────────────────────────────────────────────────────┘
```

**Benefits of this layered approach:**
- **Level 1 (derivedByYear)**: Instant access during a single view session
- **Level 2 (InfographicsCache)**: Fast access across multiple views in same app session
- **Level 3 (InfographicsCacheManager)**: Persistent storage across app launches

---

## Implementation Strategy

### Step 1: Define the `Derived` Struct

This struct holds **all** precomputed data for a specific year:

```swift
/// Holds all derived/precomputed data for a specific year
struct Derived {
    // Filtered events (base for all calculations)
    let filteredEvents: [Event]
    
    // Event type data (for donut chart)
    let eventTypeData: [(type: String, icon: String, count: Int, percentage: Int)]
    
    // Top locations (for bar chart & lists)
    let topLocations: [(name: String, count: Int, color: Color)]
    
    // Events with coordinates (for map)
    let eventsWithCoordinates: [Event]
    
    // Polyline coordinates (for journey map)
    let polylineCoordinates: [CLLocationCoordinate2D]
    
    // Travel statistics
    let travelStats: TravelStatisticsCache?
    
    // Top activities
    let topActivities: [(name: String, count: Int)]
    
    // Top people
    let topPeople: [(name: String, count: Int)]
    
    // Travel reach data
    let countriesVisited: Set<String>
    let detectedStates: Set<String>
    let usStaysCount: Int
    let internationalStaysCount: Int
    
    // Overview stats
    let totalStays: Int
    let uniqueLocationsCount: Int
    let totalDaysCount: Int
    let uniqueActivitiesCount: Int
    let uniquePeopleCount: Int
    let tripsCount: Int
}
```

### Step 2: Add Memoization State to InfographicsView

```swift
struct InfographicsView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedYear: String = "All Time"
    
    // MEMOIZATION: Store derived data per year
    @State private var derivedByYear: [String: Derived] = [:]
    
    // Track if current year is ready
    @State private var isCalculating = false
    
    // ... rest of the view
}
```

### Step 3: Compute Derived Data on Year Change

```swift
var body: some View {
    NavigationStack {
        ScrollView {
            VStack(spacing: 24) {
                yearFilterSection
                headerSection
                
                // Only show content when derived data is ready
                if let derived = derivedByYear[selectedYear] {
                    overviewStatsSection(derived: derived)
                    eventTypeSection(derived: derived)
                    locationStatsSection(derived: derived)
                    travelReachSection(derived: derived)
                    activitiesSection(derived: derived)
                    peopleSection(derived: derived)
                    journeyMapSection(derived: derived)
                    environmentalImpactSection(derived: derived)
                } else {
                    ProgressView("Calculating statistics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("Travel Infographic")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    generatePDF()
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
    .task(id: selectedYear) {
        // Check if we already have derived data for this year
        if derivedByYear[selectedYear] != nil {
            print("✅ Derived data already computed for \(selectedYear)")
            return
        }
        
        // Compute derived data in background
        isCalculating = true
        await computeDerivedData(for: selectedYear)
        isCalculating = false
    }
}
```

### Step 4: Implement computeDerivedData

```swift
private func computeDerivedData(for year: String) async {
    print("🔄 Computing derived data for \(year)...")
    
    // Step 1: Filter events for this year
    let filtered = computeFilteredEvents(for: year)
    
    // Step 2: Compute all derived values in a detached task
    let derived = await Task.detached(priority: .userInitiated) {
        // Event type data
        let eventTypeData = await computeEventTypeData(from: filtered)
        
        // Top locations
        let topLocations = await computeTopLocations(from: filtered)
        
        // Events with coordinates
        let eventsWithCoords = filtered.filter { event in
            let hasEventCoords = event.latitude != 0.0 && event.longitude != 0.0
            let hasLocationCoords = event.location.latitude != 0.0 && event.location.longitude != 0.0
            return hasEventCoords || hasLocationCoords
        }.sorted { $0.date < $1.date }
        
        // Polyline coordinates
        let polylineCoords = eventsWithCoords.map { event in
            if event.latitude != 0.0 && event.longitude != 0.0 {
                return CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
            } else {
                return CLLocationCoordinate2D(
                    latitude: event.location.latitude,
                    longitude: event.location.longitude
                )
            }
        }
        
        // Travel statistics
        let travelStats = await computeTravelStatistics(from: eventsWithCoords)
        
        // Top activities
        let topActivities = await computeTopActivities(from: filtered)
        
        // Top people
        let topPeople = await computeTopPeople(from: filtered)
        
        // Travel reach
        let countriesVisited = Set(filtered.compactMap { $0.country }.filter { !$0.isEmpty })
        let usStaysCount = filtered.filter { event in
            let country = event.country?.uppercased() ?? ""
            return country == "UNITED STATES" || country == "US" || country == "USA"
        }.count
        let internationalStaysCount = filtered.filter { event in
            let country = event.country?.uppercased() ?? ""
            return !country.isEmpty && country != "UNITED STATES" && country != "US" && country != "USA"
        }.count
        
        // States detection (if needed, can be done separately)
        let detectedStates: Set<String> = []  // Will be populated by separate task
        
        // Overview stats
        let totalStays = filtered.count
        let uniqueLocationsCount = Set(filtered.map { $0.location.id }).count
        let totalDaysCount = filtered.count
        let uniqueActivitiesCount = Set(filtered.flatMap { $0.activityIDs }).count
        let uniquePeopleCount = Set(filtered.flatMap { $0.people.map { $0.displayName } }).count
        
        // Get trips count for this year
        let tripsCount = await MainActor.run {
            if year == "All Time" {
                return store.trips.count
            } else if let y = Int(year) {
                return store.trips.filter { 
                    Calendar.current.component(.year, from: $0.departureDate) == y 
                }.count
            }
            return 0
        }
        
        return Derived(
            filteredEvents: filtered,
            eventTypeData: eventTypeData,
            topLocations: topLocations,
            eventsWithCoordinates: eventsWithCoords,
            polylineCoordinates: polylineCoords,
            travelStats: travelStats,
            topActivities: topActivities,
            topPeople: topPeople,
            countriesVisited: countriesVisited,
            detectedStates: detectedStates,
            usStaysCount: usStaysCount,
            internationalStaysCount: internationalStaysCount,
            totalStays: totalStays,
            uniqueLocationsCount: uniqueLocationsCount,
            totalDaysCount: totalDaysCount,
            uniqueActivitiesCount: uniqueActivitiesCount,
            uniquePeopleCount: uniquePeopleCount,
            tripsCount: tripsCount
        )
    }.value
    
    // Step 3: Store in state
    await MainActor.run {
        derivedByYear[year] = derived
        print("✅ Derived data computed for \(year)")
    }
}
```

### Step 5: Update View Sections to Use Derived Data

Instead of computed properties, pass the derived data:

```swift
// BEFORE: Computed property
private var eventTypeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Event Types")
            .font(.headline)
        
        let data = eventTypeData  // Recomputes every time!
        // ...
    }
}

// AFTER: Accept derived data
@ViewBuilder
private func eventTypeSection(derived: Derived) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Event Types")
            .font(.headline)
        
        let data = derived.eventTypeData  // Instant access!
        // ...
    }
}
```

### Step 6: Invalidate Memoization on Data Changes

```swift
struct InfographicsView: View {
    @EnvironmentObject var store: DataStore
    
    var body: some View {
        // ...
    }
    .onChange(of: store.dataUpdateToken) { _, _ in
        // Data changed - clear memoization
        derivedByYear.removeAll()
        
        // Recompute current year
        Task {
            await computeDerivedData(for: selectedYear)
        }
    }
}
```

---

## Benefits of This Approach

### 1. **Instant Year Switching**
```
User switches from 2024 → 2023 → 2024
├── 2023: Check derivedByYear["2023"]
│   └── Found! Display instantly (no calculation)
├── 2024: Check derivedByYear["2024"]
│   └── Found! Display instantly (no calculation)
Total time: <1ms
```

### 2. **Single Calculation Per Year**
```
First view of 2024:
├── computeDerivedData(for: "2024")
│   ├── Filter events: 50ms
│   ├── Compute all sections: 200ms
│   └── Store in derivedByYear["2024"]
Total: ~250ms

Subsequent views of 2024:
├── Access derivedByYear["2024"]
└── Display instantly
Total: <1ms
```

### 3. **Efficient Memory Usage**
```
Typical usage pattern: User views 2-3 years
├── derivedByYear["All Time"] → ~2KB
├── derivedByYear["2024"] → ~1KB
├── derivedByYear["2023"] → ~1KB
Total: ~4KB in memory
```

### 4. **Smart Invalidation**
```
User adds 1 event to 2024:
├── store.dataUpdateToken changes
├── derivedByYear.removeAll()
├── Recompute current year only
└── Other years computed on-demand
```

---

## Integration with Existing Cache Systems

### Option A: Use Only Memoization (Simplest)
- Remove `InfographicsCache` and `InfographicsCacheManager`
- Use only `derivedByYear` for in-memory caching
- **Pros**: Simple, clean, no complexity
- **Cons**: Cache cleared on app restart

### Option B: Layer Memoization + InfographicsCache (Recommended)
- Keep `InfographicsCache` for session-level caching
- Use `derivedByYear` for view-level memoization
- **Pros**: Fast access, survives view recreation
- **Cons**: Two cache layers

### Option C: Full Three-Tier (Advanced)
- Layer all three: derivedByYear → InfographicsCache → InfographicsCacheManager
- **Pros**: Maximum performance, persistent cache
- **Cons**: Most complex

**Recommendation**: Start with **Option A** for simplicity. You can add persistence later if needed.

---

## Implementation Checklist

- [ ] 1. Define `Derived` struct with all precomputed fields
- [ ] 2. Add `@State private var derivedByYear: [String: Derived]` to InfographicsView
- [ ] 3. Implement `computeDerivedData(for:)` method
- [ ] 4. Add `.task(id: selectedYear)` to trigger computation
- [ ] 5. Update all view sections to accept `Derived` parameter
- [ ] 6. Add `.onChange(of: store.dataUpdateToken)` to invalidate cache
- [ ] 7. Remove old computed properties (filteredEvents, topLocations, etc.)
- [ ] 8. Test year switching performance
- [ ] 9. Test data changes invalidation
- [ ] 10. Monitor memory usage

---

## Code Structure

```swift
// InfographicsView.swift
struct InfographicsView: View {
    // MARK: - State
    @EnvironmentObject var store: DataStore
    @State private var selectedYear: String = "All Time"
    @State private var derivedByYear: [String: Derived] = [:]
    @State private var isCalculating = false
    
    // MARK: - Body
    var body: some View {
        // Main UI
    }
    
    // MARK: - Derived Data Computation
    private func computeDerivedData(for year: String) async {
        // Compute all derived values
    }
    
    private func computeFilteredEvents(for year: String) -> [Event] {
        // Filter events
    }
    
    private func computeEventTypeData(from events: [Event]) -> [(type: String, icon: String, count: Int, percentage: Int)] {
        // Compute event types
    }
    
    private func computeTopLocations(from events: [Event]) -> [(name: String, count: Int, color: Color)] {
        // Compute locations
    }
    
    private func computeTravelStatistics(from events: [Event]) async -> TravelStatisticsCache? {
        // Compute travel stats
    }
    
    private func computeTopActivities(from events: [Event]) -> [(name: String, count: Int)] {
        // Compute activities
    }
    
    private func computeTopPeople(from events: [Event]) -> [(name: String, count: Int)] {
        // Compute people
    }
    
    // MARK: - View Sections
    @ViewBuilder
    private func overviewStatsSection(derived: Derived) -> some View {
        // UI using derived data
    }
    
    @ViewBuilder
    private func eventTypeSection(derived: Derived) -> some View {
        // UI using derived data
    }
    
    // ... more sections
}

// MARK: - Derived Data Model
struct Derived {
    // All precomputed fields
}
```

---

## Performance Expectations

### Before Memoization
```
Action: Switch years 5 times
├── Calculation time: 5 × 250ms = 1,250ms
├── UI freezes: 5 times
└── Memory spikes: 5 times
```

### After Memoization
```
Action: Switch years 5 times
├── First calculation: 250ms (once)
├── Cached access: 4 × 1ms = 4ms
├── UI freezes: 0
└── Memory spikes: 0
Total: ~254ms vs 1,250ms (5x faster)
```

### Memory Usage
```
Before: Recalculates on every access (no memory overhead)
After: Stores ~4KB per year (negligible)

Typical scenario (3 years cached):
Memory overhead: ~12KB
Performance gain: 5-10x faster
```

---

## Next Steps

1. **Review this guide** and decide on architecture (Option A, B, or C)
2. **Implement the Derived struct** with all necessary fields
3. **Add memoization state** to InfographicsView
4. **Implement computeDerivedData** method
5. **Update view sections** to use derived data
6. **Test and measure** performance improvements
7. **Document** the final implementation

Would you like me to proceed with implementing this solution?
