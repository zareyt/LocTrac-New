# Map View Year Filter & Dynamic Sizing Feature

## Overview
Added year-based filtering and **smooth proportional sizing** to the map view for both Location stays (red pins) and Other stay events (blue pins). Pins and labels now scale dynamically based on the number of events relative to the maximum, creating a natural visual hierarchy.

## Features Implemented

### 1. Year Filter
- **Filter Picker**: Appears at **bottom** of map view (just above tab bar) with calendar icon
- **Options**: "All Years" (default) + all available years from events
- **Sorting**: Years displayed most recent first
- **Design**: Frosted glass appearance (`.ultraThinMaterial`)
- **Filtering**: Applies to both regular locations and "Other" events simultaneously
- **Ergonomics**: Bottom placement for easy thumb access on mobile devices

### 2. Smooth Proportional Sizing
Pins and labels scale **smoothly** based on event count relative to the maximum:

#### Scaling Algorithm:
- **Range**: 0.7x (minimum) to 2.0x (maximum scale)
- **Formula**: `scale = minScale + (√proportion × (maxScale - minScale))`
- **Proportional**: Calculated relative to location/city with most events
- **Square Root Curve**: Better visual distribution
  - Prevents tiny items from being invisible
  - Prevents huge items from dominating the map
  - Creates smooth gradual transitions
- **Adaptive**: Recalculates when year filter changes

#### Example Scenarios:
**Scenario 1: All Years View**
- Mom's House: 100 events → 2.0x scale (max)
- Friend's House: 50 events → 1.61x scale (smooth mid-range)
- Coffee Shop: 25 events → 1.35x scale
- One-time Visit: 1 event → 0.7x scale (min)

**Scenario 2: Filtered to 2024**
- Arrowhead: 20 events (max in 2024) → 2.0x scale
- Friend's House: 10 events → 1.61x scale
- Coffee Shop: 5 events → 1.35x scale

#### Visual Changes:
- **Pin Size**: Scales smoothly and proportionally (both red location pins and blue "Other" pins)
- **Label Text**: Font size increases progressively with scale
- **Event Count Badge**: Small pill-shaped badge showing exact number of stays
  - Red badge for Location stays
  - Blue badge for Other stay events
- **Natural Hierarchy**: Visual importance matches actual usage patterns

#### Font Mapping:
| Scale Range    | Font Size      |
|----------------|----------------|
| 0.7 - 0.9      | Caption        |
| 0.9 - 1.1      | Caption        |
| 1.1 - 1.3      | Subheadline    |
| 1.3 - 1.5      | Body           |
| 1.5 - 1.7      | Callout        |
| 1.7 - 1.85     | Title 3        |
| 1.85 - 2.0     | Title 2        |
| 2.0+           | Title          |

### 3. Responsive Behavior
- **All Years**: Shows all locations and events (no filtering)
- **Specific Year**: Shows only locations/cities with events from that year
- **Real-time Updates**: Map updates immediately when year filter changes
- **Selected State**: Selected locations scale an additional 1.2x larger

## Implementation Details

### LocationsMapViewModel.swift
Added enhanced scaling functions:

```swift
// Get available years from all events
func availableYears() -> [Int]

// Get event count for a location (respects year filter)
func eventCount(for location: Location) -> Int

// Get maximum event count (includes both locations and "Other" cities)
func maxEventCount() -> Int

// Calculate smooth proportional scale factor
func scaleForEventCount(_ count: Int) -> CGFloat

// Map scale to appropriate font size
func fontSizeForScale(_ scale: CGFloat) -> Font
```

**Key Improvements:**
- `maxEventCount()` now considers both regular locations AND "Other" city events
- Scaling uses square root curve for better visual distribution
- Font sizes map smoothly to scale values

### LocationsView.swift
Enhanced with:

1. **Year Filter Picker UI**
   - Clean HStack with calendar icon + picker
   - **Positioned at bottom** (just above tab bar)
   - Easy thumb access on mobile devices

