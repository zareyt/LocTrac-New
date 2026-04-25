# LocTrac Changelog

# Changelog

All notable changes to LocTrac are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2.0] – 2026-04-25

### Added

- **Authentication System (Phase A)**
  - Optional sign-in with Apple Sign-In and Email/Password
  - Credentials stored securely in Keychain (`com.loctrac.auth`)
  - `AuthenticationService` actor for all auth logic (async/await)
  - `AuthState` ObservableObject injected alongside DataStore
  - Session persistence via Keychain — stays logged in across launches
  - CryptoKit password hashing (SHA256 + salt)
  - Apple credential validation on session restore

- **Sign-In Views (Phase B)**
  - `WelcomeView` — first launch prompt (Skip or Sign In)
  - `SignInView` — Apple Sign-In + email/password login
  - `SignUpView` — account registration
  - `ForgotPasswordView` — password reset flow
  - Non-intrusive banner prompt for existing users with data

- **User Profile & Preferences (Phase C)**
  - New `UserProfile` model with Codable persistence to `profile.json`
  - Separate from `backup.json` — auth data never leaks into exports
  - `ProfileView` — account hub with profile, preferences, security, and notifications
  - `EditProfileView` — edit display name, photo, email
  - `PreferencesView` — travel-specific: default location, distance unit (mi/km), default transport mode

- **Existing User Migration (Phase E)**
  - One-time prompt for users with existing data to create an account
  - Zero data loss — `backup.json` format completely unchanged
  - "Skip for now" always available — never blocks the user
  - Rollback-safe — deleting `profile.json` returns to guest mode

- **Biometric Authentication & App Lock (Phase D)**
  - Face ID / Touch ID via `LocalAuthentication` framework
  - `BiometricLockView` — full-screen lock overlay in `AppEntry.swift`
  - App auto-locks on background when biometrics enabled + authenticated
  - Auto-attempts biometric unlock when returning to foreground
  - scenePhase monitoring in AppEntry for lock/unlock lifecycle
  - `BiometricService` with enable/disable helpers and graceful fallback

- **Two-Factor Authentication (Phase D)**
  - Real TOTP using CryptoKit HMAC-SHA1 (RFC 6238)
  - Data-based secrets (20-byte random), not String-based
  - Verification with +/-1 period clock drift tolerance
  - QR code generation via `otpauth://` URI
  - Backup codes generated on setup, stored in Keychain as JSON
  - `TwoFactorSetupView` — QR code + manual key + backup codes
  - `TwoFactorVerifyView` — 6-digit code entry with backup code fallback
  - 2FA gates email sign-in: `requiresTwoFactor` flag set before `isAuthenticated`

- **Event Type Visual Revamp**
  - Event types now use SF Symbol icons and a consistent color palette across the entire app
  - Stay (red), Host (blue), Vacation (green), Family (purple), Business (brown), Unspecified (gray)
  - Donut chart legend features modern colored capsule badges with icons
  - Colors and icons driven by `EventType.color` and `EventType.sfSymbol` — single source of truth

- **Custom Event Types**
  - New "Manage Event Types" screen in Settings menu for creating, editing, and deleting event types
  - Each type gets a custom name, SF Symbol icon, and color
  - Built-in types can be customized but not deleted
  - Set a default event type in Profile > Preferences to pre-fill new stay forms

- **Smart Add Stay Button**
  - Home screen "Add Stay" button is now context-aware
  - Checks if today has a stay, finds most recent gap in timeline, adapts label and action
  - Three modes: add today's stay, fill missing date range, or edit today's event

- **Copy Stay to Dates**
  - Copy an existing stay's data to a range of other dates
  - Choose which fields to copy (location, type, people, activities, affirmations, notes)
  - Same-location dates merge automatically; different-location conflicts offer skip or replace
  - Adding a multi-day stay auto-opens the copy view for field selection

- **Compact Activity Picker**
  - Activities in event forms now use a compact chip-based design instead of a long toggle list
  - Selected activities appear as small capsule tags; "Add More" button opens a dedicated picker sheet
  - Works consistently across new stay, edit stay, and calendar inline editor forms

- **Event Photos**
  - Add up to 6 photos to any individual stay, separate from location-level images
  - Horizontal gallery in the event form; optionally include when copying stays
  - Photos automatically cleaned up when events or locations are deleted

