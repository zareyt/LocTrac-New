# Location Color Propagation Debug Guide

## Debug Logging Added

Comprehensive debug logging has been added to track the location color update flow from the moment a location is saved through to the calendar decoration rendering.

## Debug Flow

### 1. Location Update (DataStore.swift)

When you save a location color change in Manage Locations, you'll see:

```
🎨 ========== LOCATION UPDATE START ==========
🎨 Updating location: [Location Name]
🎨 Location ID: [UUID]
🎨 New theme: [Theme Name]
🎨 New customColorHex: [#RRGGBB or nil]
🎨 Found location at index [N] in locations array
🎨 Location updated in array:
   Old theme: [Old Theme] → New theme: [New Theme]
   Old colorHex: [Old Hex] → New colorHex: [New Hex]
🎨 Searching for events with location ID: [UUID]
🎨 Total events in store: [N]
🎨 Updated event [index]: [Event UUID]
   Event date: [Date]
   Old location theme: [Old Theme]
   New location theme: [New Theme]
   Old location colorHex: [Old Hex]
   New location colorHex: [New Hex]
🎨 Total events updated: [N]
🎨 Calling bumpCalendarRefresh()
🎨 Calendar refresh token bumped to: [New UUID]
🎨 Saving data to disk...
🎨 ========== LOCATION UPDATE END ==========
```

**Key Things to Check:**
- ✅ Does it find the location in the array?
- ✅ Are theme and customColorHex being updated?
- ✅ How many events are being updated? (Should be > 0 if location has events)
- ✅ Is `bumpCalendarRefresh()` being called?
- ✅ Does the calendar refresh token change?

---

### 2. Calendar Refresh Trigger (ModernEventsCalendarView.swift)

When the calendar detects the refresh token change:

```
🔄 [ModernEventsCalendarView] Calendar refresh token changed!
   Old token: [Old UUID]
   New token: [New UUID]
   Incrementing calendarRefreshTrigger from [N] to [N+1]
```

**Key Things to Check:**
- ✅ Does the onChange handler fire?
- ✅ Is the token actually different?
- ✅ Is calendarRefreshTrigger being incremented?

---

### 3. Calendar Reload Execution (ModernCalendarView.Coordinator)

When the calendar reloads decorations:

```
🔄 ========== CALENDAR RELOAD START ==========
🔍 [Coordinator] Reloading based on [visible month/selected date/today]: [Date]
🔄 [Coordinator] Reloading decorations from [Start Date] to [End Date]
🔄 [Coordinator] Reloading [N] days of decorations
🔄 [Coordinator] Reload complete!
🔄 ========== CALENDAR RELOAD END ==========
```

**Key Things to Check:**
- ✅ Does the reload function get called?
- ✅ How many days are being reloaded? (Should be ~90 days for 3-month window)
- ✅ Does it complete successfully?

---

### 4. Calendar Decoration Rendering (ModernCalendarView.Coordinator)

For each date decoration being rendered:

```
📅 [Calendar Decoration] Rendering decoration for date: [DateComponents]
   Event location: [Location Name]
   Event location ID: [Location UUID]
   Event location theme: [Theme]
   Event location customColorHex: [#RRGGBB or nil]
   Store location theme: [Theme from store]
   Store location customColorHex: [Hex from store]
   Using color from event.location.effectiveColor
```

**Key Things to Check:**
- ✅ Does the event's embedded location have the NEW color?
- ✅ Does the store location have the NEW color?
- ✅ Do they match?

---

## How to Test with Debugging

### Step-by-Step Testing:

1. **Open Xcode Console** (View → Debug Area → Activate Console or ⇧⌘Y)

2. **Filter Console Output** (Optional)
   - Click the filter field in console
   - Type: `🎨` to see only location updates
   - Type: `🔄` to see only calendar reloads
   - Type: `📅` to see only decoration rendering

3. **Perform Color Change**
   - Launch app
   - Navigate to Settings → Manage Locations
   - Select a location that has events
   - Change its color
   - Tap Save

4. **Watch Console Output** - You should see the complete flow:
   ```
   🎨 LOCATION UPDATE START
     → Events updated
     → Calendar refresh triggered
   🎨 LOCATION UPDATE END
   
   🔄 Calendar refresh token changed
     → Trigger incremented
   
   🔄 CALENDAR RELOAD START
     → Decorations reloading
   🔄 CALENDAR RELOAD END
   
   📅 Calendar Decoration (for each visible date with events)
     → Color should be new color
   ```

5. **Navigate to Calendar**
   - Go to Calendar tab
   - Look at dates with events from the changed location
   - Decorations should show new color

6. **Check Console Again**
   - New decoration renders should show when calendar tab is visible
   - Event location should have new color

---

## Common Issues and Diagnostics

### Issue: No events updated
**Console Shows:**
```
🎨 Total events updated: 0
```

**Possible Causes:**
1. Location has no events yet
2. Location ID mismatch between location and events
3. Events stored with different location ID

