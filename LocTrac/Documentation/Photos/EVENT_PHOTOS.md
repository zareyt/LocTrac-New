# Event Photos - Implementation Guide

**Version**: 2.0
**Date**: 2026-04-24

---

## Overview

LocTrac v2.0 adds photo support to individual stays/events, complementing the existing location-level photos. Users can attach up to 6 photos per event, separate from location photos.

## Architecture

### Two-Level Photo System

| Level | Scope | Use Case |
|-------|-------|----------|
| **Location Photos** | Shared across all events at that location | General place photos (building, scenery) |
| **Event Photos** | Specific to a single stay/date | Moments, people, activities on that day |

### Storage

- Photos are stored as JPEG files in the app's Documents directory
- Each photo gets a UUID-based filename (e.g., `A1B2C3D4-E5F6.jpg`)
- `Event.imageIDs: [String]` stores the filenames (not full paths)
- `ImageStore` enum handles save/load/delete operations
- Photos are copies, not references to the Photos library

### Data Flow

```
PhotosPicker (SwiftUI)
    -> loadTransferable(type: Data.self)
    -> UIImage(data:)
    -> ImageStore.save(image:) -> filename
    -> viewModel.imageIDs.append(filename)
    -> Event saved via store.update() or store.add()
    -> storeData() persists filename in backup.json
```

## Files Modified

### Model Layer
- **Event.swift** - Added `var imageIDs: [String] = []` field + parameter to both inits
- **EventFormViewModel.swift** - Added `@Published var imageIDs: [String] = []`, loaded from event in init
- **DataStore.swift** - `update()` copies imageIDs, `delete()` cleans up image files for both events and locations

### Import/Export
- **ImportExport.swift** - `Import.Event.imageIDs: [String]?` (optional for backward compat), `Export.EventData.imageIDs: [String]` with tolerant decoder defaulting to `[]`
- **TimelineRestoreView.swift** - Passes `imageIDs` when constructing events from imports

### UI
- **ModernEventFormView.swift** - PhotosPicker + horizontal thumbnail gallery with delete buttons, max 6 images
- **CopyEventView.swift** - "Photos" as a copyable field option (default off), supported in both `buildEvent()` and `buildMergedEvent()`
- **ModernEventsCalendarView.swift** - `buildCurrentEventForCopy()` passes imageIDs

## Backward Compatibility

- `Event.imageIDs` defaults to `[]` - existing events work without changes
- `Import.Event.imageIDs` is optional (`[String]?`) - old backups decode as `nil`, mapped to `[]`
- `Export.EventData` has a custom decoder that defaults `imageIDs` to `[]` for old exports
- No migration needed - empty array is the correct default

## Image Lifecycle

### Adding Photos
1. User taps "Add Photos" in event form
2. PhotosPicker shows (max selection = 6 - current count)
3. Each selected photo is saved via `ImageStore.save()`
4. Filename appended to `viewModel.imageIDs`
5. On form save, imageIDs are included in the Event constructor

### Deleting Photos
1. User taps X on a thumbnail in the event form
2. Confirmation dialog shown
3. `ImageStore.delete(filename:)` removes file from disk
4. Filename removed from `viewModel.imageIDs`

### Event Deletion Cleanup
- `DataStore.delete(_ event:)` iterates `event.imageIDs` and calls `ImageStore.delete()` for each
- `DataStore.delete(_ location:)` does the same for `location.imageIDs`
- Prevents orphaned image files on disk

### Copy Stay
- Photos are a selectable field in CopyEventView (default: off)
- When selected, `sourceEvent.imageIDs` are copied to new events
- Note: This shares the same image files - deleting the copy's reference doesn't delete the file if the original still references it

## Batch Event Creation

When creating a multi-day stay:
- Photos are attached to the **first day only** (`n == 0`)
- Subsequent days get empty imageIDs
- This prevents unnecessary file duplication

## Limits

- Maximum 6 photos per event (enforced in UI via `maxSelectionCount`)
- Maximum 6 photos per location (existing limit)
- Photos stored as JPEG at 0.9 quality (~100KB-1MB each)
- No automatic compression or resizing beyond JPEG quality

## Debug Logging

All photo operations log via `DebugConfig.shared.log(.dataStore, ...)`:
- `[EventForm] Saved photo: <filename>` - Photo added
- `[EventForm] Deleted photo: <filename>` - Photo removed from form
- `[Delete Event] Cleaned up N image(s)` - Cleanup on event deletion
- `[Delete Location] Cleaned up N image(s)` - Cleanup on location deletion

## Future: Export/Import with Images

Phase 4 (planned) will add:
- Toggle in BackupExportView to include photos in exports
- `.zip` archive format containing `backup.json` + images folder
- Import detects `.json` vs `.zip` format automatically
- Image conflict resolution (rename/skip/replace)
- Size estimate before export
- Selective image import based on date range

## Testing

See `Tests/EventImageTests.swift` for:
- Model initialization with/without imageIDs
- ViewModel loading from events
- Codable backward compatibility (old JSON without imageIDs)
- Export/import roundtrip preservation
