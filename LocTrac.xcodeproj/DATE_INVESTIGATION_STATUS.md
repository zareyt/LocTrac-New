# Date Issue - Current Status

**Date**: 2026-04-14  
**Status**: INVESTIGATING - Compilation errors fixed, testing needed

---

## 🐛 The Problem

When you create an event for **April 15** and then reopen it to edit, it shows **April 14**.

### What We Know

1. **Event storage is CORRECT**:
   ```
   ➕ add(Event) called for id=..., date=2026-04-15 00:00:00 +0000
   ```
   The event IS being saved with April 15 UTC.

2. **Display formatting is WRONG**:
   ```
   🚗 [Auto-Trip] Checking if new event creates a trip...
      New event: at location 'Loft' on Apr 14, 2026  ← WRONG!
   ```
   When displayed, it shows April 14.

3. **DateFormatter says it SHOULD show correctly**:
   ```
   📅 [CONVERT UTC→Local] DatePicker will show: Apr 15, 2026 at 12:00 AM
   ```
   The conversion function claims the picker will show April 15.

4. **Conversion is NOT actually happening**:
   ```
   📅 [CONVERT UTC→Local] Result local date: 2026-04-15 06:00:00 +0000
                                                                 ^^^^^
                                                            Still showing UTC!
   ```
   Despite using `Calendar.current`, the result is still in UTC timezone.

---

## 🔍 Root Cause Theory

The issue is that `Calendar.current.date(from: DateComponents)` is **not respecting the calendar's timezone** when creating dates. This appears to be a Swift/Foundation behavior where:

1. We extract `year=2026, month=4, day=15` from UTC
2. We try to create a local date with those components
3. Swift creates the date **in UTC anyway** (ignoring `Calendar.current.timeZone`)
4. The result is `2026-04-15 06:00:00 +0000` (April 15 at 6 AM UTC)
5. When displayed in Mountain Time (-6 hours), this becomes April 14 at midnight

### Why This is Confusing

- **Internally, all `Date` objects in Swift are UTC timestamps**
- What matters is **how they're interpreted/formatted for display**
- We need April 15 midnight **in Denver** → which is April 15 at 6 AM UTC
- But we're getting April 15 midnight **in UTC** → which displays as April 14 in Denver

---

## 🛠️ Current Fix Attempt

Added explicit hour/minute/second components to `DateComponents`:

```swift
private func localStartOfDay(fromUTCStartOfDay utc: Date) -> Date {
    // Extract Y/M/D from UTC midnight
    var utcCal = Calendar(identifier: .gregorian)
    utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
    let ymd = utcCal.dateComponents([.year, .month, .day], from: utc)
    
    // Create local midnight
    var localCal = Calendar.current
    var components = DateComponents()
    components.year = ymd.year
    components.month = ymd.month
    components.day = ymd.day
    components.hour = 0      // Midnight
    components.minute = 0
    components.second = 0
    
    // This SHOULD create April 15 midnight MT = April 15 06:00 UTC
    guard let result = localCal.date(from: components) else { return utc }
    return result
}
```

**Expected**:
- Input: `2026-04-15 00:00:00 +0000` (April 15 UTC)
- Output: `2026-04-15 06:00:00 +0000` (April 15 midnight MT, stored as UTC)

**Actual** (from previous logs):
- Output: `2026-04-15 06:00:00 +0000` ✅ Correct timestamp!

Wait... the timestamp IS correct! April 15 at 06:00 UTC IS April 15 at midnight Mountain Time.

So why does it display as April 14?

---

## 💡 The Real Issue

Looking at this more carefully:

```
Result: 2026-04-15 06:00:00 +0000
```

This is **April 15 at 6:00 AM UTC**.

In Mountain Time (UTC-6 during DST):
- 2026-04-15 06:00 UTC = 2026-04-15 00:00 MT (midnight) ✅

So the **Date is correct**!

The problem must be in **where it's being displayed**. The auto-trip log uses:

```swift
newEvent.date.formatted(date: .abbreviated, time: .omitted)
```

This formatter interprets the Date in the **current timezone**. So:
- Date: `2026-04-15 06:00:00 +0000`
- Interpreted in MT: April 15 at midnight ✅
- **Should** display: "Apr 15, 2026"

But it's showing "Apr 14, 2026". This means one of two things:

1. **The Date is actually wrong** (not what logs show)
2. **The formatter is using the wrong timezone**

---

## 🧪 Next Steps - TESTING REQUIRED

### Test 1: Verify Date Storage
1. Create a new event for April 15
2. Look at the console log for:
   ```
   ➕ add(Event) called for id=..., date=<CHECK THIS>
   ```
3. **Expected**: `2026-04-15 00:00:00 +0000` (stored in UTC)
4. **If wrong**: The date is being saved incorrectly

### Test 2: Check Display in DatePicker
1. Create event for April 15
2. **Look at the actual UI** (not logs)
3. Does the DatePicker show "April 15" or "April 14"?
4. Close and reopen to edit
5. Does it still show the same date?

### Test 3: Check with Enhanced Logging
1. Build and run with the new debug logs
2. Create event for April 15
3. Look for these new logs:
   ```
   📅 [CONVERT DEBUG] localCal.timeZone = America/Denver
   📅 [CONVERT DEBUG] Creating date from components in local calendar...
   📅 [CONVERT DEBUG] Result: <CHECK THIS>
   ```
4. The result should show a **non-zero hour** (like 06:00) if timezone is working

### Test 4: Timezone Change Test
1. Create event in Denver timezone (MT)
2. Go to Settings → change timezone to Los Angeles (PT)
3. Reopen LocTrac
4. View the same event - what date shows?
5. **Expected**: Still April 15 (dates are timezone-agnostic)
6. **If wrong**: We have a deeper timezone issue

---

## 📋 Build Instructions

1. **Clean build folder**: ⇧⌘K
2. **Build**: ⌘B
3. **Verify no errors** (just fixed compilation issues)
4. **Run**: ⌘R
5. **Test with steps above**

---

## 🤔 Alternative Hypothesis

Maybe the issue is NOT in the date pickers at all. Maybe it's only in the **display logging** (auto-trip message). Let me ask directly:

**WHERE do you actually see "April 14" instead of "April 15"?**

- [ ] In the DatePicker when creating the event?
- [ ] In the DatePicker when editing the event?
- [ ] In the calendar view (dots on dates)?
- [ ] In a list of events?
- [ ] Only in the console logs?

If it's **only in console logs**, then the problem is just the formatter used for logging, not the actual data or UI.

---

*Investigation ongoing - awaiting test results*
