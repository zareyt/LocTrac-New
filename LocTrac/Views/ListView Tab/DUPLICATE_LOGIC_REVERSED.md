# Duplicate Detection Logic - REVERSED! ✅

## What Changed

The duplicate detection now **keeps ORIGINALS and deletes IMPORTS** (previously it was backwards).

## New Priority Order (Keep First)

The logic now prioritizes keeping your original events:

### 1. ❌ Deprioritize Import Locations
Events at **"Loft"** or **"Other"** are marked as likely imports and will be deleted

### 2. 👥 Keep Events with People
Events that have people associated are kept (imports have none)

### 3. 🏃 Keep Events with More Activities  
Events with more activities are kept (imports typically only have "Golfing")

### 4. 📝 Keep Events with Longer Notes
Events with more detailed notes are kept (imports just have golf course name)

### 5. 🆔 Keep Older ID
If everything else is equal, keep the event with the earlier UUID (older)

## Example

### Before (Wrong Behavior):
```
KEEP: Location=Loft, Note="Pebble Beach" (import) ❌
DELETE: Location=Home, Note="Golf with Bob", 3 activities, 2 people ❌
```

### After (Correct Behavior):
```
✅ KEEP: Location=Home, Note="Golf with Bob", 3 activities, 2 people
🗑️ DELETE: Location=Loft, Note="Pebble Beach" (import)
```

## What You'll See in Preview

### Events Marked to KEEP (Green):
- Real location names (Home, Office, etc.)
- Detailed notes with context
- Multiple activities
- Associated people
- Older creation date

### Events Marked to DELETE (Red):
- Location = "Loft" or "Other"
- Simple note (just golf course name)
- Only "Golfing" activity (or none)
- No people
- Recently created (from import)

## Test It

1. Click "Scan for Duplicate Events by Date"
2. Click "Preview Duplicates"
3. Check the first few entries:
   - Green (KEEP) should show your original events with rich data
   - Red (DELETE) should show "Loft"/"Other" locations with minimal data
4. If it looks correct, tap "Delete X Duplicates"
5. If something looks wrong, tap "Cancel" and nothing happens

The system will now correctly identify and remove the imported duplicates while preserving your original event data! 🎯
