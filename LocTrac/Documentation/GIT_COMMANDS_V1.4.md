# Git Commands for v1.4 Release

## Commit Message
```
v1.4 – Infographics PDF/Screenshot Export

New Features:
- Infographics PDF export with real Apple Maps tiles
- High-resolution screenshot sharing (3x scale)
- Journey map visualization in PDF exports
- Share button with menu (PDF and Screenshot options)
- UIActivityViewController integration for system-wide sharing

Architecture:
- NotificationCenter communication pattern for TabView toolbars
- MKMapSnapshotter for capturing actual map tiles asynchronously
- UIGraphicsImageRenderer for drawing routes and markers on maps
- Two-phase async PDF generation (snapshot → render)
- Unified presentShareSheet() handler for both export types

Bug Fixes:
- Fixed share button not working (missing .onReceive() listeners)
- Fixed toolbar not appearing (removed NavigationStack from TabView child)
- Fixed journey map not rendering in PDFs (implemented MKMapSnapshotter)

Documentation:
- Updated CLAUDE.md to v1.4
- Added MapKit PDF export gotchas and patterns
- Added async PDF generation workflow tips
- Created VERSION_1.4_RELEASE_NOTES.md
- Created JOURNEY_MAP_VISUAL_GRAPHIC.md
- Created SHARE_BUTTON_ACTUAL_FIX.md
- Created INFOGRAPHICS_SHARE_FIX.md
```

## Git Commands

```bash
# Stage all modified and new files
git add InfographicsView.swift
git add StartTabView.swift
git add CLAUDE.md
git add VERSION_1.4_RELEASE_NOTES.md
git add JOURNEY_MAP_VISUAL_GRAPHIC.md
git add SHARE_BUTTON_ACTUAL_FIX.md
git add INFOGRAPHICS_SHARE_FIX.md
git add GIT_COMMANDS_V1.4.md

# Or stage everything at once
git add .

# Create commit with the message above
git commit -m "v1.4 – Infographics PDF/Screenshot Export

New Features:
- Infographics PDF export with real Apple Maps tiles
- High-resolution screenshot sharing (3x scale)
- Journey map visualization in PDF exports
- Share button with menu (PDF and Screenshot options)
- UIActivityViewController integration for system-wide sharing

Architecture:
- NotificationCenter communication pattern for TabView toolbars
- MKMapSnapshotter for capturing actual map tiles asynchronously
- UIGraphicsImageRenderer for drawing routes and markers on maps
- Two-phase async PDF generation (snapshot → render)
- Unified presentShareSheet() handler for both export types

Bug Fixes:
- Fixed share button not working (missing .onReceive() listeners)
- Fixed toolbar not appearing (removed NavigationStack from TabView child)
- Fixed journey map not rendering in PDFs (implemented MKMapSnapshotter)

Documentation:
- Updated CLAUDE.md to v1.4
- Added MapKit PDF export gotchas and patterns
- Added async PDF generation workflow tips
- Created VERSION_1.4_RELEASE_NOTES.md
- Created JOURNEY_MAP_VISUAL_GRAPHIC.md
- Created SHARE_BUTTON_ACTUAL_FIX.md
- Created INFOGRAPHICS_SHARE_FIX.md"

# Create annotated tag for v1.4
git tag -a v1.4 -m "Version 1.4 – Infographics PDF/Screenshot Export with Real Apple Maps"

# Push to remote with tag
git push origin main --follow-tags

# Verify tag was pushed
git tag -l
git show v1.4
```

## Verification

After pushing, verify:
1. Check GitHub that v1.4 tag appears in releases
2. Verify all files were committed
3. Check that commit message is properly formatted
4. Ensure tag annotation is visible

## Rollback (if needed)

```bash
# If you need to undo the tag locally
git tag -d v1.4

# If you need to delete from remote
git push origin :refs/tags/v1.4

# Then you can recreate it
git tag -a v1.4 -m "Version 1.4 – Infographics PDF/Screenshot Export with Real Apple Maps"
git push origin v1.4
```

## Summary

**Files Modified**: 3
- InfographicsView.swift
- StartTabView.swift  
- CLAUDE.md

**Files Created**: 5
- VERSION_1.4_RELEASE_NOTES.md
- JOURNEY_MAP_VISUAL_GRAPHIC.md
- SHARE_BUTTON_ACTUAL_FIX.md
- INFOGRAPHICS_SHARE_FIX.md
- GIT_COMMANDS_V1.4.md (this file)

**Total Changes**: ~650 lines added, major feature complete
