# HealthKit Integration — Implementation Plan

**Version**: 2.1 Feature
**Date**: 2026-04-25
**Author**: Tim Arey / Claude

---

## Overview

Read-only integration with Apple HealthKit to pull workout/exercise data and display it alongside daily stays. Exercise data appears in the Infographics tab and is persisted locally in `backup.json` for offline access. This is an **optional feature** toggled in Profile > Preferences.

### Design Principles

- **Read-only** — LocTrac only reads from HealthKit, never writes
- **Optional** — Users who don't enable HealthKit see no exercise UI
- **Offline-first** — Exercise data cached locally (Option A), synced periodically
- **Stay-linked** — Exercise data only displays for dates with existing stays
- **Backward compatible** — Existing backups import without exercise data

---

## User Decisions

| Question | Decision |
|----------|----------|
| Workout types | Walking, Running, Cycling, Hiking, Swimming, Yoga, Strength Training, Other Workout |
| Date association | Only show when a stay exists for that date; alert if user tries to sync data for a date without a stay |
| Historical depth | Pull as far back as the first event/stay in the user's data |
| Storage strategy | Option A — cache locally in `backup.json`, sync periodically |
| Sync reminder | Remind user if last sync > X days (configurable in preferences) |
| Cycling treatment | Extra treatment — cycling miles offset environmental impact (CO2 savings card), not trip-oriented |
| Export compatibility | New optional `exerciseEntries` field in Import/Export |

---

## New Files (5)

| File | Location | Purpose |
|------|----------|---------|
| `ExerciseEntry.swift` | `Models/` | Codable model for persisted exercise data |
| `HealthKitService.swift` | `Services/` | Authorization, workout queries, sync logic |
| `HealthKitSettingsView.swift` | `Views/Profile/` | Detailed HealthKit controls (sync, status, reminder config) |
| `HealthKitExerciseSection.swift` | `Views/` | Reusable exercise infographic section |
| `HealthKitTests.swift` | `LocTracTests/` | Unit tests for exercise data logic |

## Modified Files (8)

| File | Change |
|------|--------|
| `Models/DataStore.swift` | Add `@Published var exerciseEntries: [ExerciseEntry]`, CRUD methods, sync hooks |
| `Services/ImportExport.swift` | Add optional `exerciseEntries` to Import/Export structs |
| `Views/InfographicsView.swift` | New exercise summary section below Activities bar chart |
| `Views/Profile/PreferencesView.swift` | "Health & Fitness" section with toggle, sync reminder days |
| `Models/UserProfile.swift` | Add `healthKitEnabled`, `healthKitSyncReminderDays`, `lastHealthKitSync` |
| `Models/DebugConfig.swift` | Add `.healthKit` log category |
| `Info.plist` | Add `NSHealthShareUsageDescription` |
| `LocTrac.entitlements` | Add HealthKit capability |

---

## Data Model

### ExerciseEntry

```swift
struct ExerciseEntry: Identifiable, Codable, Hashable {
    let id: String                      // UUID string
    var date: Date                      // UTC midnight (matches event dates)
    var workoutType: WorkoutType        // Enum mapping to HKWorkoutActivityType
    var durationMinutes: Double         // Total duration in minutes
    var distanceMiles: Double?          // nil for non-distance workouts (yoga, strength)
    var caloriesBurned: Double?         // Active energy burned
    var sourceWorkoutID: String?        // HKWorkout UUID string for dedup

    enum WorkoutType: String, Codable, CaseIterable, Hashable {
        case walking
        case running
        case cycling
        case hiking
        case swimming
        case yoga
        case strengthTraining
        case otherWorkout

        var displayName: String {
            switch self {
            case .walking: return "Walking"
            case .running: return "Running"
            case .cycling: return "Cycling"
            case .hiking: return "Hiking"
            case .swimming: return "Swimming"
            case .yoga: return "Yoga"
            case .strengthTraining: return "Strength Training"
            case .otherWorkout: return "Other Workout"
            }
        }

        var sfSymbol: String {
            switch self {
            case .walking: return "figure.walk"
            case .running: return "figure.run"
            case .cycling: return "bicycle"
            case .hiking: return "figure.hiking"
            case .swimming: return "figure.pool.swim"
            case .yoga: return "figure.yoga"
            case .strengthTraining: return "dumbbell.fill"
            case .otherWorkout: return "figure.mixed.cardio"
            }
        }

        var color: Color {
            switch self {
            case .walking: return .green
            case .running: return .orange
            case .cycling: return .blue
            case .hiking: return .brown
            case .swimming: return .cyan
            case .yoga: return .purple
            case .strengthTraining: return .red
            case .otherWorkout: return .gray
            }
        }
    }
}
```

