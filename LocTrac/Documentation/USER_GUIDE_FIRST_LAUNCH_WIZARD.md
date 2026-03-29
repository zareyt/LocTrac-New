# LocTrac - First Launch Wizard

## Overview

LocTrac now includes a comprehensive first-launch wizard that guides new users through initial app setup. The wizard appears automatically on first launch and helps users configure locations, activities, and understand required permissions.

---

## Features

### 4-Step Onboarding Process

The wizard guides users through these steps:

#### Step 1: Welcome
- Introduction to LocTrac
- Overview of key features:
  - Track Locations
  - Log Events  
  - Track Activities

#### Step 2: Permissions
- Clear explanation of required iOS permissions
- **Location Services** - Auto-detect current location when adding places
- **Photo Library** - Add photos to locations and events
- **Contacts** - Tag people in events
- Privacy notice emphasizing all data stays on device
- Expandable cards with step-by-step instructions for enabling permissions

#### Step 3: Add Locations
Users can add initial locations using two methods:

**Option A: Current Location (Automatic)**
- Toggle "Use Current Location" ON
- Grant location permission when prompted
- App detects coordinates and reverse-geocodes to city name
- Enter a name for the location (e.g., "Home", "Office")
- Location saves with accurate GPS coordinates

**Option B: Manual Entry**
- Toggle "Use Current Location" OFF (default)
- Enter location name
- Enter city name
- App geocodes city to find coordinates
- Location saves with approximate coordinates

**Features:**
- Add multiple locations during setup
- Choose theme color for each location
- Delete locations before completing wizard
- See real-time location detection status
- Graceful error handling if location detection fails

#### Step 4: Activities
Set up activities to track at locations:

- **Pre-selected Defaults**: 6 common activities (Golfing, Skiing, Biking, Yoga, Exercise, Pickleball)
- **Additional Suggestions**: Hiking, Swimming, Running, Reading
- **Custom Activities**: Add your own activities with the text field
- Toggle activities on/off with visual checkboxes
- Delete activities before completing wizard

### Smart Features

**Location Detection**
- 5-second timeout prevents hanging
- 3-second geocoding timeout
- Falls back to manual entry on failure
- Works offline with default coordinates

**Data Persistence**
- All wizard data saves to `backup.json`
- UserDefaults flag ensures wizard shows only once
- Data immediately available after wizard completes

**Error Handling**
- Location permission denied → Clear error message
- Geocoding timeout → Uses fallback values
- Network unavailable → Continues with defaults
- Empty required fields → Button disabled with visual feedback

**iPad Compatibility**
- Responsive layout for both portrait and landscape
- Scrollable content accommodates all screen sizes
- All functionality works identically to iPhone

---

## User Experience

### First Launch
```
1. Open LocTrac for the first time
2. Wizard appears automatically
3. Follow 4 steps to set up the app
4. Tap "Get Started" to complete
5. Main app opens with your data
```

### Subsequent Launches
```
1. Open LocTrac
2. Main app loads immediately
3. Wizard never shows again
4. All setup data is preserved
```

### Skipping Steps
- Locations and activities can be skipped
- Users can add them later from the main app
- Minimum requirement: Complete all 4 steps (can be empty)

---

## Location Features in Detail

### Current Location Detection

**When to Use:**
- You're physically at the location you want to add
- You want accurate GPS coordinates
- You have location services enabled

**How It Works:**
1. Toggle "Use Current Location" ON
2. App requests location permission (first time only)
3. Grant "Allow While Using App" permission
4. Wait 2-5 seconds for detection
5. See "Location detected" checkmark
6. Enter location name
7. City name auto-fills from GPS coordinates
8. Tap "Add Location"

**Status Indicators:**
- 🔵 "Waiting for location..." (initial state)
- 🟡 Spinner + "Detecting location..." (searching)
- 🟢 Checkmark + "Location detected" (success)
- 🟠 Warning + Error message (failure)

**Error Messages:**
- "Location access denied" → Enable in Settings or toggle off for manual entry
- "Location timeout" → Toggle off and enter manually
- "Location currently unavailable" → Move to area with better signal

### Manual Location Entry

**When to Use:**
- You're not currently at the location
- Planning to visit a location later
- Location services unavailable
- Privacy preference

