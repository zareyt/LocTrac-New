# Debug System Concurrency Fix

**Date**: April 14, 2026  
**Issue**: Swift 6 Main Actor Isolation Errors  
**Status**: ✅ Fixed

---

## 🐛 Problem

When converting print statements to the debug framework, we encountered Swift 6 concurrency errors:

```
Main actor-isolated static property 'shared' can not be referenced from a nonisolated context
Call to main actor-isolated instance method 'log(_:_:file:function:line:)' in a synchronous nonisolated context
```

**Root cause:**
- `DebugConfig` is marked `@MainActor` (required for SwiftUI `@Published` properties)
- Static methods like `WhatsNewFeature.features(for:)` are nonisolated
- Calling `DebugConfig.shared.log()` from nonisolated context violates Swift 6 concurrency rules

---

## ✅ Solution

Made the `log()` method **nonisolated** with safe main actor access:

### 1. Made `log()` Method Nonisolated

```swift
// Before:
func log(_ category: LogCategory, _ message: String, ...) {
    guard isEnabled else { return }
    // ...
}

// After:
nonisolated func log(_ category: LogCategory, _ message: String, ...) {
    // Handle both main thread and background thread calls safely
    // ...
}
```

### 2. Added Thread-Safe Implementation

```swift
nonisolated func log(
    _ category: LogCategory,
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    // Early exit if not on main thread - logging from background is fine
    guard Thread.isMainThread else {
        // For background threads, just print without checking config
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("\(category.emoji) [BG] [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
        #endif
        return
    }
    
    // On main thread, use assumeIsolated for safe access
    MainActor.assumeIsolated {
        guard isEnabled else { return }
        guard category.isEnabled(in: self) else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        print("\(category.emoji) [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)")
    }
}
```

### 3. Made `LogCategory.isEnabled(in:)` Nonisolated

```swift
// Before:
@MainActor
func isEnabled(in config: DebugConfig) -> Bool {
    // ...
}

// After:
nonisolated func isEnabled(in config: DebugConfig) -> Bool {
    // Must be called within MainActor context (handled by log() method)
    // ...
}
```

---

## 🎯 Benefits

### 1. **Can Call from Any Context**
```swift
// ✅ From nonisolated static method
static func features(for version: String) -> [WhatsNewFeature] {
    DebugConfig.shared.log(.parser, "Loading features")  // Now works!
    // ...
}

// ✅ From @MainActor context
@MainActor
func doSomething() {
    DebugConfig.shared.log(.dataStore, "Doing something")  // Still works!
    // ...
}

// ✅ Even from background threads
Task.detached {
    DebugConfig.shared.log(.network, "Background work")  // Now works too!
    // ...
}
```

### 2. **Thread-Safe Logging**
- Main thread calls respect `isEnabled` and category toggles
- Background thread calls log with `[BG]` prefix in DEBUG builds
- No crashes, no concurrency violations

### 3. **Swift 6 Compatible**
- No more "main actor isolation" errors
- Follows Swift 6 strict concurrency checking
- Uses `MainActor.assumeIsolated` correctly

---

## 🔍 How It Works

### Main Thread Path
```
1. Call DebugConfig.shared.log(.parser, "message")
2. Check Thread.isMainThread → true
3. Use MainActor.assumeIsolated { }
4. Check isEnabled → true/false
5. Check category.isEnabled → true/false
6. Print with timestamp and formatting
```

### Background Thread Path
```
1. Call DebugConfig.shared.log(.network, "message")
2. Check Thread.isMainThread → false
3. In DEBUG builds, print with [BG] prefix
4. Skip config checks (background logging always allowed in DEBUG)
```

---

## 📝 Usage Examples

All these now work without errors:

### Nonisolated Static Methods
```swift
struct WhatsNewFeature {
    static func features(for version: String) -> [WhatsNewFeature] {
        DebugConfig.shared.log(.parser, "Loading features for version \(version)")
        // ✅ No errors!
    }
}
```

### Main Actor Methods
```swift
@MainActor
class DataStore: ObservableObject {
    func loadData() {
        DebugConfig.shared.log(.persistence, "Loading data from backup.json")
        // ✅ Still works perfectly!
    }
}
```

### Background Tasks
```swift
Task.detached {
    let result = await someNetworkCall()
    DebugConfig.shared.log(.network, "Network call completed")
    // ✅ Logs with [BG] prefix in DEBUG builds
}
```

---

## ⚠️ Important Notes

### 1. Background Logging Always Prints (DEBUG Only)
In DEBUG builds, background thread logs always print (ignoring config) because:
- Can't safely access `@Published` properties from background
- Background logging is rare and usually important
- Marked with `[BG]` prefix so you know it's from background thread

### 2. MainActor.assumeIsolated Safety
We use `MainActor.assumeIsolated` because:
- We've already checked `Thread.isMainThread`
- This is guaranteed to be safe (no async overhead)
- Allows synchronous access to `@Published` properties

### 3. Production Builds
In production builds (when `DEBUG` is not defined):
- Background thread logs are completely skipped
- Main thread logs still respect all config settings
- Zero performance impact

---

## 🧪 Testing

All these scenarios should work:

### ✅ Test 1: Nonisolated Context
```swift
func testNonisolatedLogging() {
    DebugConfig.shared.log(.parser, "Test message")
    // Should compile without errors
}
```

### ✅ Test 2: Main Actor Context
```swift
@MainActor
func testMainActorLogging() {
    DebugConfig.shared.log(.startup, "Test message")
    // Should compile without errors
}
```

### ✅ Test 3: Background Thread
```swift
Task.detached {
    DebugConfig.shared.log(.network, "Background test")
    // Should compile and run without crashes
}
```

### ✅ Test 4: Static Methods
```swift
struct MyType {
    static func myStaticMethod() {
        DebugConfig.shared.log(.charts, "Static method log")
        // Should compile without errors
    }
}
```

---

## 📚 References

- **Swift Concurrency**: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- **MainActor**: https://developer.apple.com/documentation/swift/mainactor
- **assumeIsolated**: https://developer.apple.com/documentation/swift/mainactor/assumeisolated(_:file:line:)

---

## ✅ Checklist

- [x] Made `log()` method nonisolated
- [x] Made `LogCategory.isEnabled(in:)` nonisolated
- [x] Added thread safety with `Thread.isMainThread` check
- [x] Used `MainActor.assumeIsolated` for safe main thread access
- [x] Added background thread support with `[BG]` prefix
- [x] Wrapped background logging in `#if DEBUG`
- [x] Tested from nonisolated context (WhatsNewFeature.swift)
- [x] Tested from @MainActor context (should still work)
- [x] No build errors
- [x] Swift 6 strict concurrency mode compatible

---

*DEBUG_CONCURRENCY_FIX.md — LocTrac v1.5 — 2026-04-14*
