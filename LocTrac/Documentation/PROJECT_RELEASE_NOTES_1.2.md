# LocTrac 1.2 — Trip Confirmation Flow and Stability Improvements

## Overview
This release improves reliability of the trip confirmation flow by presenting the confirmation sheet from the app’s primary root view, StartTabView. It also consolidates shared types to resolve build issues and reduce duplication.

## What’s New
- Reliable Trip Confirmation
  - The TripConfirmationView is now presented from StartTabView so it observes the same DataStore instance used by the app’s root navigation.
  - This ensures the sheet appears consistently when a new event implies travel.

- Centralized PendingTripItem
  - Introduced a new shared type file, PendingTripItem.swift, used by any view that needs to present or pass trip confirmation data.
  - Eliminates “Invalid redeclaration” and “ambiguous type lookup” errors.

## Quality Improvements
- ContentView Cleanup
  - Removed redundant sheet presentation and observers from ContentView.
  - StartTabView is now the single owner of the trip confirmation sheet.

- Code Hygiene
  - Addressed a local “variable never mutated” warning during trip confirmation save by using a temporary updatedTrip copy.

## How It Works
1. Create a new event at a different location than the previous day (> 0.5 miles).
2. DataStore sets pendingTrip when a trip is suggested by TripMigrationUtility.
3. StartTabView observes pendingTrip and presents TripConfirmationView.
4. On Save:
   - Selected transport mode and notes are applied.
   - CO2 recalculated.
   - Trip saved via `store.addTrip(_:)` and persisted to backup.json.
5. On Cancel or Dismiss:
   - pendingTrip is cleared.

## Files Affected
- New
  - PendingTripItem.swift

- Modified
  - StartTabView.swift
  - ContentView.swift

- Referenced
  - DataStore (pendingTrip, addTrip)
  - TripConfirmationView
  - Trip

## Upgrade Notes
- If you previously referenced a local PendingTripItem, remove it and use the shared definition from PendingTripItem.swift.
- Keep trip confirmation presentation logic in StartTabView to avoid duplicate sheet presentations.

## Testing Checklist
- Create events on consecutive days at different locations.
- Verify console logs:
  - “⏳ Trip pending user confirmation…”
  - “UI Root (StartTabView): hasPendingTrip? true”
- Confirm the sheet appears and saving a trip logs:
  - “🛫 addTrip called: …”
- Verify the trip appears in Trips-related UI and persists to backup.json.

## Version
- 1.2 (tag: v1.2)
