# Backup & Export Feature

## ✅ Implementation Complete!

Added a comprehensive backup and export utility accessible from the main menu.

## 🎉 Features

### **1. Data Summary**
Shows complete overview of your data:
- 📍 **Locations count**
- 📅 **Events count**
- 🚶 **Activities count**
- 🕒 **Last backup date** (relative time)
- 📄 **File size** (human-readable format)

### **2. Export Options**

#### **Share Backup File**
- Creates a timestamped copy: `LocTrac_Backup_YYYY-MM-DD_HHMMSS.json`
- Opens iOS share sheet with all sharing options:
  - 📧 **Email** - Send via Mail app
  - 💬 **Messages** - Send via iMessage/SMS
  - 📱 **AirDrop** - Share to nearby devices
  - ☁️ **Cloud Services** - Save to iCloud Drive, Dropbox, etc.
  - 📲 **Other Apps** - Share to any compatible app

#### **Create Fresh Backup**
- Forces immediate save of current data
- Updates backup.json with latest changes
- Refreshes file info (date, size)
- Shows success confirmation

### **3. File Information**
Displays technical details:
- **Filename**: backup.json
- **Format**: JSON
- **Location**: App Documents folder

## 📱 User Interface

### **Layout:**

```
┌─────────────────────────────────────┐
│    Backup & Export          [Done]  │
├─────────────────────────────────────┤
│ ABOUT                               │
│ ℹ️  Backup Your Data                │
│    Export all locations, events,    │
│    and activities                   │
├─────────────────────────────────────┤
│ DATA SUMMARY                        │
│ 🔴 15                    Locations  │
│ 🔵 127                   Events     │
│ 🟢 6                     Activities │
│ 🟠 2 hours ago           Last Backup│
│ 🟣 23.4 KB               File Size  │
├─────────────────────────────────────┤
│ EXPORT OPTIONS                      │
│ 📤 Share Backup File          →     │
│    Send via Messages, Email, etc.   │
│                                     │
│ 🔄 Create Fresh Backup        →     │
│    Update backup with current data  │
├─────────────────────────────────────┤
│ FILE DETAILS                        │
│ Filename:            backup.json    │
│ Format:              JSON           │
│ Location:            App Documents  │
└─────────────────────────────────────┘
```

## 🎯 How to Use

### **Access the Feature:**

1. Open LocTrac app
2. Tap the **menu button** (ellipsis ⋯) in top-left corner
3. Select **"Backup & Export"**

### **Share Your Backup:**

1. In Backup & Export view
2. Tap **"Share Backup File"**
3. Choose how to share:
   - **Email**: Select Mail → Enter recipient → Send
   - **Messages**: Select Messages → Choose contact → Send
   - **AirDrop**: Select nearby device → Accept on receiver
   - **Save to Files**: Select location → Save

### **Create Fresh Backup:**

1. In Backup & Export view
2. Tap **"Create Fresh Backup"**
3. Confirmation appears: "Backup Created"
4. File info updates with new date/size

## 💾 File Format

### **backup.json Structure:**

```json
{
  "locations": [
    {
      "id": "UUID",
      "name": "Location Name",
      "city": "City",
      "latitude": 39.123,
      "longitude": -106.456,
      "country": "Country",
      "theme": "Theme",
      "imageIDs": ["image1.jpg", "image2.jpg"]
    }
  ],
  "events": [
    {
      "id": "UUID",
      "eventType": "stay",
      "date": "2024-01-15T12:00:00Z",
      "location": { /* location object */ },
      "city": "City",
      "latitude": 39.123,
      "longitude": -106.456,
      "country": "Country",
      "note": "Event note",
      "people": [...],
      "activityIDs": [...]
    }
  ],
  "activities": [
    {
      "id": "UUID",
      "name": "Activity Name"
    }
  ]
}
```

## 🔧 Technical Details

### **Files Created:**

**BackupExportView.swift**
- Main view with data summary and export options
- File information display
- Share sheet integration
- Error handling

**ShareSheet** (UIViewControllerRepresentable)
- Native iOS share functionality
- Supports all system sharing options
- Automatic activity suggestions

### **Integration:**

**StartTabView.swift**
- Added menu item: "Backup & Export"
- Sheet presentation binding
- Environment object passing

### **Key Functions:**

```swift
// Load file metadata
func loadFileInfo()
- Gets last modified date
- Calculates file size
- Updates display

// Create new backup
func createBackup()
- Calls store.storeData()
- Refreshes file info
- Shows success alert

// Export and share
func exportAndShare()
- Creates timestamped copy
- Moves to temp directory
- Opens share sheet
- Error handling
```

## 📊 Data Summary Details

### **Statistics Shown:**

| Metric | Icon | Color | Description |
|--------|------|-------|-------------|
| Locations | 📍 | Red | Total saved locations |
| Events | 📅 | Blue | Total event entries |
| Activities | 🚶 | Green | Total activity types |
| Last Backup | 🕒 | Orange | Time since last save |
| File Size | 📄 | Purple | Backup file size |

### **Last Backup Display:**

Shows relative time:
- "Just now"
- "2 minutes ago"
- "1 hour ago"
- "Yesterday"
- "2 days ago"

### **File Size Format:**

