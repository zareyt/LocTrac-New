# LocTrac 4.1 – Release Notes

Date: [YYYY-MM-DD]
Author: Tim Arey

## Highlights

- New Home tab as the app’s default landing page
- Backup & Import improvements: list refresh and clearer naming
- Restore preview compatibility with older backups
- Golfshot CSV import: duplicate handling and preview flow
- “Other” cities experience improved and shareable
- General UI/UX polish and stability fixes

---

## New: Home Tab

Added a new “Home” tab (first tab, default on launch) that provides a friendly overview and quick actions.

File:
- HomeView.swift (new)

Features:
- Quick Actions
  - Add Event: jumps to Calendar tab
  - Add Location: opens Location form (LocationFormType.new)
- Today & Upcoming
  - Shows today’s events and the next upcoming event
- Recent Activity
  - Last 5 events with key info (location, time, activities/people counts)
- Top Activities (Rolling 12 Months)
  - Counts activity usage across events within the last 12 months
- Top Locations (Overall)
  - Most visited locations by event count
- Other Cities
  - Preview of unique cities under the “Other” location
  - Button to open the full “Other Cities & Dates” view

Integration:
- StartTabView.swift updated to include Home as the first tab and start selection at index 0
- Home actions are wired to:
  - Switch to Calendar tab
  - Present Add Location sheet
  - Present OtherCitiesListView (if “Other” exists)
  - Open Locations/Infographics tabs

---

## Backup & Import Enhancements

Renamed UI text from “Backup & Export” to “Backup & Import” and ensured newly created backups appear immediately in the Exported Backups list.

Files:
- ViewsBackupExportView.swift (updated)
- StartTabView.swift (menu label updated)

Changes:
- Navigation title: “Backup & Import”
- Export Options section header: “Backup & Import”
- Create Fresh Backup:
  - Saves to Documents/backup.json
  - Immediately creates a timestamped copy in the temporary directory (LocTrac_Backup_YYYY-MM-DD_HHmmss.json)
  - Refreshes the Exported Backups list (count updates instantly)
- Added “Select Backup from Files” button to launch restore flow without a preselected file (uses existing RestoreBackupView flow)

Note:
- Exported Backups lists timestamped copies in the temporary directory for easy sharing/versioning.

---

## Restore Preview Compatibility

Older backups may not contain newer keys (activities/trips). The restore preview now tolerates missing keys and decodes successfully.

File:
- ImportExport.swift (updated)

Changes:
- Export now implements a custom Decodable init:
  - locations, events: required
  - activities, trips: optional; default to [] if missing
- This fixes “Failed to decode backup… data couldn’t be read because it is missing” for legacy files.

---

## Golfshot CSV Import and Duplicates

File:
- ImportGolfshotView.swift (updated)

Changes:
- Duplicate detection and preview:
  - Groups .stay events by date
  - Sorts to keep the most “complete” event and remove imported duplicates
  - Preview UI to swap which event to keep
- Import preview flow:
  - Displays per-date action: update, remove duplicates, or skip
  - Ensures “Golfing” activity exists and adds it where appropriate
- Minor cleanup:
  - Removed unused local variables in duplicate scan
  - Improved error/result messaging

---

## “Other” Cities Experience

File:
- OtherCitiesListView.swift (new or updated)

Changes:
- Clean grouped view of cities and dates for the “Other” location
- GMT-pinned date formatting for stable cross-timezone display
- Full-content share support:
  - Renders the entire list offscreen and shares a snapshot via UIActivityViewController

Integration:
- StartTabView presents OtherCitiesListView as a sheet from menu and from Home tab’s section.

---

## Share Sheet Deduplication

Avoided duplicate type declarations of ShareSheet.

Changes:
- Retained a single ShareSheet (UIViewControllerRepresentable) implementation
- Removed the duplicate definition from BackupExportView to prevent “Invalid redeclaration” errors
- All usages point to the single implementation (also used by RestoreBackupView)

---

## General UI/UX and Stability

- StartTabView.swift:
  - Added Home tab (index 0) and made it the initial selection
  - Renamed menu item to “Backup & Import”
  - Preserved first launch wizard presentation
  - Kept existing sheets for Activities, Trips, Default Location, Golfshot Import, Backup & Import, Other Cities
- DonutChartView.swift:
  - No functional change in this release; remains integrated with DataStore and ChartDataContainer

---

## Developer Notes

- Rolling 12-month logic:
  - HomeView computes the window as Date() minus 12 months through now
  - Counts activityIDs across events in that window and maps IDs to names via store.activities
- Exported backups list:
  - The list is built from the temporary directory only
  - “Create Fresh Backup” now writes a timestamped copy to temp to immediately reflect in the list and increment the count
- Legacy backup decoding:
  - Export decoding now handles missing activities/trips keys gracefully

---

## Known Limitations

- Add Event quick action currently routes to the Calendar tab rather than opening a dedicated event editor sheet
  - Future enhancement: wire a direct event editor if/when exposed as a sheet
- Exported Backups are stored in temporary storage
  - iOS may clean up temp files; users should share/save important backups to Files or cloud storage

---

## Migration / Backward Compatibility

- No breaking changes to data models used by the app
- Restore preview now supports older backups missing newer keys
- UI label changes only (no API changes)

---

## Testing Checklist

- Home tab
  - Quick actions work (Calendar switch, Add Location sheet)
  - Today/Upcoming list shows correct events
  - Recent Activity shows last 5 events
  - Top Activities (rolling 12 months) displays expected counts
  - Top Locations list correct
  - “Other Cities” button opens full list when “Other” exists
- Backup & Import
  - Create Fresh Backup creates backup.json and a timestamped copy
  - Exported Backups count updates immediately
  - Select Backup from Files launches restore flow
  - “Preview & Restore” from a listed file works
- Restore Preview
  - Older backups without activities/trips preview successfully
- Golfshot Import
  - Duplicate scan groups by date and preview works
  - Swap keep/delete in preview works
  - Import adds “Golfing” activity where needed and removes duplicates
- ShareSheet
  - No redeclaration compiler errors

---

## Files Added / Modified

Added:
- HomeView.swift
- OtherCitiesListView.swift (if newly introduced in repo)

Modified:
- StartTabView.swift
- ViewsBackupExportView.swift
- ImportExport.swift
- ImportGolfshotView.swift

Potentially Removed:
- Duplicate ShareSheet implementation in BackupExportView.swift

---

## Future Enhancements (Suggestions)

- Direct “Add Event” sheet from Home quick actions
- Year filter or segmented control in Home’s Top Activities
- Persist Exported Backups in a dedicated folder (e.g., Documents/Backups) rather than temporary directory
- Centralize ShareSheet into its own file (ShareSheet.swift) for clarity
- Add haptics and subtle animations to Home interactions