**How It Works:**
1. Leave "Use Current Location" OFF (default)
2. Enter location name (e.g., "Grandma's House")
3. Enter city name (e.g., "Denver")
4. Tap "Add Location"
5. App geocodes city to find approximate coordinates
6. Location saves with city-level accuracy

**Coordinate Accuracy:**
- Geocoding places marker in city center
- Sufficient for city-level tracking
- Can be edited later in main app if needed

### Toggle Behavior

**Switching from Manual to Current Location:**
- City field disappears
- Location detection starts automatically
- Name field still required

**Switching from Current Location to Manual:**
- Location detection stops
- City field appears
- Both name and city required

---

## Activities Features

### Default Activities

Six common activities are **pre-selected** when you reach Step 4:
- Golfing
- Skiing
- Biking
- Yoga
- Exercise
- Pickleball

**To keep defaults:**
- Simply tap "Get Started" (no action needed)

**To customize:**
- Tap activities to toggle on/off
- Blue background = selected
- White background = not selected

### Additional Suggestions

Four more activities are available to select:
- Hiking
- Swimming
- Running
- Reading

**To add:**
- Tap any suggested activity
- It turns blue and is added to your list

### Custom Activities

**To add your own activity:**
1. Type activity name in text field
2. Tap + button
3. Activity appears in your list with checkmark
4. Selected by default

**Examples:**
- Sports: Tennis, Basketball, Football
- Hobbies: Gardening, Photography, Painting
- Work: Remote Work, Client Meeting
- Social: Dining, Concert, Party

### Managing Activities

**During wizard:**
- Toggle activities on/off
- Add custom activities
- Delete with trash icon
- See count of selected activities

**After wizard:**
- Add more activities: Menu → Manage Activities
- Edit activity names in main app
- Delete unused activities
- Activities available in all events

---

## Privacy & Permissions

### What Permissions Are Needed?

**Location Services** (Optional)
- **Purpose**: Auto-detect your current location when adding places
- **When**: Requested when you toggle "Use Current Location" ON
- **Required**: No - you can use manual entry instead

**Photo Library** (Optional)
- **Purpose**: Add photos to locations and events  
- **When**: Requested when you tap "Add Photos" in location details
- **Required**: No - events work without photos

**Contacts** (Optional)
- **Purpose**: Tag people in your events
- **When**: Requested when you try to add people to an event
- **Required**: No - events work without contacts

### Privacy Promise

**All data stays on your device:**
- No server uploads
- No cloud sync
- No third-party sharing
- No analytics or tracking
- Full control of your data

**Data stored locally:**
- Locations, events, and activities: `backup.json` file
- Settings and preferences: UserDefaults
- Photos: App's documents directory

### Permission Settings

**To check or change permissions:**
1. Open iOS Settings app
2. Scroll down to LocTrac
3. Tap LocTrac
4. Toggle permissions on/off

**Note**: Photos and Contacts won't appear in Settings until the app requests them for the first time.

---

## Troubleshooting

### Wizard Not Appearing

**Symptom**: App opens directly to main view, no wizard

**Causes:**
1. Already completed wizard once
2. backup.json exists from previous installation
3. UserDefaults flag is set

**Solution:**
- Delete app and reinstall for fresh setup
- Or add locations manually from main app menu

### Location Detection Not Working

**Symptom**: "Use Current Location" doesn't detect location

**Possible Causes & Solutions:**

1. **Permission Denied**
   - Error: "Location access denied"
   - Solution: Settings → Privacy → Location Services → LocTrac → "While Using App"

2. **Location Services Disabled**
   - Solution: Settings → Privacy → Location Services → Toggle ON

3. **Poor GPS Signal**
   - Error: "Location timeout"
   - Solution: Move to area with clear sky view, or use manual entry

4. **Airplane Mode**
   - Solution: Disable Airplane Mode or use manual entry

### Button Not Visible (iPad)

**Symptom**: Can't see "Add Location" button on iPad

**Cause**: Button is below visible area in ScrollView

**Solution**: Scroll down to see button - this is expected behavior

### Geocoding Issues

**Symptom**: City shows as "Unknown" or coordinates are (0, 0)

**Causes:**
- No internet connection during geocoding
- Geocoding service timeout
- Invalid city name entered

**Impact:**
- Location still saves and works
- Can edit location later in main app
- Events can still be created at this location

**Solution:**
- Edit location details in main app to update
- Or delete and recreate with better connection

### Activities Not Saving