- **Photo Backup & Import**
  - "Include Photos" toggle in Backup & Import creates a .zip archive with backup.json and all photos
  - Auto-detects .zip vs .json format on import
  - Conflict resolution: skip, replace, or rename existing photos
  - Selective date-range import applies to photos too

- **One Stay Per Day Enforcement**
  - Batch event creation prevents duplicate stays on the same date
  - Existing dates automatically skipped with summary alert showing skipped vs. created counts

- **Bulk Person Assignment Utility**
  - Select a contact and update events for a date range with that person
  - Skips events where the person already exists; one-off utility for cleaning up large data sets

- **Testing Strategy & Test Suite**
  - Created comprehensive `TESTING_MASTER_GUIDE.md` covering unit, data, and regression testing
  - Added test files for DataStore CRUD, ImportExport, TripMigration, EventForm, UTC dates, and more
  - Uses Swift Testing framework (`@Test`, `@Suite`, `#expect`)

### Changed

- **AppEntry.swift** — AuthState creation, environment injection, biometric lock overlay with scenePhase monitoring, stay reminder refresh on launch and foreground
- **StartTabView.swift** — Added Profile & Account as first menu item, menu reorganization, tab name change
- **Info.plist** — Added `NSFaceIDUsageDescription` for Face ID access (required, crashes without it)
- **Menu Reorganization**:
  - "Profile & Account" added as first menu item with divider
  - "Notifications" moved from main menu to ProfileView (under ACCOUNT for signed-in, SETTINGS for signed-out)
  - "Travel History" moved to be directly below "Manage Trips"
- **Tab Rename**: "Locations" tab renamed to "Travel Map" with updated map icon
- **LocationsManagementView**: Removed filter bar (abc A-Z, Most Used, Country) — simplified for typical location counts

### Fixed

- **Data Safety Guaranteed** — Authentication system completely isolated from travel data; deleting account removes only profile data
- **Preferences Sync Fix** — Default location, event type, and transport mode in Profile > Preferences now persist correctly for guest users and sync with global defaults
- **Read-Only Location Fields** — City, state, and country fields in event form now read-only when a named location is selected; editable only in Manage Locations
- **Smarter "Other" Location Display** — Trips and data enhancement views now show actual city name instead of "Other" for events at non-standard locations
- **Date Display Timezone Fix** — Fixed dates appearing off by one day in Enhance Location Data, Travel History details, trip views, and other screens; all date display now uses UTC-pinned formatters
- **Smarter Trip Generation** — Fixed trip refresh generating phantom trips between "Other" location events in the same city; trip engine now compares city names before falling back to distance; fixed coordinate resolution mismatch for "Other" events; trip refresh shows full details for each addition, modification, and deletion
- **Stay Reminder Timezone Fix** — Fixed stay reminder notification incorrectly reporting missing stays due to timezone mismatch; uses UTC calendar to match stored event dates; missing-days count now refreshes on app launch, foreground return, and event change
- **Event Type Graph & Legend Sync** — Fixed Infographic donut chart colors not matching legend; all event type display now driven by single source of truth
- **Edit Stay City/State Population** — Fixed event form not displaying city and state from parent location for named locations
- **Travel History Location Jumping** — Fixed location list reordering when expanding/collapsing entries; now sorted by most event stays with stable ordering
- **Debug View Names** — Fixed Show View Names debug option not displaying in the app UI; comprehensive analysis and implementation of all debug options

### Technical

- **New Files**: 16+ (4 Services, 2 Models, 7 Auth Views in `Services/Auth/`, 4 Profile Views in `Views/Profile/`, plus EventTypeItem, SmartStayAction, test files)
- **Modified Files**: 4 core (AppEntry, StartTabView, Info.plist, LocTrac.entitlements) plus numerous view and model updates
- **Data Layer**: Unchanged — DataStore and backup.json unaffected
- **Auth views location**: `Services/Auth/` (not `Views/Auth/`)
- **Key gotcha**: `.accent` is not a valid ShapeStyle — always use `Color.accentColor`

### Documentation

- Added `DocumentationV2.0_IMPLEMENTATION_PLAN.md` — complete implementation plan
- Added `VERSION_2.0_RELEASE_NOTES.md` — user-facing release notes
- Added `TESTING_MASTER_GUIDE.md` — comprehensive testing strategy
- Updated `CLAUDE.md` — v2.0 architecture, gotchas, menu structure, all phases marked complete
- Updated `CHANGELOG.md` — v2.0 entry with all features, fixes, and improvements
- Updated `WhatsNewFeature.swift` — v2.0 features and bug fixes, removed v1.5 hardcoded features

