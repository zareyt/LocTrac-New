# Changelog

All notable changes to this project will be documented in this file.

## [1.2] — 2026-03-30
### Added
- PendingTripItem.swift: Centralized `PendingTripItem` type used to drive trip confirmation sheet presentation.

### Changed
- StartTabView.swift:
  - Added `pendingItem` state and `.onChange(of: store.pendingTrip != nil)` to observe pending trips.
  - Added `.sheet(item: $pendingItem)` to present `TripConfirmationView` from the app’s root, ensuring consistent behavior.
  - Confirmation path updates mode, notes, recalculates CO2, and saves via `store.addTrip(_:)`.

### Removed
- ContentView.swift:
  - Removed duplicate `PendingTripItem` and pending trip sheet logic to prevent double presentation and type conflicts.

### Notes
- This release resolves “Invalid redeclaration” and “ambiguous type lookup” errors related to `PendingTripItem`.
- Trip confirmation now triggers reliably when a new event implies travel between locations.

[1.2]: https://example.com/loctrac/releases/tag/v1.2
