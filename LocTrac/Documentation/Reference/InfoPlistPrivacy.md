# 🔐 Required Info.plist Privacy Permissions

## Overview

Your wizard now includes a permissions step and uses location services. You **must** add privacy usage descriptions to your `Info.plist` file, or your app will crash when requesting permissions.

## Required Keys

Add these keys to your `Info.plist`:

### 1. Location Services

**Key:** `NSLocationWhenInUseUsageDescription`

**Value (example):**
```
LocTrac uses your location to automatically detect and populate location details when adding new places and events.
```

**Alternative wording:**
```
We need your location to help you quickly add places you visit and track your stays.
```

### 2. Photo Library

**Key:** `NSPhotoLibraryUsageDescription`

**Value (example):**
```
LocTrac needs access to your photo library so you can add photos to your locations and events to remember special moments.
```

**Alternative wording:**
```
Add photos to your locations to keep memories of the places you visit.
```

### 3. Contacts

**Key:** `NSContactsUsageDescription`

**Value (example):**
```
LocTrac uses your contacts to help you quickly add people to your events.
```

**Alternative wording:**
```
Access your contacts to easily tag people in your location events.
```

## How to Add These Keys

### Method 1: Using Xcode's Info Tab (Recommended)

1. **Select your project** in the Project Navigator (top item)
2. **Select your app target** (under "Targets")
3. **Click the "Info" tab**
4. **Hover over any row** and click the **+ button** that appears
5. **Start typing the key name** (e.g., "NSLocationWhenInUse...")
6. **Select it from the dropdown**
7. **Enter your description text** in the Value column
8. **Repeat for all three keys**

### Method 2: Editing Info.plist Directly

1. **Find Info.plist** in your Project Navigator
2. **Right-click** → Open As → Source Code
3. **Add these lines** inside the `<dict>` tag:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>LocTrac uses your location to automatically detect and populate location details when adding new places and events.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>LocTrac needs access to your photo library so you can add photos to your locations and events to remember special moments.</string>

<key>NSContactsUsageDescription</key>
<string>LocTrac uses your contacts to help you quickly add people to your events.</string>
```

## Complete Example Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Your existing keys -->
    
    <!-- Privacy Permissions -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>LocTrac uses your location to automatically detect and populate location details when adding new places and events.</string>
    
    <key>NSPhotoLibraryUsageDescription</key>
    <string>LocTrac needs access to your photo library so you can add photos to your locations and events to remember special moments.</string>
    
    <key>NSContactsUsageDescription</key>
    <string>LocTrac uses your contacts to help you quickly add people to your events.</string>
</dict>
</plist>
```

## What Happens Without These Keys

⚠️ **Your app will crash** when trying to request these permissions with an error like:

```
*** Terminating app due to uncaught exception 'NSInternalInconsistencyException', 
reason: 'This app has attempted to access privacy-sensitive data without a usage description. 
The app's Info.plist must contain an "NSLocationWhenInUseUsageDescription" key...'
```

## Testing the Permissions

After adding the keys:

1. **Clean and rebuild** your project (Cmd+Shift+K, then Cmd+B)
2. **Delete the app** from simulator/device
3. **Run the app again**
4. **Go through the wizard** - you should see permission prompts
5. **Check Settings app** → LocTrac to verify permissions

## Permission Prompts

Users will see these system prompts:

### Location
> **"LocTrac" Would Like to Access Your Location While You Use the App**
> 
> LocTrac uses your location to automatically detect and populate location details when adding new places and events.
> 
> [Don't Allow] [Allow While Using App]

### Photos
> **"LocTrac" Would Like to Access Your Photos**
> 
> LocTrac needs access to your photo library so you can add photos to your locations and events to remember special moments.
> 
> [Select Photos...] [Allow Access to All Photos] [Don't Allow]

### Contacts
> **"LocTrac" Would Like to Access Your Contacts**
> 
> LocTrac uses your contacts to help you quickly add people to your events.
> 
> [Don't Allow] [OK]

## Best Practices

### Be Specific
Explain exactly **how** you use the data, not just **why** you need it.

### Be Honest
Don't claim you need permissions for features you don't actually use.

### Be Brief
Keep descriptions under 50 words. Users won't read long explanations.

### Use "Your"
Address the user directly: "your location", "your photos", "your contacts"

### Avoid Technical Jargon
Use plain language that anyone can understand.

## Example Variations

### More Casual Tone
```
Location: "Help us figure out where you are so you don't have to type it!"
Photos: "Add photos to remember your favorite places."
Contacts: "Quickly tag friends in your location events."
```

### More Formal Tone
```
Location: "LocTrac requires location access to provide accurate geographical data for your recorded locations and events."
Photos: "Photo library access enables you to attach images to your location records."
Contacts: "Contact access facilitates adding people to your event entries."
```

### Privacy-Focused Tone
```
Location: "Your location data stays on your device and is used only to auto-fill location details."
Photos: "Photos you add are stored locally on your device and never uploaded."
Contacts: "Contact names are stored locally and never shared with third parties."
```

## Additional Optional Keys (for future features)

If you add these features later, you'll need:

### Background Location (if you track location in background)
```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>LocTrac needs background location access to automatically track your visits.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>LocTrac needs background location access to automatically track your visits.</string>
```

### Camera (if you add photo capture)
```xml
<key>NSCameraUsageDescription</key>
<string>LocTrac needs camera access to take photos of your locations.</string>
```

### Photo Library Add Only (iOS 14+)
```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>LocTrac needs permission to save photos you capture.</string>
```

## Checklist

- [ ] Add `NSLocationWhenInUseUsageDescription` to Info.plist
- [ ] Add `NSPhotoLibraryUsageDescription` to Info.plist
- [ ] Add `NSContactsUsageDescription` to Info.plist
- [ ] Clean build folder (Cmd+Shift+K)
- [ ] Delete app from simulator
- [ ] Build and run
- [ ] Test wizard - permissions should be requested
- [ ] Verify no crashes
- [ ] Check Settings app for permissions

---

**Note:** These keys are **required by Apple** for App Store submission. Apps without proper usage descriptions will be rejected during review.
