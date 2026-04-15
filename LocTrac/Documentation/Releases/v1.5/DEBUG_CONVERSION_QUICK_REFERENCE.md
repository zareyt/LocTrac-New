# Quick Reference: Converting Print Statements to Debug Framework

**Date**: April 14, 2026  
**For**: LocTrac v1.5 Debug System Integration

---

## 🎯 Quick Conversion Guide

### Pattern 1: Simple Message
```swift
// ❌ Before:
print("📊 Chart rendering started")

// ✅ After:
DebugConfig.shared.log(.charts, "Chart rendering started")
```

### Pattern 2: With Variables
```swift
// ❌ Before:
print("📦 Locations count: \(locations.count)")

// ✅ After:
DebugConfig.shared.log(.startup, "Locations count: \(locations.count)")
```

### Pattern 3: Multi-line (Combine into One)
```swift
// ❌ Before:
print("📊 Location: \(name)")
print("   Theme: \(theme)")
print("   Color: \(color)")

// ✅ After:
DebugConfig.shared.log(.charts, "Location: \(name), Theme: \(theme), Color: \(color)")
```

### Pattern 4: Conditional Debug (Remove Condition)
```swift
// ❌ Before:
#if DEBUG
print("🚀 App started")
#endif

// ✅ After:
DebugConfig.shared.log(.startup, "App started")
// (Framework handles the gating automatically)
```

---

## 📋 Category Reference

| Emoji in Current Code | New Category | Example Use Case |
|----------------------|--------------|------------------|
| 💾 | `.dataStore` | CRUD operations on events, locations, etc. |
| 📁, 📂, 📄 | `.persistence` | Save/load from backup.json |
| 🧭 | `.navigation` | Sheet presentation, navigation actions |
| 🌐 | `.network` | Geocoding, network requests |
| ⚡ | `.cache` | Cache operations, invalidation |
| ✈️ | `.trips` | Trip calculations, suggestions |
| 📈, 📊 | `.charts` | Chart rendering, color themes |
| 📝, 🔍 (parsing) | `.parser` | Markdown parsing, release notes |
| 🚀, 🟢 (init) | `.startup` | App initialization, first launch |

---

## 🔍 Search Commands (Xcode)

### Find All Print Statements
```
⇧⌘F (Find in Project)
Search: print\(
```

### Find Specific Patterns
```
Search: "📊 \[Charts\]"
Search: "🚀 StartTabView"
Search: "Loading from backup"
Search: "Loaded Trips:"
```

---

## ✅ Complete Examples from Your Console

### Chart Color Debugging
```swift
// ❌ Current code (somewhere in chart views):
print("📊 [Charts] Location: \(location.name)")
print("   Theme: \(location.theme.rawValue)")
print("   CustomColorHex: \(location.customColorHex ?? "nil")")
print("   Using effectiveColor")

// ✅ Replace with:
DebugConfig.shared.log(.charts, 
    "Location: \(location.name), Theme: \(location.theme.rawValue), " +
    "CustomColorHex: \(location.customColorHex ?? "nil"), Using effectiveColor"
)
```

### Startup Logging
```swift
// ❌ Current code (likely in StartTabView):
print("🚀 StartTabView appeared")
print("📝 isFirstLaunch: \(isFirstLaunch)")
print("📦 Locations count: \(store.locations.count)")
print("✅ hasCompletedFirstLaunch: \(hasCompletedFirstLaunch)")
print("📄 backup.json exists: \(backupExists)")

// ✅ Replace with:
DebugConfig.shared.log(.startup, "StartTabView appeared")
DebugConfig.shared.log(.startup, "isFirstLaunch: \(isFirstLaunch)")
DebugConfig.shared.log(.startup, "Locations count: \(store.locations.count)")
DebugConfig.shared.log(.startup, "hasCompletedFirstLaunch: \(hasCompletedFirstLaunch)")
DebugConfig.shared.log(.startup, "backup.json exists: \(backupExists)")
```

### Persistence Logging
```swift
// ❌ Current code (likely in DataStore):
print("📂 Loading from backup.json")
print("✅ Loaded Trips: \(trips.count)")
print("✅ Loaded Locations: \(locations.count)")
print("✅ Loaded Events: \(events.count)")
print("✅ Loaded Activities: \(activities.count)")
print("✅ Loaded Affirmations: \(affirmations.count)")

// ✅ Replace with:
DebugConfig.shared.log(.persistence, "Loading from backup.json")
DebugConfig.shared.log(.persistence, "Loaded Trips: \(trips.count)")
DebugConfig.shared.log(.persistence, "Loaded Locations: \(locations.count)")
DebugConfig.shared.log(.persistence, "Loaded Events: \(events.count)")
DebugConfig.shared.log(.persistence, "Loaded Activities: \(activities.count)")
DebugConfig.shared.log(.persistence, "Loaded Affirmations: \(affirmations.count)")
```

