# Build Errors Fix Guide

## Errors Fixed

### ✅ 1. OrphanedEventsAnalyzerView.swift - Line 359

**Error**: `Call can throw, but it is not marked with 'try' and the error is not handled`

**Problem**: `Task.sleep()` can throw but wasn't marked with `try`

**Fixed**:
```swift
// BEFORE:
await Task.sleep(nanoseconds: 100_000_000)

// AFTER:
try? await Task.sleep(nanoseconds: 100_000_000)
```

**Also Fixed**: Line 362 - `await analyzer.analyze()` changed to `analyzer.analyze()` (not async)

---

## Errors to Fix Manually

### 🔧 2. Widget Version Mismatch

**Error**: `The CFBundleShortVersionString of an app extension ('1.0') must match that of its containing parent app ('1.5').`

**How to Fix**:
1. In Xcode, select the **LocTracWidget** target
2. Go to **General** tab
3. Find **Version** field (currently shows "1.0")
4. Change it to **"1.5"** to match your main app
5. Also update **Build** number to match if needed

**Location**: Project navigator → Targets → LocTracWidget → General → Identity → Version

---

## Warnings (Optional Fixes)

These won't prevent compilation but are good to clean up:

### 3. DebugConfig.swift:251 - State Modification Warning

**Warning**: `Modifying state during view update, this will cause undefined behavior`

**What to Check**: Look for any `@State` or `@Published` property being modified inside a view's `body` or computed property. Move the modification to an action or `onAppear`.

---

### 4. AppEntry.swift:32 - Deprecated API

**Warning**: `'applicationIconBadgeNumber' was deprecated in iOS 17.0`

**How to Fix**:
```swift
// OLD (deprecated):
UIApplication.shared.applicationIconBadgeNumber = count

// NEW (iOS 17+):
UNUserNotificationCenter.current().setBadgeCount(count) { error in
    if let error = error {
        print("Error setting badge: \(error)")
    }
}
```

---

### 5. Variable Mutation Warnings

Several files have warnings about variables that should be `let` instead of `var`:

**DataStore.swift:744**:
```swift
// Change from:
var geocodedFromCity = 0

// To (if never modified):
let geocodedFromCity = 0
```

**LocationDataEnhancer.swift:224, 330**:
```swift
// Change from:
var city = ...

// To (if never modified):
let city = ...
```

**LocationDataEnhancementView.swift:800**:
```swift
// Change from:
var currentRetryQueue = ...

// To (if never modified):
let currentRetryQueue = ...
```

**EventFormView.swift:106, 119**:
```swift
// Change from:
var localCal = ...

// To (if never modified):
let localCal = ...
```

**ModernEventFormView.swift:727, 770**:
```swift
// Change from:
var localCal = ...

// To (if never modified):
let localCal = ...
```

**MarkdownDocumentView.swift:304**:
```swift
// Change from:
var result = ...

// To (if never modified):
let result = ...
```

---

### 6. LocationDataEnhancementView.swift:91, 104 - Immutable Property Warning

**Warning**: `Immutable property will not be decoded because it is declared with an initial value which cannot be overwritten`

**What to Check**: Properties with `let` that have initial values and are `Codable`. Either:
- Remove initial value and make it required in init
- Make it `var` instead of `let`
- Add `CodingKeys` to exclude it from decoding

---

### 7. TimelineRestoreView.swift:1099 - Unused Variable

**Warning**: `Initialization of variable 'importedEventsWithAffirmationsCount' was never used`

**How to Fix**:
```swift
// Either use it:
print("Imported \(importedEventsWithAffirmationsCount) events with affirmations")

// Or remove it:
_ = importedEvents.filter { !$0.affirmationIDs.isEmpty }.count
```

---

### 8. NotificationManager.swift:45 - Unnecessary await

**Warning**: `No 'async' operations occur within 'await' expression`

**How to Fix**: Remove `await` if the function being called isn't actually async.

---

## Priority Fix List

### Must Fix (Prevents Build):
1. ✅ **OrphanedEventsAnalyzerView.swift** - Fixed above
2. ⚠️ **Widget Version** - Must fix manually in Xcode

### Should Fix (Warnings):
3. DebugConfig.swift - State modification
4. AppEntry.swift - Deprecated API (use iOS 17+ method)

### Nice to Fix (Code Quality):
5-8. All the `var` → `let` warnings
9. Unused variables

---

## Quick Fix Steps

1. **Widget Version** (Required):
   ```
   Xcode → Targets → LocTracWidget → General → Version: "1.5"
   ```

2. **Clean Build** (Recommended):
   ```
   Product → Clean Build Folder (⇧⌘K)
   Product → Build (⌘B)
   ```

3. **Test Run**:
   ```
   Product → Run (⌘R)
   ```

---

## Summary

**Critical Errors**: 1 fixed ✅, 1 requires manual fix (widget version)  
**Warnings**: 11 optional improvements

**Status After Widget Version Fix**: ✅ Should build successfully

---

## Next Steps

1. Fix widget version to 1.5
2. Clean and rebuild
3. Test the app
4. Optionally clean up warnings for code quality

The app will work fine with just the widget version fix. The warnings are code quality improvements but won't prevent the app from running.