---

## [1.5] – 2026-04-14

### Added

- **International Location Support**
  - Added `state` field to Location and Event models for provinces/territories
  - Added `countryCode` field for ISO country codes (e.g., "US", "CA", "GB")
  - Added `isGeocoded: Bool` flag to Event to prevent redundant geocoding
  - Enhanced geocoding with forward/reverse lookup capabilities
  - Smart parsing of manual entry formats (e.g., "Denver, CO")
  - Computed properties for clean address display (`effectiveCity`, `effectiveState`, etc.)

- **Location Data Enhancement Tool**
  - New Settings menu item: "Enhance Location Data"
  - Complete UI for validating and enriching location data
  - 4-step priority algorithm for efficient geocoding
  - Rate limiting (45 requests/min) to respect Apple's limits
  - Support for 50+ countries with long-form names
  - Session persistence - resume enhancement sessions later
  - "Retry Errors" button for reprocessing failed items
  - Geocoding efficiency: 50-66% API savings via `isGeocoded` flag

- **Country & State Mappers**
  - `CountryCodeMapper` - ISO codes to full names ("US" → "United States")
  - `CountryNameMapper` - Long names to standard forms ("Scotland" → "United Kingdom")
  - `USStateCodeMapper` - Abbreviations to full names ("CO" → "Colorado")
  - Support for UK regions, Canadian provinces, and international territories

### Fixed

- **Import Location ID Remapping** (**Critical Fix**)
  - Fixed orphaned events created during merge imports
  - Import now properly remaps old location IDs to current store IDs
  - Special handling for "Other" location (always maps to current instance)
  - Graceful fallback: events without valid locations assigned to "Other"
  - Prevents 100% of orphaned events on import
  - "Fix Orphaned Events" tool moved to DEBUG-only (issue resolved at source)

### Technical

- **Files Modified**
  - `TimelineRestoreView.swift` - Added location ID remapping during import
  - `Event.swift` - Added `state`, `countryCode`, `isGeocoded` fields
  - `Location.swift` - Added `state`, `countryCode` fields
  - `LocationDataEnhancementView.swift` - New enhancement UI
  - `LocationDataEnhancer.swift` - New enhancement service
  - `OrphanedEventsAnalyzer.swift` - Enhanced duplicate detection (DEBUG only)
  - `OrphanedEventsAnalyzerView.swift` - Analyzer UI (DEBUG only)

### Documentation

- Added `ORPHANED_EVENTS_IMPORT_FIX.md` - Root cause analysis and solution
- Updated `CLAUDE.md` - v1.5 features and gotchas
- Updated `VERSION_1.5_INTERNATIONAL_LOCATIONS.md` - Complete spec

---

## [1.4] – 2026-04-08

### Added

- **Daily Affirmation Widget** (`LocTracWidget.swift`, `LocTracWidgetBundle.swift`)
  - Home screen widget displaying one affirmation per day
  - Small (square) and Medium (rectangular) widget families
  - Automatic midnight updates using WidgetKit Timeline API
  - Day-of-year rotation algorithm for consistent daily affirmations
  - Color-coded by affirmation category with soft gradient backgrounds
  - Minimal, calming design with category icons and day names
  - Widget Extension target added to project structure

- **Daily Notifications** (`NotificationManager.swift`)
  - Optional daily notification system for affirmations and stay reminders
  - Sends same affirmation as home screen widget
  - Notification time customizable between 12:00 AM - 12:00 PM
  - Stay reminder checks for missing days in past 7 days
  - Badge count shows number of missing stays
  - Calm, supportive notification tone
  - Notification actions: "View in App", "Add Stay", "Dismiss"
  - Settings view for enabling/disabling and time selection
  - Respects system Do Not Disturb settings

- **Custom Location Colors** (`Locations.swift`, `ImportExport.swift`)
  - Full spectrum color picker without theme snapping
  - New `customColorHex: String?` optional field in Location model
  - New `effectiveColor` computed property (custom or theme fallback)
  - Color ↔ Hex conversion helpers using UIColor bridge
  - Custom colors persist in backup.json with backward compatibility
  - All location displays updated to use `effectiveColor`

