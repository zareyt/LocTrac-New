# CLAUDE.md — LocTrac AI Assistant Context

This file provides Claude with everything it needs to assist effectively on the
LocTrac project. Update this file whenever the architecture, conventions, or
backlog change significantly.

**Last Updated**: 2026-04-25
**Current Version**: 2.0
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
│   ├── FirstLaunchWizard.swift      ← First-launch onboarding logic
│   ├── AuthState.swift              ← v2.0: Observable auth state (@EnvironmentObject)
│   └── UserProfile.swift            ← v2.0: Profile model + profile.json persistence
│
├── Services/
│   ├── ImportExport.swift           ← Import/Export Codable structs (Import, Export)
│   ├── KeychainHelper.swift         ← v2.0: Keychain read/write/delete wrapper
│   ├── AuthenticationService.swift  ← v2.0: Auth logic actor (Apple Sign-In, email/password)
│   ├── BiometricService.swift       ← v2.0: Face ID / Touch ID via LAContext
│   ├── TOTPService.swift            ← v2.0: TOTP generation/verification (RFC 6238)
│   └── Auth/                        ← v2.0: Auth-related views
│       ├── WelcomeView.swift            ← First launch sign-in prompt
│       ├── SignInView.swift             ← Apple + email login
│       ├── SignUpView.swift             ← Account registration
│       ├── ForgotPasswordView.swift     ← Password reset flow
│       ├── TwoFactorSetupView.swift     ← TOTP QR code + backup codes
│       ├── TwoFactorVerifyView.swift    ← TOTP code entry on login
│       └── BiometricLockView.swift      ← Full-screen lock overlay for app lock
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
│   ├── Profile/
│   │   ├── ProfileView.swift            ← v2.0: Account hub
│   │   ├── EditProfileView.swift        ← v2.0: Edit name, photo, email
│   │   ├── PreferencesView.swift        ← v2.0: App preferences
│   │   └── SecuritySettingsView.swift   ← v2.0: Password, 2FA, biometrics
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

### AuthState — v2.0 Authentication (ObservableObject)

```swift
class AuthState: ObservableObject {
    @Published var isAuthenticated: Bool
    @Published var currentUser: UserProfile?
    @Published var isLoading: Bool
    @Published var authError: String?
    @Published var requiresTwoFactor: Bool
    @Published var hasDismissedMigrationPrompt: Bool

    // Computed helpers
    var currentAuthProvider: UserProfile.SignInMethod  // .apple, .email, .none
    var currentEmail: String?
    var initials: String  // "TA" from "Tim Arey"
}
```

Injected alongside DataStore in `AppEntry.swift`:
```swift
@StateObject private var store = DataStore()
@StateObject private var authState = AuthState()
@State private var isLocked = false  // Biometric app lock

var body: some Scene {
    WindowGroup {
        ZStack {
            StartTabView()
                .environmentObject(store)
                .environmentObject(authState)
            if isLocked {
                BiometricLockView(isLocked: $isLocked)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Lock on background, auto-unlock on active
        }
    }
}
```

**Biometric App Lock**: When `BiometricService.isEnabled` and user is authenticated,
the app locks on background (`scenePhase == .background`) and shows `BiometricLockView`
as a full-screen overlay. On return to foreground, it auto-attempts biometric unlock.

### UserProfile — v2.0 Separate Storage

- Stored in `Documents/profile.json` — completely separate from `backup.json`
- **Never** included in exports — auth data stays private
- Preferences: `defaultLocationID`, `distanceUnit` (.miles/.kilometers), `defaultTransportMode`
- Deleting `profile.json` returns the user to guest mode with all travel data intact

### Tab Layout (StartTabView)

| Index | Label | View | Nav Title |
|---|---|---|---|
| 0 | Home | `HomeView` | "Home" |
| 1 | Calendar | `ModernEventsCalendarView` | "Stays" |
| 2 | Charts | `DonutChartView` | "Stays Overview" |
| 3 | Travel Map | `LocationsUnifiedView` | "Travel Map" |
| 4 | Infographic | `InfographicsView` | "Infographic" |

### Sheet Orchestration

**All sheets are owned and presented by `StartTabView`**. Individual child views
must NOT present their own competing sheets for app-level flows. Use callbacks or
environment objects to bubble up sheet requests.

