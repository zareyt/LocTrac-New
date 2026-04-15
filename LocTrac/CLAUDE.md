# CLAUDE.md — LocTrac AI Assistant Context

This file provides Claude with everything it needs to assist effectively on the
LocTrac project. Update this file whenever the architecture, conventions, or
backlog change significantly.

**Last Updated**: 2026-04-13
**Current Version**: 1.5 (Complete - Ready for Release)
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
## Context Recovery
If I paste a previous response at the start of a conversation, treat it as 
recent context and continue from where it left off without re-explaining 
or re-summarizing unless asked.


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
## File Editing Behavior
- ALWAYS edit existing files in place rather than creating new files
- NEVER create a replacement file (e.g., `MyView_new.swift`, `MyView_v2.swift`)
- When modifying a file, use targeted edits to change only the relevant sections
- Do NOT rewrite an entire file unless explicitly asked
- If a file needs structural changes, modify it directly and preserve all existing code that isn't being changed
- Before creating any new file, confirm it doesn't already exist in the project


## New File Policy
- Only create new files when implementing genuinely new functionality
- Ask before creating a new file if it's unclear whether one already exists
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
@State private var showDebugSettings: Bool           // v1.5: Debug system settings (DEBUG only)
@State private var pendingItem: PendingTripItem?     // drives trip confirmation
@StateObject private var debugConfig = DebugConfig.shared  // v1.5: Debug configuration
```

**Settings/Options Menu Location**: The main app settings menu is in `StartTabView`, 
typically in a toolbar Menu button (often gear icon or ellipsis). To add new menu items,
find the `Menu { }` block in the toolbar and add your item there. For debug-only items,
wrap in `#if DEBUG ... #endif`.

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

## 🗃️ Data Models (v1.5)

### Key Models

```swift
// Location — a named place
struct Location: Identifiable, Codable {
    var id: String
    var name: String
    var city: String?           // City name ONLY (no state/country)
    var state: String?          // v1.5: State, province, territory, etc.
    var latitude: Double
    var longitude: Double
    var country: String?        // Country name (e.g., "United States")
    var countryCode: String?    // v1.5: ISO country code (e.g., "US", "CA")
    var theme: Theme            // color theme enum
    var imageIDs: [String]?
    var customColorHex: String? // optional custom color
    
    // v1.5: Computed properties
    var fullAddress: String      // "Denver, Colorado, United States"
    var shortAddress: String     // "Denver, Colorado"
    var effectiveColor: Color    // custom color or theme color
}

// Event — a stay at a location
struct Event: Identifiable, Codable {
    var id: String
    var eventType: String       // .unspecified, .stay, .vacation, etc.
    var date: Date
    var location: Location      // embedded snapshot, NOT a reference ID
    var city: String?           // v1.5: City for "Other" location events only
    var latitude: Double        // For "Other" location events
    var longitude: Double       // For "Other" location events
    var country: String?        // Country (for "Other" events)
    var state: String?          // v1.5: State/province (for "Other" events)
    var note: String
    var people: [Person]
    var activityIDs: [String]
    var affirmationIDs: [String]
    var isGeocoded: Bool        // v1.5: Prevents re-geocoding successfully processed events
    
    // v1.5: Computed properties for effective values
    var effectiveCoordinates: (latitude: Double, longitude: Double)
    var effectiveCity: String?       // Event city for "Other", location city for named
    var effectiveState: String?      // Event state for "Other", location state for named
    var effectiveCountry: String?    // Event country for "Other", location country for named
    var effectiveAddress: String     // Full address based on location type
    var effectiveShortAddress: String // City, state only
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
    var id: String
    var name: String
}

// Affirmation — motivational text associated with events
struct Affirmation: Identifiable, Codable {
    var id: String
    var text: String
    var category: Category
    var createdDate: Date
    var color: String
    var isFavorite: Bool
    static var presets: [Affirmation]  // default seeded affirmations
}

// v1.5: GeocodeResult — structured geocoding response
struct GeocodeResult {
    let city: String?
    let state: String?          // administrativeArea
    let country: String?
    let countryCode: String?    // isoCountryCode
    let latitude: Double
    let longitude: Double
}
```

