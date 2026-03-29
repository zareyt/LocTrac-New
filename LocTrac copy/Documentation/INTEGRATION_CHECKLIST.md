# 📋 Implementation Checklist

Follow these steps to integrate the First Launch Wizard into your app.

## ✅ Pre-Integration Checks

- [ ] **Check for Person Model**
  - Search your project for `struct Person` or `class Person`
  - If found, **delete** the Person definition from `ImportExportModels.swift` (lines with MARK: - Person Model)
  - If not found, keep the Person struct in ImportExportModels.swift

- [ ] **Backup Your Project**
  - Commit current changes to git, or
  - Create a backup copy of your project folder

- [ ] **Find Your Main View**
  - Locate your app's main entry point (file with `@main struct`)
  - Identify your main navigation view (TabView, NavigationStack, etc.)
  - You'll need this name for Step 3

## 🔧 Integration Steps

### Step 1: Add New Files ✅ (Already Done)

These files have been created:
- ✅ `FirstLaunchWizard.swift`
- ✅ `ImportExportModels.swift`
- ✅ `RootView.swift`
- ✅ `FIRST_LAUNCH_WIZARD_GUIDE.md`
- ✅ `FIRST_LAUNCH_WIZARD_QUICKSTART.md`

### Step 2: Update DataStore ✅ (Already Done)

Changes made to `DataStore.swift`:
- ✅ Added `isFirstLaunch` property
- ✅ Updated `loadData()` to handle missing files
- ✅ Added `loadFromURL()` helper method
- ✅ Removed `fatalError` calls
- ✅ Added graceful error handling

### Step 3: Update RootView

- [ ] Open `RootView.swift`
- [ ] Find line 17: `Text("Main App Content")`
- [ ] Replace with your main view name, for example:
  ```swift
  StartTabView()
  // or
  MainTabView()
  // or
  ContentView()
  ```

### Step 4: Update App Entry Point

- [ ] Find your app's main file (e.g., `LocTracApp.swift` or `YourAppNameApp.swift`)
- [ ] Locate the `@main` struct with `var body: some Scene`
- [ ] Replace the WindowGroup content with `RootView()`:

**Before:**
```swift
@main
struct LocTracApp: App {
    @StateObject private var store = DataStore()
    
    var body: some Scene {
        WindowGroup {
            YourMainView()  // or StartTabView(), etc.
                .environmentObject(store)
        }
    }
}
```

**After:**
```swift
@main
struct LocTracApp: App {
    @StateObject private var store = DataStore()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
```

### Step 5: Build & Test

- [ ] Clean build folder: `Product > Clean Build Folder` (Cmd+Shift+K)
- [ ] Delete app from simulator
- [ ] Build and run
- [ ] Verify wizard appears
- [ ] Complete wizard
- [ ] Verify app loads normally

## 🧪 Testing Checklist

### Test 1: First Launch
- [ ] App shows wizard automatically
- [ ] Can navigate through all 3 steps
- [ ] Can add locations (with city geocoding)
- [ ] Can select default activities
- [ ] Can add custom activities
- [ ] "Get Started" button completes wizard
- [ ] App navigates to main view

### Test 2: Second Launch
- [ ] Force quit app
- [ ] Relaunch app
- [ ] Wizard does NOT appear
- [ ] App loads normally
- [ ] Data from wizard is present

### Test 3: Data Persistence
- [ ] Check Documents folder for `backup.json`
- [ ] Verify JSON contains locations and activities
- [ ] Verify UserDefaults has `hasCompletedFirstLaunch = true`

### Test 4: Error Handling
- [ ] No crashes if geocoding fails
- [ ] No crashes if user skips all steps
- [ ] No crashes with empty data

## 🐛 Troubleshooting

### Issue: Build errors about Person
**Solution:** Check if Person is defined elsewhere in your project. Delete duplicate definition.

### Issue: Build errors about Import/Export
**Solution:** Make sure `ImportExportModels.swift` is added to your target in Xcode.

### Issue: Wizard doesn't appear
**Solution:** 
1. Delete app from simulator
2. Check that no `backup.json` exists
3. Verify `isFirstLaunch` returns true
4. Check console logs for "📝 No backup.json found"

### Issue: App crashes on first launch
**Solution:**
1. Check console for error messages
2. Verify all force unwraps are removed from DataStore
3. Check that Export/Import models match your data structures

### Issue: Can't find main view name
**Solution:**
1. Look for `@main struct` in your project
2. Find the view inside `WindowGroup { ... }`
3. Use that view name in RootView.swift

## 🎨 Customization (Optional)

After successful integration, you can customize:

- [ ] Modify default activities list
- [ ] Change wizard colors/styling
- [ ] Add more wizard steps
- [ ] Customize welcome message
- [ ] Add app logo to welcome screen

See `FIRST_LAUNCH_WIZARD_GUIDE.md` for customization details.

## 📝 Notes

- Keep `Seed.json` if you have it - it provides fallback data
- Wizard is shown only once per installation
- To reset: `UserDefaults.standard.removeObject(forKey: "hasCompletedFirstLaunch")`
- All wizard steps are optional - users can skip adding data
- Geocoding has built-in rate limiting

## ✨ Success Criteria

Your integration is successful when:

✅ App launches without crashes on first run
✅ Wizard appears and guides user through setup
✅ backup.json is created after wizard completion
✅ App launches normally on subsequent runs
✅ No wizard appears after completion
✅ Added locations and activities are visible in app

---

**Questions or issues?** Check the detailed guide: `FIRST_LAUNCH_WIZARD_GUIDE.md`
