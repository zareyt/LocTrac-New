# Release 4.2 - Git Comparison Guide

This document helps you compare your current working directory against the last commit to ensure everything is ready for release 4.2.

---

## Step 1: Check Current Status

git status

**Expected Output:**
- Modified files in red (unstaged) or green (staged)
- New untracked files listed
- Clean working tree = nothing to commit

**What to Look For:**
- ✅ Modified files you expect (HomeView.swift, etc.)
- ✅ New documentation files
- ❌ Build artifacts (.build, DerivedData)
- ❌ User-specific files (.DS_Store, xcuserdata)

---

## Step 2: View Summary of Changes

git diff --stat

**Expected Output:**
```
HomeView.swift                          | 150 ++++++++++++++++++++
FirstLaunchWizard.swift                 |  85 ++++++-----
DataStore.swift                         |  45 +++---
Info.plist                              |   8 +-
[other files]                           | [changes]
```

**What to Look For:**
- Line count changes make sense
- No unexpectedly large changes
- No binary files changed unintentionally

---

## Step 3: Review Specific File Changes

### HomeView.swift (Current File)

git diff HomeView.swift

**Expected Changes:**
- New navigation callbacks (onAddEvent, onAddLocation, etc.)
- New computed properties (todayEvents, nextUpcomingEvent, etc.)
- New sections (todayUpcomingSection, recentActivitySection, etc.)
- Better empty states
- Event row formatting improvements

**Should NOT See:**
- Debug print statements
- Commented-out code blocks
- TODO/FIXME without resolution
- Hardcoded test data

---

### Info.plist

git diff Info.plist

**Expected Changes:**
- `CFBundleShortVersionString` → `4.2`
- `CFBundleVersion` → [incremented]
- `AppReleaseDate` → `March 29, 2026`
- `NSLocationWhenInUseUsageDescription` added
- `NSPhotoLibraryUsageDescription` added
- `NSContactsUsageDescription` added

**Should NOT See:**
- Removed keys
- Malformed XML
- Missing closing tags

---

### FirstLaunchWizard.swift

git diff FirstLaunchWizard.swift

**Expected Changes:**
- `WizardLocationManager` class added
- `PermissionsStepView` added
- `LocationsStepView` updated with:
  - `useCurrentLocation` toggle (default: false)
  - Location timeout (5 seconds)
  - Error handling
  - Status display
- `totalSteps` changed from 3 to 4

**Should NOT See:**
- Removed error handling
- Hardcoded coordinates
- Removed fallback to manual entry

---

### DataStore.swift

git diff DataStore.swift

**Expected Changes:**
- Removed Seed.json loading logic
- Simplified `loadData()` function
- Added print statements for first launch detection
- Cleaner initialization

**Should NOT See:**
- Removed backup.json handling
- Broken data saving
- Removed essential properties

---

## Step 4: Check for New Files

git ls-files --others --exclude-standard

**Expected New Files:**
- `RELEASE_4.2_CHECKLIST.md` ✅
- `RELEASE_NOTES_4.2.md` ✅
- Any new Swift files (if added)
- Updated documentation files

**Should NOT See:**
- `.DS_Store`
- `*.xcuserdata`
- Build artifacts
- Temporary files

---

## Step 5: Review All Modified Files Line by Line

git diff

**This shows every change in detail.**

**What to Review:**
1. **Removed Code**: Why was it removed? Is it safe?
2. **Added Code**: Does it follow project conventions?
3. **Changed Logic**: Is the behavior change intentional?
4. **Whitespace**: Clean up unnecessary whitespace changes

**Red Flags:**
- Secrets or API keys in code
- Database credentials
- Personal information
- Debugging code left in
- Incomplete implementations

---

## Step 6: Compare Against Specific Commit

### Find Last Release Tag

git tag -l

**Should show:** v4.1, v4.0, etc.

### Compare Against Last Release

git diff v4.1..HEAD

**This shows all changes since version 4.1**

### View Commit Log Since Last Release

git log v4.1..HEAD --oneline

**Shows list of commits since 4.1**

---

## Step 7: Verify Specific Features

### Test Cases Before Committing

#### 1. Clean Build Test

- Product → Clean Build Folder (⇧⌘K)
- Product → Build (⌘B)
- Should complete with 0 errors

#### 2. Fresh Install Test

- Delete app from simulator
- Build and Run (⌘R)
- Wizard should appear
- Complete wizard with manual location entry
- App should work normally

