# Debug Logging Summary - Location Color Propagation

## What Was Added

Comprehensive debug logging to track location color changes from save to calendar display.

## Files Modified

### 1. DataStore.swift - `update(_ location: Location)`
**Added:** Extensive logging for entire update process
- Location update details (ID, theme, color hex)
- Before/after comparison
- Event update loop with per-event logging
- Total events updated count
- Calendar refresh trigger confirmation

### 2. ModernEventsCalendarView.swift - Three Areas

#### A. Calendar Refresh Token Observer
**Added:** Detailed onChange handler logging
- Old and new token values
- Trigger increment tracking

#### B. Calendar Decoration Rendering
**Added:** Per-decoration color debugging
- Event location details
- Store location details
- Color comparison
- Confirms which color is being used

#### C. Three-Month Window Reload
**Added:** Reload process tracking
- Start/end markers
- Date range being reloaded
- Number of days
- Success/failure states

## How to Use

### Quick Test:
1. Open Xcode console (⇧⌘Y)
2. Launch app
3. Go to Manage Locations
4. Change a location's color
5. Save
6. Watch console output

### Expected Output:
```
🎨 ========== LOCATION UPDATE START ==========
  [Location update details]
  [Events updated: N]
  [Calendar refresh triggered]
🎨 ========== LOCATION UPDATE END ==========

🔄 [Calendar refresh token changed]
  [Trigger incremented]

🔄 ========== CALENDAR RELOAD START ==========
  [Reloading N days]
🔄 ========== CALENDAR RELOAD END ==========

📅 [Calendar Decoration rendering]
  [Color details for each date]
```

## What to Look For

### Success Indicators:
✅ Events updated count > 0 (if location has events)
✅ Calendar refresh token changes
✅ Reload gets called
✅ Decorations render with new color

### Failure Indicators:
❌ 0 events updated (when location should have events)
❌ Calendar refresh token doesn't change
❌ Reload not called
❌ Decorations show old color
❌ Event location color != Store location color

## Console Filtering

To focus on specific parts:
- Filter: `🎨` → See only location updates
- Filter: `🔄` → See only calendar reloads
- Filter: `📅` → See only decoration renders
- Filter: `[DataStore]` → See only DataStore operations
- Filter: `[Coordinator]` → See only calendar coordinator

## Key Change

Also changed decoration color source:
```swift
// OLD: Look up from store
let eventColor = store.locations[index].theme.uiColor

// NEW: Use event's embedded location
let eventColor = UIColor(singleEvent.location.effectiveColor)
```

This ensures we're using the updated location that was copied to the event.

## Documentation

Full debug guide in: `DEBUG_LOCATION_COLOR.md`

## Next Steps

1. Run app with these changes
2. Perform color change test
3. Review console output
4. Share output to identify where the flow breaks
5. Fix identified issue
6. Optionally reduce verbosity for release

---

**Status**: 🔍 Debug Mode Active  
**Purpose**: Diagnose location color propagation issue  
**Created**: April 14, 2026