Human-readable sizes:
- "12.3 KB"
- "1.5 MB"
- "Unknown" (if file not found)

## 📤 Share Sheet Options

When you tap "Share Backup File", iOS shows these options:

**Communication:**
- Mail - Email the backup
- Messages - Send via SMS/iMessage
- WhatsApp, Telegram, etc. (if installed)

**Cloud Storage:**
- iCloud Drive
- Dropbox
- Google Drive
- OneDrive

**Transfer:**
- AirDrop - Share to nearby devices
- Nearby Share

**Actions:**
- Save to Files - Store in Files app
- Copy - Copy to clipboard
- Print - Print the JSON (not recommended)

**Apps:**
- Any app that accepts JSON files

## ⚠️ Error Handling

### **Scenarios Covered:**

**1. File Not Found**
```
Alert: "Export Error"
Message: "Backup file not found. Please create a backup first."
Action: User taps "Create Fresh Backup"
```

**2. Cannot Locate File**
```
Alert: "Export Error"
Message: "Could not locate backup file"
Action: Check file system, try again
```

**3. File Copy Error**
```
Alert: "Export Error"
Message: "Error preparing file: [details]"
Action: Shows specific error from system
```

## 🎨 UI Design

### **Color Scheme:**

- **Primary Actions**: Blue (Share, Info)
- **Success Actions**: Green (Create Backup)
- **Info Icons**: Various (Red, Blue, Green, Orange, Purple)
- **Text**: System colors (primary, secondary)

### **Layout Hierarchy:**

1. **Info Section** - What this feature does
2. **Data Summary** - Current data statistics
3. **Export Options** - Main actions (prominent)
4. **File Details** - Technical information

### **Visual Elements:**

- **Icons** - Clear visual indicators
- **Disclosure indicators** - Shows tappable items (→)
- **Spacing** - Generous padding for readability
- **Grouping** - Logical sections with headers/footers

## 💡 Use Cases

### **Use Case 1: Regular Backups**
```
User wants to backup weekly:
1. Open menu → Backup & Export
2. Tap "Create Fresh Backup"
3. Confirmation appears
4. Done! (takes 1 second)
```

### **Use Case 2: Email to Self**
```
User wants email backup for safekeeping:
1. Open menu → Backup & Export
2. Tap "Share Backup File"
3. Select Mail
4. Enter own email
5. Send
6. Now backed up in email!
```

### **Use Case 3: Switch Devices**
```
User getting new iPhone:
1. On old phone: Backup & Export → Share
2. Select AirDrop → New iPhone
3. Accept on new phone
4. File saved to Files app
5. Can import later (when import feature added)
```

### **Use Case 4: Share with Family**
```
Family wants copy of travel data:
1. Backup & Export → Share
2. Select Messages
3. Choose family member
4. Send
5. They receive LocTrac_Backup_2024-03-23.json
```

### **Use Case 5: Cloud Backup**
```
User wants cloud storage:
1. Backup & Export → Share
2. Select "Save to Files"
3. Navigate to iCloud Drive
4. Save
5. Now backed up in cloud!
```

## ✨ Benefits

### **For Users:**
- ✅ **Easy access** - Right in main menu
- ✅ **Clear information** - See what you're backing up
- ✅ **Flexible sharing** - All iOS sharing options
- ✅ **Timestamped files** - Never overwrite backups
- ✅ **No confusion** - Clear instructions and labels

### **For Data Safety:**
- ✅ **Regular backups** - Quick to create
- ✅ **Off-device storage** - Email, cloud, other devices
- ✅ **Version history** - Timestamped filenames
- ✅ **JSON format** - Human-readable, parseable
- ✅ **Complete data** - Everything in one file

## 🚀 Future Enhancements

**Potential additions:**

1. **Import Feature** - Restore from backup file
2. **Automatic Backups** - Scheduled background backups
3. **Backup History** - Keep multiple versions
4. **Cloud Sync** - Automatic iCloud backup
5. **Selective Export** - Choose what to include
6. **Format Options** - CSV, XML, etc.
7. **Encryption** - Password-protect sensitive data
8. **Compression** - Zip files for easier sharing

## 📝 Testing Checklist

- [x] Menu item appears in ellipsis menu
- [x] View opens correctly
- [x] Data summary shows correct counts
- [x] Last backup date displays
- [x] File size calculates correctly
- [x] "Create Fresh Backup" works
- [x] Success alert appears
- [x] "Share Backup File" opens share sheet
- [x] Timestamped filename created
- [x] Email sharing works
- [x] Messages sharing works
- [x] AirDrop works
- [x] Save to Files works
- [x] Error handling works
- [x] File not found handled gracefully

## 🎉 Summary

**Feature Complete:**
- ✅ Backup & Export view created
- ✅ Added to main menu
- ✅ Data summary display
- ✅ Share functionality
- ✅ Create backup function
- ✅ File information display
- ✅ Error handling
- ✅ Native iOS share sheet

**User Experience:**
```
Before: "How do I backup my data?" 🤔
After:  Menu → Backup & Export → Share! 🎉
```

**Access:**
```
Main Menu (⋯) → Backup & Export → Easy sharing options
```

---

**Your data is now easy to backup and share! 💾📤✨**
