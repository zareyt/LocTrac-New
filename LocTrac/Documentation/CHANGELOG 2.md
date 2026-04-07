# LocTrac — Changelog

All notable changes to LocTrac are documented here, newest first.

---

## Version 1.3
*Released 2025*

### ✨ New Features
- **Affirmations activity** — add personal affirmations to any stay. Browse by category (Relationships, Success, Mindfulness, etc.), mark favourites, and attach one or more to an event.
- **Manage Affirmations** moved into Manage Activities & Affirmations for a unified experience.
- **Auto-create "Other" location** — the required Other location is now created automatically during the first-launch wizard.

### 🔧 Improvements
- **Smarter Imports** — the import flow now shows a timeline slider so you can restore only the date range you need. You can also choose exactly which data types to import: People, Activities, Trips, Events, or all of them.
- **Backup & Import rename** — "Backup & Export" is now "Backup & Import" with clearer labels throughout.

### 🐛 Bug Fixes
- Calendar no longer requires a month change to refresh when switching between People, Activities, and Locations filters.

---

## Version 1.2
*Released 2025*

### ✨ New Features
- **Travel History view** — browse every country, city and stay with ABC / Most-Used / Country sort modes, mirrors the Manage Locations experience.
- **Geo-coded country field** — events now automatically derive their country from the city name (e.g. "Caen, France", "Castle Rock, CO") using reverse geocoding.

### 🐛 Bug Fixes
- Trip confirmation sheet now appears reliably from the correct `DataStore` instance.
- Removed duplicate `PendingTripItem` declaration that caused build errors.

---

## Version 1.1
*Released 2025*

### ✨ New Features
- **Manage Locations** — full CRUD for locations with search, sort, map previews, and per-location stats. Replaces the old "Add Location" menu item.
- **Default Location** system — set any location as the default for new stays.
- **Manage Trips** — dedicated view to review, edit and refresh trips. Default Location option is now integrated here instead of the standalone menu item.

---

## Version 1.0
*Released 2024*

- Initial public release of LocTrac (new repository).
- All documentation moved to the Documents folder.

---

## Version 0.x
*Pre-release development builds*

- 0.4.2 — Unified `InfographicsCacheManager` and `InfographicsCache`.
- 0.4.1 — Golfshot CSV import utility added under Utilities.
- 0.4.0 — Home screen dashboard introduced.
- 0.3.0 — Infographics trip counts, environment impact section, and Calendar revamp.
