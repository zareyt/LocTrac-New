# Auto-Trip Issues & Fixes

## Issue 1: Trip Count Not Updating on Delete

**Problem**: Deleting event removes trips but count in Manage Trips doesn't decrement

**Cause**: The `@Published var trips` should trigger updates, but UI might be caching or not observing properly

**Debug Steps**:
1. Check if `store.trips.count` actually changes after delete
2. Check if TripsManagementView is using `store.trips` directly
3. Verify `@EnvironmentObject` is properly connected

**Status**: Need to verify if this is a UI refresh issue or actual data issue

---

## Issue 2: New Trips Not Showing in Home Screen

**Problem**: Creating trip doesn't add it to "Recent Events" on Home screen

**Cause**: Home screen `recentEvents` only shows `Event` objects, not `Trip` objects

**Fix Needed**: Add a new "Recent Trips" section to HomeView

### Proposed HomeView Addition:

```swift
private var recentTrips: [Trip] {
    Array(store.trips.sorted { $0.departureDate > $1.departureDate }.prefix(5))
}

// In body, add new section:
recentTripsSection

// New view component:
private var recentTripsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Image(systemName: "airplane.departure")
                .foregroundStyle(.blue)
            Text("Recent Trips")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        
        if recentTrips.isEmpty {
            Text("No trips yet")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        } else {
            ForEach(recentTrips) { trip in
                if let fromEvent = store.events.first(where: { $0.id == trip.fromEventID }),
                   let toEvent = store.events.first(where: { $0.id == trip.toEventID }) {
                    HStack {
                        Image(systemName: trip.mode.icon)
                            .foregroundStyle(Color(trip.mode.color))
                        
                        VStack(alignment: .leading) {
                            Text("\(fromEvent.location.name) → \(toEvent.location.name)")
                                .font(.subheadline)
                            Text("\(trip.formattedDistance) mi • \(trip.mode.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(trip.departureDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    .padding(.vertical, 8)
    .background(Color(.systemGray6))
    .cornerRadius(12)
    .padding(.horizontal)
}
```

---

## Testing Plan

### Test 1: Verify Trip Count Updates
1. Note current trip count in Manage Trips
2. Add event at different location
3. Check console for "✅ Creating new trip"
4. Go to Manage Trips
5. **Verify**: Count increased by 1
6. Delete the event
7. Check console for "✅ Removed X trip(s)"
8. Go to Manage Trips
9. **Verify**: Count decreased properly

### Test 2: Verify Recent Trips Display
1. Add new event (creates trip)
2. Go to Home screen
3. **Verify**: "Recent Trips" section shows new trip
4. **Verify**: Trip shows from/to locations, distance, mode

---

## Current Status

### Working ✅
- Trip creation when adding events
- Trip deletion when removing events
- Effective coordinates logic
- Debug logging

### Needs Investigation ❌
- Trip count UI refresh
- Recent trips on Home screen

---

## Quick Checks

### Check 1: Is data actually changing?
Add this log after trip operations:
```swift
print("   📊 Total trips now: \(trips.count)")
```

### Check 2: Is UI observing changes?
Verify TripsManagementView has:
```swift
@EnvironmentObject var store: DataStore
```

And uses:
```swift
store.trips.count // NOT a cached value
```

---

## Next Steps

1. ✅ Fixed effective coordinates
2. ✅ Added comprehensive debugging
3. ⏳ Add trip count to debug output
4. ⏳ Add recent trips section to HomeView
5. ⏳ Verify UI refresh behavior