### v1.5: "Other" Location Concept

The "Other" location is special — it acts as a catch-all for events at non-standard locations:

- **Named locations** (Loft, Cabo, etc.) → Use `location.city`, `location.state`, `location.country`
- **"Other" location events** → Each event stores its own `city`, `state`, `country`, `latitude`, `longitude`

This allows "Other" to represent multiple different cities/countries across different events.

**Example:**
```swift
// Named location event
let event1 = Event(
    location: loftLocation,    // Has city="Denver", state="Colorado"
    city: nil,                 // Not used for named locations
    state: nil,                // Not used for named locations
    // ... effectiveCity will return "Denver" from location
)

// "Other" location event #1
let event2 = Event(
    location: otherLocation,   // Generic "Other" 
    city: "Paris",             // Event-specific
    state: nil,                // France has no states
    country: "France",         // Event-specific
    // ... effectiveCity will return "Paris" from event
)

// "Other" location event #2
let event3 = Event(
    location: otherLocation,   // Same "Other" location
    city: "Tokyo",             // Different event-specific city
    state: "Tokyo",            // Event-specific
    country: "Japan",          // Different event-specific country
    // ... effectiveCity will return "Tokyo" from event
)
```

### Serialization (ImportExport.swift)

The on-disk format is `Export` / `Import`. When decoding older backups,
`activities`, `affirmations`, `trips`, `state`, and `countryCode` are optional 
and default to `[]` or `nil`.

**v1.5: All new fields are optional in `Import` struct for backward compatibility.**

```swift
struct Export: Codable { locations, events, activities, affirmations, trips }
struct Import: Codable { 
    locations, events, 
    activities?, affirmations?, trips?  // Optional for v1.3 backups
    // v1.5: state?, countryCode?, city? all optional in nested structs
}
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

7. **Debug logging** uses the centralized `DebugConfig` framework. Use 
   `DebugConfig.shared.log(.category, "message")` instead of raw `print()` 
   statements. Available categories: `.dataStore`, `.persistence`, `.navigation`, 
   `.network`, `.cache`, `.trips`, `.charts`, `.parser`, `.startup`. All debug 
   output can be toggled on/off via Debug Settings in the app (DEBUG builds only).

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
| **Location Data Enhancement** | v1.5 tool for cleaning/geocoding location data. Accessible via Settings → Enhance Location Data. Uses rate limiting (45/min) to respect Apple's geocoding limit. Processes master Locations first, then "Other" Events. Skips named-location Events (inherit from master) and already-geocoded Events (`isGeocoded` flag). Session persistence allows resuming later. "Retry Errors" button reprocesses only failed items. |
| **Geocoding efficiency** | `Event.isGeocoded` flag prevents re-geocoding successfully processed events. Set to `true` only when geocoding fully succeeds. Saves 50-66% of API calls on subsequent enhancement runs. Already-geocoded events are skipped silently. |
| **Import location remapping** | v1.5 fix: Import now remaps old location IDs to current store IDs during merge. Special handling for "Other" location prevents orphaned events. Events reference valid locations after import. "Fix Orphaned Events" tool moved to DEBUG-only (issue resolved at import time). |
| **Dynamic What's New** | v1.5+: Features are parsed from `VERSION_x.x_RELEASE_NOTES.md` files at runtime. Format: `### Title\nicon: symbol \| color: name\nDescription`. Falls back to hardcoded features in `WhatsNewFeature.swift` if parsing fails. Always include markdown file in Xcode target. See `WHATS_NEW_DYNAMIC_SYSTEM.md` for complete guide. |

---

## 🔖 Git & Versioning

### Version History

| Tag | Notes |
|---|---|
| `v1.5` | **In Development** — International location support with state/province fields, enhanced geocoding, data migration utility |
| `v1.4` | Infographics PDF/Screenshot export with real Apple Maps, Journey map visualization, Share button implementation with NotificationCenter |
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

