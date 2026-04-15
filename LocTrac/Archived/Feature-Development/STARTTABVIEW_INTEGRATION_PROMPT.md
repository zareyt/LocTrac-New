# Prompt: Wire Up Location Data Enhancement in StartTabView

Use this prompt to complete the integration of the Location Data Enhancement menu in HomeView.

---

## 📝 Prompt for AI Assistant

```
I've added a "Enhance Location Data" menu item to HomeView's toolbar. Now I need to wire it up in StartTabView.

Please update StartTabView.swift to:

1. Add state variable for the sheet:
   @State private var showLocationDataEnhancement = false

2. Add the sheet modifier (following the pattern of other sheets in StartTabView):
   .sheet(isPresented: $showLocationDataEnhancement) {
       NavigationStack {
           LocationDataEnhancementView()
               .environmentObject(store)
       }
   }

3. Update the HomeView initialization to pass the callback:
   Add onShowLocationDataEnhancement: { showLocationDataEnhancement = true }

Follow these requirements:
- Use the existing sheet orchestration pattern from StartTabView
- Place state variable with other @State variables
- Place sheet modifier with other .sheet() modifiers
- Use NavigationStack wrapper (consistent with other sheets)
- Pass environmentObject(store) to the view
- Follow project conventions from CLAUDE.md

LocationDataEnhancementView should already exist in the project (created in v1.5).
If it doesn't exist, let me know and I'll provide the file.
```

---

## 🔍 What to Look For in StartTabView

You'll need to find these sections:

### State Variables Section
Look for other `@State` variables like:
- `showAbout`
- `showActivitiesManager`
- `showBackupExport`
- `showTripsManagement`
- etc.

Add here:
```swift
@State private var showLocationDataEnhancement = false
```

### Sheet Modifiers Section
Look for `.sheet(isPresented:)` modifiers for the above states.

Add here:
```swift
.sheet(isPresented: $showLocationDataEnhancement) {
    NavigationStack {
        LocationDataEnhancementView()
            .environmentObject(store)
    }
}
```

### HomeView Initialization Section
Look for where HomeView is created in the TabView.

Update the initializer to include the new callback:
```swift
onShowLocationDataEnhancement: {
    showLocationDataEnhancement = true
}
```

---

## ✅ Expected Result

After making these changes:

1. **Build succeeds** with no errors
2. **HomeView shows menu** icon in top-left toolbar
3. **Menu contains** "Enhance Location Data" option
4. **Tapping menu item** presents LocationDataEnhancementView as a sheet
5. **Sheet displays** with navigation bar and content
6. **Dismissing sheet** returns to HomeView

---

## 🧪 Quick Test

```swift
// Minimal test in StartTabView.onAppear
print("🔍 showLocationDataEnhancement: \(showLocationDataEnhancement)")

// After tapping menu item, should log:
print("🎯 Location Data Enhancement sheet triggered")
```

---

## 📚 Reference Files

- `HOME_VIEW_ENHANCEMENT_MENU.md` - This implementation summary
- `CLAUDE.md` - Project conventions and patterns
- `HomeView.swift` - Updated with menu and callback
- `LocationDataEnhancementView.swift` - The view to present (should exist)
- `StartTabView.swift` - File to modify (your current task)

---

*STARTTABVIEW_INTEGRATION_PROMPT.md — LocTrac v1.5 — Tim Arey — 2026-04-14*
