# LocTrac Debug System - Best Practices Guide

**Created**: April 13, 2026  
**Version**: 1.0  
**Status**: Production Ready

---

## 📋 Overview

The LocTrac Debug System provides granular, toggleable debugging capabilities designed for SwiftUI development. It follows Apple's best practices and can be completely disabled for production builds.

### Key Features

1. **Master Switch** - Single toggle to enable/disable all debug features
2. **View Name Overlays** - Show view names in italics at bottom of screen
3. **Lifecycle Logging** - Track onAppear/onDisappear events
4. **Performance Metrics** - Count body recomputation
5. **Category-Based Logging** - Granular control per subsystem (DataStore, Network, etc.)
6. **Persistence** - Settings saved to UserDefaults
7. **Environment Integration** - Works seamlessly with SwiftUI's environment system

---

## 🏗️ Architecture

### Components

**DebugConfig.swift**
- `@MainActor class DebugConfig: ObservableObject`
- Singleton pattern with `DebugConfig.shared`
- UserDefaults persistence
- Category-based logging
- Quick presets (All, None, UI, Data)

**DebugSettingsView.swift**
- SwiftUI view for controlling debug features
- Organized sections:
  - Master Control
  - Quick Presets
  - UI Debug Features
  - Console Logging Categories
  - Info/Help

**View Modifier: `debugViewName(_:)`**
- Shows view name overlay when enabled
- Tracks lifecycle events
- Counts body recomputations
- Non-intrusive (only visible when debug enabled)

---

## 🚀 Setup & Integration

### 1. Add to DataStore/RootView

Inject DebugConfig into the environment at app root:

```swift
// In your @main App or RootView
@StateObject private var debugConfig = DebugConfig.shared

var body: some Scene {
    WindowGroup {
        StartTabView()
            .environmentObject(store)
            .environmentObject(debugConfig)  // ← Add this
    }
}
```

### 2. Add to Settings Menu

Add DebugSettingsView to your Settings/Options menu:

```swift
// In StartTabView or OptionsView
@State private var showDebugSettings = false

Menu {
    // ... other menu items ...
    
    #if DEBUG
    Button {
        showDebugSettings = true
    } label: {
        Label("Debug Settings", systemImage: "ladybug")
    }
    #endif
}

.sheet(isPresented: $showDebugSettings) {
    DebugSettingsView()
}
```

### 3. Add to Views

Apply the debug view name modifier to your views:

```swift
struct HomeView: View {
    @EnvironmentObject var debugConfig: DebugConfig
    
    var body: some View {
        VStack {
            // Your content
        }
        .debugViewName("HomeView")  // ← Add this
    }
}
```

### 4. Add Logging to Code

Use the category-based logging system:

```swift
// In DataStore
func add(_ event: Event) {
    DebugConfig.shared.log(.dataStore, "Adding event: \(event.id)")
    events.append(event)
    storeData()
}

// In network code
func geocode(latitude: Double, longitude: Double) async {
    DebugConfig.shared.log(.network, "Geocoding coordinates: (\(latitude), \(longitude))")
    // ... geocoding code ...
}

// In navigation
.onAppear {
    DebugConfig.shared.log(.navigation, "Sheet presented")
}
```

---

## 📖 Usage Guide

### For Developers

#### Basic Usage

1. **Enable Debug Mode**
   - Settings → Debug Settings
   - Toggle "Enable Debug Mode" ON
   
2. **Choose Features**
   - Toggle individual features as needed
   - Or use Quick Presets (Enable All, UI Only, Data Only)

3. **View Console**
   - Open Xcode Console (⇧⌘Y)
   - See categorized logs with emoji prefixes

#### View Name Overlays

When "Show View Names" is enabled:
- Each view shows its name in italics at bottom
- Non-intrusive gray overlay
- Updates in real-time

#### Performance Monitoring

When "Show Performance Metrics" is enabled:
- Body computation count shown under view name
- Console log every 10 computations
- Helps identify excessive recomputations

**Example:**
```
InfographicsView
Body: 47
```

#### Console Logging

Logs appear with this format:
```
💾 [10:30:45] [DataStore.swift:123] add(_:) - Adding event: abc-123
🌐 [10:30:46] [LocationEnhancer.swift:45] geocode() - Geocoding coordinates: (39.7, -104.9)
🧭 [10:30:47] [StartTabView.swift:89] body - Presenting sheet: LocationForm
```

**Format:**
- Emoji (category)
- Timestamp
- File:Line
- Function name
- Message

---

## 🎯 Best Practices

### When to Use What

