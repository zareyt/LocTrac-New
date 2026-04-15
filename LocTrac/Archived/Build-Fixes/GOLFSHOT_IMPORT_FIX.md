# Golfshot Import Bug Fix

## Problem Diagnosed

The Golfshot import was creating duplicate `.stay` events instead of updating existing events.

### Root Cause

**Line 186** in the original code had a critical bug:

```swift
// ❌ INCORRECT - Date doesn't have a .startOfDay property
return ev.date.startOfDay == localStartOfDay
```

The code was trying to access `ev.date.startOfDay` as a property, but `Date` doesn't have a `startOfDay` property. This caused the comparison to **always fail**, which meant:
- The `first(where:)` predicate never found matching events
- New events were created every time instead of updating existing ones
- This resulted in duplicate entries for the same day

### The Fix

**Corrected to:**
```swift
// ✅ CORRECT - Call the startOfDay(in:) method
return ev.date.startOfDay(in: .current) == localStartOfDay
```

Now the code properly calls the `startOfDay(in:)` method defined in the extension at the bottom of the file.

## New Features Added

### 1. Duplicate Detection
A new "Find Duplicate Golfing Events" button that:
- Scans all `.stay` events with the "Golfing" activity
- Groups them by date (start of day)
- Counts how many duplicates exist

### 2. Duplicate Removal
When duplicates are found:
- Shows the count of duplicate entries
- Displays a "Remove Duplicates" button
- Shows a confirmation dialog before deletion
- Keeps the first event for each day and removes the rest
- Updates the results panel with the count of removed entries

## How to Use

1. **Remove Existing Duplicates:**
   - Open the Import Golfshot view
   - Tap "Find Duplicate Golfing Events"
   - Review the count of duplicates found
   - Tap "Remove Duplicates" 
   - Confirm the action

2. **Future Imports:**
   - The import will now correctly update existing events
   - Only creates new events when no .stay event exists for that day
   - Properly appends the Golfing activity to existing events
   - Adds facility names to event notes (or appends with " • " separator)

## Technical Details

The fix ensures that:
- Dates are properly normalized to start-of-day for comparison
- The comparison uses the same timezone (`.current`) for both dates
- Existing events are properly identified and updated in-place
- The `store.update()` method is called to persist changes
- Duplicate detection uses the same date normalization logic as the import
