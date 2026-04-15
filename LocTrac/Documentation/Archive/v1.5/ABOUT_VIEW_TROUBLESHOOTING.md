# About LocTrac View - Troubleshooting Guide

## Issue 1: "What's New" Button Not Showing

### Problem
The "What's New in Version X.X" button doesn't appear in About LocTrac.

### Root Cause
The button only shows if `WhatsNewFeature.features(for: appVersion)` returns features.

### Check Your Version
1. Run the app
2. Go to About LocTrac
3. Look at "Version X.X (build)" - note the version number
4. Open `WhatsNewFeature.swift`
5. Check if there's a `case "X.X":` for that version

### Example
If your app shows **"Version 1.5"**, you need this in `WhatsNewFeature.swift`:

```swift
case "1.5":
    return [
        WhatsNewFeature(
            symbolName: "globe",
            symbolColor: .blue,
            title: "Enhanced Geocoding",
            description: "Smart parsing of addresses..."
        ),
        // ... more features
    ]
```

### Quick Fix (Temporary)
The code now has a debug override:
```swift
if true || hasWhatsNewFeatures {  // 'true ||' forces it to show
```

This will make the button **always appear** for testing. Once you've added your version's features, you can remove the `true ||` part.

### Long-term Fix
Add your current version to `WhatsNewFeature.swift`:

```swift
// In WhatsNewFeature.swift
static func features(for version: String) -> [WhatsNewFeature] {
    switch version {
    
    case "1.3":
        return [ /* existing features */ ]
        
    case "1.4":
        return [ /* existing features */ ]
    
    case "1.5":  // ← ADD YOUR VERSION
        return [
            WhatsNewFeature(
                symbolName: "globe",
                symbolColor: .blue,
                title: "Enhanced Geocoding",
                description: "Smart address parsing with city/state/country detection and automatic rate limit handling."
            ),
            WhatsNewFeature(
                symbolName: "arrow.triangle.2.circlepath",
                symbolColor: .green,
                title: "Data Migration",
                description: "Batch migration tools to update existing location data with new geocoding features."
            ),
            // ... add more features
        ]
        
    default:
        return []
    }
}
```

---

## Issue 2: "Document Not Found" - README.md Not in App Bundle

### Problem
Tapping "Read Me", "Changelog", or "License" shows:
```
Document Not Found
README.md was not found in the app bundle.
Make sure the file is added to the Xcode target.
```

### Root Cause
The `.md` files exist in your project folder but aren't included in the app bundle.

### Visual Indicators
The updated code now shows **⚠️ warning icons** next to any documents that aren't in the bundle:

```
Documentation
  ✨ What's New in Version 1.5
  📄 Read Me                    ⚠️  ← File not in bundle
  📋 Changelog                  ⚠️  ← File not in bundle
  ✅ License                    ⚠️  ← File not in bundle
```

### Fix: Add Files to Target

#### Method 1: File Inspector (Recommended)
1. **In Xcode**, select `README.md` in the Project Navigator
2. Open **File Inspector** (right panel, or press `⌥⌘1`)
3. Find **Target Membership** section
4. **Check** the box next to **LocTrac** ✅
5. Repeat for `CHANGELOG.md` and `LICENSE.md`

#### Method 2: Add Files Dialog
1. Right-click on your project root in Navigator
2. Select **Add Files to "LocTrac"...**
3. Navigate to and select:
   - `README.md`
   - `CHANGELOG.md`
   - `LICENSE.md`
4. **Important**: UNCHECK "Copy items if needed" (files are already there)
5. **Important**: CHECK "Add to targets: LocTrac" ✅
6. Click **Add**

#### Method 3: Build Phases
1. Select your project in Navigator
2. Select the **LocTrac** target
3. Go to **Build Phases** tab
4. Expand **Copy Bundle Resources**
5. Click the **+** button
6. Select `README.md`, `CHANGELOG.md`, `LICENSE.md`
7. Click **Add**

### Verify It Worked
1. **Build** the app (`⌘B`)
2. **Run** the app (`⌘R`)
3. Go to **About LocTrac**
4. **Check**: Warning icons (⚠️) should be **gone**
5. **Tap** "Read Me" - should open successfully

---

## Issue 3: Files Exist but Still Not Found

### Possible Causes

#### 1. Wrong File Extension
- Files must be named **exactly**: `README.md`, `CHANGELOG.md`, `LICENSE.md`
- Not: `README.MD` or `readme.md` (case matters on some systems)
- Not: `README.txt` or `README` (must be `.md`)

