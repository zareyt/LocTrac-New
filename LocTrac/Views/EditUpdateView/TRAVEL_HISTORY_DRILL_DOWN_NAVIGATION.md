# Travel History: Drill-Down Navigation & List Jump Fix

## Problem Statement
- **List jumping**: Locations with 400+ entries were jumping around when selected
- **Usability**: Had to scroll excessively to get back to top after viewing an event
- **Scalability**: Expanding/collapsing 400+ items in a single list was slow and unwieldy

## Solution: Hierarchical Drill-Down Navigation

### New Architecture
Instead of expand/collapse in a single long list, implemented **3-level drill-down**:

```
Travel History (Main)
  └─ Location List (e.g., "Loft")
      └─ Year List (e.g., "2025") → Tap to drill down
          └─ Month List (e.g., "March") → Tap to drill down
              └─ Individual Stays → Tap to view details
```

### Benefits
1. ✅ **No more list jumping** - Each level is a separate view with stable state
2. ✅ **Better performance** - Only render visible level (not 400+ items at once)
3. ✅ **Easier navigation** - Clear hierarchy makes finding specific dates intuitive
4. ✅ **Back button** - iOS native back navigation (no scrolling to top)
5. ✅ **Faster loading** - Lazy loading of each drill-down level

## New Views

### 1. LocationDetailView
**Shows**: All events for a location grouped by year