Sheet state variables in `StartTabView`:
```swift
@State private var showAbout: Bool
@State private var showProfile: Bool                 // v2.0: Profile & Settings sheet
@State private var lformType: LocationFormType?      // add/update location
@State private var showActivitiesManager: Bool
@State private var showBackupExport: Bool
@State private var showFirstLaunchWizard: Bool
@State private var showTripsManagement: Bool
@State private var showTravelHistory: Bool           // v2.0: moved next to Manage Trips
@State private var showImportGolfshot: Bool          // prepared, not yet in menu
@State private var showLocationsManagement: Bool
@State private var showCountryUpdater: Bool          // hidden, pending review
@State private var showLocationSync: Bool            // hidden, pending review
@State private var showDebugSettings: Bool           // v1.5: Debug system settings (DEBUG only)
@State private var pendingItem: PendingTripItem?     // drives trip confirmation
@StateObject private var debugConfig = DebugConfig.shared  // v1.5: Debug configuration
```

**v2.0 Menu Structure** (ellipsis.circle toolbar):
1. **Profile & Account** — opens ProfileView sheet (first item)
2. *(divider)*
3. About LocTrac
4. *(divider)*
5. Manage Locations / Activities & Affirmations / Manage Trips / **Travel History** (moved here)
6. *(divider)*
7. Data Management submenu (Backup & Import, Enhance Location Data, Fix Orphaned Events [DEBUG])
8. Debug Settings [DEBUG]

**Notifications** menu item moved from main menu to **ProfileView** (under ACCOUNT section
for signed-in users, under SETTINGS for signed-out users).

**Settings/Options Menu Location**: The main app settings menu is in `StartTabView`,
typically in a toolbar Menu button (ellipsis.circle). To add new menu items,
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