### HKWorkoutActivityType Mapping

| HKWorkoutActivityType | ExerciseEntry.WorkoutType |
|---|---|
| `.walking` | `.walking` |
| `.running` | `.running` |
| `.cycling` | `.cycling` |
| `.hiking` | `.hiking` |
| `.swimming` | `.swimming` |
| `.yoga` | `.yoga` |
| `.functionalStrengthTraining`, `.traditionalStrengthTraining` | `.strengthTraining` |
| All others | `.otherWorkout` |

### Distance Extraction per Type

| WorkoutType | HealthKit Distance Type |
|---|---|
| Walking, Running, Hiking | `HKQuantityType(.distanceWalkingRunning)` |
| Cycling | `HKQuantityType(.distanceCycling)` |
| Swimming | `HKQuantityType(.distanceSwimming)` |
| Others | `HKWorkout.totalDistance` (if available) |

---

## HealthKitService

```swift
/// Read-only HealthKit integration service
actor HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    // MARK: - Device Support

    /// Check if HealthKit is available on this device
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    /// Request read-only authorization for workout data
    func requestAuthorization() async throws {
        let readTypes: Set<HKObjectType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.appleExerciseTime)
        ]
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Querying Workouts

    /// Fetch workouts between two dates and convert to ExerciseEntry
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [ExerciseEntry] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let workouts = try await descriptor.result(for: healthStore)
        return workouts.map { mapWorkoutToEntry($0) }
    }

    // MARK: - Sync

    /// Incremental sync — fetch workouts since last sync date
    /// Returns count of new entries added
    func syncNewWorkouts(since lastSync: Date, store: DataStore) async throws -> Int {
        let newWorkouts = try await fetchWorkouts(from: lastSync, to: Date())

        // Get existing source IDs for dedup
        let existingIDs = Set(store.exerciseEntries.compactMap { $0.sourceWorkoutID })

        // Filter to only workouts that have a matching stay
        let stayDates = Set(store.events.map { $0.date.startOfDay })

        let newEntries = newWorkouts.filter { entry in
            let isNew = entry.sourceWorkoutID == nil || !existingIDs.contains(entry.sourceWorkoutID!)
            let hasStay = stayDates.contains(entry.date)
            return isNew && hasStay
        }

        // Entries without a stay — count for alert
        let orphanedCount = newWorkouts.filter { entry in
            let isNew = entry.sourceWorkoutID == nil || !existingIDs.contains(entry.sourceWorkoutID!)
            return isNew && !stayDates.contains(entry.date)
        }.count

        // Add new entries to store
        for entry in newEntries {
            store.addExerciseEntry(entry)
        }

        return (newEntries.count, orphanedCount) // tuple: (added, skippedNoStay)
    }

    // MARK: - Mapping

    private func mapWorkoutToEntry(_ workout: HKWorkout) -> ExerciseEntry {
        let workoutType = mapActivityType(workout.workoutActivityType)
        let distance = extractDistance(from: workout, type: workoutType)
        let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())

        return ExerciseEntry(
            id: UUID().uuidString,
            date: workout.startDate.startOfDay,
            workoutType: workoutType,
            durationMinutes: workout.duration / 60.0,
            distanceMiles: distance,
            caloriesBurned: calories,
            sourceWorkoutID: workout.uuid.uuidString
        )
    }

    private func mapActivityType(_ type: HKWorkoutActivityType) -> ExerciseEntry.WorkoutType {
        switch type {
        case .walking: return .walking
        case .running: return .running
        case .cycling: return .cycling
        case .hiking: return .hiking
        case .swimming: return .swimming
        case .yoga: return .yoga
        case .functionalStrengthTraining, .traditionalStrengthTraining: return .strengthTraining
        default: return .otherWorkout
        }
    }

    private func extractDistance(from workout: HKWorkout, type: ExerciseEntry.WorkoutType) -> Double? {
        guard let totalDistance = workout.totalDistance else { return nil }
        let meters = totalDistance.doubleValue(for: .meter())
        return meters / 1609.344  // Convert to miles
    }
}
```

---

## DataStore Changes

### New Properties

```swift
// In DataStore
@Published var exerciseEntries: [ExerciseEntry] = []
```

### New CRUD Methods