**UI Debugging (View Names + Lifecycle)**
- Diagnosing navigation issues
- Understanding view hierarchy
- Tracking sheet presentation/dismissal
- Identifying which view is rendering

**Performance Debugging (Performance Metrics)**
- Identifying view performance issues
- Finding excessive body recomputations
- Optimizing expensive views
- Before/after optimization comparison

**Data Debugging (DataStore + Persistence)**
- Tracking CRUD operations
- Debugging data flow
- Understanding save/load behavior
- Verifying cache invalidation

**Network Debugging (Network + Geocoding)**
- Debugging API calls
- Tracking rate limiting
- Understanding geocoding behavior
- Network error diagnosis

### Logging Best Practices

**DO:**
```swift
// ✅ Clear, informative
DebugConfig.shared.log(.dataStore, "Added event \(event.id) at \(location.name)")

// ✅ Include relevant context
DebugConfig.shared.log(.network, "Geocoding failed for (\(lat), \(lon)): \(error)")

// ✅ Use appropriate category
DebugConfig.shared.log(.trips, "Suggested trip from \(from.id) to \(to.id), distance: \(dist)mi")
```

**DON'T:**
```swift
// ❌ Too verbose
DebugConfig.shared.log(.dataStore, "Event object: \(event)")

// ❌ Wrong category
DebugConfig.shared.log(.dataStore, "Network request started")  // Use .network!

// ❌ Not useful
DebugConfig.shared.log(.dataStore, "Something happened")
```

### View Modifier Usage

**Apply to all major views:**
```swift
// ✅ Major views
HomeView().debugViewName("HomeView")
LocationFormView().debugViewName("LocationFormView")
InfographicsView().debugViewName("InfographicsView")

// ✅ Sheets
.sheet(item: $item) { item in
    TripFormView()
        .debugViewName("TripFormView")
}

// ⚠️ Optional for small components
Text("Hello")  // No need for debugViewName on tiny views

// ❌ Don't overuse
HStack {
    Text("Name")
}.debugViewName("NameLabel")  // Too granular
```

---

## 🔧 Customization

### Adding New Categories

To add a new logging category:

1. **Add to DebugConfig:**
```swift
@Published var logMyFeature: Bool {
    didSet {
        UserDefaults.standard.set(logMyFeature, forKey: "Debug.logMyFeature")
    }
}
```

2. **Add to LogCategory enum:**
```swift
enum LogCategory {
    // ... existing ...
    case myFeature
    
    var emoji: String {
        switch self {
        // ... existing ...
        case .myFeature: return "🎨"
        }
    }
    
    func isEnabled(in config: DebugConfig) -> Bool {
        switch self {
        // ... existing ...
        case .myFeature: return config.logMyFeature
        }
    }
}
```

3. **Add to DebugSettingsView:**
```swift
HStack {
    Text("🎨 My Feature")
    Spacer()
    Toggle("", isOn: $debugConfig.logMyFeature)
        .labelsHidden()
}
```

4. **Initialize in init():**
```swift
self.logMyFeature = UserDefaults.standard.bool(forKey: "Debug.logMyFeature")
```

### Custom Presets

Add custom preset combinations:

```swift
// In DebugConfig
func presetPerformance() {
    isEnabled = true
    showViewNames = true
    showLifecycle = false
    showPerformance = true
    // All logging off except performance
    logDataStore = false
    logPersistence = false
    logNavigation = false
    logNetwork = false
    logCache = false
    logTrips = false
}
```

---

## 📊 Performance Impact

### When Disabled (Production)

- **Zero overhead** - Early returns prevent any execution
- Modifiers are no-op when `isEnabled = false`
- Perfect for App Store builds

### When Enabled (Development)

- **Minimal impact** on most operations
- View overlays: Negligible (SwiftUI overlay)
- Logging: ~0.1ms per log call
- Body counting: Negligible (increment only)

**Recommendation:** Disable before performance profiling or App Store builds

---

## 🚦 Recommended Workflow

### Daily Development

```
1. Enable "UI Only" preset
2. Work on features
3. Check view names as needed
4. Disable when not needed
```

### Debugging Data Issues

```
1. Enable "Data Only" preset
2. Reproduce issue
3. Check console logs
4. Filter by emoji in Xcode console
5. Disable when done
```

### Performance Optimization

```
1. Enable "Show Performance Metrics"
2. Navigate to slow view
3. Note body computation count
4. Make optimizations
5. Compare before/after
```

### Pre-Release

```
1. Disable Debug Mode
2. Verify no debug UI visible
3. Check logs are silent
4. Performance test
5. Archive for App Store
```

---

## 🔍 Troubleshooting

### View Names Not Showing

**Problem:** Debug enabled but view names don't appear

