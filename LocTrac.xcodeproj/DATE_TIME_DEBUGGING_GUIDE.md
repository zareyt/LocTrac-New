# Date/Time Issue Debugging Guide

**Issue**: When editing an event for April 11, the form shows April 10 at 6:00 PM

**Status**: Debug logging added, ready for investigation

**Last Updated**: 2026-04-13

---

## 🎯 Your Approach is Fundamentally Correct

Your strategy for handling dates is **exactly right** for a travel app:

### ✅ **Correct Design Principles**

1. **Store dates as UTC midnight** — No timezone ambiguity
   ```swift
   event.date = Date().startOfDay  // Always UTC 00:00:00
   ```

2. **Display dates in local timezone** — User sees dates in their current timezone
   ```swift
   let localDate = localStartOfDay(fromUTCStartOfDay: utcDate)
   ```

3. **Use date-only comparisons** — "April 11" is the same everywhere
   ```swift
   DatePicker(..., displayedComponents: .date)  // ✅ No time component
   ```

### 💡 **Why This Works for Travel Apps**

- **Timezone-agnostic**: "I stayed in Denver on April 11" is meaningful regardless of where you view it
- **No time precision needed**: You don't care that you checked in at 3:47 PM
- **Consistent sorting**: Events always sort by calendar date, not wall-clock time
- **Simple backup/restore**: Dates remain stable across device timezone changes

**Tim's Assessment: Your architecture is solid. The bug is in the execution, not the design.**

---

## 🐛 The Bug: Date Conversion Mismatch

### **Symptom**
- Tap April 11 event → Edit shows "April 10, 6:00 PM"
- 6-hour offset = your Mountain Time (UTC-6) timezone

### **Root Cause Hypothesis**
When `EventFormViewModel` is initialized with an existing event's date, one of these is happening:

1. **Date not normalized**: `viewModel.date` contains a full timestamp instead of start-of-day
2. **Double conversion**: Date is being converted UTC→Local→UTC→Local (compounding errors)
3. **Picker binding issue**: The `get` closure receives a non-midnight timestamp

### **Expected Flow** (Editing April 11 event)
```
Stored UTC:        2026-04-11 00:00:00 +0000
   ↓ localStartOfDay()
Local Display:     2026-04-11 00:00:00 -0600 (Mountain Time)
   ↓ DatePicker shows
User Sees:         "April 11, 2026"
```

### **Actual Buggy Flow** (Hypothesis)
```
Stored UTC:        2026-04-11 00:00:00 +0000
   ↓ (interpreted in local timezone by mistake)
Local Display:     2026-04-10 18:00:00 -0600 (Mountain Time)
   ↓ DatePicker shows
User Sees:         "April 10, 2026 at 6:00 PM" ❌
```

---

## 🔍 Debug Logging Added

I've added comprehensive logging to `ModernEventFormView.swift`:

### **Where Logs Will Appear**

1. **On form open** (`setupInitialValues()`)
   ```
   📅 [DATE DEBUG] === EDITING EXISTING EVENT ===
   📅 [DATE DEBUG] Original viewModel.date: <timestamp>
   📅 [DATE DEBUG] After conversion to local: <timestamp>
   📅 [DATE DEBUG] Local timezone: America/Denver (offset: -6hrs)
   ```

2. **During date conversion** (`localStartOfDay()` / `utcStartOfDay()`)
   ```
   📅 [CONVERT UTC→Local] Input UTC: 2026-04-11 00:00:00 +0000
   📅 [CONVERT UTC→Local] Extracted Y/M/D: 2026/4/11
   📅 [CONVERT UTC→Local] Result local date: 2026-04-11 00:00:00 -0600
   ```

3. **When user interacts with DatePicker** (get/set closures)
   ```
   📅 [PICKER GET] UTC start of day: <timestamp>
   📅 [PICKER GET] Converted to local: <timestamp>
   ```

### **How to Use Debug Logs**

1. **Build and run** the app in Xcode
2. Open **Settings → Debug Settings** (DEBUG builds only)
3. Enable debug mode (or use "Data Debug Only" preset)
4. Open the **Xcode Console** (⇧⌘Y)
5. Tap an April 11 event to edit it
6. **Copy all console output** that starts with `📅`
7. Paste it back to me for analysis

---

