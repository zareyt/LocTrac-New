# Affirmations Import Bug Fix

## Issue Found and Fixed ✅

### **Problem**
Only 2 affirmations were being restored during import instead of all affirmations.

### **Root Cause**
**Replace Mode** was missing the code to import affirmations! 

In `TimelineRestoreView.swift`, the Replace mode section imported:
- ✅ Locations: `store.locations = backup.locations`
- ✅ Activities: `store.activities = backup.activities`  
- ❌ **Affirmations: MISSING!**

### **The Fix**

Added the missing affirmations import in Replace mode:

```swift
if importAffirmations {
    store.affirmations = backup.affirmations
    importedAffirmationsCount = backup.affirmations.count
    print("📝 [performImport] Replace mode - Imported all affirmations: \(importedAffirmationsCount)")
}
```

Also added affirmation stripping in Replace mode when toggle is OFF:

```swift
if !importAffirmations {
    modifiedEvent.affirmationIDs = []
}
```

---

## Debug Logging Added 🔍

### **1. Backup Loading Debug**

Added to `loadBackupFile()`:
```swift
print("📊 [loadBackupFile] Decoded affirmations:")
print("   Total affirmations in backup: \(affirmations.count)")
for (index, affirmation) in affirmations.enumerated() {
    print("   [\(index)] ID: \(affirmation.id), Text: '\(affirmation.text)', Category: \(affirmation.category.rawValue)")
}
```

**What to look for**:
- Check if affirmations are being decoded from backup.json
- Verify count matches what you expect
- Check IDs and text are correct

### **2. Merge Mode Import Debug**

Added to affirmations import section:
```swift
print("📝 [performImport] Affirmations import (Merge mode):")
print("   Filtered events count: \(filteredEvents.count)")
print("   Referenced affirmation IDs: \(referencedAffirmationIDs.count)")
print("   IDs: \(Array(referencedAffirmationIDs))")
print("   Affirmations to import: \(affirmationsToImport.count)")
print("   Current store.affirmations count: \(store.affirmations.count)")

for affirmation in affirmationsToImport {
    let alreadyExists = store.affirmations.contains(where: { $0.id == affirmation.id })
    print("   Checking '\(affirmation.text)' (ID: \(affirmation.id)) - Already exists: \(alreadyExists)")
    
    if !alreadyExists {
        print("   ✅ Imported: '\(affirmation.text)'")
    } else {
        print("   ⏭️ Skipped (already exists): '\(affirmation.text)'")
    }
}

print("   Final imported count: \(importedAffirmationsCount)")
```

**What to look for**:
- How many events are in the selected date range
- Which affirmation IDs are referenced in those events
- How many affirmations are actually being imported
- Are any being skipped because they already exist?

### **3. Replace Mode Import Debug**

Added to Replace mode section:
```swift
if importAffirmations {
    store.affirmations = backup.affirmations
    importedAffirmationsCount = backup.affirmations.count
    print("📝 [performImport] Replace mode - Imported all affirmations: \(importedAffirmationsCount)")
}
```

**What to look for**:
- Confirmation that Replace mode is importing affirmations
- Total count imported

### **4. Event Stripping Debug (Replace Mode)**

Added:
```swift
if !importAffirmations && originalAffirmationCount > 0 {
    print("   🧹 Stripped \(originalAffirmationCount) affirmation references from events (Affirmations toggle OFF)")
}
```

**What to look for**:
- If affirmations toggle is OFF, are affirmation IDs being removed from events?

---

## How to Debug the Issue

### **Step 1: Check the Console During Import**

When you import a backup, look for these log messages:

```
📊 [loadBackupFile] Decoded affirmations:
   Total affirmations in backup: 10
   [0] ID: ABC123, Text: 'I am healthy, strong, and vibrant', Category: Health & Wellness
   [1] ID: DEF456, Text: 'I am grateful for this moment', Category: Gratitude
   ...
```

**Question**: Does it show all your affirmations from the backup file?
- ✅ YES → Backup file is good, decoding works
- ❌ NO → Problem is in backup.json or decoding

### **Step 2: Check Import Mode**

```
📥 [TimelineRestoreView] performImport starting:
   Import toggles - Events: true, Trips: true, Locations: true, Activities: true, Affirmations: true, People: true
   Import mode: Replace
```

**Questions**:
- Is `Affirmations: true`? (Toggle is ON)
- Is mode "Replace" or "Merge"?

### **Step 3A: If Replace Mode**

Look for:
```
📝 [performImport] Replace mode - Imported all affirmations: 10
```

