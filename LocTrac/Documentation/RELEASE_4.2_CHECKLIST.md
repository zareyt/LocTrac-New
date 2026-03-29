# Release 4.2 Pre-Commit Checklist

## Overview
This document outlines all necessary checks and steps before committing code and creating release 4.2 of LocTrac.

---

## 1. Version & Build Information

### Update Version Numbers
- [ ] Update `CFBundleShortVersionString` to `4.2` in Info.plist
- [ ] Increment `CFBundleVersion` (build number) in Info.plist
- [ ] Update `AppReleaseDate` to `March 29, 2026` in Info.plist
- [ ] Verify version displays correctly in AboutLocTracView

### Verify in Code

git diff Info.plist

---

## 2. Info.plist Privacy Keys Verification

### Required Privacy Keys (Must Exist)
- [ ] `NSLocationWhenInUseUsageDescription` - "LocTrac uses your location to automatically detect your current city when adding locations."
- [ ] `NSPhotoLibraryUsageDescription` - "LocTrac accesses your photos to add images to your locations."
- [ ] `NSContactsUsageDescription` - "LocTrac accesses contacts to tag people in your events."

### Verify Keys

git diff Info.plist | grep -E "(NSLocation|NSPhoto|NSContacts)"

---

## 3. Code Quality Checks

### Build Status
- [ ] Clean build folder (Product → Clean Build Folder)
- [ ] Build succeeds with zero errors
- [ ] Build succeeds with zero warnings (or document acceptable warnings)
- [ ] No deprecated API usage warnings

### Code Review
- [ ] Review all modified files for:
  - [ ] Console.log or debug print statements (remove or comment)
  - [ ] TODO/FIXME comments (resolve or document)
  - [ ] Commented-out code blocks (remove or document why kept)
  - [ ] Hardcoded test data (remove)
  - [ ] Force unwraps that should be optional bindings

### Files to Review

git status
git diff

---

## 4. Feature Completeness

### Core Features Working
- [ ] **Home Tab**: Displays today/upcoming events, recent activity, top locations
- [ ] **Calendar Tab**: Shows events, can add/edit/delete
- [ ] **Charts Tab**: Donut chart displays location data
- [ ] **Locations Tab**: Shows all locations, can add/edit/delete
- [ ] **Infographics Tab**: Displays statistics and insights
- [ ] **Settings Tab**: All settings functional

### First Launch Wizard
- [ ] Wizard appears on first launch (fresh install)
- [ ] Step 1 (Welcome) displays correctly
- [ ] Step 2 (Permissions) displays all three permissions with instructions
- [ ] Step 3 (Locations):
  - [ ] Manual location entry works
  - [ ] "Use Current Location" toggle works
  - [ ] Location permission prompt appears when toggling ON
  - [ ] Location timeout (5 seconds) works
  - [ ] Error messages display correctly
  - [ ] Can add multiple locations
- [ ] Step 4 (Activities) can add activities
- [ ] Wizard completion creates backup.json
- [ ] Wizard doesn't reappear after completion

### Data Management
- [ ] Events save and load correctly
- [ ] Locations save and load correctly  
- [ ] Activities save and load correctly
- [ ] Trips save and load correctly (if implemented)
- [ ] Backup/export creates valid JSON
- [ ] Import restores data correctly
- [ ] No data loss on app restart

### New Features in 4.2
- [ ] Home tab navigation callbacks work
- [ ] Quick actions (Add Event, Add Location) function
- [ ] Section navigation (Calendar, Locations, Infographics) works
- [ ] "Other Cities" view displays correctly
- [ ] Top activities (12-month rolling) calculates correctly
- [ ] Top locations ranking displays correctly

---

## 5. Testing Scenarios

### Fresh Install Testing
- [ ] Delete app from device/simulator
- [ ] Clean build folder
- [ ] Install and launch
- [ ] Wizard appears automatically
- [ ] Complete wizard with manual location entry
- [ ] Complete wizard with current location (permission granted)
- [ ] Complete wizard with current location (permission denied)
- [ ] App functions normally after wizard

### Existing User Testing
- [ ] Existing data loads correctly
- [ ] No data corruption
- [ ] All existing events display
- [ ] All existing locations display
- [ ] Migration (if any) works correctly

### Edge Cases
- [ ] Empty state: no events, no locations
- [ ] Single event/location
- [ ] Large dataset (100+ events)
- [ ] Network offline (manual location entry)
- [ ] Location permission denied scenario
- [ ] Location timeout scenario

---

## 6. UI/UX Verification

### Visual Checks
- [ ] No layout issues on iPhone SE (small screen)
- [ ] No layout issues on iPhone 16 Pro Max (large screen)
- [ ] No layout issues on iPad (if supported)
- [ ] Dark mode displays correctly
- [ ] Light mode displays correctly
- [ ] Colors use semantic colors (adapt to light/dark)
- [ ] All text is readable
- [ ] No truncated labels

### Navigation
- [ ] All tab bar items work
- [ ] Navigation between views works
- [ ] Back buttons function correctly
- [ ] Sheet presentations work
- [ ] Modals can be dismissed

### Accessibility
- [ ] All buttons have accessible labels
- [ ] VoiceOver can navigate the app
- [ ] Dynamic Type scaling works
- [ ] Sufficient color contrast

---

## 7. Performance Checks

### App Launch
- [ ] Cold launch < 3 seconds
- [ ] No visible lag or freezing
- [ ] Wizard doesn't hang (location timeout works)

