# Photo Backup & Import

## Overview

v2.0 adds the ability to export and import photos alongside travel data. When "Include Photos" is enabled during backup, the app creates a standard `.zip` archive containing `backup.json` plus an `images/` folder with all referenced location and event photos.

## Architecture

### BackupArchiveService (`Services/BackupArchiveService.swift`)

Central service for zip archive operations. Implemented as an `enum` with static methods (no state).

**Key Methods:**
- `createArchive(jsonData:imageFilenames:outputURL:)` - Creates .zip with backup.json + images
- `extractArchive(at:)` - Extracts .zip, returns (jsonData, imageEntries dictionary)
- `isZipArchive(at:)` - Detects .zip by extension or magic bytes (PK\x03\x04)
- `allReferencedImageFilenames(locations:events:)` - Collects all image filenames
- `imageFilenames(for:locations:)` - Collects filenames for specific events + their locations
- `estimateImageSize(imageFilenames:)` - Total size in bytes of image files
- `importImages(_:resolution:)` - Imports images with conflict resolution, returns filename map
- `detectConflicts(imageFilenames:)` - Lists filenames that already exist on disk

### ZIP Format

Uses a minimal custom ZIP implementation (stored method, no compression):
- `ZipWriter` - Creates standard ZIP files with local file headers + central directory
- `ZipReader` - Reads ZIP files by parsing EOCD -> central directory -> local file headers
- CRC-32 computed via `zlib.crc32()` (ships with iOS)
- No third-party dependencies

Files are stored uncompressed (method 0) since images are already JPEG-compressed. This keeps the implementation simple while producing standard .zip files readable by any zip tool.

### Archive Structure

```
LocTrac_Backup_2026-04-24_143000.zip
  backup.json            <- Standard LocTrac backup data
  images/
    UUID1.jpg            <- Location and event photos
    UUID2.jpg
    ...
```

## Export Flow

1. User toggles "Include Photos" in BackupExportView
2. Photo count and size estimate displayed immediately
3. On "Create Backup with Photos":
   - `store.storeData()` saves current data
   - `allReferencedImageFilenames()` collects all image filenames from locations + events
   - `createArchive()` builds .zip with backup.json + images
   - File saved as `LocTrac_Backup_YYYY-MM-DD_HHmmss.zip` in temp directory
4. .zip files appear in Exported Backups list with photo icon indicator

## Import Flow

1. User selects file via `.fileImporter` (accepts .json, .zip, and archive types)
2. `loadBackupFile()` detects format:
   - `.zip` -> `BackupArchiveService.extractArchive()` -> stores image entries in state
   - `.json` -> Direct JSON decode (existing behavior)
3. For .zip archives, "Photo Import" section appears with:
   - Toggle to include/exclude photos
   - Conflict count display
   - Conflict resolution picker (skip/replace/rename)
4. During `performImport()`:
   - Images filtered to only those referenced by events in selected date range
   - `importImages()` writes files to Documents with chosen resolution
   - If "rename" resolution used, image references in events/locations are remapped

## Conflict Resolution

When importing images that already exist on disk:

| Resolution | Behavior |
|-----------|----------|
| **Skip** | Keep existing file, don't import. References unchanged. |
| **Replace** | Overwrite existing file with archive version. References unchanged. |
| **Rename** | Import with new UUID filename. All event/location references remapped to new filename. |

## Selective Import

Image import respects the date range filter:
- Only images referenced by events within the selected date range are imported
- Location-level images are imported if any event in the range references that location
- Images not referenced by any event in the range are skipped

## Testing

See `Tests/BackupArchiveTests.swift` for unit tests covering:
- Zip roundtrip (create + extract)
- Empty archives (no images)
- Invalid archive handling
- Archive detection (extension + magic bytes)
- Size estimation
- Conflict detection
- All three conflict resolutions (skip/replace/rename)
- Referenced filename collection

## Files Modified

- `Services/BackupArchiveService.swift` - NEW: Zip archive service
- `Views/BackupExportView.swift` - Include Photos toggle, size estimate, .zip creation
- `Views/TimelineRestoreView.swift` - .zip detection, image import section, conflict resolution
- `Views/WhatsNewFeature.swift` - Photo Backup & Import entry
- `VERSION_2.0_RELEASE_NOTES.md` - Release notes entry
