# Release 4.2 - Command Reference

Copy and paste these commands to prepare and release version 4.2.

---

## Phase 1: Review Current State

git status

git diff --stat

git diff

git diff HomeView.swift

git diff Info.plist

git diff FirstLaunchWizard.swift

git diff DataStore.swift

git ls-files --others --exclude-standard

---

## Phase 2: Check for Issues

git diff | grep -i "print("

git diff | grep -i "TODO"

git diff | grep -i "FIXME"

git diff | grep -i "password"

git diff | grep -i "apikey"

---

## Phase 3: Compare with Previous Release

git tag -l

git diff v4.1..HEAD

git log v4.1..HEAD --oneline

git log v4.1..HEAD --stat

---

## Phase 4: Stage Changes

git add -A

git status

git diff --cached

git diff --cached --stat

---

## Phase 5: Commit

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

## Phase 6: Create Tag

git tag -a v4.2 -m "Release version 4.2 - Enhanced home view and wizard improvements"

git tag -l

git show v4.2

---

## Phase 7: Verify Before Push

git log -1

git log -1 --stat

git diff v4.1..v4.2 --stat

---

## Phase 8: Push to Remote

git push origin main

git push origin v4.2

---

## Phase 9: Verify Remote

git ls-remote --tags origin

git log origin/main -1

---

## Bonus: View Release

git show v4.2 --stat

git log --oneline --graph --decorate

git log v4.1..v4.2 --oneline

---

## Emergency: Undo Commands (Use Only if Needed)

### Unstage all files

git reset HEAD

### Unstage specific file

git reset HEAD HomeView.swift

### Undo last commit (keep changes)

git reset --soft HEAD^

### Undo last commit (discard changes) ⚠️ DANGEROUS

git reset --hard HEAD^

### Delete local tag

git tag -d v4.2

### Delete remote tag (if already pushed) ⚠️ CAREFUL

git push origin :refs/tags/v4.2

---

## Quick Status Checks

### Current branch

git branch

### Remote status

git remote -v

### Last 5 commits

git log -5 --oneline

### All tags

git tag -l

### Current commit hash

git rev-parse HEAD

### Files changed in last commit

git diff HEAD^ HEAD --name-only

---

## Archive Commands (For Records)

### Create patch file

git diff v4.1..v4.2 > release_4.2.patch

### Create commit log

git log v4.1..v4.2 > release_4.2_commits.txt

### Create detailed change log

git log v4.1..v4.2 --stat > release_4.2_detailed.txt

### Export specific file version

git show v4.2:HomeView.swift > HomeView_v4.2.swift

---

**All commands ready for copy/paste!**
**Release**: 4.2
**Date**: March 29, 2026