**Symptom**: Selected activities don't appear after wizard

**Likely Cause**: Did not complete wizard fully

**Solution:**
- Ensure you tap "Get Started" on Step 4
- Wait for wizard to dismiss
- Add activities manually: Menu → Manage Activities

---

## Tips & Best Practices

### Location Setup

**For Best Results:**
- Add 3-5 primary locations during wizard setup
- Use current location detection when physically present
- Choose distinctive names (e.g., "Lake House" not just "House")
- Select appropriate theme colors for visual distinction
- Add more locations later as needed

**Naming Conventions:**
- Descriptive: "Mom's House" instead of "House"
- Unique: "Denver Office" vs "Austin Office"
- Personal: Use names meaningful to you
- Short: Fit on map pins and lists

### Activity Setup

**Recommended Approach:**
- Start with pre-selected defaults (accept all 6)
- Add 2-3 custom activities specific to your interests
- Total of 8-10 activities is optimal
- Can always add more later

**Activity Naming:**
- Action-oriented: "Swimming" not "Pool"
- Specific: "Mountain Biking" vs "Biking" if you do both
- Consistent: Use same tense (all -ing or all nouns)

### Privacy Considerations

**Location Permission:**
- Grant "While Using App" for convenience
- Or use manual entry for complete privacy
- Permission only used during explicit "Use Current Location"
- Never background tracking

**Photo/Contact Permissions:**
- Can deny and still use app fully
- Grant only if you plan to use those features
- Revoke anytime in Settings

---

## Frequently Asked Questions

### General

**Q: Can I redo the wizard after completing it?**
A: The wizard only shows once automatically. To reset: delete the app and reinstall, or add data manually through the main app.

**Q: What if I skip adding locations in the wizard?**
A: No problem! Add locations anytime: Main menu (⋯) → Add Location

**Q: Are there any required steps?**
A: No. You can skip adding locations and activities (though it's recommended to add at least one location for tracking).

**Q: Can I edit wizard data later?**
A: Yes! All locations and activities can be edited, deleted, or new ones added in the main app.

### Locations

**Q: How many locations should I add?**
A: Add 1-5 primary locations during setup. More can be added anytime.

**Q: What if I enter the wrong city name?**
A: Edit the location in the main app: Tap location → Edit details

**Q: Can I use the same name for multiple locations?**
A: Yes, but it's confusing. Use distinguishing names like "Home - Denver" and "Home - Austin"

**Q: Do I need location permission to use the app?**
A: No. Manual entry works without any permissions.

### Activities

**Q: Can I delete pre-selected activities?**
A: Yes. Tap any selected activity to deselect it.

**Q: How many activities can I add?**
A: Unlimited, but 8-12 is typically sufficient.

**Q: Can I rename activities later?**
A: No. Delete and recreate with the correct name, or add a new one.

**Q: Do activities affect anything in the app?**
A: Yes. They appear when creating events, helping you track what you do at each location.

### Technical

**Q: Where is my data stored?**
A: Locally on your device in `Documents/backup.json`. Never uploaded to servers.

**Q: What happens if I reinstall the app?**
A: All data is deleted (unless you backed up with iTunes/iCloud device backup). Wizard will show again.

**Q: Does the wizard work offline?**
A: Partially. Location detection requires GPS. Geocoding requires internet. Manual entry works offline with default coordinates.

**Q: Is the wizard accessible for VoiceOver users?**
A: All elements have accessibility labels and support VoiceOver navigation.

---

## Support

### Getting Help

**In-App:**
- Menu (⋯) → About LocTrac

**Common Issues:**
- See Troubleshooting section above
- Check iOS Settings for permission status
- Restart app if UI seems frozen
- Reinstall app for complete reset

### Data Management

**Backup Your Data:**
- LocTrac data is included in iTunes/iCloud device backups
- No built-in cloud sync
- Use app's Export feature: Menu → Backup & Export

**Reset App:**
1. Delete LocTrac app
2. Reinstall from App Store
3. Wizard appears on first launch
4. Set up from scratch

---

## Version Information

**Feature**: First Launch Wizard
**Version**: Introduced in current version
**Platform**: iOS 16.0+
**Devices**: iPhone, iPad

---

## Credits

LocTrac by Tim Arey
Wizard implementation: 2025

---

*This documentation covers the first-launch wizard experience. For information about main app features, see the full user guide.*