9. **Build and verify** — After completing any code changes, always run
   `BuildProject` to confirm the project compiles with zero errors. Use
   `XcodeRefreshCodeIssuesInFile` for quick per-file checks during development.
   Never consider a task complete until the build passes.

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
| **Date handling** | All dates are stored as UTC midnight. **Never use `.formatted(date:time:)`** to display event/trip dates — it uses the local timezone and causes ±1 day drift. Use `date.utcMediumDateString` or `date.utcLongDateString` (defined in `Date+Extension.swift`). For `DatePicker`, set `.environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)`. For `Calendar` operations, always use a UTC-pinned calendar. |
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
| **EventType colors** | v2.0: `Event.EventType` has `color: Color` and `sfSymbol: String` computed properties — the single source of truth for all event type display. Stay=red, Host=blue, Vacation=green, Family=purple, Business=brown, Unspecified=gray. Always use these properties; never hardcode event type colors. The legacy `icon` (emoji squares) is kept but deprecated. InfographicsView donut chart uses explicit `.foregroundStyle(item.color)` — NOT `.foregroundStyle(by:)` which auto-assigns colors. |
| **One stay per day** | v2.0: Batch event creation (`createNewEvents()` in both `ModernEventFormView` and `EventFormView`) skips any date that already has an event. An alert informs the user how many days were skipped. This prevents duplicate stays on the same date. The check uses `store.events.map { $0.date.startOfDay }` for O(1) lookup. |
| **Auth is separate from data** | v2.0: Authentication (`profile.json`, Keychain) is completely isolated from travel data (`backup.json`). Never put auth data in exports. Never put user IDs in backup.json. |
| **profile.json vs backup.json** | v2.0: `profile.json` stores user profile and preferences. `backup.json` stores travel data. They are independent — deleting one does not affect the other. |
| **AuthState injection** | v2.0: `AuthState` is injected via `.environmentObject()` alongside `DataStore` in `AppEntry.swift`. Both are `ObservableObject` with `@Published` properties. |
| **Optional sign-in** | v2.0: Sign-in is never required. Users can always skip and use the app as a guest. Existing data is always accessible regardless of auth state. |
| **Keychain service ID** | v2.0: All Keychain operations use service identifier `com.loctrac.auth`. |
| **NSFaceIDUsageDescription** | v2.0: **Required** in Info.plist for Face ID. Without it, the app crashes on biometric access. Value: "LocTrac uses Face ID to securely unlock your account and verify your identity for password resets." |
| **`.accent` vs `Color.accentColor`** | v2.0: SwiftUI's `.accent` is NOT a valid `ShapeStyle`. Use `Color.accentColor` in `.foregroundStyle()`, `.background()`, `.fill()`, etc. This caused 16 build errors during v2.0 development. |
| **Auth views in Services/Auth/** | v2.0: Auth-related views (WelcomeView, SignInView, SignUpView, ForgotPasswordView, TwoFactorSetupView, TwoFactorVerifyView, BiometricLockView) live in `Services/Auth/`, NOT `Views/Auth/`. |
| **Biometric app lock** | v2.0: `BiometricLockView` is a full-screen ZStack overlay in `AppEntry.swift`, driven by `scenePhase` monitoring. Locks on background when biometrics enabled + authenticated, auto-unlocks on foreground. |
| **TOTP is real RFC 6238** | v2.0: TOTPService uses CryptoKit HMAC-SHA1 with Data-based secrets. Verification allows +/-1 period for clock drift. Backup codes stored in Keychain as JSON-encoded `[String]`. |
| **2FA gates sign-in** | v2.0: When `TOTPService.isEnabled`, `signInWithEmail()` sets `requiresTwoFactor = true` instead of `isAuthenticated = true`. User must verify TOTP code before access. `completeTwoFactorAuth()` finishes the flow. |
| **Info.plist required keys** | v2.0: `NSFaceIDUsageDescription` (Face ID), Sign in with Apple capability in entitlements (`com.apple.developer.applesignin`), `aps-environment` for push notifications. |

---

## 🔖 Git & Versioning

### Version History

| Tag | Notes |
|---|---|
| `v2.0` | **In Development** — Authentication (Apple Sign-In, email/password), user profile, biometrics, 2FA, preferences |
| `v1.5` | International location support with state/province fields, enhanced geocoding, data migration utility |
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

### **Current Version (v2.0 - In Development)**
| File | Contents |
|------|----------|
| `DocumentationV2.0_IMPLEMENTATION_PLAN.md` | Complete implementation plan for auth & profile |
| `VERSION_2.0_RELEASE_NOTES.md` | User-facing release notes for v2.0 |

### **Previous Versions (v1.4 - v1.5)**
| File | Contents |
|------|----------|
| `VERSION_1.5_RELEASE_NOTES.md` | User-facing release notes for v1.5 |
| `VERSION_1.5_SUMMARY.md` | Quick overview for v1.5 |
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

### v2.0 - Complete

- [x] **Phase A: Auth Service & Models**
  - `Services/KeychainHelper.swift` — Keychain wrapper (`com.loctrac.auth`)
  - `Services/AuthenticationService.swift` — Auth actor (Apple Sign-In, email/password, session)
  - `Models/AuthState.swift` — ObservableObject with 2FA gate, computed helpers
  - `Models/UserProfile.swift` — Profile model + `profile.json` persistence
  - `AppEntry.swift` — AuthState injection, biometric lock via scenePhase
  - `Info.plist` — NSFaceIDUsageDescription, Sign in with Apple capability

- [x] **Phase B: Sign-In Views**
  - `Services/Auth/WelcomeView.swift` — First launch sign-in prompt (Skip or Sign In)
  - `Services/Auth/SignInView.swift` — Apple + email/password login
  - `Services/Auth/SignUpView.swift` — Account registration
  - `Services/Auth/ForgotPasswordView.swift` — Password reset flow

- [x] **Phase C: Profile Management**
  - `Views/Profile/ProfileView.swift` — Account hub (profile, preferences, security, notifications)
  - `Views/Profile/EditProfileView.swift` — Edit name, photo, email
  - `Views/Profile/PreferencesView.swift` — Default location, distance unit, transport mode
  - `StartTabView.swift` — showProfile state, menu item, sheet, menu reorganization

- [x] **Phase E: Existing User Migration**
  - One-time prompt for users with existing data
  - Zero data loss — backup.json unchanged
  - "Skip for now" always available

- [x] **Phase D: Biometrics & 2FA**
  - `Services/BiometricService.swift` — Face ID / Touch ID with enable/disable helpers
  - `Services/TOTPService.swift` — Real TOTP (RFC 6238, HMAC-SHA1, Data-based secrets)
  - `Services/Auth/TwoFactorSetupView.swift` — TOTP QR + backup codes
  - `Services/Auth/TwoFactorVerifyView.swift` — TOTP code entry with backup code support
  - `Services/Auth/BiometricLockView.swift` — Full-screen lock overlay for app lock
  - `Views/Profile/SecuritySettingsView.swift` — Password, 2FA, biometrics toggles
  - `AppEntry.swift` — scenePhase-driven biometric lock/unlock

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

## 🚀 Ready to Publish Workflow

When the user says **"I'm ready to publish this release"**, execute the following
checklist in order. **Confirm each step with the user before proceeding.**

### Pre-Flight Checks
1. **Flip `DebugConfig.showDebugMenu` to `false`** (`Models/DebugConfig.swift`)
   - Ask user to confirm: "Should I flip showDebugMenu to false?"
   - This hides the Debug Settings menu item entirely

2. **Review CHANGELOG** — Ensure all features, bug fixes, and improvements for
   the current version are captured. Use existing wording where possible.

3. **Review WhatsNew** — Verify `VERSION_x.x_RELEASE_NOTES.md` and
   `WhatsNewFeature.swift` hardcoded fallback are in sync. Exclude
   developer-specific items (testing, debug, one-off utilities).

4. **Set Release Date** — Update `VERSION_x.x_RELEASE_NOTES.md` (Release Date
   field) and `CHANGELOG.md` (`## [x.x] – YYYY-MM-DD`) to today's date.

5. **Build Project** — Run `BuildProject` and confirm zero errors.

### Git Operations (Confirm Before Each Step)

6. **Stage all changes** — Show the user what will be committed:
   ```
   git add -A
   git status
   ```

7. **Propose commit message** — Show the full commit message for user approval:
   ```
   v<X.Y> – <Short title>

   New Features:
   - Feature A
   - Feature B

   Bug Fixes:
   - Fix A
   - Fix B

   Improvements:
   - Improvement A
   ```

8. **Commit** — After user approves the message:
   ```
   git commit -m "<approved message>"
   ```

9. **Propose tag** — Show the tag for user approval:
   ```
   git tag -a v<X.Y> -m "Version <X.Y> – <summary>"
   ```

10. **Push** — After user approves:
    ```
    git push origin main --follow-tags
    ```
    Remote: `https://github.com/zareyt/LocTrac-New.git`

### Post-Push Verification

11. **Run regression tests** — Execute `RunAllTests` and report results.

12. **Update CLAUDE.md** — Bump version history table, update "Current Version"
    in header, update "Last Updated" date, and update footer.

13. **Confirm completion** — Report summary of what was published.

### Important Notes
- **Never use `--tags`** on push (risks rejecting existing tags)
- **Always use `--follow-tags`** to push only the new annotated tag
- Remote is `origin` → `https://github.com/zareyt/LocTrac-New.git`
- After publishing, flip `DebugConfig.showDebugMenu` back to `true` for next dev cycle

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

5. **Date display = UTC** — never use `.formatted(date:time:)` on event or trip
   dates. Use `date.utcMediumDateString` or `date.utcLongDateString` from
   `Date+Extension.swift`. These use UTC-pinned formatters that prevent ±1 day
   drift. For `DatePicker`, set `.environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)`.

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

15. **Auth data stays out of exports** — `profile.json` and Keychain data must never
    be included in `backup.json` exports. The auth system is additive and isolated.

16. **AuthState uses @EnvironmentObject** — same pattern as DataStore. Inject in
    `AppEntry.swift`, consume with `@EnvironmentObject var authState: AuthState`.

17. **Never block users on sign-in** — all auth flows must have a "Skip" or
    "Continue without account" option. Existing data is always accessible.

18. **Always ask about WhatsNew updates** — after completing any feature or bug
    fix, ask the user: "Should I update the WhatsNew view (feature or bug fix
    entry)?" Both `VERSION_2.0_RELEASE_NOTES.md` (dynamic parsing source) AND
    the hardcoded fallback in `WhatsNewFeature.swift` must be kept in sync.
    The dynamic parser reads from the markdown file first; the hardcoded array
    is the safety net if parsing fails.

---

*CLAUDE.md — LocTrac v2.0 — Tim Arey — 2026-04-25*
*Update this file with each major release.*
