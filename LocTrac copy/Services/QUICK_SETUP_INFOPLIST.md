# 📱 Quick Setup Guide - Info.plist Privacy Keys

## ⚠️ CRITICAL: Add These Before Testing

Your app **will crash** without these privacy keys. Add them now!

## Option 1: Visual Editor (Easiest) ✨

### Step 1: Open Info Tab
```
1. Click your PROJECT (blue icon at top of navigator)
2. Select your TARGET (app name under "Targets")
3. Click the "Info" tab at the top
```

### Step 2: Add Three Keys

For each key below:
1. Hover over any row → Click **+** button
2. Start typing the key name
3. Select from dropdown
4. Paste the value text

#### Key 1: Location
```
Key: Privacy - Location When In Use Usage Description
Value: LocTrac uses your location to automatically detect and populate location details when adding new places and events.
```

#### Key 2: Photos
```
Key: Privacy - Photo Library Usage Description
Value: LocTrac needs access to your photo library so you can add photos to your locations and events to remember special moments.
```

#### Key 3: Contacts
```
Key: Privacy - Contacts Usage Description
Value: LocTrac uses your contacts to help you quickly add people to your events.
```

### Step 3: Save & Test
```
1. Click anywhere outside the fields to save
2. Clean build folder (Cmd+Shift+K)
3. Delete app from simulator
4. Run app - wizard should work!
```

---

## Option 2: Source Code Editor (Advanced) 🔧

### Step 1: Open Info.plist as Source
```
1. Find Info.plist in Project Navigator
2. Right-click → Open As → Source Code
```

### Step 2: Copy This Block
Paste this **inside** the `<dict>` tags (after `<dict>`, before `</dict>`):

```xml
<!-- Privacy Permission Descriptions -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>LocTrac uses your location to automatically detect and populate location details when adding new places and events.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>LocTrac needs access to your photo library so you can add photos to your locations and events to remember special moments.</string>

<key>NSContactsUsageDescription</key>
<string>LocTrac uses your contacts to help you quickly add people to your events.</string>
```

### Step 3: Save & Test
```
1. Save file (Cmd+S)
2. Clean build folder (Cmd+Shift+K)
3. Delete app from simulator
4. Run app!
```

---

## ✅ Verification Checklist

After adding keys, verify:

- [ ] All three keys added to Info.plist
- [ ] No typos in key names
- [ ] Values are user-friendly text (not code)
- [ ] Saved the file
- [ ] Cleaned build folder
- [ ] Deleted old app from simulator
- [ ] Built and ran app
- [ ] Wizard Step 3 requests location permission
- [ ] No crashes!

---

## 🎯 Quick Test

1. **Run app**
2. **Go to wizard Step 3** (Add Locations)
3. **You should see:** "Use Current Location" toggle
4. **System should prompt:** "Allow LocTrac to access your location?"
5. **Click "Allow While Using App"**
6. **You should see:** "📍 Current location detected"

If this works → ✅ Setup complete!

If app crashes → ⚠️ Check Info.plist keys again

---

## 🆘 Troubleshooting

### Error: "This app has attempted to access privacy-sensitive data..."
**Fix:** Info.plist keys are missing or misspelled
**Action:** Double-check all three keys are exactly as shown above

### Error: Can't find Info.plist
**Fix:** Look in project root folder or under "Supporting Files"
**Action:** Use Cmd+Shift+O and type "Info.plist" to find it

### Wizard shows but no location prompt
**Fix:** Keys might be wrong or permissions already denied
**Action:** 
1. Check Settings → Privacy → Location Services → LocTrac
2. Reset by deleting app completely
3. Run again

---

## 📝 The Three Keys (Copy-Paste Reference)

### XML Format (for source editor)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>LocTrac uses your location to automatically detect and populate location details when adding new places and events.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>LocTrac needs access to your photo library so you can add photos to your locations and events to remember special moments.</string>

<key>NSContactsUsageDescription</key>
<string>LocTrac uses your contacts to help you quickly add people to your events.</string>
```

### Key Names Only (for visual editor search)
```
NSLocationWhenInUseUsageDescription
NSPhotoLibraryUsageDescription
NSContactsUsageDescription
```

---

**Total time: 2 minutes** ⏱️

Just add these three keys and you're done! 🚀
