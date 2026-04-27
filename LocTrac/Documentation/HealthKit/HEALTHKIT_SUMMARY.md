# HealthKit Integration Summary

**Version**: 2.1  
**Date**: 2026-04-25  
**Status**: Complete

---

## Overview

LocTrac integrates with Apple HealthKit to read exercise/workout data and display it alongside travel stays in the Infographics tab. This is a **read-only** integration — LocTrac never writes to HealthKit.

## Architecture

### Files

| File | Purpose |
|------|---------|
| `Models/ExerciseEntry.swift` | Data model + `ExerciseSummary` computation |
| `Services/HealthKitService.swift` | Actor-based HealthKit query service |
| `Views/Profile/PreferencesView.swift` | Health & Fitness settings UI |
| `Views/HomeView.swift` | Sync reminder banner |
| `Views/InfographicsView.swift` | Exercise & Fitness infographic section |
| `Models/DataStore.swift` | CRUD for exercise entries |
| `Services/ImportExport.swift` | Backup/restore exercise data |
| `Models/UserProfile.swift` | HealthKit preference fields |
| `Models/DebugConfig.swift` | `.healthKit` logging category |

### Data Flow

```
HealthKit (on device)
    | requestAuthorization() -- read-only
    | fetchWorkouts(from:to:) -- HKSampleQueryDescriptor
    | mapWorkoutToEntry() -- HKWorkout -> ExerciseEntry
    | syncNewWorkouts(since:store:) -- dedup + date filter
    v
DataStore.exerciseEntries -> backup.json
    v
InfographicsView -> ExerciseSummary.compute()
    -> Overview stats (calories, minutes, active days)
    -> Workout breakdown by type
    -> Cycling CO2 offset spotlight
```

### Key Design Decisions

1. **Date association**: Exercise entries only display for dates that have existing stays. Entries without a matching stay are skipped during sync (user is informed of count).

2. **Storage**: Cached locally in `backup.json` alongside other data. Sync is manual via Preferences > Sync Now button.

3. **Sync reminder**: Configurable reminder (3/7/14/30 days). Orange banner on HomeView when overdue.

4. **Cycling CO2 offset**: Cycling miles offset CO2 vs driving using EPA standard (0.363 lbs CO2/mile). Displayed in both Infographics exercise section and environmental impact context.

5. **Historical depth**: First sync pulls back to the earliest event date. Subsequent syncs are incremental from `lastHealthKitSync`.

6. **Dedup**: Uses `sourceWorkoutID` (HKWorkout UUID) to prevent duplicates on re-sync. Already-synced entries are skipped silently without triggering cache resets.

7. **Activity auto-linking**: During sync, workout types are matched (case-insensitive) to existing Activities. Matched activities are automatically added to that day's event. Unmatched types are presented in a post-sync summary where users can Add (creates activity + retroactively links) or Ignore (remembered in profile for future syncs).

8. **Per-type miles**: Walking, Running, Cycling, Swimming, and Hiking miles are tracked separately in ExerciseSummary and displayed in the Infographics workout breakdown.

9. **Ignored workout types**: Stored in `UserProfile.ignoredWorkoutTypesForActivities` as `[String]` (WorkoutType rawValues). Persisted across syncs so users aren't re-prompted.

## Data Model

```swift
struct ExerciseEntry: Identifiable, Codable, Hashable {
    let id: String
    var date: Date                  // UTC midnight
    var workoutType: WorkoutType    // 8 types
    var durationMinutes: Double
    var distanceMiles: Double?      // nil for yoga, strength
    var caloriesBurned: Double?
    var sourceWorkoutID: String?    // HKWorkout UUID for dedup
}
```

### WorkoutType Enum (8 types)

| Type | SF Symbol | Color |
|------|-----------|-------|
| Walking | figure.walk | green |
| Running | figure.run | orange |
| Cycling | bicycle | blue |
| Hiking | figure.hiking | brown |
| Swimming | figure.pool.swim | cyan |
| Yoga | figure.yoga | purple |
| Strength Training | dumbbell.fill | red |
| Other Workout | figure.mixed.cardio | gray |

## Entitlements and Privacy

- **Entitlement**: `com.apple.developer.healthkit` = true
- **Entitlement**: `com.apple.developer.healthkit.access` = [] (empty -- read only)
- **Info.plist**: `NSHealthShareUsageDescription` (read-only description)
- No `NSHealthUpdateUsageDescription` needed (we never write)

## Backward Compatibility

- `ExerciseEntry` data in `ImportExport` is optional (`exerciseEntries?`) -- old backups decode fine
- `UserProfile` HealthKit fields use tolerant decoding -- old profiles default to disabled
- Exercise section in Infographics only renders when data exists

## Debug Logging

All HealthKit operations log under the `.healthKit` category (muscle emoji).  
Toggle via Debug Settings > HealthKit.

## Tests

`LocTracTests/HealthKitTests.swift` -- 20+ tests covering:
- ExerciseEntry model and Codable
- WorkoutType properties
- ExerciseSummary computation (totals, active days, avg, breakdown, CO2)
- DataStore CRUD (add, delete, delete by date, filter by date)
- UserProfile backward compatibility
