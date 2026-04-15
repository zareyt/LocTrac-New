# 🔧 Critical Fix: Sheet Presentation Hierarchy

## The Real Problem Discovered

Looking at your console output:
```
🔵 [TimelineRestoreView] Start date button tapped
🔵 [TimelineRestoreView] End date button tapped
📆 [TimelineRestoreView] Date picker sheet appeared
...
Attempt to present <...> while a presentation is in progress.
Attempt to present <...> while a presentation is in progress.
```

**Both date buttons were triggered!** This caused **TWO sheet presentations** to be queued up, causing the conflict.

## Root Cause

The `.sheet()` modifier was attached to the **Section** inside the List, not to the main view. This creates a **nested presentation context** that SwiftUI doesn't handle well.

### Before (WRONG) ❌
```swift
private var timelineFilterSection: some View {
    Section {
        // Date picker buttons
    }
    .sheet(isPresented: $showingDatePicker) {  // ❌ Sheet attached to Section
        // Date picker content
    }
}

private var timelineRestoreView: some View {
    List {
        timelineFilterSection  // Contains its own sheet
    }
}
```

**Problem:** When the section is inside a List, inside a NavigationStack, inside another sheet (from BackupExportView), the presentation hierarchy gets confused.

### After (CORRECT) ✅
```swift
private var timelineFilterSection: some View {
    Section {
        // Date picker buttons (NO sheet modifier here)
    }
}

private var timelineRestoreView: some View {
    List {
        timelineFilterSection
    }
    .sheet(isPresented: $showingDatePicker) {  // ✅ Sheet attached at top level
        // Date picker content
    }
}
```

**Solution:** The `.sheet()` modifier is now at the **top level of timelineRestoreView**, which is the proper presentation context.

## Why This Matters

### Presentation Hierarchy (Correct Order):
1. **StartTabView** (root)
   - `.sheet` → **BackupExportView**
     - `.sheet` → **TimelineRestoreView**
       - `.sheet` → **Date Picker** ✅ (at view level)

### What Was Happening (Broken):
1. **StartTabView** (root)
   - `.sheet` → **BackupExportView**
     - `.sheet` → **TimelineRestoreView**
       - **List**
         - **Section**
           - `.sheet` → **Date Picker** ❌ (nested too deep)

SwiftUI's presentation system can't properly coordinate sheets that are nested inside List → Section → Sheet.

## Additional Fix: Double-Tap Protection

Looking at your console, both buttons triggered almost simultaneously:
```
🔵 [TimelineRestoreView] Start date button tapped
🔵 [TimelineRestoreView] End date button tapped  ← Same moment!
```

This suggests you might have tapped near both buttons, or there's a UI layout issue causing both to trigger.

### Optional: Add Button Disable During Sheet Presentation

If you want extra protection against double-taps:

```swift
Button {
    print("🔵 [TimelineRestoreView] Start date button tapped")
    editingStartDate = true
    showingDatePicker = true
} label: {
    // ... button content
}
.disabled(showingDatePicker)  // ← Prevent taps while sheet is presenting

Button {
    print("🔵 [TimelineRestoreView] End date button tapped")
    editingStartDate = false
    showingDatePicker = true
} label: {
    // ... button content
}
.disabled(showingDatePicker)  // ← Prevent taps while sheet is presenting
```

## Summary of Changes

### Change #1: Removed `.sheet()` from Section
**File:** `TimelineRestoreView.swift`
**Function:** `timelineFilterSection`
- Removed the `.sheet(isPresented: $showingDatePicker)` modifier from the Section
- Section now only contains the UI elements

### Change #2: Added `.sheet()` to Main View
**File:** `TimelineRestoreView.swift`
**Function:** `timelineRestoreView`
- Added the `.sheet(isPresented: $showingDatePicker)` modifier to the main List view
- Now at the proper hierarchy level

## Expected Result

✅ **No more "presentation is in progress" errors**  
✅ **Date picker opens cleanly**  
✅ **Only ONE sheet presentation happens**  
✅ **Proper presentation hierarchy**  

## Test Again

1. **Clean build** (just to be safe)
2. **Run the app**
3. **Navigate to:** Backup & Import → Import from Backup File → Select file
4. **Tap ONE date button** (From or To)
5. **Sheet should open and stay open!**

The error should be gone now. The sheet modifier is at the correct level in the view hierarchy.

---

## Technical Explanation

SwiftUI's presentation system uses a **presentation coordinator** that manages all sheet presentations. When you attach `.sheet()` to a nested view (like a Section inside a List), that nested view tries to create its own presentation context. But it's already inside multiple presentation layers:

```
NavigationStack (in BackupExportView sheet)
  └─ List
       └─ Section
            └─ .sheet()  ← Too deep! Can't coordinate with parent sheets
```

By moving `.sheet()` to the top level of the view:

```
NavigationStack (in BackupExportView sheet)
  └─ List
       └─ Section (just UI)
  └─ .sheet()  ← At proper level! Can coordinate with parent
```

The presentation coordinator can now properly manage all three sheets in the hierarchy:
1. BackupExportView sheet (from StartTabView)
2. TimelineRestoreView sheet (from BackupExportView)
3. Date picker sheet (from TimelineRestoreView) ✅

All three are now at the proper levels and won't conflict!
