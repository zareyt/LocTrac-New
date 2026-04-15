# 🔄 First Launch Wizard - Flow Diagram

## App Launch Flow

```
┌─────────────────────────────────────────┐
│         App Launches                    │
│     (LocTracApp.swift)                  │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│      DataStore.init()                   │
│      calls loadData()                   │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│   Does backup.json exist?               │
└────┬──────────────────────┬─────────────┘
     │ NO                   │ YES
     │                      │
     ▼                      ▼
┌─────────────┐     ┌──────────────────────┐
│ Check for   │     │  Load backup.json    │
│ Seed.json   │     │  Parse data          │
└─────┬───────┘     │  Populate arrays     │
      │             └──────────┬───────────┘
      │ EXISTS                 │
      ▼                        │
┌─────────────┐                │
│ Load from   │                │
│ Seed.json   │                │
└─────┬───────┘                │
      │                        │
      │ MISSING                │
      ▼                        │
┌─────────────┐                │
│ Initialize  │                │
│ empty data  │                │
└─────┬───────┘                │
      │                        │
      └────────┬───────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│          RootView loads                 │
│      checks isFirstLaunch               │
└────────────┬────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
    ▼ TRUE            ▼ FALSE
┌─────────────┐   ┌──────────────────────┐
│   Show      │   │   Show Main App      │
│   Wizard    │   │   (Your TabView)     │
└─────┬───────┘   └──────────────────────┘
      │
      │ User completes
      ▼
┌─────────────────────────────────────────┐
│  Wizard Completion:                     │
│  1. Set UserDefaults flag               │
│  2. Save data (creates backup.json)     │
│  3. Dismiss wizard                      │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│       Main App Shown                    │
└─────────────────────────────────────────┘
```

## Wizard Steps Flow

```
┌──────────────────────────────────────────────────┐
│             WIZARD STEP 1                        │
│              Welcome                             │
│                                                  │
│  • App introduction                              │
│  • Feature overview                              │
│  • Visual presentation                           │
│                                                  │
│                         [Next →]                 │
└────────────────────┬─────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────┐
│             WIZARD STEP 2                        │
│             Locations                            │
│                                                  │
│  • Add location name                             │
│  • Add city (auto-geocoded)                      │
│  • Choose theme color                            │
│  • View added locations                          │
│  • [Optional - Can skip]                         │
│                                                  │
│  [← Back]              [Next →]                  │
└────────────────────┬─────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────┐
│             WIZARD STEP 3                        │
│            Activities                            │
│                                                  │
│  • Select default activities                     │
│  • Add custom activities                         │
│  • View all activities                           │
│  • [Optional - Can skip]                         │
│                                                  │
│  [← Back]              [Get Started]             │
└────────────────────┬─────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────┐
│              Completion                          │
│                                                  │
│  1. setupDefaultData()                           │
│     - Ensure activities exist                    │
│  2. UserDefaults.set(hasCompletedFirstLaunch)    │
│  3. store.storeData()                            │
│     - Creates backup.json                        │
│  4. dismiss()                                    │
│                                                  │
└────────────────────┬─────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────┐
│              Main App                            │
└──────────────────────────────────────────────────┘
```

## Data Flow

```
┌─────────────────────────────────────────┐
│         User Actions in Wizard          │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│       DataStore (Observable)            │
│                                         │
│  @Published var locations: [Location]   │
│  @Published var activities: [Activity]  │
│  @Published var events: [Event]         │
└─────────────┬───────────────────────────┘
              │
              │ store.add(location)
              │ store.addActivity(activity)
              ▼
┌─────────────────────────────────────────┐
│      Automatic Save via CRUD            │
│         store.storeData()               │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│     Export Model Conversion             │
│                                         │
│  Export(locations, events, activities)  │
│     ↓                                   │
│  ExportLocation, ExportEvent, etc.      │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│        JSON Encoding                    │
│     JSONEncoder().encode(export)        │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│        Write to File                    │
│                                         │
│  Documents/backup.json                  │
└─────────────────────────────────────────┘
```

## First Launch Detection Logic

```
┌─────────────────────────────────────────┐
│    Check: isFirstLaunch                 │
└─────────────┬───────────────────────────┘
              │
       ┌──────┴──────┐
       │             │
       ▼             ▼
┌─────────────┐  ┌─────────────────────────┐
│ UserDefaults│  │  FileManager check      │
│ check       │  │  backup.json exists?    │
│             │  │                         │
│ key =       │  │  In Documents folder    │
│ "has        │  └───────────┬─────────────┘
│ Completed   │              │
│ FirstLaunch"│              │
└──────┬──────┘              │
       │                     │
       │ false               │ false
       └──────┬──────────────┘
              │
              ▼ (Both false = First Launch)
┌─────────────────────────────────────────┐
│          Show Wizard                    │
└─────────────────────────────────────────┘

              OR
              
       │ true                │ true
       └──────┬──────────────┘
              │
              ▼ (Either true = Not First Launch)
┌─────────────────────────────────────────┐
│          Show Main App                  │
└─────────────────────────────────────────┘
```

## File Structure

```
LocTrac/
├── DataStore.swift (✏️ Modified)
│   ├── isFirstLaunch computed property
│   ├── loadData() - graceful error handling
│   └── loadFromURL() - new private method
│
├── FirstLaunchWizard.swift (✨ New)
│   ├── FirstLaunchWizard (main view)
│   ├── WelcomeStepView
│   ├── LocationsStepView
│   ├── ActivitiesStepView
│   └── FeatureRow (helper)
│
├── ImportExportModels.swift (✨ New)
│   ├── Export struct
│   ├── ExportLocation, ExportEvent, ExportActivity
│   ├── Import (typealias)
│   └── Person (if needed)
│
├── RootView.swift (✨ New)
│   ├── Checks first launch
│   ├── Shows wizard or main app
│   └── Wraps your main view
│
├── Locations.swift (unchanged)
├── Event.swift (unchanged)
├── Activity.swift (unchanged)
├── Theme.swift (unchanged)
│
└── YourAppNameApp.swift (✏️ Update to use RootView)
    └── WindowGroup { RootView() }
```

## UserDefaults & FileManager

```
User's Device
│
├── UserDefaults
│   └── "hasCompletedFirstLaunch": Bool
│       ├── false (or missing) → Show wizard
│       └── true → Show main app
│
└── File System
    └── Documents/
        └── backup.json
            ├── Missing → Initialize empty or load Seed.json
            └── Exists → Load and parse data
```

## Error Handling Flow

```
┌─────────────────────────────────────────┐
│       Try to load backup.json           │
└─────────────┬───────────────────────────┘
              │
       ┌──────┴──────┐
       ▼ File exists  ▼ File missing
┌─────────────┐  ┌──────────────────┐
│ Try parse   │  │ Try Seed.json    │
│ JSON        │  └────────┬─────────┘
└──────┬──────┘           │
       │                  ▼ Missing
       ▼ Success     ┌──────────────────┐
┌─────────────┐      │ Empty arrays     │
│ Load data   │      │ (for wizard)     │
└──────┬──────┘      └────────┬─────────┘
       │                      │
       └──────┬───────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│          App continues                  │
│       (No crash! 🎉)                    │
└─────────────────────────────────────────┘
```

## Key Points

✅ **No Force Unwraps** - All optional chaining or default values
✅ **No fatalError** - Graceful degradation to empty data
✅ **One-Time Setup** - UserDefaults prevents re-showing
✅ **Flexible** - Works with or without Seed.json
✅ **Safe** - Always creates valid backup.json on completion
