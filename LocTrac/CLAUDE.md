# CLAUDE.md — LocTrac AI Assistant Context

This file provides Claude with everything it needs to assist effectively on the
LocTrac project. Update this file whenever the architecture, conventions, or
backlog change significantly.

**Last Updated**: 2026-04-08
**Current Version**: 1.4
**Author**: Tim Arey

---

## 🗺️ Project Summary

**LocTrac** is a privacy-first iOS/iPadOS travel tracking app built entirely in
SwiftUI. It stores all data locally (no cloud, no server). Users record locations,
stays/events, trips, activities, and affirmations, then visualize their travel
history through maps, charts, and infographics.

- **Platform**: iOS 18.0+ / iPadOS 18.0+
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
    var id: UUID               // ⚠️ UUID type (only Trip.id is UUID!)
    var fromEventID: String    // ⚠️ String! References Event.id
    var toEventID: String      // ⚠️ String! References Event.id
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

### ⚠️ Important: Trip References Event IDs

**Trips link to Events using Strings, not UUIDs:**
```swift
// Trip stores Event IDs as Strings
trip.fromEventID  // String - matches event.id
trip.toEventID    // String - matches event.id

// When filtering trips by events:
let eventIDs = Set(events.map { $0.id })  // Set<String>
let relevantTrips = store.trips.filter { trip in
    eventIDs.contains(trip.toEventID)  // ✅ Both are Strings
}
```

❌ **Don't do this:**
```swift
eventIDs.contains(trip.toEventID.uuidString)  // ERROR: toEventID is already a String!
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

### Navigation & Toolbar Patterns

**TabView Navigation Architecture:**
- `StartTabView` contains a `NavigationStack` wrapping the `TabView`
- Navigation titles are set centrally in `StartTabView.navigationTitleForSelection()`
- **Tab-embedded views must NOT have their own `NavigationStack`** — this causes toolbar items to be hidden

**Toolbar Guidelines:**

```swift
// ✅ For views presented as SHEETS (e.g., TravelHistoryView):
var body: some View {
    NavigationStack {  // ✅ Own NavigationStack OK for sheets
        List { ... }
            .navigationTitle("Travel History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { ShareLink(...) }
            }
    }
}

// ✅ For views EMBEDDED IN TABVIEW (e.g., InfographicsView):
var body: some View {
    ScrollView { ... }  // ❌ NO NavigationStack wrapper
    // ❌ NO .toolbar { } modifier on TabView children
    // ❌ NO .navigationTitle() - title is set in StartTabView
    // ✅ Listen for toolbar actions via NotificationCenter
}

// ❌ WRONG — TabView child with NavigationStack:
var body: some View {
    NavigationStack {  // ❌ Will hide toolbar!
        ScrollView { ... }
            .toolbar { ... }  // ❌ Won't appear
    }
}

// ❌ WRONG — TabView child with .toolbar:
var body: some View {
    ScrollView { ... }
        .toolbar { ... }  // ❌ Won't work - toolbar must be in StartTabView
}
```

**Communication from StartTabView toolbar to child views:**
- Use `NotificationCenter` for actions (e.g., PDF generation, screenshots)
- Child views listen with `.onReceive(NotificationCenter.default.publisher(for: ...))`
- Always add debug logging to verify notification flow

**Complete Working Example:**
```swift
// In StartTabView toolbar (with conditional display):
if selection == 4 {
    ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
            Button {
                print("🔘 PDF export button tapped")  // Debug log
                NotificationCenter.default.post(
                    name: NSNotification.Name("GeneratePDF"), 
                    object: nil
                )
            } label: {
                Label("Export as PDF", systemImage: "doc.fill")
            }
            
            Button {
                print("🔘 Screenshot share button tapped")  // Debug log
                NotificationCenter.default.post(
                    name: NSNotification.Name("ShareScreenshot"), 
                    object: nil
                )
            } label: {
                Label("Share Screenshot", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .imageScale(.large)
        }
    }
}

