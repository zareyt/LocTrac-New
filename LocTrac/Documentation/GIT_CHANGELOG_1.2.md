# Version 1.2 — Centralize Trip Confirmation flow and deduplicate PendingTripItem

## Summary
- Centralized the TripConfirmationView presentation in StartTabView, ensuring it observes the same DataStore instance used by the app’s root.
- Deduplicated PendingTripItem by moving it into a shared file to eliminate type conflicts.
- Removed pendingTrip observation/sheet from ContentView to avoid double presentation and to fix “Invalid redeclaration” / “ambiguous type” errors.
- Minor code hygiene improvements.

## Changes

### Added
- PendingTripItem.swift
  - struct PendingTripItem: Identifiable { id, trip, fromEvent, toEvent }

### Modified
- StartTabView.swift
  - Added `@State private var pendingItem: PendingTripItem?`
  - Added `.onChange(of: store.pendingTrip != nil)` to map the store’s pendingTrip tuple into a sheet-driving PendingTripItem
  - Added `.sheet(item: $pendingItem)` presenting TripConfirmationView
  - Confirm path updates mode/notes, recalculates CO2, and calls `store.addTrip(_:)`
  - Cancel path clears pending state
- ContentView.swift
  - Removed local PendingTripItem and the pendingTrip observer/sheet logic
  - Now a simple placeholder view

### Unchanged (but used)
- DataStore.pendingTrip and addTrip(_:)
- TripConfirmationView
- Trip

## Rationale
- StartTabView is the effective UI root (presented by AppEntry). Hosting the sheet there ensures consistent presentation and state observation.
- Centralizing PendingTripItem avoids duplicate struct declarations and resolves build errors.

## Verification
1. Create two events on consecutive days at different locations (> 0.5 mi apart).
2. Console should show:
   - “⏳ Trip pending user confirmation…”
   - “UI Root (StartTabView): hasPendingTrip? true”
3. TripConfirmationView appears. On Save:
   - Console shows “🛫 addTrip called: …”
   - Trip persists to backup.json and is visible in UI.

## Suggested Git Commands
- `git add PendingTripItem.swift StartTabView.swift ContentView.swift`
- `git commit -m "Version 1.2: Centralize trip confirmation in StartTabView, deduplicate PendingTripItem, clean ContentView"`
- `git tag -a v1.2 -m "LocTrac 1.2"`
- `git push origin main --tags`