**Questions**:
- Does it say "Imported all affirmations: X"?
- Is X the number you expect?
- If this line is MISSING → Bug was that Replace mode wasn't importing affirmations (NOW FIXED!)

### **Step 3B: If Merge Mode**

Look for:
```
📝 [performImport] Affirmations import (Merge mode):
   Filtered events count: 50
   Referenced affirmation IDs: 8
   IDs: ["ABC123", "DEF456", "GHI789", ...]
   Affirmations to import: 8
   Current store.affirmations count: 2
   Checking 'I am healthy...' (ID: ABC123) - Already exists: false
   ✅ Imported: 'I am healthy...'
   Checking 'I am grateful...' (ID: DEF456) - Already exists: true
   ⏭️ Skipped (already exists): 'I am grateful...'
   ...
   Final imported count: 6
```

**Questions**:
- How many events are in your date range?
- How many unique affirmation IDs are referenced?
- Are affirmations being skipped because they already exist?
- Is final count what you expect?

---

## Common Scenarios

### **Scenario 1: Only 2 Affirmations Imported (Your Case)**

**Possible Reasons**:

1. **Replace Mode Bug (NOW FIXED!)**
   - Replace mode wasn't importing affirmations at all
   - Only 2 existed before import, so you saw 2 total
   - **Solution**: Update applied! Try import again

2. **Merge Mode + Only 2 Referenced**
   - You're in Merge mode
   - Selected date range only has events with 2 unique affirmations
   - **Solution**: 
     - Check filtered events count
     - Check referenced affirmation IDs count
     - Use Replace mode to import all, OR
     - Expand date range to include more events

3. **Merge Mode + Already Exist**
   - You have existing affirmations
   - Import is skipping duplicates
   - **Solution**: Check "Already exists" logs
     - If all are being skipped, they're already there!
     - Use Replace mode to overwrite

### **Scenario 2: 0 Affirmations Imported**

**Possible Reasons**:

1. **Toggle is OFF**
   - Look for: `Affirmations: false` in import toggles
   - **Solution**: Turn ON the Affirmations toggle

2. **Backup has no affirmations**
   - Look for: `Total affirmations in backup: 0`
   - **Solution**: Backup was created before affirmations were added to device

3. **Merge Mode + No References**
   - Selected events don't use any affirmations
   - Look for: `Referenced affirmation IDs: 0`
   - **Solution**: Use Replace mode or expand date range

### **Scenario 3: Some But Not All Affirmations**

**Possible Reasons**:

1. **Merge Mode Filtering**
   - Only importing affirmations used in selected date range
   - Example: 10 total, but only 5 used in Jan-March
   - **Solution**: Expected behavior for Merge mode! Use Replace to get all

2. **Duplicate Detection**
   - Some affirmations already exist (same ID)
   - Look for: `⏭️ Skipped (already exists)`
   - **Solution**: Working as designed (prevents duplicates)

---

## Testing the Fix

### **Test 1: Replace Mode - All Affirmations**

1. Create backup with 10 affirmations
2. Start fresh or use Replace mode
3. Toggle Affirmations ON
4. Import

**Expected Result**:
```
📝 [performImport] Replace mode - Imported all affirmations: 10
✓ Successfully imported: X events, 10 affirmations, ...
```

### **Test 2: Merge Mode - Referenced Only**

1. Create backup with 10 affirmations
2. Select date range with events using only 3 affirmations
3. Use Merge mode
4. Toggle Affirmations ON
5. Import

**Expected Result**:
```
📝 [performImport] Affirmations import (Merge mode):
   Referenced affirmation IDs: 3
   Affirmations to import: 3
   Final imported count: 3
✓ Successfully imported: X events, 3 affirmations, ...
```

### **Test 3: Toggle OFF - No Affirmations**

1. Any backup
2. Toggle Affirmations OFF
3. Import

**Expected Result**:
```
📝 [performImport] Affirmations import DISABLED by toggle
(No affirmations in result message)
```

---

## Summary

### **Bug Fixed** ✅
- Replace mode now imports all affirmations
- Events properly cleaned when affirmations toggle is OFF

### **Debug Logging Added** 🔍
- Backup decoding logs show what's in the file
- Import logs show what's being imported/skipped
- Event stripping logs show what's being removed

### **Next Steps**
1. Try importing again with the fix applied
2. Check console logs to see what's happening
3. Share the logs if still having issues

The most likely cause was **Replace mode not importing affirmations** - now fixed!
