# First Launch Wizard Implementation Guide

## Overview

The First Launch Wizard provides a smooth onboarding experience for new users, guiding them through setting up:
- Initial locations
- Activity types
- Understanding event types

This prevents the app from crashing when `backup.json` doesn't exist on first launch.

## Files Created

### 1. **FirstLaunchWizard.swift**
The main wizard interface with three steps:
- **Welcome Step**: Introduces the app and its features
- **Locations Step**: Allows users to add their first locations (optional)
- **Activities Step**: Lets users select from common activities or create custom ones

### 2. **ImportExportModels.swift**
Defines the data structures for saving/loading backup.json:
- `Export`: Container for all app data
- `ExportLocation`, `ExportEvent`, `ExportActivity`: Individual models
- `Import`: Type alias for backward compatibility
- `Person`: Person model for events (if not defined elsewhere)

### 3. **RootView.swift**
A wrapper view that checks for first launch and shows the wizard when needed.

## Changes Made to Existing Files

### DataStore.swift

#### Added Properties:
```swift
var isFirstLaunch: Bool {
    let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedFirstLaunch")
    let backupExists = FileManager.default.fileExists(
        atPath: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("backup.json").path
    )
    return !hasCompleted && !backupExists
}
```

#### Updated Methods:

**loadData()** - Now handles missing files gracefully:
- Checks if backup.json exists
- Falls back to Seed.json if available
- Initializes with empty data if neither exists (for wizard)
- No longer crashes with `fatalError`

**loadFromURL()** - New private method:
- Separated loading logic for reusability
- Handles decoding errors gracefully
- Uses safe unwrapping instead of force unwraps
- Returns empty data on failure instead of crashing

## Integration Instructions

### Option 1: Using RootView (Recommended)

Replace your app's main view with RootView:

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

Then update RootView.swift to use your actual main view:

```swift
var body: some View {
    Group {
        StartTabView() // Replace with your actual main view
            .onAppear {
                checkFirstLaunch()
            }
    }
    .sheet(isPresented: $showWizard) {
        FirstLaunchWizard()
            .environmentObject(store)
    }
}
```

### Option 2: Direct Integration

Add the wizard check directly to your main view:

```swift
struct YourMainView: View {
    @EnvironmentObject var store: DataStore
    @State private var showWizard = false
    
    var body: some View {
        // Your existing view code
        TabView {
            // ...
        }
        .onAppear {
            if store.isFirstLaunch {
                showWizard = true
            }
        }
        .sheet(isPresented: $showWizard) {
            FirstLaunchWizard()
                .environmentObject(store)
        }
    }
}
```

## How It Works

### First Launch Detection

The wizard appears when:
1. `backup.json` doesn't exist in Documents folder
2. User hasn't completed wizard before (`hasCompletedFirstLaunch` UserDefaults key is false)

### Wizard Flow

**Step 1: Welcome**
- Introduces app features
- Explains what locations, events, and activities are
- Beautiful visual introduction

**Step 2: Locations (Optional)**
- Users can add locations with names and cities
- Automatically geocodes city names to get coordinates and country
- Displays added locations with ability to delete
- Skippable - users can add locations later

**Step 3: Activities**
- Shows common activities (Golfing, Skiing, Biking, etc.)
- Pre-selected defaults for convenience
- Users can toggle these on/off
- Users can add custom activities
- Manages the global activities list in DataStore

**Completion**
- Saves UserDefaults flag: `hasCompletedFirstLaunch = true`
- Calls `store.storeData()` to create initial `backup.json`
- Dismisses wizard
- User sees main app interface

### Data Created

On wizard completion:
- `backup.json` is created in Documents folder
- Contains any locations user added (or empty array)
- Contains selected activities
- Empty events array (user will add events in app)
- UserDefaults flag prevents wizard from showing again

## Error Handling

The updated DataStore now handles errors gracefully:

### Missing Seed.json
- **Old behavior**: Fatal crash
- **New behavior**: Initializes with empty data, wizard fills it

### Corrupted JSON
- **Old behavior**: Fatal crash
- **New behavior**: Logs error, initializes with empty data

### Missing Required Fields
- **Old behavior**: Force unwrap crash
- **New behavior**: Uses default values or creates placeholder data

## Testing

### Test First Launch
1. Delete the app from simulator/device
2. Clean build folder (Cmd+Shift+K)
3. Build and run
4. Wizard should appear automatically

### Test After Wizard
1. Complete wizard
2. Force quit app
3. Relaunch
4. Should go directly to main app (no wizard)

### Reset First Launch
```swift
// Run this in Xcode console or add as debug menu option
UserDefaults.standard.removeObject(forKey: "hasCompletedFirstLaunch")
```

## Customization

### Modify Default Activities
Edit the list in `ActivitiesStepView`:
```swift
let defaultActivities = ["Golfing", "Skiing", "Biking", "Yoga", "Exercise", "Pickleball", "Hiking", "Swimming", "Running", "Reading"]
```

### Modify Pre-Selected Activities
Edit in `ActivitiesStepView.onAppear`:
```swift
selectedDefaultActivities = Set(["Golfing", "Skiing", "Biking", "Yoga", "Exercise", "Pickleball"])
```

### Change Wizard Steps
Add or remove steps in `FirstLaunchWizard`:
```swift
let totalSteps = 4 // Increase number

TabView(selection: $currentStep) {
    WelcomeStepView().tag(0)
    LocationsStepView().tag(1)
    ActivitiesStepView().tag(2)
    YourNewStepView().tag(3) // Add new step
}
```

### Styling
All views use native SwiftUI components with material backgrounds for modern appearance. Customize colors, fonts, and spacing as needed.

## Troubleshooting

### Wizard Won't Appear
- Check that `backup.json` is truly missing
- Verify UserDefaults hasn't been set
- Ensure `isFirstLaunch` returns true

### App Still Crashes
- Check if Person model exists elsewhere (might conflict with ImportExportModels.swift)
- Verify all force unwraps are removed from DataStore
- Check console for specific error messages

### Data Not Saving
- Verify Documents directory is writable
- Check `storeData()` logs for errors
- Ensure Export model matches your data structures

## Future Enhancements

Consider adding:
- Event type introduction/tutorial in wizard
- Sample data option ("Load example data to get started")
- Import existing backup during setup
- Permission requests (Location, Contacts) with explanations
- More detailed location setup (categories, tags, etc.)
- Video tutorial or interactive tour

## Notes

- Wizard is non-dismissible (`.interactiveDismissDisabled()`) to ensure completion
- All steps are optional - users can skip adding data
- Geocoding has rate limits - delays are built in
- Default activities are seeded if wizard is skipped
- Wizard uses SwiftUI's TabView for smooth page transitions
- Progress indicator shows current step
- Back button only appears after first step
