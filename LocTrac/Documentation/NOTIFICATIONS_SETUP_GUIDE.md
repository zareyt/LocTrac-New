# Daily Notifications Setup Guide

**Version**: 1.4  
**Author**: Tim Arey  
**Date**: 2026-04-08  

---

## 📋 Implementation Checklist

### ☐ Step 1: Add Notification Capability

1. **Open Xcode** → Select LocTrac target
2. **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **Push Notifications** (even though we're using local notifications, this enables UserNotifications framework)

### ☐ Step 2: Update Info.plist

Add notification usage description:

```xml
<key>NSUserNotificationsUsageDescription</key>
<string>LocTrac sends daily affirmations and gentle reminders to log your travels. Notifications are optional and help you stay consistent with your travel tracking.</string>
```

### ☐ Step 3: Register Notification Categories

In your app's entry point (`AppEntry.swift` or `@main` struct), add:

```swift
import SwiftUI
import UserNotifications

@main
struct LocTracApp: App {
    @StateObject private var store = DataStore()
    
    init() {
        // Register notification categories on launch
        NotificationManager.shared.registerNotificationCategories()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onAppear {
                    // Check notification authorization status
                    NotificationManager.shared.checkAuthorizationStatus()
                }
        }
    }
}
```

### ☐ Step 4: Add Notification Settings to Options Menu

In your Options/Settings menu (wherever you have Manage Locations, etc.), add a button:

```swift
Section {
    NavigationLink {
        NotificationSettingsView()
            .environmentObject(store)
    } label: {
        Label("Notifications", systemImage: "bell.badge.fill")
    }
} header: {
    Text("Preferences")
}
```

### ☐ Step 5: Schedule Notifications When Data Changes

In `DataStore.swift`, add a method to update stay reminders:

```swift
func updateStayReminders() {
    Task {
        await NotificationManager.shared.scheduleStayReminder(for: self)
    }
}
```

Call this method after:
- Adding a new stay
- Updating an existing stay
- Deleting a stay

Example:

```swift
func add(_ event: Event) {
    events.append(event)
    changedEvent = event
    storeData()
    invalidateCacheForEvent(event)
    
    // NEW: Update stay reminders
    updateStayReminders()
}
```

### ☐ Step 6: Handle Notification Actions (Optional)

If you want to handle notification taps, add this to your app delegate or scene delegate:

```swift
extension LocTracApp {
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "VIEW_AFFIRMATION":
            // Navigate to affirmations library
            print("User tapped View Affirmation")
            
        case "ADD_STAY":
            // Navigate to add event form
            print("User tapped Add Stay")
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            print("User tapped notification")
            
        default:
            break
        }
    }
}
```

---

## 🎨 Notification Sound Setup (Optional)

To add a custom calm notification sound:

1. Add a `.aiff`, `.wav`, or `.m4a` file named `calm_notification.aiff` to your project
2. Ensure it's added to the **Copy Bundle Resources** build phase
3. Duration should be **30 seconds or less**
4. Sample rate: **Linear PCM or IMA4 (iOS)**

If you don't add a custom sound, the code will fall back to the system default sound.

---

## 🧪 Testing Notifications

### **Test in Simulator**
```bash
# Send a test notification from Terminal
xcrun simctl push booted com.yourdomain.LocTrac notification.json
```

Example `notification.json`:
```json
{
  "aps": {
    "alert": {
      "title": "Daily Affirmation",
      "body": "I am worthy of love and respect"
    },
    "sound": "calm_notification.aiff",
    "badge": 0
  }
}
```

### **Test on Device**
1. **Build & Run** on physical device
2. **Enable notifications** in NotificationSettingsView
3. **Set notification time** to 1-2 minutes in the future
4. **Close app** (background or force quit)
5. **Wait** for notification to arrive
6. **Verify**:
   - ✅ Notification appears at scheduled time
   - ✅ Affirmation text matches widget
   - ✅ Actions appear (View, Dismiss)
   - ✅ Badge count shows missing stays

---

## 🐛 Troubleshooting

### **Notifications not appearing**
1. Check authorization status:
   ```swift
   Task {
       let settings = await UNUserNotificationCenter.current().notificationSettings()
       print("Authorization: \(settings.authorizationStatus)")
   }
   ```
2. Verify notification is scheduled:
   ```swift
   Task {
       let requests = await NotificationManager.shared.getPendingNotifications()
       print("Pending: \(requests.count) notifications")
       requests.forEach { print("  - \($0.identifier) at \($0.trigger)") }
   }
   ```
3. Check device settings: Settings → LocTrac → Notifications

### **Badge count not updating**
- Ensure `content.badge = NSNumber(value: count)` is set
- Badge requires notification to be delivered
- Badge clears when user opens the app

### **Wrong affirmation displayed**
- Verify day-of-year calculation matches widget
- Check time zone consistency (use UTC)
- Confirm Affirmation.presets array is identical in both widget and app

### **Notification time not respected**
- iOS may delay notifications for battery optimization
- Notifications are **best-effort**, not guaranteed
- Do Not Disturb will suppress notifications

---

## 📊 Notification Schedule Example

User sets notification time to **9:00 AM**:

| Time | Event |
|------|-------|
| 9:00 AM | **Affirmation notification** ("I am worthy of love and respect") |
| 9:15 AM | **Stay reminder** ("You have 3 days without logged stays in the past week") |
| Next day 9:00 AM | **New affirmation** (different message based on day of year) |

---

## 🔐 Privacy Considerations

### **What Data is Collected?**
**None.** All notifications are:
- ✅ Generated locally on-device
- ✅ Scheduled locally via UNUserNotificationCenter
- ✅ No data sent to servers
- ✅ No analytics or tracking

### **What Permissions are Requested?**
- **Notifications** (UNAuthorizationOptions: .alert, .sound, .badge)
- User can deny, grant, or revoke at any time

### **User Control**
- ✅ Opt-in only (off by default)
- ✅ Can disable in app settings
- ✅ Can disable in system settings
- ✅ Respects Do Not Disturb
- ✅ No notification history stored

---

## 📝 Code Integration Points

### **Files to Modify**

| File | Change | Reason |
|------|--------|--------|
| `AppEntry.swift` | Call `registerNotificationCategories()` | Register actions |
| `DataStore.swift` | Add `updateStayReminders()` | Keep reminders current |
| `OptionsView.swift` or similar | Add NotificationSettingsView link | User access |
| `Info.plist` | Add notification usage description | App Store requirement |

### **Files Already Created**

| File | Status | Purpose |
|------|--------|---------|
| `NotificationManager.swift` | ✅ Complete | Notification system & settings UI |

---

## ✅ Verification Checklist

After implementation:

- [ ] Notifications toggle works in settings
- [ ] Time picker updates notification schedule
- [ ] Affirmation matches widget
- [ ] Stay reminder calculates correctly
- [ ] Badge count shows missing days
- [ ] Notification actions work
- [ ] Authorization prompt appears
- [ ] Denied state shows "Open Settings" button
- [ ] Notifications respect user time choice
- [ ] No crashes on notification delivery

---

## 🚀 Deployment Notes

### **Before Submitting to App Store**

1. **Test on multiple iOS versions** (18.0, 18.1, 18.2)
2. **Test notification permissions flow**:
   - First launch (allow)
   - First launch (deny) → re-enable later
   - Upgrade from previous version (no notifications)
3. **Verify notification text is clear and helpful**
4. **Check that notifications don't annoy users**:
   - Once per day only ✅
   - Morning hours (avoid late night) ✅
   - Supportive tone ✅
5. **Update app privacy details** in App Store Connect:
   - Data Types Collected: **None**
   - Data Used to Track You: **No**
   - Data Linked to You: **No**

---

## 📚 References

- [Apple: UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [Apple: Scheduling a Notification Locally](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [Apple: Notification Actions](https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types)
- [Human Interface Guidelines: Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications)

---

*LocTrac Daily Notifications Setup — v1.4 — Tim Arey — 2026-04-08*