### Changed

- **LocationsManagementView.swift**
  - ColorPicker now allows full spectrum selection
  - Location editor sheet updated to write custom colors
  - All location circles, map pins, and previews use custom colors

- **LocationFormView.swift**
  - Add/Update location forms support custom color selection
  - Preview fills show custom colors when set

- **LocationFormViewModel.swift** & **LocationSheetEditorModel.swift**
  - Added `customColorHex` published property
  - Added `effectiveColor` computed property for UI binding

- **DataStore.swift**
  - `update(_:Location)` now saves `customColorHex`
  - Import mapping includes `customColorHex` from backup files

- **CLAUDE.md**
  - Updated project structure with Widget Extension target
  - Added widget-specific coding conventions (tip #15)
  - Updated version history to 1.4
  - Added widget documentation references

### Documentation

- **WIDGET_IMPLEMENTATION.md** — Complete widget setup guide with Xcode instructions
- **WIDGET_QUICK_START.md** — Quick setup checklist for developers
- **RELEASE_NOTES_v1.4.md** — User-facing release notes with feature highlights
- **WIDGET_SUMMARY_v1.4.md** — Technical implementation summary and architecture decisions

---

## [1.3] – 2026-04-04

### Added

- **Travel History View** (`TravelHistoryView.swift`)
  - New comprehensive view of all stays organized by country and city
  - Search, filter, and sort capabilities (by Country, City, Most Visited, Recent)
  - Filter toggle between All stays and Other/unnamed locations
  - Accessible from the Home tab (formerly "Other Cities" button) and from the main Options menu
  - Replaces the older "Other Cities" action with a richer, more informative experience

- **Locations Unified View** (`LocationsUnifiedView.swift`)
  - New unified Locations tab that combines map and list into one cohesive experience
  - Created `LocationsMapViewModel` to encapsulate map state
  - Automatically refreshes when `DataStore.locations` changes
  - Replaces previous split map/list approach with a cleaner single-view architecture

- **Infographics View** (`InfographicsView.swift`)
  - New dedicated Infographic tab (tab index 4) with `chart.bar.doc.horizontal` icon
  - Full-year and multi-year infographic data display
  - Integrated `ChartDataContainer` environment object for chart data management

- **First Launch Wizard** (`FirstLaunchWizard.swift`)
  - First-time onboarding wizard shown automatically on fresh install
  - Gated by `store.isFirstLaunch` flag
  - Step-by-step setup experience for new users
  - Wizard state managed in `StartTabView` via `showFirstLaunchWizard`

- **Trip Confirmation Flow** (`TripConfirmationView.swift`, `PendingTripItem.swift`)
  - New `PendingTripItem` model (`Identifiable`) to drive the trip confirmation sheet
  - `TripConfirmationView` allows user to choose travel mode, add notes, and confirm or cancel
  - Automatically recalculates CO₂ on confirm via `recalculateCO2()`
  - Driven by `store.pendingTrip` observable; clears on dismiss or cancel
  - `onChange(of: store.pendingTrip != nil)` watcher in `StartTabView` keeps sheet in sync

- **Locations Management View** (`LocationsManagementView.swift`)
  - Dedicated full-screen location manager accessible from Options menu
  - Search, sort (Alphabetical, Most Used, Country), inline editing
  - Mini map previews, event and photo counts per location
  - Set/clear default location with persistent UserDefaults storage

- **Golfshot CSV Import** (`ImportGolfshotView.swift`)
  - Import support for Golfshot-formatted CSV files
  - Sheet managed by `showImportGolfshot` state (currently not surfaced in menu — available for future enablement)

- **Infographics Cache System** (`DataStore+InfographicsCache.swift`)
  - New `InfographicsCacheManager` actor and `InfographicsChangeTracker` for targeted cache invalidation
  - Cache invalidation hooks on event, activity, and location changes
  - `invalidateCacheForYear(_:)` and `clearInfographicsCache()` helpers
  - Eliminates redundant infographic recalculations on unrelated data changes

- **Smart US State Detection** (`StateDetector.swift`)
  - Async reverse-geocoding state detection using `CLGeocoder`
  - Intelligent caching to minimize API calls
  - Integrated into `InfographicsView` with live state count and state-chip display
  - Progress indicator shown during detection; updates when year filter changes

- **Default Location System** (`DefaultLocationHelper.swift`)
  - Extension on `DataStore` to get/set a persistent default location via UserDefaults
  - Visual DEFAULT badge (⭐) in `LocationsManagementView`
  - Default auto-selected when creating new stays

### Changed

- **Tab Layout Restructured** (`StartTabView.swift`)
  - Tab 0: Home
  - Tab 1: Calendar (was already present; label "Stays")
  - Tab 2: Charts / Stays Overview (`DonutChartView`)
  - Tab 3: Locations — now `LocationsUnifiedView` (replaces old split view)
  - Tab 4: Infographic — new (`InfographicsView`)

- **Home Tab Callbacks Updated**
  - `onShowOtherCities` callback now routes to `TravelHistoryView` instead of old cities list

- **Navigation Titles Updated**
  - Tab 1 title: `"Stays"`
  - Tab 2 title: `"Stays Overview"`
  - Tab 3 title: `"Locations"`
  - Tab 4 title: `"Infographic"`

- **Options Menu Reorganized** (hamburger `ellipsis.circle` menu)
  - Added: **Travel History** (airplane.departure icon)
  - Added: **Manage Locations** (map icon)
  - Existing: Manage Activities & Affirmations, Manage Trips, Backup & Import
  - Commented out (pending clarification): Sync Event Coordinates, Update Event Countries

- **Map Label Appearance**
  - Changed annotation backgrounds to translucent (30% white opacity)
  - Regular location labels: red text; "Other" city labels: blue text
  - Reduced label padding for a cleaner look
  - **Files**: `TravelJourneyView.swift`, `LocationsView.swift`

- **Stay Type Picker Style**
  - Changed from segmented/inline style to standard dropdown / navigation-link picker
  - Shows emoji icons + capitalized type names
  - Now visible and functional in `EventFormView`, `ModernEventFormView`, and `ModernEventsCalendarView`

- **Locations Tab** (`LocationsUnifiedView`)
  - Replaced previous separate map + list view with `LocationsUnifiedView` as a single tab entry point
  - Map view model (`LocationsMapViewModel`) now initialized and refreshed from the unified wrapper

### Fixed

- **Stay Type Missing in Editor**
  - Stay type picker was absent from `ModernEventEditorSheet` — now added and wired to save logic
  - **File**: `ModernEventsCalendarView.swift`

- **Default Location Property Conflict**
  - Removed duplicate `defaultLocationID` computed property that caused "Cannot assign to property: 'self' is immutable" compile errors
  - Centralized in `DefaultLocationHelper.swift`

- **State Count Accuracy** (`InfographicsView.swift`)
  - Fixed overcounting: now groups by unique location IDs to prevent duplicate state tallies
  - Proper US-location validation before counting
  - Handles both named locations and "Other" events correctly

- **Duplicate Code / Brace Mismatch**
  - Removed duplicate closing braces in `InfographicsView.swift` that caused compile errors

- **Debug Prints Removed from Production**
  - Cleaned up excessive debug `print` statements from `InfographicsView.swift` and related files
  - Diagnostic prints retained only in `StartTabView.onAppear` for first-launch debugging

### Deprecated / Removed

- Old "Other Cities" routing in `HomeView` — replaced by `TravelHistoryView`
- Separate map/list tab structure — replaced by `LocationsUnifiedView`
- `showCountryUpdater` / `EventCountryUpdaterView` — commented out, hidden pending use-case review
- `showLocationSync` / `LocationSyncUtilityView` — commented out, hidden pending clarification

---

## [3.0] – 2026-03-29

*(See `VERSION_3.0_RELEASE_NOTES.md` for full detail)*

### Added
- Default location system with persistent storage
- Smart US state detection with reverse geocoding (`StateDetector.swift`)
- Enhanced `LocationsManagementView` with search, sort, and inline editing
- Translucent map labels for better map readability

### Fixed
- Default location property conflicts causing compile errors
- Missing stay type picker in `ModernEventEditorSheet`
- Incorrect state counting logic
- Duplicate code and brace mismatches in `InfographicsView.swift`

---

## [Prior Versions]

Refer to `VERSION_3.0_RELEASE_NOTES.md` and `README_LICENSE_SUMMARY.md` for history
prior to version 3.0.

---

*Generated: 2026-04-04 | Author: Tim Arey*
