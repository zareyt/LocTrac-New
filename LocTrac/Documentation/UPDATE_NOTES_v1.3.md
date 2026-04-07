# LocTrac – Version 1.3 Update Notes

**Release Date**: April 4, 2026
**Version**: 1.3
**Author**: Tim Arey

---

## What's New in Version 1.3

### ✈️ Travel History

A brand new **Travel History** view gives you a rich, searchable breakdown of every
place you've ever stayed, organized by country and city. Sort by country, city name,
most visited, or most recent — and filter to just your named locations or all stays.
Access it from the Home screen or the Options (⋯) menu.

---

### 🗺️ Unified Locations Tab

The Locations tab has been streamlined into a single, unified experience. The map and
location list now live together in one cohesive view (`LocationsUnifiedView`), with the
map automatically refreshing whenever you add, edit, or delete a location.

---

### 🧭 First Launch Wizard

New users are greeted with a step-by-step onboarding wizard on first install. The wizard
walks you through the app's core concepts before you dive in, and only appears once.

---

### 🚗 Trip Confirmation Flow

After LocTrac detects a potential trip between two stays, a **Trip Confirmation** sheet
now appears automatically. Choose your travel mode (car, flight, train, etc.), add
optional notes, and confirm — LocTrac will calculate the CO₂ impact and save the trip.
Dismiss the sheet any time to skip without saving.

---

### 📊 Infographics Tab

A dedicated **Infographic** tab (the 5th tab) now surfaces your travel data in
chart form. Filter by year to explore patterns across your entire travel history.
The new infographics cache system means data loads faster after the first view — only
the data that actually changed gets recalculated.

---

### 📍 Default Location

You can now designate one location as your **default** — it will be automatically
pre-selected whenever you create a new stay. Look for the ⭐ DEFAULT badge in
Manage Locations to set or change it.

---

### 🇺🇸 US State Detection

LocTrac now automatically identifies which US states you've visited using reverse
geocoding. Your infographics show a live state count and a chip for each state, and
the detection updates intelligently when you change the year filter.

---

### 🏌️ Golfshot Import (Coming Soon)

Infrastructure for importing Golfshot-formatted CSV files is complete and will be
surfaced in a future update.

---

## Improvements

| Area | Change |
|---|---|
| Options Menu | Added Travel History and Manage Locations entries |
| Stay Type Picker | Switched to dropdown/navigation style with emoji icons across all forms |
| Map Labels | Translucent backgrounds (30% white) with color-coded text (red = location, blue = Other) |
| Navigation Titles | All 5 tabs now have clear, accurate titles |
| Home Callback | "Other Cities" now opens the full Travel History view |

---

## Bug Fixes

| Issue | Resolution |
|---|---|
| Stay type missing in event editor | Stay type picker added and wired to save in all forms |
| Compile error: duplicate `defaultLocationID` property | Centralized in `DefaultLocationHelper.swift` |
| US state count overcounting | Now groups by unique location IDs |
| Crash from duplicate closing braces | Fixed in `InfographicsView.swift` |
| Debug prints leaking in production | Removed from all production code paths |

---

## Tab Layout Reference

| Tab | Label | View |
|---|---|---|
| 0 | Home | `HomeView` |
| 1 | Calendar | `ModernEventsCalendarView` (title: Stays) |
| 2 | Charts | `DonutChartView` (title: Stays Overview) |
| 3 | Locations | `LocationsUnifiedView` |
| 4 | Infographic | `InfographicsView` |

---

## Developer Notes

- `PendingTripItem` is `Identifiable` and drives the trip confirmation sheet via
  `sheet(item:)` — this avoids the boolean `isPresented` / item desync bug.
- `DataStore+InfographicsCache.swift` uses a Swift actor (`InfographicsCacheManager`)
  for thread-safe cache access.
- `StateDetector.swift` caches geocoding results to avoid hammering `CLGeocoder`.
- `LocationsUnifiedView` uses `onChange(of: store.locations)` to trigger
  `mapVM.refreshLocations()` without requiring the map to be rebuilt.
- `StartTabView` uses `onChange(of: store.pendingTrip != nil)` (equatable Bool) so the
  sheet only fires when the presence of a pending trip actually changes.

---

## Next Steps / Future Backlog

- [ ] Re-evaluate **Sync Event Coordinates** use case and re-enable if appropriate
- [ ] Re-evaluate **Update Event Countries** and re-enable if appropriate
- [ ] Surface **Golfshot CSV Import** in the Options menu
- [ ] Add unit tests for `StateDetector`, `InfographicsCacheManager`, and `DataStore`
- [ ] Accessibility audit across all new views
- [ ] iCloud sync exploration
- [ ] watchOS companion app

---

*LocTrac v1.3 — April 4, 2026 — Tim Arey*