```swift
func addExerciseEntry(_ entry: ExerciseEntry) {
    exerciseEntries.append(entry)
    storeData()
}

func deleteExerciseEntry(_ entry: ExerciseEntry) {
    exerciseEntries.removeAll { $0.id == entry.id }
    storeData()
}

func deleteExerciseEntries(for date: Date) {
    exerciseEntries.removeAll { $0.date.startOfDay == date.startOfDay }
    storeData()
}

/// Convenience: exercise entries for a specific date
func exerciseEntries(for date: Date) -> [ExerciseEntry] {
    exerciseEntries.filter { $0.date.startOfDay == date.startOfDay }
}
```

### Import/Export

```swift
// In Import struct — add:
let exerciseEntries: [ExerciseEntryData]?  // Optional for backward compat

struct ExerciseEntryData: Codable {
    let id: String
    let date: Date
    let workoutType: String
    let durationMinutes: Double
    let distanceMiles: Double?
    let caloriesBurned: Double?
    let sourceWorkoutID: String?
}

// In Export struct — add:
let exerciseEntries: [ExerciseEntryData]
```

---

## UserProfile Changes

```swift
// Add to UserProfile:
var healthKitEnabled: Bool = false
var healthKitSyncReminderDays: Int = 7       // Default: remind after 7 days
var lastHealthKitSync: Date?                  // nil = never synced
```

All three fields optional in Codable with defaults for backward compatibility.

---

## PreferencesView — Health & Fitness Section

New section between existing sections:

```
HEALTH & FITNESS
┌──────────────────────────────────────────┐
│ Sync with Apple Health        [Toggle]   │
│ ────────────────────────────────────────  │
│ Last synced: April 25, 2026              │
│ ────────────────────────────────────────  │
│ Sync Reminder       [Picker: 3/7/14/30] │
│   Remind if not synced for X days        │
│ ────────────────────────────────────────  │
│ [Sync Now]                    [Settings] │
└──────────────────────────────────────────┘
```

- Toggle triggers HealthKit authorization on first enable
- "Sync Now" does incremental sync from `lastHealthKitSync`
- First sync pulls back to the date of the user's earliest event
- "Settings" navigates to `HealthKitSettingsView` for detailed controls

---

## Sync Reminder Logic

```swift
// In AppEntry.swift or HomeView — check on appear:
if let profile = authState.currentUser,
   profile.healthKitEnabled,
   let lastSync = profile.lastHealthKitSync {
    let daysSinceSync = Calendar.current.dateComponents([.day], from: lastSync, to: Date()).day ?? 0
    if daysSinceSync >= profile.healthKitSyncReminderDays {
        showHealthKitSyncReminder = true
    }
}
```

Reminder shown as a banner or alert: "Your health data hasn't been synced in X days. Sync now?"

---

## InfographicsView — Exercise Sections

### Exercise Summary Card (below Activities bar chart)

```
EXERCISE SUMMARY
┌──────────────────────────────────────────┐
│  figure.run   Total Exercise    423 min  │
│  flame.fill   Calories Burned  12,450    │
│  ruler        Total Distance    87.3 mi  │
│  calendar     Active Days        42      │
│  chart.bar    Avg per Day       10.1 min │
└──────────────────────────────────────────┘
```

### Workout Type Breakdown (horizontal bar chart)

Same style as existing Activities chart — `Chart` with `BarMark`, colored by workout type, top 8 types.

### Cycling Spotlight Card

```
CYCLING & ENVIRONMENT
┌──────────────────────────────────────────┐
│  bicycle     Cycling Miles     234.5 mi  │
│  leaf.fill   CO2 Saved          ~85 lbs  │
│  number      Total Rides          28     │
│  chart.line  Avg per Ride       8.4 mi   │
│                                          │
│  "By cycling 234.5 miles, you avoided    │
│   approximately 85 lbs of CO2 emissions  │
│   compared to driving."                  │
└──────────────────────────────────────────┘
```

**CO2 savings formula**: Average car emits ~0.363 lbs CO2 per mile. Cycling miles * 0.363 = CO2 saved.

### Derived Struct Extension

```swift
// Add to Derived:
let exerciseSummary: ExerciseSummary?

struct ExerciseSummary {
    let totalMinutes: Double
    let totalCalories: Double
    let totalDistanceMiles: Double
    let activeDays: Int
    let avgMinutesPerDay: Double
    let workoutTypeBreakdown: [(type: ExerciseEntry.WorkoutType, count: Int, totalMinutes: Double)]
    let cyclingMiles: Double
    let cyclingRideCount: Int
    let co2SavedLbs: Double         // cyclingMiles * 0.363
}
```

---

## Debug Logging

### New Category

```swift
// Add to LogCategory enum:
case healthKit

// Emoji and label:
case .healthKit: return "💪"
case .healthKit: return "healthKit"

// In DebugConfig — new property:
@Published var logHealthKit: Bool { ... }

// In enableAll/disableAll/presetData — include logHealthKit
```

