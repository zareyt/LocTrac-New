# 🐛 Debugging First Launch Wizard

## Current Status

✅ App doesn't crash anymore
❌ Wizard not showing on first launch
❌ Seed.json not loading

## What I've Just Fixed

I've integrated the wizard directly into `StartTabView.swift` with extensive debug logging. The changes include:

1. **Added state variable** for wizard
2. **Added `.onAppear` handler** that checks `isFirstLaunch`
3. **Added debug prints** to see what's happening
4. **Added `.sheet` presentation** for the wizard

## Testing Steps

### Step 1: Clean Slate Test

To test first launch properly:

1. **Delete the app** from simulator/device completely
2. **Clean build folder**: Product > Clean Build Folder (Cmd+Shift+K)
3. **Build and run** the app
4. **Check the Xcode console** for debug output

### Step 2: Read the Console Output

After launching, you should see output like this:

```
🚀 StartTabView appeared
📝 isFirstLaunch: true
📦 Locations count: 0
📦 Events count: 0
📦 Activities count: 0
✅ hasCompletedFirstLaunch: false
📄 backup.json exists: false
📍 backup.json path: /path/to/backup.json
🎉 Showing First Launch Wizard!
```

**What to look for:**
- `isFirstLaunch` should be `true`
- `hasCompletedFirstLaunch` should be `false`
- `backup.json exists` should be `false`
- Counts should be `0` or show Seed.json data

### Step 3: Check Seed.json

If you want Seed.json to load:

1. Make sure `Seed.json` is in your project
2. Check that it's included in the app target:
   - Select Seed.json in Project Navigator
   - Look at File Inspector (right panel)
   - Verify "Target Membership" has your app checked ✅

3. If Seed.json exists, you should see:
   ```
   📝 No backup.json found - this appears to be first launch
   📦 Loading from Seed.json
   ✅ Loaded Locations: X
   ✅ Loaded Events: Y
   ✅ Loaded Activities: Z
   ```

### Step 4: Test Wizard Flow

If wizard appears:
1. Go through all 3 steps
2. Click "Get Started" on final step
3. Check console for:
   ```
   Data saved successfully
   /path/to/backup.json
   ```

## Common Issues & Solutions

### Issue 1: Wizard Still Doesn't Appear

**Possible causes:**
1. UserDefaults still has the flag from previous testing
2. backup.json exists from previous run

**Solution:**
```swift
// Add this as a debug option or run in console:
UserDefaults.standard.removeObject(forKey: "hasCompletedFirstLaunch")

// Then find and delete backup.json manually:
// Simulator: ~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/...
// Or just delete the app and reinstall
```

### Issue 2: Seed.json Not Loading

**Check 1:** Is it in the bundle?
```swift
// This should print the URL
if let url = Bundle.main.url(forResource: "Seed", withExtension: "json") {
    print("✅ Seed.json found at: \(url)")
} else {
    print("❌ Seed.json NOT in bundle")
}
```

**Check 2:** Is it valid JSON?
- Open Seed.json in Xcode
- Check for syntax errors
- Verify it matches the Import structure

**Check 3:** Target membership
- Select Seed.json in Project Navigator
- Ensure it's checked for your app target

### Issue 3: Console Shows "isFirstLaunch: false" But It Should Be True

This means either:
- backup.json exists (shouldn't on first launch)
- hasCompletedFirstLaunch is true (shouldn't be)

**Fix:**
1. Delete the app
2. Clean build folder
3. Check for orphaned UserDefaults or files

## Manual Testing Checklist

Run through these scenarios:

- [ ] **Fresh Install**
  - Delete app
  - Clean build
  - Run app
  - Wizard should appear
  - Console shows debug output

- [ ] **With Seed.json**
  - Ensure Seed.json is in project
  - Delete app
  - Run app
  - Should load Seed.json data
  - Console shows: "📦 Loading from Seed.json"

- [ ] **Without Seed.json**
  - Remove Seed.json from target
  - Delete app
  - Run app
  - Should initialize empty arrays
  - Console shows: "🎯 No Seed.json found - initializing with empty data"
  - Wizard should appear

- [ ] **After Wizard Completion**
  - Complete wizard
  - Close app
  - Reopen app
  - Wizard should NOT appear
  - Console shows: "👍 Not first launch, proceeding normally"

- [ ] **Data Persistence**
  - Add location in wizard
  - Complete wizard
  - Close app
  - Reopen app
  - Location should still be there

## Debug Commands

### Reset First Launch Flag
```swift
UserDefaults.standard.removeObject(forKey: "hasCompletedFirstLaunch")
```

### Check backup.json Location
```swift
let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    .first!.appendingPathComponent("backup.json")
print("backup.json path: \(path)")
print("Exists: \(FileManager.default.fileExists(atPath: path.path))")
```

### Force Show Wizard (for testing)
```swift
// In StartTabView, temporarily change:
if store.isFirstLaunch {
    showFirstLaunchWizard = true
}
// To:
showFirstLaunchWizard = true  // Always show for testing
```

## What You Should See

### Scenario A: First Launch WITH Seed.json
```
📝 No backup.json found - this appears to be first launch
📦 Loading from Seed.json
✅ Loaded Locations: 5
✅ Loaded Events: 127
✅ Loaded Activities: 6
🚀 StartTabView appeared
📝 isFirstLaunch: false  ← Note: false because data exists!
📦 Locations count: 5
```
**Result:** No wizard (data exists), but app works normally

### Scenario B: First Launch WITHOUT Seed.json
```
📝 No backup.json found - this appears to be first launch
🎯 No Seed.json found - initializing with empty data for wizard
🚀 StartTabView appeared
📝 isFirstLaunch: true
📦 Locations count: 0
📦 Events count: 0
📦 Activities count: 0
✅ hasCompletedFirstLaunch: false
📄 backup.json exists: false
🎉 Showing First Launch Wizard!
```
**Result:** Wizard appears! ✅

### Scenario C: After Wizard Completion
```
📂 Loading from backup.json
✅ Loaded Locations: 2
✅ Loaded Events: 0
✅ Loaded Activities: 6
🚀 StartTabView appeared
📝 isFirstLaunch: false
📦 Locations count: 2
✅ hasCompletedFirstLaunch: true
📄 backup.json exists: true
👍 Not first launch, proceeding normally
```
**Result:** No wizard, normal app flow ✅

## Next Steps

1. **Run the app and check console output**
2. **Copy the console output here** so we can diagnose
3. **Report which scenario you're seeing** (A, B, or C)
4. **Check if wizard appears or not**

The debug logging will tell us exactly what's happening!
