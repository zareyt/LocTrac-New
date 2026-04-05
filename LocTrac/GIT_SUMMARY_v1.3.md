# LocTrac – Version 1.3 Git Summary

**Tag**: `v1.3`
**Date**: 2026-04-04
**Author**: Tim Arey
**Branch**: `main`

---

## Overview

Version 1.3 is a substantial feature and architecture release that restructures the tab
experience, introduces a comprehensive travel history view, establishes a unified
locations tab, adds a first-launch onboarding wizard, and delivers a complete trip
confirmation workflow with CO₂ tracking. The release also includes a new infographics
caching system, smart US state detection, default location management, and a reorganized
global Options menu.

---

## New Files

| File | Purpose |
|---|---|
| `TravelHistoryView.swift` | Full travel history organized by country/city with search & sort |
| `LocationsUnifiedView.swift` | Single-entry-point Locations tab wrapping map + map VM |
| `FirstLaunchWizard.swift` | Step-by-step onboarding for new installs |
| `PendingTripItem.swift` | `Identifiable` model driving the trip confirmation sheet |
| `TripConfirmationView.swift` | Sheet for selecting travel mode, adding notes, confirming trips |
| `InfographicsView.swift` | Dedicated infographics tab with year filtering |
| `DataStore+InfographicsCache.swift` | Cache invalidation hooks and helpers on DataStore |
| `DefaultLocationHelper.swift` | DataStore extension for persistent default location |
| `StateDetector.swift` | Async CLGeocoder-backed US state detection with caching |
| `ImportGolfshotView.swift` | Golfshot CSV import sheet (prepared, not yet in menu) |
| `CHANGELOG.md` | This project changelog (new) |
| `GIT_SUMMARY_v1.3.md` | This document (new) |
| `UPDATE_NOTES_v1.3.md` | User-facing update notes (new) |

---

## Modified Files

| File | Key Changes |
|---|---|
| `StartTabView.swift` | Full tab restructure (5 tabs), new state variables, Options menu reorganization, trip confirmation sheet, first launch wizard, Travel History routing |
| `HomeView.swift` | `onShowOtherCities` callback now routes to `TravelHistoryView` |
| `LocationsManagementView.swift` | Default location UI (⭐ badge), set/clear default |
| `InfographicsView.swift` | State detection integration, year filter, debug cleanup, brace fixes |
| `EventFormView.swift` | Stay type picker style update |
| `ModernEventFormView.swift` | Stay type picker style update |
| `ModernEventsCalendarView.swift` | Stay type added to `ModernEventEditorSheet`, wired to save |
| `TravelJourneyView.swift` | Translucent map annotation labels (30% white, red/blue text) |
| `LocationsView.swift` | Translucent map annotation labels (30% white, red/blue text) |
| `DataStore.swift` | `pendingTrip` observable property; `addTrip()` method |

---

## Key Architectural Changes

### Tab Structure (StartTabView)

```
Before (3.0)          After (1.3)
─────────────         ────────────────────
Home (0)              Home (0)
Calendar (1)          Calendar / Stays (1)
Charts (2)            Charts / Stays Overview (2)
Locations (3)         Locations – LocationsUnifiedView (3)
                      Infographic – InfographicsView (4)
```

### Trip Confirmation Pipeline

```
DataStore.pendingTrip set
    → onChange in StartTabView detects change
    → Creates PendingTripItem (Identifiable)
    → Sheet: TripConfirmationView
    → User selects mode + notes → confirm
    → recalculateCO2() → store.addTrip()
    → pendingTrip cleared, sheet dismissed
```

### Infographics Cache Invalidation

```
Event / Activity / Location mutated
    → DataStore hook fires
    → InfographicsChangeTracker records affected years + sections
    → InfographicsCacheManager (actor) invalidates only affected cache entries
    → InfographicsView re-queries only changed data
```

---

## Commit Message (Use This Verbatim in Xcode)

```
v1.3 – Travel History, Unified Locations, Trip Confirmation & Infographics

New Features:
- TravelHistoryView: comprehensive stay history with country/city grouping,
  search, and sort (Country, City, Most Visited, Recent)
- LocationsUnifiedView: single-tab locations experience with LocationsMapViewModel
- FirstLaunchWizard: step-by-step onboarding on fresh install
- Trip confirmation flow: PendingTripItem + TripConfirmationView with mode
  selection, notes, and CO₂ recalculation
- InfographicsView: dedicated tab (index 4) with ChartDataContainer integration
- DataStore+InfographicsCache: targeted cache invalidation on data mutations
- DefaultLocationHelper: persistent default location via UserDefaults
- StateDetector: async CLGeocoder US state detection with caching
- ImportGolfshotView: Golfshot CSV import (prepared, not yet in menu)

Architecture:
- Tab layout expanded from 4 to 5 tabs
- Options menu reorganized: added Travel History, Manage Locations
- Home onShowOtherCities now routes to TravelHistoryView
- Sync Event Coordinates and Update Event Countries hidden pending review

UI/UX:
- Translucent map annotation labels (30% white, red/blue text)
- Stay type picker converted to navigation/dropdown style across all forms
- Navigation titles updated for all 5 tabs

Bug Fixes:
- Stay type missing from ModernEventEditorSheet — now added and saved
- Default location property conflict causing compile errors — centralized
- State count overcounting fixed — groups by unique location IDs
- Duplicate closing braces in InfographicsView — removed
- Debug print statements removed from production InfographicsView code

Documentation:
- CHANGELOG.md (new)
- GIT_SUMMARY_v1.3.md (new)
- UPDATE_NOTES_v1.3.md (new)
```

---

## Files to Stage in Xcode Source Control

Check all of the following in the Xcode **Commit** window:

**New (A):**
- `TravelHistoryView.swift`
- `LocationsUnifiedView.swift`
- `FirstLaunchWizard.swift`
- `PendingTripItem.swift`
- `TripConfirmationView.swift`
- `InfographicsView.swift`
- `DataStore+InfographicsCache.swift`
- `DefaultLocationHelper.swift`
- `StateDetector.swift`
- `ImportGolfshotView.swift`
- `CHANGELOG.md`
- `GIT_SUMMARY_v1.3.md`
- `UPDATE_NOTES_v1.3.md`

**Modified (M):**
- `StartTabView.swift`
- `HomeView.swift`
- `LocationsManagementView.swift`
- `InfographicsView.swift`
- `EventFormView.swift`
- `ModernEventFormView.swift`
- `ModernEventsCalendarView.swift`
- `TravelJourneyView.swift`
- `LocationsView.swift`
- `DataStore.swift`

---

## Pre-Commit Checklist

- [ ] App builds with zero errors and zero warnings
- [ ] TravelHistoryView opens from Home and from Options menu
- [ ] LocationsUnifiedView renders map, refreshes on data change
- [ ] First launch wizard appears on clean install (delete app → re-run)
- [ ] Trip confirmation sheet opens, saves mode/notes, clears `pendingTrip`
- [ ] Infographics tab (tab 4) loads and year filter works
- [ ] State detection shows correct US state count
- [ ] Default location persists across app restarts
- [ ] Stay type saves correctly in all three form views
- [ ] Map labels are translucent on both TravelJourney and Locations maps
- [ ] All 5 tabs display correct navigation title
- [ ] Options menu shows Travel History and Manage Locations
- [ ] No debug-only print statements in production code paths

---

*Generated: 2026-04-04*
