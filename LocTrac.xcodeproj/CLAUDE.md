# CLAUDE.md — LocTrac AI Assistant Context

This file provides Claude with everything it needs to assist effectively on the
LocTrac project. Update this file whenever the architecture, conventions, or
backlog change significantly.

**Last Updated**: 2026-04-04
**Current Version**: 1.3
**Author**: Tim Arey

---

## 🗺️ Project Summary

**LocTrac** is a privacy-first iOS/iPadOS travel tracking app built entirely in
SwiftUI. It stores all data locally (no cloud, no server). Users record locations,
stays/events, trips, activities, and affirmations, then visualize their travel
history through maps, charts, and infographics.

- **Platform**: iOS 16.0+ / iPadOS 16.0+
- **Language**: Swift 5.7+ / SwiftUI
- **Architecture**: MVVM with `@EnvironmentObject`
- **Data**: Local JSON (`backup.json`) via `Codable`
- **No third-party dependencies**

---

## 📁 Project Structure

```
LocTrac/
├── Models/
│   ├── DataStore.swift              ← Central ObservableObject, ALL data lives here
│   ├── Event.swift                  ← Event model (stay, vacation, etc.)
│   ├── Location.swift               ← Location model with Theme
│   ├── RootView.swift               ← App entry point
│   └── FirstLaunchWizard.swift      ← First-launch onboarding logic
│
├── Services/
│   └── ImportExport.swift           ← Import/Export Codable structs (Import, Export)
│
├── Views/
│   ├── HomeView.swift               ← Tab 0: dashboard, quick actions
│   ├── StartTabView.swift           ← Root TabView + all sheet orchestration
│   ├── TimelineRestoreView.swift    ← Selective backup restore with date filter
│   ├── CalendarViewTab/
│   │   └── CalendarView.swift (ModernEventsCalendarView)  ← Tab 1: Stays
│   ├── EditUpdateView/
│   │   └── EventFormViewModel.swift
│   ├── ListView Tab/
│   │   ├── ModernEventsCalendarView.swift
│   │   ├── ModernEventFormView.swift
│   │   ├── Affirmation.swift
│   │   ├── AffirmationEditorView.swift
│   │   ├── AffirmationSelectorView.swift
│   │   ├── AffirmationsLibraryView.swift
│   │   └── ManagementView.swift
│   ├── Trips/
│   │   ├── Trip.swift
│   │   ├── TripFormView.swift
│   │   ├── TripMigrationUtility.swift
│   │   ├── TripsListView.swift
│   │   └── TripsManagementView.swift
│   └── [Other view files...]
│
├── Documentation/                   ← All .md docs live here
├── Graphics/
│   └── App Store/                   ← Screenshots for all iPhone sizes
│
├── Assets.xcassets/
├── Info.plist
├── CHANGELOG.md
├── GIT_SUMMARY_v1.3.md
└── UPDATE_NOTES_v1.3.md

LocTrac.xcodeproj/
├── project.pbxproj                  ← Only legitimate tracked file here
└── project.xcworkspace/
    └── contents.xcworkspacedata     ← Only legitimate tracked file here

⚠️  NO .swift or .md files belong inside LocTrac.xcodeproj/ — .gitignore blocks them
```

---

## 🧠 Core Architecture

### DataStore — The Single Source of Truth

```swift
class DataStore: ObservableObject {
    @Published var locations: [Location]
    @Published var events: [Event]
    @Published var activities: [Activity]
    @Published var affirmations: [Affirmation]
    @Published var trips: [Trip]
    @Published var pendingTrip: (trip: Trip, fromEvent: Event, toEvent: Event)?
    @Published var calendarRefreshToken: UUID   // bump to force calendar refresh
    @Published var dataUpdateToken: UUID         // bump to notify data changed
}
```

**Always mutate data through DataStore methods**, never by direct array manipulation
in views:

| Operation | Method |
|---|---|
| Add event | `store.add(_ event: Event)` |
| Update event | `store.update(_ event: Event)` |
| Delete event | `store.delete(_ event: Event)` |
| Add location | `store.add(_ location: Location)` |
| Update location | `store.update(_ location: Location)` |
| Delete location | `store.delete(_ location: Location)` |
| Add activity | `store.addActivity(_ activity: Activity)` |
| Add affirmation | `store.addAffirmation(_ affirmation: Affirmation)` |
| Add trip | `store.addTrip(_ trip: Trip)` |
| Delete trip | `store.deleteTrip(_ trip: Trip)` |
| Save manually | `store.storeData()` or `store.save()` |
| Force calendar refresh | `store.bumpCalendarRefresh()` |