**Solution:**
Check if events actually exist for this location:
```swift
print("Events for this location:")
for event in store.events {
    if event.location.id == location.id {
        print("  - \(event.date): \(event.location.name)")
    }
}
```

---

### Issue: Calendar refresh not triggered
**Console Shows:**
```
🎨 ========== LOCATION UPDATE END ==========
```
But NO:
```
🔄 [ModernEventsCalendarView] Calendar refresh token changed!
```

**Possible Causes:**
1. Calendar view not in view hierarchy when update happens
2. Store not being observed properly
3. ObservableObject publishing not working

**Solution:**
1. Make sure calendar tab exists (even if not visible)
2. Check `@EnvironmentObject` is set
3. Try navigating to Calendar tab BEFORE changing color

---

### Issue: Reload called but decorations wrong color
**Console Shows:**
```
🔄 CALENDAR RELOAD END
📅 Event location theme: [OLD THEME]
📅 Store location theme: [NEW THEME]
```

**Problem:** Event's embedded location wasn't updated!

**Solution:** 
The loop that updates events isn't working. Check:
1. Is `events[i].location = updatedLocation` being called?
2. Are there multiple DataStore instances?
3. Is the calendar using a different DataStore reference?

---

### Issue: Decorations rendered with new color but calendar shows old
**Console Shows:**
```
📅 Event location customColorHex: [NEW HEX]
```
But calendar still shows old color.

**Possible Causes:**
1. UIColor caching
2. Animation delay
3. Color conversion issue

**Solution:**
1. Try force-quitting app and relaunching
2. Check if `effectiveColor` property is working
3. Verify hex → Color conversion

---

## Expected Console Output (Full Success)

Here's what a SUCCESSFUL color change should look like in the console:

```
🎨 ========== LOCATION UPDATE START ==========
🎨 Updating location: Loft
🎨 Location ID: 12345-ABCDE-67890-FGHIJ
🎨 New theme: magenta
🎨 New customColorHex: #FF1493
🎨 Found location at index 0 in locations array
🎨 Location updated in array:
   Old theme: blue → New theme: magenta
   Old colorHex: nil → New colorHex: #FF1493
🎨 Searching for events with location ID: 12345-ABCDE-67890-FGHIJ
🎨 Total events in store: 150
🎨 Updated event 0: EVENT-UUID-1
   Event date: Apr 1, 2026
   Old location theme: blue
   New location theme: magenta
   Old location colorHex: nil
   New location colorHex: #FF1493
🎨 Updated event 1: EVENT-UUID-2
   Event date: Apr 5, 2026
   Old location theme: blue
   New location theme: magenta
   Old location colorHex: nil
   New location colorHex: #FF1493
... (more events)
🎨 Total events updated: 45
🎨 Calling bumpCalendarRefresh()
🎨 Calendar refresh token bumped to: TOKEN-UUID-NEW
🎨 Saving data to disk...
🎨 ========== LOCATION UPDATE END ==========

🔄 [ModernEventsCalendarView] Calendar refresh token changed!
   Old token: TOKEN-UUID-OLD
   New token: TOKEN-UUID-NEW
   Incrementing calendarRefreshTrigger from 0 to 1

🔄 ========== CALENDAR RELOAD START ==========
🔍 [Coordinator] Reloading based on visible month: Apr 2026
🔄 [Coordinator] Reloading decorations from Mar 1, 2026 to May 31, 2026
🔄 [Coordinator] Reloading 92 days of decorations
🔄 [Coordinator] Reload complete!
🔄 ========== CALENDAR RELOAD END ==========

📅 [Calendar Decoration] Rendering decoration for date: year: 2026 month: 4 day: 1
   Event location: Loft
   Event location ID: 12345-ABCDE-67890-FGHIJ
   Event location theme: magenta
   Event location customColorHex: #FF1493
   Store location theme: magenta
   Store location customColorHex: #FF1493
   Using color from event.location.effectiveColor

📅 [Calendar Decoration] Rendering decoration for date: year: 2026 month: 4 day: 5
   Event location: Loft
   Event location ID: 12345-ABCDE-67890-FGHIJ
   Event location theme: magenta
   Event location customColorHex: #FF1493
   Store location theme: magenta
   Store location customColorHex: #FF1493
   Using color from event.location.effectiveColor
```

---

## Removing Debug Logging (For Release)

All debug logging is wrapped in `#if DEBUG` or uses `print()` statements that can be disabled.

To remove debug output:
1. Build in Release configuration (Product → Scheme → Edit Scheme → Run → Build Configuration → Release)
2. Or search for `print("🎨"` and `print("🔄"` and `print("📅"` and comment out

To reduce verbosity but keep some logging:
- Keep the START/END markers
- Remove the per-event detail logging
- Keep error messages

---

## Next Steps

1. **Run the app with debugging enabled**
2. **Change a location color**
3. **Copy the console output**
4. **Share the output** to diagnose where the flow breaks

The debug output will tell us exactly where the color update is failing!