---

## Info.plist & Entitlements

### Info.plist

```xml
<key>NSHealthShareUsageDescription</key>
<string>LocTrac reads your workout data to display exercise statistics alongside your travel stays. No health data is ever shared or uploaded.</string>
```

No `NSHealthUpdateUsageDescription` needed — read-only.

### Entitlements

Add HealthKit capability via Xcode:
- Signing & Capabilities > + Capability > HealthKit

---

## Implementation Phases

### Phase A: Model & DataStore (Foundation)

1. Create `ExerciseEntry.swift` with model and `WorkoutType` enum
2. Add `exerciseEntries` to `DataStore` with CRUD methods
3. Add `exerciseEntries` to `Import`/`Export` (optional field)
4. Add `healthKitEnabled`, `healthKitSyncReminderDays`, `lastHealthKitSync` to `UserProfile`
5. Add `.healthKit` log category to `DebugConfig`
6. Verify backward compatibility — import a backup without exercise data

### Phase B: HealthKit Service

1. Create `HealthKitService.swift` (actor, singleton)
2. Implement authorization request (read-only)
3. Implement workout query with date range
4. Implement `mapWorkoutToEntry` with activity type mapping
5. Implement distance extraction (meters to miles)
6. Implement incremental sync with dedup (by `sourceWorkoutID`)
7. Implement orphaned workout detection (no matching stay)
8. Add Info.plist key and HealthKit entitlement

### Phase C: UI — Preferences & Settings

1. Add "Health & Fitness" section to `PreferencesView`
2. Create `HealthKitSettingsView` with detailed controls
3. Wire authorization trigger on toggle enable
4. Implement "Sync Now" button with progress indicator
5. Implement sync reminder check in `AppEntry.swift` / `HomeView`
6. Show alert for orphaned workouts (dates without stays)

### Phase D: UI — Infographics

1. Add `ExerciseSummary` to `Derived` struct
2. Implement `computeExerciseSummary()` in InfographicsView
3. Create exercise summary card section
4. Create workout type breakdown bar chart
5. Create cycling spotlight card with CO2 savings
6. Conditionally show sections only when exercise data exists
7. Respect user's distance unit preference (miles/km)

### Phase E: Tests & Documentation

1. Write unit tests per Test Plan below
2. Update `VERSION_2.1_RELEASE_NOTES.md`
3. Update `WhatsNewFeature.swift` hardcoded fallback
4. Update `CHANGELOG.md`
5. Update `CLAUDE.md` (backlog, gotchas, file structure)

---

## Test Plan (per Testing Master Guide)

All tests use Swift Testing (`@Test`, `@Suite`, `#expect`), fresh `DataStore` per test, `TestDataFactory` for data.

### File: `LocTracTests/HealthKitTests.swift`