**Persistence**: `storeData()` encodes everything to `backup.json` in the app's
Documents directory. It also calls `bumpDataUpdate()` automatically.

### Tab Layout (StartTabView)

| Index | Label | View | Nav Title |
|---|---|---|---|
| 0 | Home | `HomeView` | "Home" |
| 1 | Calendar | `ModernEventsCalendarView` | "Stays" |
| 2 | Charts | `DonutChartView` | "Stays Overview" |
| 3 | Locations | `LocationsUnifiedView` | "Locations" |
| 4 | Infographic | `InfographicsView` | "Infographic" |

### Sheet Orchestration

**All sheets are owned and presented by `StartTabView`**. Individual child views
must NOT present their own competing sheets for app-level flows. Use callbacks or
environment objects to bubble up sheet requests.

Sheet state variables in `StartTabView`:
```swift
@State private var showAbout: Bool
@State private var lformType: LocationFormType?      // add/update location
@State private var showActivitiesManager: Bool
@State private var showBackupExport: Bool
@State private var showFirstLaunchWizard: Bool
@State private var showTripsManagement: Bool
@State private var showImportGolfshot: Bool          // prepared, not yet in menu
@State private var showLocationsManagement: Bool
@State private var showTravelHistory: Bool
@State private var showCountryUpdater: Bool          // hidden, pending review
@State private var showLocationSync: Bool            // hidden, pending review
@State private var pendingItem: PendingTripItem?     // drives trip confirmation
```

### Trip Confirmation Pipeline

```
User adds event → DataStore.add(_:)
    → checkAndCreateTripForNewEvent()
    → TripMigrationUtility.suggestTrip(from:to:)
    → store.pendingTrip = (trip, fromEvent, toEvent)
    → onChange in StartTabView detects pendingTrip != nil
    → Creates PendingTripItem (Identifiable)
    → sheet(item: $pendingItem) → TripConfirmationView
    → User confirms: recalculateCO2() → store.addTrip()
    → store.pendingTrip = nil, pendingItem = nil
```

### Infographics Cache

`DataStore+InfographicsCache.swift` provides targeted invalidation via an actor
(`InfographicsCacheManager`) and `InfographicsChangeTracker`. Cache invalidation
hooks are called automatically by the CRUD methods. Do not call `storeData()`
directly if you want cache-aware saves — use `saveWithCacheInvalidation()` or the
standard CRUD methods which call both.

---

## 🗃️ Data Models

### Key Models

```swift
// Location — a named place
struct Location: Identifiable, Codable {
    var id: UUID
    var name: String
    var city: String?
    var latitude: Double
    var longitude: Double
    var country: String?
    var theme: Theme           // color theme enum
    var imageIDs: [String]
}

// Event — a stay at a location
struct Event: Identifiable, Codable {
    var id: UUID
    var eventType: EventType   // .unspecified, .stay, .vacation, etc.
    var date: Date
    var location: Location     // embedded snapshot, NOT a reference ID
    var city: String?
    var latitude: Double
    var longitude: Double
    var country: String?
    var note: String
    var people: [String]
    var activityIDs: [UUID]
    var affirmationIDs: [UUID]
    // computed: effectiveCoordinates — prefers stored coords over location coords
}

// Trip — travel between two events
struct Trip: Identifiable, Codable {
    var id: UUID
    var fromEventID: UUID
    var toEventID: UUID
    var departureDate: Date
    var arrivalDate: Date
    var distance: Double       // miles
    var transportMode: TransportMode
    var co2Emissions: Double
    var notes: String
    var isAutoGenerated: Bool
    // method: recalculateCO2()
    // computed: mode (alias for transportMode), formattedDistance
}

// Activity — user-defined tag for events
struct Activity: Identifiable, Codable {
    var id: UUID
    var name: String
}

// Affirmation — motivational text associated with events
struct Affirmation: Identifiable, Codable {
    var id: UUID
    var text: String
    var category: Category
    var createdDate: Date
    var color: String
    var isFavorite: Bool
    static var presets: [Affirmation]  // default seeded affirmations
}
```

### Serialization (ImportExport.swift)

The on-disk format is `Export` / `Import`. When decoding older backups,
`activities`, `affirmations`, and `trips` are optional and default to `[]`.
**Never add required keys to the `Import` struct without providing a default.**

