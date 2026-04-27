# LocTrac v2.1 Release Notes

**Release Date**: 2026-04-27
**Version**: 2.1.0
**Build**: TBD

---

## What's New in v2.1

### Apple Health Integration
icon: heart.fill | color: red

Sync your workouts from Apple Health to see exercise data alongside your travel stays. To get started: open Profile & Account from the menu, tap Preferences, scroll to Health & Fitness, and toggle on Apple Health Integration. Tap "Sync Now" to pull in your workouts. View total calories, active minutes, per-type distance, and cycling CO₂ offsets in the Infographics tab. Workouts automatically link to matching activities — unmatched types (like golf appearing as "Other Workout") can be mapped to any activity or ignored from the post-sync summary. Your mappings are saved so future syncs apply them automatically. Read-only — LocTrac never writes to Apple Health.

### Home Screen Widgets
icon: rectangle.on.rectangle.angled | color: blue

Five new home screen widgets to keep your travel data at a glance. Travel Snapshot shows countries, cities, and days away from home. Activity Pulse tracks your weekly exercise progress with a circular ring toward the 150-minute CDC goal. Green Impact highlights CO₂ saved from cycling. Dashboard combines travel, fitness, environment, and affirmation stats in one widget. Available in small, medium, and large sizes.

### Environmental Factors & Vehicle Management
icon: leaf.fill | color: green

Manage your vehicles and see their real environmental impact on your travels. Add cars with fuel type (gas, diesel, hybrid, electric), MPG or kWh efficiency, and date ranges. LocTrac uses EPA-derived CO2 calculations to show accurate per-mile emissions for each vehicle. Driving trips automatically match to the right car by date range, and you can recalculate all historical trip emissions with one tap. Optionally exclude public transit (train/bus) from environmental totals. View per-car impact summaries and transport breakdowns in the Infographics tab.

### Activity Management
icon: figure.walk | color: orange

Edit an activity to see every event date it appears on, with the option to remove it from individual events. Delete an activity entirely with a confirmation showing how many events will be affected. No more accidental swipe-to-delete.

---

## Architecture

### New Files

| File | Purpose |
|------|---------|
| `Models/ExerciseEntry.swift` | Data model, WorkoutType enum (8 types), ExerciseSummary computation |
| `Services/HealthKitService.swift` | Actor-based HealthKit query and sync service |
| `LocTracTests/HealthKitTests.swift` | 25+ unit tests |
| `Documentation/HealthKit/HEALTHKIT_SUMMARY.md` | Architecture and design summary |

### Modified Files

| File | Change |
|------|--------|
| `Models/DataStore.swift` | Exercise CRUD methods (add, delete, deleteByDate, filterByDate) |
| `Models/UserProfile.swift` | Added `ignoredWorkoutTypesForActivities`, HealthKit preference fields |
| `Models/DebugConfig.swift` | Added `.healthKit` logging category |
| `Services/ImportExport.swift` | Exercise entries in backup/restore (optional, backward compatible) |
| `Views/InfographicsView.swift` | Exercise & Fitness section with formatted stats and CO2 offset |
| `Views/HomeView.swift` | HealthKit sync reminder banner |
| `Views/Profile/PreferencesView.swift` | Health & Fitness settings, Sync Now, post-sync summary sheet |
| `Info.plist` | Added `NSHealthShareUsageDescription` |
| `LocTrac.entitlements` | Added `com.apple.developer.healthkit` capability |

### Data Flow

```
HealthKit (on device)
    | requestAuthorization() -- read-only
    | fetchWorkouts(from:to:) -- HKSampleQueryDescriptor
    | mapWorkoutToEntry() -- HKWorkout -> ExerciseEntry
    | syncNewWorkouts(since:store:ignoredTypes:) -- dedup + date filter + activity linking
    v
DataStore.exerciseEntries -> backup.json
    v
InfographicsView -> ExerciseSummary.compute()
    -> Overview stats (calories, minutes, active days)
    -> Workout breakdown by type with per-type miles
    -> Cycling CO2 offset spotlight
```

### Key Design Decisions

1. **Date association**: Exercise entries only display for dates that have existing stays
2. **Storage**: Cached locally in `backup.json` alongside other data (optional field for backward compat)
3. **Sync reminder**: Configurable (3/7/14/30 days), orange banner on HomeView when overdue
4. **Cycling CO2 offset**: EPA standard (0.363 lbs CO2/mile saved vs driving)
5. **Historical depth**: First sync pulls back to earliest event date; subsequent syncs incremental
6. **Dedup**: Uses `sourceWorkoutID` (HKWorkout UUID) to prevent duplicates
7. **Activity auto-linking**: Case-insensitive name match; unmatched types prompt Add/Ignore
8. **Per-type miles**: Walking, Running, Cycling, Swimming, Hiking tracked separately
9. **Ignored workout types**: Stored in UserProfile, persisted across syncs

---

## Privacy & Entitlements

- **Entitlement**: `com.apple.developer.healthkit` = true
- **Entitlement**: `com.apple.developer.healthkit.access` = [] (read-only)
- **Info.plist**: `NSHealthShareUsageDescription` (read-only description)
- No `NSHealthUpdateUsageDescription` needed (never writes to HealthKit)

---

## Backward Compatibility

- `ExerciseEntry` data in `ImportExport` is optional (`exerciseEntries?`) — old backups decode fine
- `UserProfile` HealthKit fields use tolerant decoding — old profiles default to disabled
- Exercise section in Infographics only renders when data exists

---

**Thank you for using LocTrac!**

*Version 2.1.0 — Tim Arey*