```swift
@Suite("HealthKit Integration")
struct HealthKitTests {

    // MARK: - ExerciseEntry Model

    @Test("ExerciseEntry Codable roundtrip preserves all fields")
    func exerciseEntryCodableRoundtrip() { ... }

    @Test("WorkoutType rawValue covers all cases")
    func workoutTypeRawValues() { ... }

    @Test("WorkoutType displayName, sfSymbol, color are non-empty")
    func workoutTypeProperties() { ... }

    @Test("ExerciseEntry with nil distance and calories encodes correctly")
    func optionalFieldsEncode() { ... }

    // MARK: - Deduplication

    @Test("Duplicate sourceWorkoutID is detected")
    func deduplication() { ... }

    @Test("Entries with different sourceWorkoutIDs are both kept")
    func noDuplicateFalsePositive() { ... }

    // MARK: - Date Association

    @Test("Exercise date normalizes to UTC midnight")
    func dateNormalization() { ... }

    @Test("exerciseEntries(for:) filters by date correctly")
    func filterByDate() { ... }

    // MARK: - Distance Conversion

    @Test("Meters to miles conversion is accurate")
    func metersToMiles() { ... }
    // 1609.344 meters = 1 mile (±0.001)

    // MARK: - Workout Type Mapping

    @Test("HKWorkoutActivityType.walking maps to .walking")
    func walkingMapping() { ... }

    @Test("HKWorkoutActivityType.cycling maps to .cycling")
    func cyclingMapping() { ... }

    @Test("Unknown HKWorkoutActivityType maps to .otherWorkout")
    func unknownMapping() { ... }

    @Test("Both strength training types map to .strengthTraining")
    func strengthTrainingMapping() { ... }

    // MARK: - DataStore CRUD

    @Test("addExerciseEntry increases count")
    func addEntry() { ... }

    @Test("deleteExerciseEntry removes entry")
    func deleteEntry() { ... }

    @Test("deleteExerciseEntries(for:) removes all entries on date")
    func deleteByDate() { ... }

    // MARK: - Import/Export Compatibility

    @Test("Export with exerciseEntries produces valid JSON")
    func exportWithExercise() { ... }

    @Test("Import without exerciseEntries succeeds (legacy backup)")
    func importWithoutExercise() { ... }

    @Test("Import with exerciseEntries restores data")
    func importWithExercise() { ... }

    // MARK: - Infographics Aggregation

    @Test("ExerciseSummary computes total minutes correctly")
    func totalMinutes() { ... }

    @Test("ExerciseSummary computes total distance correctly")
    func totalDistance() { ... }

    @Test("ExerciseSummary counts active days correctly")
    func activeDays() { ... }

    @Test("CO2 savings calculated correctly from cycling miles")
    func co2Savings() { ... }
    // 100 cycling miles * 0.363 = 36.3 lbs CO2 saved

    @Test("Workout type breakdown groups and counts correctly")
    func workoutTypeBreakdown() { ... }

    @Test("Empty exercise data returns nil ExerciseSummary")
    func emptyExerciseData() { ... }

    // MARK: - Sync Logic

    @Test("Sync skips entries for dates without stays")
    func syncSkipsOrphaned() { ... }

    @Test("Sync deduplicates by sourceWorkoutID")
    func syncDeduplicates() { ... }

    // MARK: - UserProfile

    @Test("healthKitEnabled defaults to false")
    func defaultDisabled() { ... }

    @Test("healthKitSyncReminderDays defaults to 7")
    func defaultReminderDays() { ... }

    @Test("UserProfile with HealthKit fields encodes/decodes correctly")
    func profileCodable() { ... }

    // MARK: - REGRESSION

    @Test("REGRESSION: Legacy backup without exerciseEntries imports cleanly")
    func regressionLegacyImport() { ... }
}
```

**Total: ~30 tests**

### TestDataFactory Additions

```swift
extension TestDataFactory {
    static func makeExerciseEntry(
        date: Date = Date().startOfDay,
        type: ExerciseEntry.WorkoutType = .walking,
        duration: Double = 30.0,
        distance: Double? = 1.5,
        calories: Double? = 150.0,
        sourceID: String? = UUID().uuidString
    ) -> ExerciseEntry {
        ExerciseEntry(
            id: UUID().uuidString,
            date: date,
            workoutType: type,
            durationMinutes: duration,
            distanceMiles: distance,
            caloriesBurned: calories,
            sourceWorkoutID: sourceID
        )
    }
}
```

---

## Manual Testing Checklist

```
Health & Fitness Feature:
[ ] Toggle "Sync with Apple Health" in Preferences
[ ] HealthKit authorization sheet appears on first enable
[ ] "Sync Now" pulls workouts from HealthKit
[ ] Sync count alert shows correctly (X added, Y skipped)
[ ] Exercise data appears in Infographics tab
[ ] Exercise summary card shows correct totals
[ ] Workout type breakdown chart renders correctly
[ ] Cycling spotlight card shows miles and CO2 savings
[ ] Disabling toggle hides exercise sections in Infographics
[ ] Sync reminder appears after X days without sync
[ ] Backup export includes exercise entries
[ ] Import backup with exercise entries restores data
[ ] Import legacy backup (no exercise data) works fine
[ ] Toggling off and deleting account removes HealthKit prefs
[ ] No exercise UI shown for users who never enabled HealthKit
[ ] Distance displays in correct unit (miles vs kilometers)
[ ] Exercise sections respect year filter in Infographics
```

---

## CO2 Savings Calculation

**Source**: EPA average — passenger vehicles emit approximately 0.363 lbs CO2 per mile.

```swift
let co2SavedLbs = cyclingMiles * 0.363
```

This is a rough estimate for display purposes. The message:
> "By cycling X miles, you avoided approximately Y lbs of CO2 emissions compared to driving."

---

## Privacy & Data Notes

- HealthKit data is **read-only** — LocTrac never writes to Health
- Only `NSHealthShareUsageDescription` in Info.plist (no update description)
- Exercise data stored in `backup.json` alongside travel data
- Exercise data included in exports (user's choice to share)
- No HealthKit identifiers stored beyond `sourceWorkoutID` (for dedup)
- Disabling HealthKit toggle does NOT delete already-synced exercise data
- Users can manually delete exercise entries if desired

---

*HealthKit Implementation Plan — LocTrac v2.1 — 2026-04-25*
