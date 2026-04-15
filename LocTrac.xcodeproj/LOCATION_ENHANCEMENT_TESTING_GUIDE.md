# Location Data Enhancement - Testing Guide

## How to Access

1. Open LocTrac app
2. Tap the **menu button** (three dots) in the top-left
3. Select **"Enhance Location Data"**

## What to Test

### Test Scenario 1: Complete Data with "City, XX" Format
**Setup:** Create an event with:
- City: "Denver, CO"
- State: "Colorado"
- Country: "United States"
- GPS: (39.7392, -104.9903)

**Expected Result:** City cleaned to "Denver", all other fields unchanged

---

### Test Scenario 2: Valid GPS, Missing State/Country
**Setup:** Create an event with:
- City: "San Francisco"
- State: (empty)
- Country: (empty)
- GPS: (37.7749, -122.4194)

**Expected Result:** 
- City: "San Francisco"
- State: "California" (from GPS)
- Country: "United States" (from GPS)

---

### Test Scenario 3: Valid GPS with "City, XX" Format
**Setup:** Create an event with:
- City: "Los Angeles, CA"
- State: (empty)
- Country: (empty)
- GPS: (34.0522, -118.2437)

**Expected Result:**
- City: "Los Angeles" (cleaned)
- State: "California" (from GPS)
- Country: "United States" (from GPS)

---

### Test Scenario 4: No GPS, US State Code
**Setup:** Create an event with:
- City: "Austin, TX"
- State: (empty)
- Country: (empty)
- GPS: (0, 0)

**Expected Result:**
- City: "Austin"
- State: "Texas" (from code)
- Country: "United States"
- GPS: Still (0, 0)

---

### Test Scenario 5: No GPS, Country Code
**Setup:** Create an event with:
- City: "London, GB"
- State: (empty)
- Country: (empty)
- GPS: (0, 0)

**Expected Result:**
- City: "London"
- State: "England" (from forward geocoding)
- Country: "United Kingdom" (from code)
- GPS: (~51.5074, -0.1278) - from forward geocoding

---

### Test Scenario 6: Invalid Code (Should Error)
**Setup:** Create an event with:
- City: "Paris, XY"
- State: (empty)
- Country: (empty)
- GPS: (0, 0)

**Expected Result:** Error - "Unknown code 'XY' in 'Paris, XY'"

---

### Test Scenario 7: Completely Missing Data (Should Error)
**Setup:** Create an event with:
- City: (empty)
- State: (empty)
- Country: (empty)
- GPS: (0, 0)

**Expected Result:** Error - "Missing city name"

---

## How to Create Test Events

### Option 1: From Calendar
1. Go to **Calendar** tab
2. Tap **+** to add event
3. Select **"Other"** location
4. Enter test data as described above
5. Save event

### Option 2: Edit Existing Event
1. Go to **Calendar** tab
2. Tap on any event
3. Tap to edit
4. Change location to **"Other"**
5. Modify city/state/country/GPS as needed
6. Save changes

## Running the Enhancement

1. After creating test events, go to menu
2. Select **"Enhance Location Data"**
3. Review the information screen
4. Tap **"Start Enhancement"**
5. Wait for processing to complete
6. Review results

## What to Check in Results

### Success Screen Should Show:
- ✅ Number of successful updates
- ❌ Number of errors
- 📋 List of errors (if any)
- 📝 Sample of successful updates

### For Each Error:
- Event date
- Original city/state/country
- Error message explaining why it couldn't be fixed

### After Processing:
1. Go back to **Calendar** or **Travel History**
2. Find your test events
3. Verify the data was updated correctly
4. Check that errors still have original (bad) data

## Expected Behavior

### Processing Should:
- ✅ Show progress bar
- ✅ Display current event number
- ✅ Take ~50-100ms per event (rate limited)
- ✅ Not crash or freeze
- ✅ Complete with results screen

### Updates Should:
- ✅ Persist after closing the app
- ✅ Show in Travel History
- ✅ Show when editing events
- ✅ Not affect events that were skipped due to errors

## Known Limitations

1. **Geocoding Limits:** Apple limits to ~50 requests/minute
   - Our 50ms delay should stay under this limit
   - If you have 1000+ events, it may take a few minutes

2. **GPS Accuracy:** Reverse geocoding may return different results based on:
   - Coordinate precision
   - Apple's mapping data updates
   - Region boundaries

3. **Country Codes:** Only ~65 countries supported initially
   - See `CountryCodeMapper.swift` for full list
   - Can be expanded as needed

4. **US States Only:** State code parsing only works for US states
   - Canadian provinces, Australian states, etc. not included
   - International regions will come from GPS or forward geocoding

## Troubleshooting

### Problem: No events processed
**Solution:** Make sure you have events in your calendar

### Problem: All events show errors
**Solution:** Check that events have either:
- Valid GPS coordinates, OR
- City in "City, XX" format with valid code

### Problem: Geocoding errors
**Solution:** 
- Check internet connection
- Try again (geocoding service may be temporarily unavailable)
- Reduce batch size by archiving old events

### Problem: Wrong state/country populated
**Solution:**
- GPS coordinates may be inaccurate
- Manually edit the event to correct
- For future events, use "Get Current Location" for accurate GPS

## Success Metrics

After enhancement, you should see:
- ✅ No more "City, XX" formats
- ✅ All events with GPS have state and country
- ✅ All US events have proper state names
- ✅ International events properly identified
- ✅ Clear error reports for unfixable data

## Next Steps After Testing

1. **Review Errors:** Manually fix events that couldn't be auto-enhanced
2. **Verify Data:** Spot-check events in Travel History
3. **Backup:** Export a new backup with clean data
4. **Future Events:** Use proper location selection or GPS to avoid format issues

---

*Testing Guide v1.0 - 2026-04-11*