```swift
struct Export: Codable { locations, events, activities, affirmations, trips }
struct Import: Codable { locations, events, activities?, affirmations?, trips? }
```

---

## ✅ Coding Conventions

### Must Follow

1. **Swift / SwiftUI only** — No UIKit unless absolutely unavoidable. Use
   `.fileImporter` not `UIDocumentPickerViewController`. Use `.sheet` not manual
   `UIViewController` presentation.

2. **async/await** for all async work — no Combine, no GCD.

3. **@EnvironmentObject for DataStore** — inject via `.environmentObject(store)`,
   consume with `@EnvironmentObject var store: DataStore`.

4. **sheet(item:)** over `sheet(isPresented:)` whenever the sheet needs associated
   data — avoids boolean/item desync bugs.

5. **Never force-unwrap** optionals in production paths. Use `guard let` or
   `if let`. The existing codebase has a few legacy force-unwraps to clean up —
   don't add new ones.

6. **All new Swift files go in `LocTrac/`** — never inside `LocTrac.xcodeproj/`.

7. **Debug prints** are acceptable during development using emoji prefixes
   (🟢 init, 🔄 body, ✅ success, ❌ error, 📥 import, 💾 save). Remove or
   gate them before App Store builds.

8. **Navigation titles** are set centrally in `StartTabView.navigationTitleForSelection()`.
   Child views use `.navigationBarTitleDisplayMode(.inline)` only.

### State Management Patterns

```swift
// ✅ Correct — let DataStore own mutations
store.add(newEvent)

// ❌ Wrong — never mutate directly from a view
store.events.append(newEvent)

// ✅ Correct — item-based sheet for data-carrying sheets
@State private var pendingItem: PendingTripItem?
.sheet(item: $pendingItem) { item in ... }

// ✅ Correct — bool sheet for simple dismiss-only sheets
@State private var showAbout = false
.sheet(isPresented: $showAbout) { AboutLocTracView() }
```

### File Naming

| Type | Convention | Example |
|---|---|---|
| SwiftUI View | `<Name>View.swift` | `TravelHistoryView.swift` |
| ViewModel | `<Name>ViewModel.swift` | `LocationFormViewModel.swift` |
| DataStore extension | `DataStore+<Feature>.swift` | `DataStore+InfographicsCache.swift` |
| Model | `<Name>.swift` | `Event.swift`, `Trip.swift` |
| Documentation | `UPPER_SNAKE.md` in `Documentation/` | `CHANGELOG.md` |

---

## 🚫 Known Gotchas & Decisions

| Topic | Decision / Gotcha |
|---|---|
| **Sheet conflicts** | UIKit-based file pickers conflict with SwiftUI sheets. Always use `.fileImporter` modifier. |
| **Location in Event** | `Event.location` is an **embedded snapshot**, not a live reference. When a location is updated, existing events are NOT auto-updated — this is intentional (historical record). |
| **"Other" location** | A special location named "Other" must always exist. `ensureOtherLocationExists()` is called on load and after imports. Never delete it. |
| **Date handling** | All date display uses UTC calendar (`TimeZone(secondsFromGMT: 0)`) to avoid timezone-drift bugs. Follow this pattern. |
| **Infographics cache** | Adding/updating/deleting through DataStore CRUD methods triggers cache invalidation automatically. Direct array mutations bypass this. |
| **Trip migration** | On first load with events but no trips, `runTripMigration()` auto-creates trips. Do not re-run this manually. |
| **calendarRefreshToken** | Call `store.bumpCalendarRefresh()` after any import to force the calendar view to reload. |
| **Affirmation seeding** | If `affirmations` is empty after load, `seedDefaultAffirmations()` auto-populates from `Affirmation.presets`. |
| **`.xcodeproj` files** | `.gitignore` blocks `*.swift` and `*.md` inside `.xcodeproj/`. Only `project.pbxproj` and `contents.xcworkspacedata` belong there. |
| **Tag push** | Use `git push origin <tagname>` or `--follow-tags` instead of `--tags` to avoid rejected-tag errors on existing tags. |

---

## 🔖 Git & Versioning

### Version History

| Tag | Notes |
|---|---|
| `v1.3` | Current — Travel History, Unified Locations, Trip Confirmation, Infographics tab, Affirmations, Timeline Restore |
| `v3.0` (legacy label) | Default location, State detection, LocationsManagementView |
| `v1.2` | Golfshot import, Home tab, Backup & Import rename |
| `v1.1` | Travel History, ColorPicker, EventCountryGeocoder |