## 🧪 Test Cases to Run

### **Test 1: Edit Existing Event**
1. Find an event dated **April 11, 2026**
2. Tap to edit
3. **Expected**: DatePicker shows "April 11, 2026"
4. **Actual**: DatePicker shows "April 10, 2026 at 6:00 PM" (BUG)
5. **Check console** for date conversion logs

### **Test 2: Create New Event**
1. Tap a date in the calendar (e.g., April 15)
2. Create a new event
3. **Expected**: DatePicker shows "April 15, 2026"
4. **Actual**: Does it show the correct date?
5. **Check console** for initialization logs

### **Test 3: Multi-Day Event**
1. Create an event from April 20-22
2. Verify all 3 events are created correctly
3. Edit each one — do they show the correct date?

### **Test 4: Timezone Change Simulation**
1. Create an event on April 11
2. **Change device timezone** in Settings → General → Date & Time
   - From Mountain Time (Denver) to Pacific Time (Los Angeles)
3. Re-open the app
4. Does the event still show April 11? (It should!)

---

## 🛠️ Potential Fixes (After We See Logs)

### **Fix Option 1: Ensure ViewModel Date is Always UTC Start of Day**

If logs show `viewModel.date` has a non-midnight timestamp:

```swift
// In EventFormViewModel initialization (wherever that is)
init(event: Event) {
    self.date = event.date.startOfDay  // ✅ Force to start of day
    // ... rest of init
}
```

### **Fix Option 2: Simplify DatePicker Binding**

If the double-conversion is the issue:

```swift
DatePicker(
    "Start Date",
    selection: Binding<Date>(
        get: {
            // Extract Y/M/D from UTC, rebuild as local midnight
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
            let components = utcCal.dateComponents([.year, .month, .day], from: viewModel.date)
            
            var localCal = Calendar.current
            return localCal.date(from: components) ?? viewModel.date
        },
        set: { newLocalDate in
            // Extract Y/M/D from local, rebuild as UTC midnight
            var localCal = Calendar.current
            let components = localCal.dateComponents([.year, .month, .day], from: newLocalDate)
            
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
            viewModel.date = utcCal.date(from: components) ?? newLocalDate.startOfDay
        }
    ),
    displayedComponents: .date
)
```

### **Fix Option 3: Use DateComponents Instead of Date**

If the issue persists, consider storing `DateComponents` in the view model:

```swift
// Instead of:
@Published var date: Date

// Use:
@Published var dateComponents: DateComponents  // Y/M/D only, no timezone

// Convert to UTC Date only when saving
var utcDate: Date {
    var utcCal = Calendar(identifier: .gregorian)
    utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
    return utcCal.date(from: dateComponents) ?? Date()
}
```

---

## 📊 What to Report Back

When you run the tests, please share:

1. **Full console output** with `📅` emoji logs
2. **Screenshots** of the date picker showing the wrong date
3. **Your device timezone** (Settings → General → Date & Time)
4. **Sample event data** from the console (if any `Event` objects are printed)

With this information, I can pinpoint exactly where the conversion is failing.

---

## 🎓 Date/Time Best Practices Validation

Your current approach **already follows** these best practices:

| Practice | Your Implementation | Status |
|---|---|---|
| Store dates in a consistent timezone | UTC midnight | ✅ Correct |
| Extract only Y/M/D components | `dateComponents([.year, .month, .day])` | ✅ Correct |
| Use timezone-aware calendars | `Calendar(identifier: .gregorian)` with explicit TZ | ✅ Correct |
| Display dates in user's local timezone | `Calendar.current` | ✅ Correct |
| Avoid time components for date-only data | `displayedComponents: .date` | ✅ Correct |
| Use start-of-day normalization | `.startOfDay` extension | ✅ Correct |

**Conclusion**: Your architecture is excellent. This is a localized bug, not a systemic design flaw.

---

## 🚀 Next Steps

1. **Enable debug logging** (settings menu)
2. **Run Test Case 1** (edit existing event)
3. **Copy console output** (all `📅` logs)
4. **Paste here** for analysis
5. I'll identify the exact failure point
6. We'll implement the precise fix

Let's find this bug! 🐛🔍

---

*Guide created 2026-04-13 by Claude AI Assistant*
*Part of LocTrac v1.5 development*