### Data Operations
- [ ] Adding event is fast
- [ ] Deleting event is fast
- [ ] Calendar scrolling is smooth
- [ ] Charts render quickly
- [ ] No memory leaks (use Instruments if concerned)

### Infographics Caching
- [ ] InfographicsCache reduces recalculation
- [ ] Data update token properly invalidates cache
- [ ] No stale data displayed

---

## 8. Documentation Review

### User-Facing Documentation
- [ ] README.md is up to date (if exists)
- [ ] USER_GUIDE_FIRST_LAUNCH_WIZARD.md reflects current wizard flow
- [ ] WHY_PHOTOS_CONTACTS_NOT_IN_SETTINGS.md is accurate
- [ ] All markdown files have correct information

### Developer Documentation
- [ ] QUICK_FIX_SUMMARY.md reflects current implementation
- [ ] WIZARD_IMPROVEMENTS_COMPLETE.md is accurate
- [ ] INFOGRAPHICS_CACHING_QUICKSTART.md is current
- [ ] Code comments are up to date

### Create Release Notes
- [ ] Create RELEASE_NOTES_4.2.md with:
  - [ ] New features
  - [ ] Bug fixes
  - [ ] Known issues
  - [ ] Breaking changes (if any)

---

## 9. Git Repository Preparation

### Review Changes

git status

### Check for Uncommitted Files
- [ ] All new files are tracked
- [ ] No unwanted files in staging (build artifacts, etc.)
- [ ] .gitignore is properly configured

### Review Diff

git diff --stat
git diff

### Files Expected to Change
- [ ] HomeView.swift (current file)
- [ ] Info.plist (version update)
- [ ] FirstLaunchWizard.swift (location fixes)
- [ ] DataStore.swift (any updates)
- [ ] Other feature files

### Unexpected Changes to Review
- [ ] Project.pbxproj (only if adding/removing files)
- [ ] Workspace settings (avoid committing unless necessary)

---

## 10. Pre-Commit Commands

### Stage All Changes

git add -A

### Review Staged Changes

git diff --cached

### Commit with Descriptive Message

git commit -m "Release 4.2: Enhanced HomeView with navigation, improved wizard location handling, and bug fixes

Features:
- New HomeView with quick actions and section navigation
- Top activities (12-month rolling window)
- Top locations ranking
- Other cities display
- Navigation callbacks to Calendar, Locations, and Infographics tabs

Improvements:
- First launch wizard location detection with timeout
- Error handling for location permission denial
- Manual location entry as default option
- Better status feedback during location detection

Bug Fixes:
- Fixed app hanging on location permission denial
- Fixed missing Info.plist privacy keys
- Fixed location timeout issue

Version: 4.2
Build: [increment from previous]
Release Date: March 29, 2026"

---

## 11. Create Release Tag

### Verify Current Branch

git branch

### Create Annotated Tag

git tag -a v4.2 -m "Release version 4.2 - Enhanced home view and wizard improvements"

### Verify Tag

git tag -l
git show v4.2

---

## 12. Push to Remote

### Push Commits

git push origin main

### Push Tags

git push origin v4.2

---

## 13. Post-Release Verification

### GitHub/Repository Checks
- [ ] Commits appear on remote repository
- [ ] Tag appears in releases/tags section
- [ ] Create GitHub release from tag (if using GitHub)
- [ ] Upload build to TestFlight (if distributing)

### TestFlight/Distribution (if applicable)
- [ ] Archive app (Product → Archive)
- [ ] Validate archive
- [ ] Upload to App Store Connect
- [ ] Submit for TestFlight review
- [ ] Add release notes for testers

### Final Verification
- [ ] Download fresh build from distribution
- [ ] Test on actual device (not just simulator)
- [ ] Verify version number in About screen
- [ ] Verify all features work as expected

---

## 14. Known Issues & Future Work

### Document Any Known Issues
- [ ] List any bugs not fixed in 4.2
- [ ] Document workarounds if available
- [ ] Create issues/tickets for future fixes

### Future Enhancements
- [ ] Trips management feature (if not complete)
- [ ] Golfshot CSV import (if not complete)
- [ ] Default location settings (if not complete)
- [ ] Any TODOs found during code review

---

## Summary Checklist

Essential pre-commit steps:

1. [ ] Update version numbers (Info.plist)
2. [ ] Verify Info.plist privacy keys exist
3. [ ] Clean build with zero errors
4. [ ] Test first launch wizard (fresh install)
5. [ ] Test existing user upgrade
6. [ ] Test all HomeView navigation
7. [ ] Review all git diff changes
8. [ ] Remove debug code
9. [ ] Update documentation
10. [ ] Create release notes
11. [ ] Git commit with detailed message
12. [ ] Git tag v4.2
13. [ ] Push to remote
14. [ ] Verify on remote repository

---

## Quick Command Reference

Clean and test

Product → Clean Build Folder (⇧⌘K)
Product → Build (⌘B)

Review changes

git status
git diff
git diff --stat

Commit and release

git add -A
git commit -m "Release 4.2: [message]"
git tag -a v4.2 -m "Release version 4.2"
git push origin main
git push origin v4.2

View tags

git tag -l
git show v4.2

Compare with previous release

git log v4.1..v4.2
git diff v4.1..v4.2

---

**Last Updated**: March 29, 2026  
**Release Version**: 4.2  
**Author**: Tim Arey