### **Current Version (v1.5 - In Development)**
| File | Contents |
|------|----------|
| `VERSION_1.5_SUMMARY.md` | Quick overview and development status for v1.5 |
| `VERSION_1.5_INTERNATIONAL_LOCATIONS.md` | Complete technical specification for international location support |

### **Previous Version (v1.4)**
| File | Contents |
|------|----------|
| `VERSION_1.4_RELEASE_NOTES.md` | User-facing release notes for v1.4 |
| `LOCTRAC_V1.4_COMPLETE_SUMMARY.md` | Technical summary and feature breakdown |

### **Feature Guides**
| File | Contents |
|------|----------|
| `WHATS_NEW_DYNAMIC_SYSTEM.md` | Dynamic "What's New" markdown parsing system |
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

### v1.5 - Complete ✅

- [x] **Dynamic What's New System**
  - Created `ReleaseNotesParser.swift` for markdown parsing
  - Updated `WhatsNewFeature.swift` with dynamic loading + hardcoded fallback
  - Parses `VERSION_x.x_RELEASE_NOTES.md` files automatically
  - Format: `### Title\nicon: symbol | color: name\nDescription`
  - Falls back to hardcoded features if parsing fails
  - Supports 13 colors, all SF Symbols
  - See `WHATS_NEW_DYNAMIC_SYSTEM.md` for complete guide

- [x] **Model Updates**
  - Added `state`/`province` field to Location and Event models
  - Added `countryCode` field for ISO codes
  - Added `isGeocoded: Bool` flag to Event (prevents re-geocoding)
  - Enhanced geocoding service with forward/reverse geocoding
  - Smart parsing of manual entry (e.g., "Denver, CO")
  - Computed properties for clean address access
  
- [x] **Location Data Enhancement Tool**
  - Complete UI (`LocationDataEnhancementView`) for data validation and cleanup
  - `LocationDataEnhancer` service with 4-step priority algorithm
  - Rate limiting with automatic retry queue (handles Apple's 50/min limit)
  - Long country name support ("Canada", "Scotland", "United Kingdom", etc.)
  - Session persistence via UserDefaults (resume later)
  - "Retry Errors" button (process only failed items)
  - Geocoding flag skips already-processed events (50-66% API savings)
  - Comprehensive error handling with human-readable messages
  - Before/after logging for troubleshooting
  
- [x] **Country Mappers**
  - `CountryCodeMapper` - Short codes → country names ("US" → "United States")
  - `CountryNameMapper` - Long names → standardized names/codes ("Scotland" → "United Kingdom")
  - `USStateCodeMapper` - State abbreviations → full names ("CO" → "Colorado")
  - Support for 50+ countries worldwide
  
- [x] **Processing Priority Algorithm**
  - **Step 1**: If all data exists → clean format only (no geocoding)
  - **Step 2**: If GPS exists → reverse geocode for state/country
  - **Step 3**: If no GPS → parse "City, XX" format (state code / country code / country name)
  - **Step 4**: If insufficient data → report error with actionable message
  - Process master Locations first, then "Other" Events
  - Skip named-location Events (inherit from master)
  - Skip already-geocoded Events (`isGeocoded == true`)

- [x] **Import Fix - Location ID Remapping**
  - Fixed orphaned events issue during merge imports
  - Import now remaps old location IDs to current store IDs
  - Special handling for "Other" location (always maps to current "Other")
  - Graceful fallback: assigns to "Other" if location not found
  - Prevents all orphaned events on import
  - "Fix Orphaned Events" tool moved to DEBUG-only (issue resolved)

### Short Term
- [ ] Unit tests (Swift Testing) for DataStore CRUD and ImportExport
- [ ] Unit tests for migration service
- [ ] Accessibility audit — VoiceOver labels on all new views
- [x] **Debug System Integration** — Centralized debug framework with granular logging
  - All uncategorized print statements converted to `DebugConfig.shared.log()`
  - New categories: `.charts`, `.parser`, `.startup`
  - Toggle debug output via Debug Settings (Settings → Debug Settings in DEBUG builds)
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
- [ ] Timezone support per location (v1.6+)
- [ ] Hierarchical location picker (Country → State → City)

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
