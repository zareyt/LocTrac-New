# LocTrac Changelog

# Changelog

All notable changes to LocTrac are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