### Workflow

1. **Develop** in feature branches or directly on `main` for small changes
2. **Commit** via Xcode Source Control (`⌘ Option C`) or Terminal
3. **Tag** with annotated tags: `git tag -a v<X.Y> -m "Version <X.Y> – <summary>"`
4. **Push**: `git push origin main --follow-tags`
5. **Never** use `--tags` on push (risks rejecting already-existing tags)
6. **Remote**: `https://github.com/zareyt/LocTrac-New.git`

### Commit Message Format

```
v<X.Y> – <Short title>

New Features:
- Feature A
- Feature B

Architecture:
- Change C

Bug Fixes:
- Fix D

Documentation:
- Doc E added
```

---

## 🧪 Testing Status

Currently **no automated tests**. All testing is manual.

### Highest Priority Test Targets (when adding tests)

1. `DataStore` CRUD — add/update/delete for events, locations, trips
2. `ImportExport` — encode/decode roundtrip, legacy backup compatibility
3. `TripMigrationUtility.suggestTrip(from:to:)` — distance and mode logic
4. `StateDetector` — geocoding cache behavior
5. `InfographicsCacheManager` — invalidation logic

Use **Swift Testing** (`import Testing`, `@Test`, `#expect`) — not XCTest.

---

## 🗂️ Documentation Files

All docs live in `LocTrac/Documentation/`. Key files:

| File | Contents |
|---|---|
| `CHANGELOG.md` | Keep-a-Changelog format version history |
| `GIT_SUMMARY_v1.3.md` | Technical git summary for v1.3 |
| `UPDATE_NOTES_v1.3.md` | User-facing release notes for v1.3 |
| `PROJECT_ANALYSIS.md` | Architecture analysis, metrics, roadmap |
| `BACKLOG.MD` | Feature backlog |
| `KEY_CODE_CHANGES.md` | Before/after for major refactors |

---

## 🗺️ Feature Backlog (Known Priorities)

### Short Term
- [ ] Unit tests (Swift Testing) for DataStore CRUD and ImportExport
- [ ] Accessibility audit — VoiceOver labels on all new views
- [ ] Remove/gate debug print statements before App Store build
- [ ] Surface **Golfshot CSV Import** in Options menu (code is ready, just hidden)

### Medium Term
- [ ] Re-evaluate **Sync Event Coordinates** (`LocationSyncUtilityView`) and re-enable
- [ ] Re-evaluate **Update Event Countries** (`EventCountryUpdaterView`) and re-enable
- [ ] CSV / PDF export
- [ ] WidgetKit home screen widget (stats glance)
- [ ] Haptics on key interactions

### Long Term
- [ ] iCloud / CloudKit sync (multi-device)
- [ ] watchOS companion app
- [ ] Localization (i18n)
- [ ] macOS Catalyst or native macOS version
- [ ] Persist exported backups in `Documents/Backups/` instead of temp directory

---

## 💡 Tips for Claude When Helping on This Project

1. **Always use Swift and SwiftUI** — never suggest Objective-C, React Native,
   or non-Apple solutions.

2. **Check `DataStore` first** before suggesting where to put new state or logic.
   Most features extend `DataStore` or add a new `DataStore+Feature.swift`.

3. **All sheets go through `StartTabView`** — if a feature needs a new sheet,
   add a `@State private var show<Feature>: Bool` there and wire the `.sheet` there.

4. **Respect the `Import` struct's optional fields rule** — any new persisted
   property must be optional in `Import` with a default to maintain backward
   compatibility with existing `backup.json` files.

5. **Date display = UTC** — always use a UTC-pinned `Calendar` and `DateFormatter`
   for any date shown to the user.

6. **File picker = `.fileImporter`** — never `UIDocumentPickerViewController`.

7. **When generating git commit messages**, follow the multi-line format above.
   Use `git push origin main --follow-tags` for push commands.

8. **The `.xcodeproj` folder is protected** — never suggest adding `.swift` or
   `.md` files there.

9. **Check the backlog** before suggesting "new" features — many are already
   planned and may have partial implementations (e.g., `showImportGolfshot` is
   wired but not in the menu yet).

10. **Performance matters** — the app is tested with 1,500+ events. Any new
    list or computation must use `LazyVStack`, efficient grouping (Dictionary),
    and avoid recomputing in `body`.

---

*CLAUDE.md — LocTrac v1.3 — Tim Arey — 2026-04-04*
*Update this file with each major release.*