**Features**:
- Summary stats (Total Stays, # Years, Span)
- List of years with stay counts
- Tap year → Navigate to YearDetailView

**Example**:
```
Loft
┌─────────────────────────┐
│ Total: 452  Years: 8    │
│ Span: 7y                │
├─────────────────────────┤
│ 2025     124 stays    > │
│ 2024     98 stays     > │
│ 2023     87 stays     > │
│ 2022     76 stays     > │
└─────────────────────────┘
```

### 2. YearDetailView
**Shows**: All events for a location in a specific year, grouped by month

**Features**:
- Year summary stats (Stays, # Months, Avg per Month)
- List of months with stay counts
- Tap month → Navigate to MonthDetailView

**Example**:
```
Loft - 2025
┌─────────────────────────┐
│ Stays: 124  Months: 11  │
│ Avg/Month: 11.3         │
├─────────────────────────┤
│ December   15 stays   > │
│ November   12 stays   > │
│ October    10 stays   > │
│ September  11 stays   > │
└─────────────────────────┘
```

### 3. MonthDetailView
**Shows**: Individual stays for a specific month

**Features**:
- Month summary stats (Stays, Activities, People)
- Full list of individual stays
- Tap stay → View stay details (existing StayDetailSheet)

**Example**:
```
December 2025
┌─────────────────────────┐
│ Stays: 15  Activities: 8│
│ People: 4               │
├─────────────────────────┤
│ Dec 28, 2025  ⚡🏃👤  │
│ Dec 26, 2025  ⚡      │
│ Dec 24, 2025  ⚡🏃    │
│ Dec 20, 2025          │
└─────────────────────────┘
```

## Code Changes

### TravelHistoryView.swift

#### Removed State Variables
```swift
// REMOVED: No longer needed with drill-down navigation
@State private var expandedSections: Set<String> = []
```

#### Added State Variables
```swift
// NEW: For potential future enhancements
@State private var selectedLocationID: String?
@State private var selectedYear: Int?
@State private var selectedMonth: Int?
```

#### Replaced locationGroupedView
```swift
// BEFORE: Expand/collapse in same view (causes jumping)
private var locationGroupedView: some View {
    ForEach(...) { locationGroup in
        Section {
            Button { /* expand/collapse */ }
            if isExpanded {
                ForEach(stays) { stay in /* 400+ items */ }
            }
        }
    }
}

// AFTER: NavigationLink to separate view (stable)
private var locationGroupedView: some View {
    List {
        ForEach(staysByLocation, id: \.location.id) { locationGroup in
            NavigationLink(destination: LocationDetailView(
                location: locationGroup.location,
                events: locationGroup.stays
            )) {
                LocationHeaderRow(...)
            }
        }
    }
}
```

### New Views Added

1. **LocationDetailView** (~60 lines)
   - Groups events by year
   - Shows summary stats
   - NavigationLinks to YearDetailView

2. **YearDetailView** (~70 lines)
   - Groups events by month
   - Shows year summary
   - NavigationLinks to MonthDetailView

3. **MonthDetailView** (~60 lines)
   - Lists individual events
   - Shows month summary
   - Sheet presentation for stay details

## Why This Fixes List Jumping

### Root Cause of Jumping
1. Single view with 400+ items
2. `staysByLocation` is computed property that re-sorts
3. Expand/collapse changes view hierarchy
4. SwiftUI diffing gets confused with position changes
5. List jumps to maintain selected item's new position

### How Drill-Down Fixes It
1. ✅ **Separate Views**: Each level has its own view with own state
2. ✅ **Stable Lists**: Each list is small (years, months, or filtered stays)
3. ✅ **No Re-sorting**: View state doesn't change on tap
4. ✅ **Navigation Stack**: iOS handles back navigation natively
5. ✅ **No Position Tracking**: New view = fresh layout, no jumping

## User Experience Improvements

### Before (Expand/Collapse)
```
1. See "Loft" in list
2. Tap to expand
3. Wait for 400+ items to render
4. Scroll through hundreds of items
5. Tap an event
6. View details
7. Close sheet
8. List has jumped - "Loft" now at bottom
9. Scroll back to top (frustrating!)
```

### After (Drill-Down)
```
1. See "Loft" in list
2. Tap "Loft" → Navigate to Location view
3. See years (2018-2025)
4. Tap "2025" → Navigate to Year view
5. See months (Jan-Dec)
6. Tap "December" → Navigate to Month view
7. See individual stays (15 items)
8. Tap a stay → View details
9. Close sheet
10. Back button → Month view (same position)
11. Back button → Year view (same position)
12. Back button → Location list (same position)
```

**Result**: No scrolling, no jumping, clear navigation path!

## Performance Benefits

### Before
- **Render**: 400+ StayRow views when expanded
- **Memory**: All 400+ views in memory simultaneously
- **Scroll performance**: Laggy with 400+ items

### After
- **Render**: ~8 year rows, OR ~12 month rows, OR ~30 stay rows (max)
- **Memory**: Only current level loaded
- **Scroll performance**: Smooth with small lists

## Testing Checklist

### Basic Navigation
- [ ] Open Travel History
- [ ] Tap a location with many events (e.g., "Loft" with 400+)
- [ ] ✅ Navigates to Location view (no jumping)
- [ ] See years list
- [ ] Tap a year (e.g., "2025")
- [ ] ✅ Navigates to Year view
- [ ] See months list
- [ ] Tap a month (e.g., "December")
- [ ] ✅ Navigates to Month view
- [ ] See individual stays
- [ ] Tap a stay
- [ ] ✅ Sheet appears with stay details

### Back Navigation
- [ ] From stay detail sheet: Dismiss
- [ ] ✅ Returns to Month view (same scroll position)
- [ ] Tap back button
- [ ] ✅ Returns to Year view (same scroll position)
- [ ] Tap back button
- [ ] ✅ Returns to Location view (same scroll position)
- [ ] Tap back button
- [ ] ✅ Returns to Travel History main list (same position)

### Summary Stats
- [ ] Location view shows: Total Stays, # Years, Span
- [ ] Year view shows: Stays, # Months, Avg/Month
- [ ] Month view shows: Stays, Activities, People

### Edge Cases
- [ ] Location with only 1 year of data (should still work)
- [ ] Year with only 1 month (should still work)
- [ ] Month with only 1 stay (should still work)
- [ ] Location with 0 stays (shouldn't appear in list)

## Migration Notes

### What's Preserved
- ✅ StayRow component (reused in MonthDetailView)
- ✅ LocationHeaderRow (reused in main list)
- ✅ StayDetailSheet (reused for individual stay details)
- ✅ All filtering and sorting logic
- ✅ Search functionality

### What's Removed
- ❌ Expand/collapse buttons
- ❌ `expandedSections` state tracking
- ❌ Complex nested ForEach with isExpanded checks

### What's New
- ✅ 3 new detail views with drill-down navigation
- ✅ Year/Month grouping logic
- ✅ Summary statistics at each level
- ✅ NavigationLink-based navigation

## Future Enhancements

### Potential Additions
1. **Calendar View**: Month view could show calendar grid
2. **Date Range Picker**: Filter by date range at any level
3. **Quick Actions**: Share/Export at year or month level
4. **Search**: Search within a specific year or month
5. **Favorites**: Star frequently accessed months/years
6. **Insights**: "You visited this location most in March"

### Performance Optimizations
1. **Lazy Loading**: Load months/years on demand
2. **Caching**: Cache computed year/month groupings
3. **Virtualization**: Use LazyVStack for very long lists

## Notes

- "Other" filter still uses old expand/collapse (fewer entries, less problematic)
- Could apply same drill-down pattern to "Other" if needed
- NavigationStack handles all navigation state automatically
- Back gesture works as expected
- No manual state management for navigation

---

**Priority**: HIGH - Major UX improvement  
**Impact**: Huge - Especially for power users with 400+ events  
**Complexity**: Medium - New views but straightforward logic  
**Status**: ✅ IMPLEMENTED  
**Date**: 2026-04-11  
**Version**: v1.5