**Solutions:**
1. Check "Show View Names" is toggled ON
2. Verify view has `.debugViewName()` modifier
3. Ensure DebugConfig in environment
4. Check view isn't behind other views

### Logs Not Appearing

**Problem:** Logging enabled but no console output

**Solutions:**
1. Check master "Enable Debug Mode" is ON
2. Verify category toggle is ON
3. Check Xcode console is visible (⇧⌘Y)
4. Ensure you're calling correct category
5. Check log isn't filtered out in Xcode

### Performance Count Wrong

**Problem:** Body count seems too high

**Solution:** This is normal! Body recomputation happens frequently in SwiftUI:
- Parent view state changes
- Environment changes
- @Published property updates
- Navigation changes

Use this to identify **excessive** recomputation, not to eliminate all recomputation.

---

## 📝 Integration Checklist

### Initial Setup
- [ ] Add DebugConfig.swift to project
- [ ] Add DebugSettingsView.swift to project
- [ ] Inject DebugConfig into environment at app root
- [ ] Add Debug Settings to menu (wrapped in `#if DEBUG`)

### Per-View Integration
- [ ] Add `.debugViewName("ViewName")` to major views
- [ ] Add `.debugViewName()` to all sheets
- [ ] Add `.debugViewName()` to tab views

### Per-Feature Logging
- [ ] Add DataStore CRUD logging
- [ ] Add persistence save/load logging
- [ ] Add navigation logging
- [ ] Add network request logging
- [ ] Add cache operation logging
- [ ] Add trip calculation logging

### Testing
- [ ] Test master switch (on/off)
- [ ] Test view name overlays
- [ ] Test lifecycle logging
- [ ] Test performance counting
- [ ] Test each logging category
- [ ] Test quick presets
- [ ] Verify UserDefaults persistence

### Pre-Release
- [ ] Review and clean up verbose logs
- [ ] Ensure debug code gates with `#if DEBUG` where needed
- [ ] Test with debug disabled
- [ ] Performance test without debug overhead

---

## 🎓 Examples

### Example 1: Debugging Navigation

**Scenario:** Sheet not appearing when expected

**Solution:**
```swift
// Enable navigation logging
debugConfig.logNavigation = true

// In your view:
Button("Show Form") {
    DebugConfig.shared.log(.navigation, "Button tapped, setting showForm = true")
    showForm = true
}

.sheet(isPresented: $showForm) {
    FormView()
        .debugViewName("FormView")
        .onAppear {
            DebugConfig.shared.log(.navigation, "FormView sheet appeared")
        }
}

// Console will show:
// 🧭 [10:30:45] [MyView.swift:45] body - Button tapped, setting showForm = true
// 🧭 [10:30:45] [FormView.swift:12] body - FormView sheet appeared
```

### Example 2: Optimizing Performance

**Scenario:** InfographicsView seems sluggish

**Solution:**
```swift
// Enable performance metrics
debugConfig.showPerformance = true

// Navigate to InfographicsView
// Check overlay - if body count increases rapidly (e.g., 100+ in seconds)

// Console shows:
// 📊 [10:30:45] [InfographicsView.swift:89] body - InfographicsView body computed 10 times
// 📊 [10:30:46] [InfographicsView.swift:89] body - InfographicsView body computed 20 times
// 📊 [10:30:47] [InfographicsView.swift:89] body - InfographicsView body computed 30 times

// Diagnosis: Something is triggering excessive recomputation
// Check @Published properties, @State usage, etc.
```

### Example 3: Tracking Data Flow

**Scenario:** Location not saving correctly

**Solution:**
```swift
// Enable data logging
debugConfig.logDataStore = true
debugConfig.logPersistence = true

// Reproduce issue (create location)

// Console shows full flow:
// 💾 [10:30:45] [DataStore.swift:123] add(_:) - Adding location: Loft
// 📁 [10:30:45] [DataStore.swift:456] storeData() - Encoding 15 locations, 500 events
// 📁 [10:30:45] [DataStore.swift:478] storeData() - Saved to backup.json (345 KB)

// Can verify if save happened and what was saved
```

---

## 🎯 Summary

The LocTrac Debug System provides:

✅ **Non-Intrusive** - Only visible when enabled  
✅ **Granular Control** - Toggle categories independently  
✅ **Production-Safe** - Zero overhead when disabled  
✅ **Easy to Use** - Simple modifier + logging API  
✅ **Informative** - Emoji categories + timestamps  
✅ **Persistent** - Settings saved automatically  

**Ready to debug smarter, not harder!** 🐛✨

---

*LocTrac Debug System v1.0 - Best Practices Guide*  
*April 13, 2026*