// In InfographicsView (TabView child):
var body: some View {
    ScrollView {
        // content
    }
    // ✅ Listen for toolbar actions
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GeneratePDF"))) { _ in
        print("📨 Received GeneratePDF notification")  // Debug log
        generatePDF()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShareScreenshot"))) { _ in
        print("📨 Received ShareScreenshot notification")  // Debug log
        shareScreenshot()
    }
}
```

**Why NotificationCenter for TabView Toolbars:**
1. **TabView children can't have their own toolbars** - they won't display
2. **StartTabView owns the toolbar** - it wraps everything in NavigationStack
3. **NotificationCenter provides clean decoupling** - no need to pass closures through TabView
4. **Debug logging is essential** - helps verify notification flow during development
5. **One-way communication** - toolbar posts, child listens (simple and clear)

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
| **Person grouping** | People are grouped by `displayName`, not `id`. Same person can have multiple Person instances with different IDs across events. Always group by `displayName` when counting visits/occurrences. |
| **TabView toolbars** | TabView children CANNOT have `.toolbar` modifiers - they are ignored. All toolbars for tabs must be in `StartTabView` with conditional `if selection == X` logic. Use NotificationCenter to communicate toolbar actions to child views. **Missing `.onReceive()` listeners is a common bug.** |
| **NotificationCenter listeners** | When using NotificationCenter for toolbar → child communication, ALWAYS add debug logging (`print("📨 Received...")`) to both the sender and receiver. This makes it immediately obvious if notifications aren't being received. |
| **MapKit in PDFs** | Interactive MapKit `Map` views cannot be rendered in `ImageRenderer` for PDF export. Use `MKMapSnapshotter` to capture actual map images asynchronously before generating PDFs. The snapshotter must be called in an async context and its result drawn on with route lines and markers using `UIGraphicsImageRenderer`. |
| **Infographics PDF export** | PDF generation for InfographicsView uses a two-phase process: (1) async map snapshot generation with `MKMapSnapshotter`, (2) SwiftUI content rendering with `ImageRenderer`. The map snapshot is embedded as a `UIImage` in the final PDF content. This ensures real Apple Maps tiles appear in exported PDFs. |

---

## 🔖 Git & Versioning

### Version History

| Tag | Notes |
|---|---|
| `v1.4` | Current — Infographics PDF/Screenshot export with real Apple Maps, Journey map visualization, Share button implementation with NotificationCenter |
| `v1.3` | Travel History, Unified Locations, Trip Confirmation, Infographics tab, Affirmations, Timeline Restore |
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

All documentation organized for clarity. Key files:

### **Core Documentation**
| File | Contents |
|------|----------|
| `CLAUDE.md` | AI assistant context and project conventions |
| `README.md` | Project overview and getting started |
| `CHANGELOG.md` | Keep-a-Changelog format version history |
| `BACKLOG.MD` | Feature requests and bug tracking |
| `PROJECT_ANALYSIS.md` | Architecture analysis, metrics, roadmap |
| `KEY_CODE_CHANGES.md` | Major refactoring documentation |

### **Current Version (v1.4)**
| File | Contents |
|------|----------|
| `VERSION_1.4_RELEASE_NOTES.md` | User-facing release notes for v1.4 |
| `LOCTRAC_V1.4_COMPLETE_SUMMARY.md` | Technical summary and feature breakdown |

### **Feature Guides**
| File | Contents |
|------|----------|
| `WIDGET_IMPLEMENTATION.md` | Complete widget setup and troubleshooting |
| `WIDGET_QUICK_START.md` | Quick reference for widget integration |
| `NOTIFICATIONS_SETUP_GUIDE.md` | Notification system implementation guide |
| `CALENDAR_IMPLEMENTATION_GUIDE.md` | Calendar architecture and patterns |
| `INFOGRAPHICS_OPTIMIZATION_GUIDE.md` | Performance optimization strategies |
| `README_LICENSE_SUMMARY.md` | Content for About screen |

### **Deprecated/Removed**
Older version-specific docs (v1.1-v1.3), build fix notes, and feature proposals have been consolidated or archived.

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

11. **TabView children NEVER get toolbars** — if adding toolbar items for a tab,
    they must go in `StartTabView` with conditional `if selection == X` logic.
    Use NotificationCenter to trigger actions in the child view. Always add
    `.onReceive()` listeners in the child and include debug logging on both sides.

12. **Debug logging is required for NotificationCenter** — when a toolbar button
    posts a notification and a child view receives it, BOTH should log with emoji
    prefixes (🔘 for button tap, 📨 for received). This makes debugging trivial.

13. **MapKit PDF exports require MKMapSnapshotter** — `Map` views won't render in
    `ImageRenderer` because they load tiles asynchronously. Use `MKMapSnapshotter`
    in an async Task to capture real map images, then draw routes/markers on top
    using `UIGraphicsImageRenderer`. Embed the resulting `UIImage` in SwiftUI
    content for PDF generation.

14. **Async PDF generation** — when PDF content depends on async operations (like
    map snapshots), structure code as: `generatePDF()` → `Task { await generate...() }`
    → `await MainActor.run { createPDFContent(...) }`. This ensures map snapshots
    complete before PDF rendering begins.

---

*CLAUDE.md — LocTrac v1.4 — Tim Arey — 2026-04-08*
*Update this file with each major release.*