---

## 🎨 Emoji to Category Mapping

Remove emoji from message (it's now part of the category):

| Old Emoji | New Category | Auto Emoji |
|-----------|--------------|------------|
| 💾 | `.dataStore` | 💾 |
| 📁 | `.persistence` | 📁 |
| 🧭 | `.navigation` | 🧭 |
| 🌐 | `.network` | 🌐 |
| ⚡ | `.cache` | ⚡ |
| ✈️ | `.trips` | ✈️ |
| 📊, 📈 | `.charts` | 📈 |
| 📝, 🔍 | `.parser` | 📝 |
| 🚀, 🟢 | `.startup` | 🚀 |

---

## ⚙️ Testing Checklist

After converting print statements:

### 1. Test with Debug Enabled
```
1. Run app
2. Go to Settings → Debug Settings (DEBUG builds only)
3. Enable "Debug Mode"
4. Enable the category you just converted
5. Trigger the code path
6. Check Xcode console for logs
```

### 2. Test with Debug Disabled
```
1. Go to Settings → Debug Settings
2. Disable "Debug Mode"
3. Trigger the code path
4. Verify NO logs appear in console
```

### 3. Test Category Filtering
```
1. Enable only ONE category (e.g., .charts)
2. Trigger various code paths
3. Verify only that category's logs appear
```

---

## 📊 Log Format

### Old Format (Raw Print)
```
📊 [Charts] Location: Cabo
   Theme: navy
   CustomColorHex: nil
```

### New Format (Debug Framework)
```
📈 [10:45:23] [InfographicsView.swift:145] renderChart() - Location: Cabo, Theme: navy, CustomColorHex: nil
```

**Format breakdown:**
- `📈` - Category emoji (auto-added by framework)
- `[10:45:23]` - Timestamp (auto-added by framework)
- `[InfographicsView.swift:145]` - File and line number (auto-added)
- `renderChart()` - Function name (auto-added)
- `Location: Cabo...` - Your message

---

## 🚨 Common Mistakes to Avoid

### ❌ Don't include emoji in message
```swift
// ❌ Wrong:
DebugConfig.shared.log(.charts, "📈 Chart rendering")

// ✅ Right:
DebugConfig.shared.log(.charts, "Chart rendering")
```

### ❌ Don't use wrong category
```swift
// ❌ Wrong:
DebugConfig.shared.log(.dataStore, "Loading from backup.json")  // This is persistence!

// ✅ Right:
DebugConfig.shared.log(.persistence, "Loading from backup.json")
```

### ❌ Don't wrap in #if DEBUG
```swift
// ❌ Wrong (redundant):
#if DEBUG
DebugConfig.shared.log(.startup, "App started")
#endif

// ✅ Right (framework handles gating):
DebugConfig.shared.log(.startup, "App started")
```

### ❌ Don't use multiple logs for related data
```swift
// ❌ Wrong (creates noise):
DebugConfig.shared.log(.charts, "Location: \(name)")
DebugConfig.shared.log(.charts, "Theme: \(theme)")
DebugConfig.shared.log(.charts, "Color: \(color)")

// ✅ Right (single log):
DebugConfig.shared.log(.charts, "Location: \(name), Theme: \(theme), Color: \(color)")
```

---

## 🎯 Priority Files to Update

Based on your console output, focus on these files first:

1. **Chart/Visualization Files** (`.charts`)
   - Search for: `"📊 [Charts]"` or `"effectiveColor"`
   - Likely in: `InfographicsView.swift`, chart-related views

2. **StartTabView.swift** (`.startup`)
   - Search for: `"🚀 StartTabView appeared"`
   - Search for: `"isFirstLaunch"`

3. **DataStore.swift** (`.persistence`)
   - Search for: `"Loading from backup"`
   - Search for: `"Loaded Trips:"`

4. **Notification Setup** (`.startup`)
   - Search for: `"Notification categories"`
   - Likely in: App initialization code

---

## ✅ When You're Done

1. Search entire project for: `print\(`
2. Verify only these remain:
   - `DebugConfig.swift` (framework implementation)
   - Test files (if any)
   - Legitimate non-debug prints (if any)

3. Run app with all debug categories enabled
4. Run app with debug mode disabled
5. Confirm clean console output in production mode

---

*DEBUG_CONVERSION_QUICK_REFERENCE.md — LocTrac v1.5 — 2026-04-14*