2. **Dynamic Pin Rendering**
   - Regular locations (red): Pin + label + count badge
   - Other events (blue): Circle + label + count badge
   - Both use smooth proportional scaling

3. **Font Integration**
   - Uses `vm.fontSizeForScale()` for consistent sizing
   - All labels scale appropriately with pins

## User Experience

### Before:
```
Map View
├── All locations shown equally (no filtering)
├── All pins same size
└── No visual indication of activity level
```

### After:
```
Map View
├── Map with proportionally sized pins
├── Busier locations = Larger pins/labels (smooth gradation)
├── Event count badges on all pins
├── Only shows locations/events from selected year
└── [📅 2024 ▼]  ← Filter picker at bottom (above tab bar)
```

### Example Visual Hierarchy:
Using "All Years" filter where max is 100 events:
- **Mom's House** (100 stays) → 2.0x scale, title font, "100" badge (LARGEST)
- **Arrowhead** (50 stays) → 1.61x scale, title3 font, "50" badge (large)
- **Friend's House** (25 stays) → 1.35x scale, body font, "25" badge (medium)
- **Coffee Shop** (10 stays) → 1.11x scale, subheadline font, "10" badge (small)
- **One-time Visit** (1 stay) → 0.7x scale, caption font, "1" badge (smallest)

Switching to "2024" filter where max becomes 20 events:
- **Arrowhead** (20 stays) → 2.0x scale, title font, "20" badge (NOW LARGEST)
- **Friend's House** (10 stays) → 1.61x scale, title3 font, "10" badge
- **Coffee Shop** (5 stays) → 1.35x scale, body font, "5" badge

## Benefits

1. **Better Data Visualization**: Immediately see which locations you visit most
2. **Smooth Visual Hierarchy**: Proportional scaling creates natural, readable map
3. **Temporal Filtering**: Focus on specific years of travel
4. **Adaptive Scaling**: Maximum always gets largest size, proportions adjust dynamically
5. **Reduced Clutter**: Filter out irrelevant time periods
6. **Quick Insights**: Visual hierarchy shows travel patterns at a glance
7. **Ergonomic Design**: Bottom filter placement for easy mobile access
8. **Consistent Design**: Same sizing logic for both location types

## Technical Notes

- Year filter is optional (`Int?`) - `nil` represents "All Years"
- Event counting respects the current year filter
- **Smooth scaling formula**: `scale = 0.7 + (√(count/max) × 1.3)`
- Square root prevents extreme size differences
- `maxEventCount()` includes both regular locations and "Other" cities
- Filtering happens in computed properties for efficiency
- Scale calculations are centralized in view model
- Font sizes map smoothly to scale ranges for readability

## Math Behind the Scaling

```swift
// Given:
let count = 25        // Events at this location
let maxCount = 100    // Maximum events at any location
let minScale = 0.7    // Minimum visual scale
let maxScale = 2.0    // Maximum visual scale

// Calculate:
let proportion = 25 / 100 = 0.25
let smoothProportion = √0.25 = 0.5
let scale = 0.7 + (0.5 × (2.0 - 0.7)) = 0.7 + 0.65 = 1.35

// Result: This location appears at 1.35x scale
```

This ensures that a location with 25% of the maximum events appears at roughly the midpoint of the visual scale range, creating better visual balance.

## Testing Checklist

- [ ] Year filter shows all available years from events
- [ ] "All Years" option shows all locations and events
- [ ] Selecting a year filters both red and blue pins
- [ ] Pin sizes scale correctly based on event count
- [ ] Labels use appropriate font sizes for each scale tier
- [ ] Event count badges display correct numbers
- [ ] Selected location scales an additional 20% larger
- [ ] Filtering updates in real-time when year changes
- [ ] Locations with 0 events in selected year are hidden
- [ ] Badge colors match pin types (red/blue)
