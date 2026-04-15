# Location Data Enhancement - Retry Errors Feature

**Date**: 2026-04-13  
**Status**: ✅ Complete - Ready for Testing

---

## 🎯 Problem

After the first enhancement pass, some items fail with network errors or rate limiting. The user has to run the entire enhancement again (processing all 1500+ items) just to retry the 10-20 that failed.

**User Request:**
> "I want an option after the first pass to go back and reprocess the ones that return as network errors. I don't want the full dataset reprocessed."

---

## ✅ Solution: "Retry Errors" Button

Added a **"Retry Errors"** button that appears in the results summary after the first pass completes. This button:

1. **Only processes items that failed** (not skipped items)
2. **Reuses rate limiting logic** (won't hit Apple's limit again)
3. **Updates results in place** (shows real-time progress)
4. **Can be run multiple times** (if some still fail)

---

## 🖼️ UI Changes

### Results Summary - Before:
```
Summary:
✅ 495 Successful
❌ 15 Errors
⏭️ 1200 Skipped

Note: Skipped items don't need processing...
```

### Results Summary - After (with errors):
```
Summary:
✅ 495 Successful
❌ 15 Errors
⏭️ 1200 Skipped

🔄 Retry 15 Errors →

Tap 'Retry Errors' to reprocess only the failed items.
This is useful for network errors or rate limiting issues.
```

### Results Summary - During Retry:
```
Summary:
✅ 495 Successful
❌ 15 Errors
⏭️ 1200 Skipped

⏳ Retrying errors...

(Button disabled during retry)
```

### Results Summary - After Retry:
```
Summary:
✅ 505 Successful  ← Updated!
❌ 5 Errors        ← Updated!
⏭️ 1200 Skipped

🔄 Retry 5 Errors →  ← Still available if errors remain
```

---

## 🔧 Implementation Details

### New State Variable:
```swift
@State private var isRetryingErrors = false  // Track if we're in error retry mode
```

### New Function:
```swift
private func retryErrorsOnly() async {
    // 1. Filter for error items only
    let errorLocations = locationResults.filter { 
        if case .error = $0.result { return true }
        return false
    }
    let errorEvents = eventResults.filter { 
        if case .error = $0.result { return true }
        return false
    }
    
    // 2. Process only those items
    for location in errorLocations {
        let result = await enhancer.processLocation(&location)
        // Update result in place
    }
    
    for event in errorEvents {
        let result = await enhancer.processEvent(&event)
        // Update result in place
    }
}
```

### UI Integration:
```swift
// In results summary section
if errorCount > 0 && !isRetryingErrors {
    Button {
        Task {
            await retryErrorsOnly()
        }
    } label: {
        HStack {
            Image(systemName: "arrow.clockwise.circle.fill")
            Text("Retry \(errorCount) Errors")
            Spacer()
            Image(systemName: "chevron.right")
        }
    }
}

if isRetryingErrors {
    HStack {
        ProgressView()
        Text("Retrying errors...")
    }
}
```

---

## 📊 Workflow

### First Pass:
```
1. User taps "Start Enhancement"
2. Processing 1515 items...
   ├─ 495 successful
   ├─ 15 errors (network/rate limit)
   └─ 1200 skipped
3. Shows results with "Retry 15 Errors" button
```

### Retry Pass:
```
1. User taps "Retry 15 Errors"
2. Processing only 15 error items...
   ├─ 10 now successful (network recovered)
   ├─ 5 still errors (bad data)
3. Updates results:
   ├─ 505 successful (+10)
   ├─ 5 errors (-10)
   └─ 1200 skipped (unchanged)
4. Shows "Retry 5 Errors" button again
```

### Multiple Retries:
```
User can keep tapping "Retry Errors" until:
- All errors are resolved (button disappears)
- Or errors are persistent (bad data, not network)
```

---

## 🔍 Console Output

### First Pass:
```
✅ Enhancement Complete
   ✅ Success: 495
   ❌ Errors: 15
   ⏭️ Skipped: 1200
```

### User Taps "Retry Errors":
```
🔄 RETRY ERRORS: Processing 15 failed items
   📍 Locations: 3
   📅 Events: 12

   ✅ Retry success: location 'Some Location'
   ✅ Retry success: event on Apr 5, 2024
   ❌ Still error: event on Apr 6, 2024 - Missing city name
   ✅ Retry success: event on Apr 7, 2024
   ...

✅ Retry Complete
   ✅ Now successful: 10
   ❌ Still errors: 5
```

### Results Update Automatically:
- Success count increases from 495 → 505
- Error count decreases from 15 → 5
- "Retry 5 Errors" button still available

