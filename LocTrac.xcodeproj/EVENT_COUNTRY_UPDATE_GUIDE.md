# Event Country Update Feature

## Overview

The Event Country Geocoder automatically detects and fills in missing country information for your events using three intelligent methods.

## How It Works

### 1. Parse City Strings
Extracts country from city names formatted like:
- `"Caen, France"` → `"France"`
- `"Paris, France"` → `"France"`
- `"Tokyo, Japan"` → `"Japan"`

### 2. Detect US States
Recognizes US state codes and converts to "United States":
- `"Castle Rock, CO"` → `"United States"`
- `"Denver, Colorado"` → `"United States"`
- `"New York, NY"` → `"United States"`

### 3. Reverse Geocode Coordinates
Uses GPS coordinates to look up country:
- `(39.7392, -104.9903)` → `"United States"`
- `(48.8566, 2.3522)` → `"France"`
- `(35.6762, 139.6503)` → `"Japan"`

## Usage

### Option 1: User-Friendly Interface (Recommended)

1. **Open Menu**
   - Tap the menu button (⋯)

2. **Select "Update Event Countries"**
   - Located under "Backup & Import"

3. **Review Summary**
   - See how many events need updating
   - View what will be updated

4. **Start Update**
   - Tap "Update X Events" button
   - Watch progress in real-time
   - See results when complete

### Option 2: Programmatic Usage

```swift
// In any view with access to DataStore
Button("Update Countries") {
    Task {
        let (updated, failed) = await EventCountryGeocoder
            .updateAllMissingCountries(store: store)
        print("✅ Updated \(updated) events")
        print("❌ Failed \(failed) events")
    }
}
```

## What Gets Updated

### Events Updated
- ✅ Events with `country == nil`
- ✅ Events with `country == ""` (empty)
- ✅ Events where location also has no country

### Events Skipped
- ⏭️ Events already having a country
- ⏭️ Events inheriting country from location

## Examples

### Before Update
```json
{
  "city": "Caen, France",
  "country": null,  // Missing!
  "latitude": 49.1829,
  "longitude": -0.3707
}
```

### After Update
```json
{
  "city": "Caen, France",
  "country": "France",  // ✅ Detected!
  "latitude": 49.1829,
  "longitude": -0.3707
}
```

## Features

### Smart Detection
- Tries city parsing first (fastest)
- Falls back to geocoding if needed
- Handles multiple formats

### Rate Limited
- 100ms delay between events
- Prevents API throttling
- Respectful of Apple's services

### Safe & Non-Destructive
- Only updates missing countries
- Never overwrites existing data
- Saves to backup.json when complete

### Progress Tracking
- Real-time progress bar
- Current event count
- Success/failure counters

## Performance

### Speed
- **Parsing**: Instant (< 1ms per event)
- **Geocoding**: ~100-500ms per event
- **Rate Limit**: 100ms between requests

### Typical Times
- 10 events: ~1-5 seconds
- 100 events: ~10-60 seconds
- 1000 events: ~2-10 minutes

### Network Usage
- Only geocoding requires network
- Parsing works offline
- Minimal data transfer

## Supported Formats

### City String Formats

**Works:**
- ✅ `"City, Country"` → `"Country"`
- ✅ `"City, State"` → `"United States"` (if 2-letter state)
- ✅ `"City, ST"` → `"United States"` (uppercase state code)

**Doesn't Work:**
- ❌ `"City"` (no comma) → Tries geocoding
- ❌ `"City State"` (no comma) → Tries geocoding

### State Codes Recognized

All 50 US states and territories:
- AL, AK, AZ, AR, CA, CO, CT, DE, FL, GA
- HI, ID, IL, IN, IA, KS, KY, LA, ME, MD
- MA, MI, MN, MS, MO, MT, NE, NV, NH, NJ
- NM, NY, NC, ND, OH, OK, OR, PA, RI, SC
- SD, TN, TX, UT, VT, VA, WA, WV, WI, WY
- DC, PR, VI, GU, AS, MP

## Error Handling

### Common Issues

**No Network**
- Parsing still works
- Geocoding fails gracefully
- Shows as "failed" in results

**Invalid Coordinates**
- (0, 0) coordinates skipped
- No geocoding attempted
- Counted as failed

**API Rate Limits**
- 100ms delay prevents this
- Adjust in code if needed
- Retry later if hit

**No City Data**
- Event skipped
- Cannot determine country
- Manual edit needed

## Menu Location

```
⋯ Menu
├─ About LocTrac
├─ Travel History
├─ ─────────────
├─ Manage Locations
├─ Manage Activities
├─ Manage Trips
├─ ─────────────
├─ Backup & Import
└─ Update Event Countries  ← HERE
```

## Tips

### Best Results
1. **Run on Wi-Fi**: Faster geocoding
2. **Patience**: Let it complete (don't interrupt)
3. **Backup First**: Use Backup & Import before updating
4. **Check Results**: Review Travel History after

### When to Run
- After importing data
- When you notice "Unknown" countries
- After adding many events manually
- Periodically for maintenance

### Manual Override
If auto-detection is wrong:
1. Edit the event manually
2. Set correct country
3. Won't be overwritten (has country now)

## Files

### Code Files
- `EventCountryGeocoder.swift` - Core geocoding logic
- `EventCountryUpdaterView.swift` - User interface
- `StartTabView.swift` - Menu integration

### How It Saves
- Updates events in DataStore
- Calls `store.storeData()`
- Saves to `backup.json`
- Changes persist automatically

## Privacy

### Data Stays Local
- ✅ All parsing happens on-device
- ✅ Only geocoding uses Apple's servers
- ✅ No third-party services
- ✅ No data collection

### What's Sent to Apple
- Only GPS coordinates (for reverse geocoding)
- Minimal data transfer
- Standard MapKit usage
- Covered by Apple's privacy policy

## Troubleshooting

### "0 Events Need Update"
- All events already have countries ✅
- Check Travel History to verify

### "All Failed"
- Check network connection
- Try again on Wi-Fi
- Some events may not have enough data

### "Partial Success"
- Normal! Some events can't be auto-detected
- Edit remaining ones manually
- Usually events with (0,0) coordinates

### Progress Stuck
- Wait a bit (geocoding is slow)
- May take minutes for many events
- Check console for errors

## Console Output

When running, you'll see logs like:
```
📍 Found 50 events without country data
✅ Updated event ABC123: Caen → France
✅ Updated event DEF456: Denver, CO → United States
📍 Geocoding (48.8566, 2.3522) → France
❌ Failed event GHI789: No data available
💾 Saved 48 updated events
```

## Summary

The Event Country Geocoder is a powerful tool to automatically fill in missing country data using intelligent parsing and geocoding. It's safe, non-destructive, and works with your existing data formats.

**Run it whenever you see "Unknown" countries in your Travel History!**

---
**Feature**: Event Country Geocoding
**Version**: 1.1
**Status**: Production Ready
**Author**: Tim Arey