#### 3. Fresh Install with Location

- Delete app from simulator
- Build and Run (⌘R)
- Toggle "Use Current Location" ON
- Allow location permission
- Location should detect or timeout after 5s
- Should complete successfully

#### 4. Fresh Install with Location Denied

- Delete app from simulator
- Build and Run (⌘R)
- Toggle "Use Current Location" ON
- Deny location permission
- Should show error message
- Toggle OFF should allow manual entry
- Should complete successfully

#### 5. Existing User Upgrade Test

- Launch with existing data
- App should load normally
- Wizard should NOT appear
- All data should be intact

---

## Step 8: Documentation Review

### Verify Documentation Matches Code

#### Check First Launch Wizard Docs

diff <(grep -o "totalSteps = [0-9]" FirstLaunchWizard.swift) <(echo "totalSteps = 4")

**Should match:** 4 steps

#### Check Version in About View

grep "4.2" AboutLocTracView.swift

**Should NOT hardcode version** (should read from Info.plist)

#### Check All Markdown Files

find . -name "*.md" -exec echo "=== {} ===" \; -exec head -5 {} \;

**Review:**
- Dates are current
- Information is accurate
- No TODO sections

---

## Step 9: Pre-Commit Validation

### Run These Checks

1. View current changes summary

git status
git diff --stat

2. Review each changed file

git diff HomeView.swift
git diff Info.plist
git diff FirstLaunchWizard.swift
git diff DataStore.swift

3. Check for debug code

git diff | grep -i "print("
git diff | grep -i "TODO"
git diff | grep -i "FIXME"

4. Verify no secrets

git diff | grep -i "password"
git diff | grep -i "apikey"
git diff | grep -i "secret"

---

## Step 10: Comparison Checklist

Before proceeding to commit:

- [ ] `git status` shows only expected files
- [ ] `git diff --stat` shows reasonable line changes
- [ ] HomeView.swift changes are intentional
- [ ] Info.plist updated to version 4.2
- [ ] Info.plist has all 3 privacy keys
- [ ] FirstLaunchWizard.swift has timeout logic
- [ ] DataStore.swift no longer loads Seed.json
- [ ] No debug print statements in diff
- [ ] No TODO/FIXME unresolved
- [ ] No secrets or credentials in diff
- [ ] Documentation matches code
- [ ] Clean build succeeds (0 errors)
- [ ] Fresh install wizard works
- [ ] Location permission denial handled gracefully
- [ ] Existing user data loads correctly
- [ ] All navigation callbacks work in HomeView

---

## Step 11: Ready to Commit

Once all checks pass, proceed with:

git add -A
git status

**Verify staged changes look correct**

git diff --cached

**Review what will be committed**

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
Build: [your build number]
Release Date: March 29, 2026"

---

## Step 12: Create and Verify Tag

git tag -a v4.2 -m "Release version 4.2 - Enhanced home view and wizard improvements"

git show v4.2

**Verify:**
- Tag points to correct commit
- Message is correct
- Commit includes all expected changes

---

## Step 13: Final Verification Before Push

git log -1 --stat

**Should show:**
- Correct commit message
- All expected files changed
- Reasonable line counts

git diff v4.1..v4.2

**Review all changes between versions**

---

## Quick Reference Card

Show status

git status

Show summary of changes

git diff --stat

Show detailed changes

git diff

Show changes in specific file

git diff HomeView.swift

Show staged changes

git diff --cached

Compare with previous version

git diff v4.1..HEAD

Find debug code

git diff | grep -E "(print\(|TODO|FIXME)"

View commit that will be created

git diff --cached --stat

---

## Troubleshooting

### "Too many changes to review"

git diff --stat | head -20

**Focus on files with most changes first**

### "Don't remember what I changed"

git diff HomeView.swift | grep "^+" | grep -v "^+++"

**Shows only added lines**

### "Want to see old vs new side by side"

git difftool HomeView.swift

**Opens visual diff tool (if configured)**

### "Accidentally staged wrong file"

git reset HEAD <file>

**Unstages file**

### "Want to see specific function changes"

git diff HomeView.swift | grep -A 10 "func topActivitiesSection"

**Shows changes in specific function**

---

**Use this guide to ensure your commit is clean and ready for release 4.2!**

**Created**: March 29, 2026  
**For Release**: 4.2  
**Author**: Tim Arey