---

## ✨ Benefits

1. **Faster retry** - Only processes 15 items instead of 1515
2. **Network recovery** - Handles temporary network issues gracefully
3. **Multiple attempts** - Can retry as many times as needed
4. **Real-time feedback** - Shows progress and updated counts
5. **Non-destructive** - Doesn't affect successful or skipped items
6. **Rate limit aware** - Still uses rate limiting logic (100ms delays)

---

## 🧪 Testing Scenarios

### Scenario 1: Network Recovers
**Setup:**
- First pass: 15 network errors
- Network is now stable

**Expected:**
1. Tap "Retry 15 Errors"
2. All 15 succeed
3. Button disappears (no more errors)

**Console:**
```
🔄 RETRY ERRORS: Processing 15 failed items
   ✅ Retry success: event on Apr 5, 2024
   ... (15 successes)
✅ Retry Complete
   ✅ Now successful: 15
   ❌ Still errors: 0
```

### Scenario 2: Mixed Results
**Setup:**
- First pass: 10 network errors, 5 bad data errors

**Expected:**
1. Tap "Retry 15 Errors"
2. 10 network errors succeed
3. 5 bad data errors still fail
4. "Retry 5 Errors" button still available

**Console:**
```
🔄 RETRY ERRORS: Processing 15 failed items
   ✅ Retry success: event on Apr 5, 2024
   ... (10 successes)
   ❌ Still error: event on Apr 10, 2024 - Missing city name
   ... (5 persistent errors)
✅ Retry Complete
   ✅ Now successful: 10
   ❌ Still errors: 5
```

### Scenario 3: Rate Limited Again
**Setup:**
- Retry immediately after first pass
- Rate limit not reset yet

**Expected:**
1. Tap "Retry 15 Errors"
2. Some succeed, some rate limited
3. "Retry X Errors" button updates with remaining count

**Console:**
```
🔄 RETRY ERRORS: Processing 15 failed items
   ⏸️ Rate limit reached - waiting 5s
   ✅ Retry success: event on Apr 5, 2024
   ... (10 successes)
   ⏸️ Rate limited: event on Apr 10, 2024
   ... (5 still rate limited)
✅ Retry Complete
   ✅ Now successful: 10
   ❌ Still errors: 5
```

---

## 🎯 User Flow

### Happy Path:
```
1. Start Enhancement
   ↓
2. Wait for completion (1-2 min)
   ↓
3. See results: 495 success, 15 errors
   ↓
4. Tap "Retry 15 Errors"
   ↓
5. Wait for retry (5-10 sec)
   ↓
6. See updated results: 505 success, 5 errors
   ↓
7. (Optional) Tap "Retry 5 Errors" again
   ↓
8. All errors resolved or identified as bad data
```

### With Multiple Retries:
```
Pass 1: 1515 items → 495 success, 15 errors
Retry 1: 15 items → 505 success, 5 errors
Retry 2: 5 items → 508 success, 2 errors
Retry 3: 2 items → 510 success, 0 errors ✅
```

---

## ⚙️ Technical Details

### Error Filtering:
```swift
// Only items with .error result
let errorLocations = locationResults.enumerated().filter {
    if case .error = $0.element.result { return true }
    return false
}

// Skipped items are NOT retried
// Successful items are NOT retried
```

### Result Updates:
```swift
// Find original item in store
guard let location = store.locations.first(where: { $0.id == locationResult.locationID })

// Process it
let result = await enhancer.processLocation(&mutableLocation)

// Update result in place
if case .success = result {
    locationResults[index] = LocationResult(
        // ... same original data ...
        result: .success  // ← Updated result
    )
    store.update(mutableLocation)  // ← Save to store
}
```

### Rate Limiting:
```swift
// 100ms delay between retry items (safer than 50ms)
try? await Task.sleep(nanoseconds: 100_000_000)

// Rate limiter still active
await checkRateLimit()  // Called by enhancer
```

---

## 📝 Summary

**Changes Made:**
1. ✅ Added `isRetryingErrors` state variable
2. ✅ Added "Retry Errors" button to results summary
3. ✅ Added `retryErrorsOnly()` function
4. ✅ Updated footer text with instructions
5. ✅ Added progress indicator during retry

**File Modified:**
- `LocationDataEnhancementView.swift`

**Result:**
- User can retry only failed items
- No need to reprocess entire dataset
- Can retry multiple times until all errors resolved
- Real-time feedback with updated counts

**Ready to test!** 🚀

Run enhancement, get some errors, tap "Retry Errors", and watch it process only the failed items!