#### 2. Files in Wrong Location
- Files should be in your project directory
- Check the file path in Xcode (select file, see path in File Inspector)

#### 3. Clean Build Needed
Sometimes Xcode's cache gets stale:
```
Product → Clean Build Folder (⇧⌘K)
Product → Build (⌘B)
```

#### 4. File Name Mismatch
The code looks for files with these exact names:
```swift
// In AboutLocTracView:
MarkdownDocumentView(fileName: "README", title: "Read Me")
MarkdownDocumentView(fileName: "CHANGELOG", title: "Changelog")
MarkdownDocumentView(fileName: "LICENSE", title: "License")

// In MarkdownDocumentView:
Bundle.main.url(forResource: fileName, withExtension: "md")
// Looks for: "README.md", "CHANGELOG.md", "LICENSE.md"
```

Make sure your files match these names exactly.

---

## Creating Missing Files

If the files don't exist, you can create them:

### README.md
```markdown
# LocTrac

A powerful, privacy-focused iOS app for tracking your locations, travels, and life events.

## Features

- 🗺️ Track locations with interactive maps
- 📅 Calendar-based event tracking
- 📊 Visual analytics and infographics
- 🔒 100% local storage (no cloud sync)
- 🎨 Beautiful SwiftUI interface

## Version 1.5

Enhanced geocoding and data migration tools.

## Privacy

Your data never leaves your device. Everything is stored locally in JSON format.

## Developer

Made with ❤️ and SwiftUI by Tim Arey
```

### CHANGELOG.md
```markdown
# Changelog

All notable changes to LocTrac will be documented in this file.

## [1.5] - 2026-04-10

### Added
- Enhanced geocoding system with smart parsing
- Forward and reverse geocoding
- Rate limit handling with automatic retry
- Data migration tools
- City name preservation

### Fixed
- Geocoding rate limit errors
- City name overwrites from geocoding

## [1.4] - 2026-03-29

### Added
- Travel History view
- Unified Locations tab
- Infographics tab
- First Launch Wizard
- Default location support

## [1.3] - 2026-03-15

### Added
- Affirmations feature
- Smarter imports with date range
- Calendar refresh improvements
- Auto "Other" location creation
```

### LICENSE.md
```markdown
# MIT License

Copyright (c) 2026 Tim Arey

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Quick Diagnostic Checklist

Run through this checklist:

### What's New Button
- [ ] Button appears in Documentation section
- [ ] Shows correct version number
- [ ] Opens WhatsNewView when tapped
- [ ] Displays features correctly

### Markdown Documents
- [ ] README.md exists in project
- [ ] CHANGELOG.md exists in project
- [ ] LICENSE.md exists in project
- [ ] All files added to LocTrac target (Target Membership checked)
- [ ] No warning icons (⚠️) displayed
- [ ] Documents open successfully
- [ ] Markdown formatting displays correctly
- [ ] Dark mode works properly

### Files in Bundle
```swift
// Run this in debug to check:
print("README:", Bundle.main.url(forResource: "README", withExtension: "md") != nil)
print("CHANGELOG:", Bundle.main.url(forResource: "CHANGELOG", withExtension: "md") != nil)
print("LICENSE:", Bundle.main.url(forResource: "LICENSE", withExtension: "md") != nil)
```

---

## Still Not Working?

### Debug Steps

1. **Check Console Logs**
   - Look for "Document Not Found" errors
   - Check file paths in errors

2. **Verify File Names**
   ```bash
   # In Terminal, go to your project directory:
   ls -la *.md
   ```
   Should show:
   ```
   README.md
   CHANGELOG.md
   LICENSE.md
   ```

3. **Check Build Log**
   - Product → Build (⌘B)
   - Show **Report Navigator** (⌘9)
   - Look for "Copy Bundle Resources" phase
   - Should list all three .md files

4. **Inspect App Bundle**
   - Build and run in Simulator
   - Find app bundle: `~/Library/Developer/CoreSimulator/Devices/.../LocTrac.app`
   - Check if .md files are inside

---

## Summary

**Two main issues fixed:**

1. ✅ **What's New button now always shows** (with debug override)
2. ✅ **Warning icons show missing files** (visual debugging)

**Your action items:**

1. 🔧 **Add .md files to target** (File Inspector → Target Membership)
2. 📝 **Add version features** to WhatsNewFeature.swift
3. ✅ **Test** that warning icons disappear
4. 🎉 **Enjoy** your working documentation!

---

**Created**: April 10, 2026  
**Issue**: Documentation access in About screen  
**Status**: Fixed with debug helpers
