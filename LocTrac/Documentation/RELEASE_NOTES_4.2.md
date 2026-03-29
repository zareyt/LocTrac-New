# Release Notes - LocTrac 4.2

**Release Date**: March 29, 2026  
**Version**: 4.2  
**Build**: [To be set in Info.plist]

---

## 🎉 What's New

### Enhanced Home View
The Home tab has been completely redesigned to provide quick access to your most important location data:

- **Quick Actions**: Add events and locations directly from the home screen
- **Today & Upcoming**: See today's events and your next scheduled event at a glance
- **Recent Activity**: View your 5 most recent events
- **Top Activities**: Rolling 12-month view of your most frequent activities
- **Top Locations**: See which locations you visit most often
- **Other Cities**: Quick view of cities tracked under the "Other" location
- **Smart Navigation**: Tap section headers to jump directly to Calendar, Locations, or Infographics tabs

### Improved First Launch Experience

#### Wizard Location Detection
- **Manual Entry by Default**: New users can quickly add locations without requiring permissions
- **Optional Location Services**: Toggle "Use Current Location" to enable automatic city detection
- **Timeout Protection**: Location detection times out after 5 seconds (no more app hanging!)
- **Better Error Handling**: Clear error messages if location permission is denied
- **Status Feedback**: Real-time status updates during location detection

#### Permissions Step
- **New Step 2**: Explains what permissions are needed and why
- **Privacy First**: Clear explanation that all data stays on your device
- **Step-by-Step Instructions**: Expandable cards show how to enable each permission
- **Three Key Permissions**:
  - 📍 Location Services (auto-detect current city)
  - 📷 Photo Library (add images to locations)
  - 👥 Contacts (tag people in events)

---

## 🐛 Bug Fixes

### Critical Fixes
- **Fixed**: App hanging indefinitely when location permission is denied
- **Fixed**: Missing Info.plist privacy description keys causing permission issues
- **Fixed**: Location services not timing out, causing poor user experience
- **Fixed**: No fallback when location detection fails

### UI/UX Improvements
- **Fixed**: Empty states now show helpful messages instead of blank sections
- **Fixed**: Event rows now display city, activity count, and people count
- **Fixed**: Top locations display with colored indicators matching location themes
- **Fixed**: "Other Cities" section only appears when "Other" location exists

---

## ✨ Improvements

### Home View
- Cleaner, more organized layout with distinct sections
- Better use of visual hierarchy and spacing
- Contextual navigation (tap "Open Calendar" to jump to calendar tab)
- Shows event type icons (🟥 stay, 🟦 host, 🟩 vacation, etc.)
- Smart empty states for each section

### Data Management
- Removed dependency on Seed.json
- First launch now initializes with empty data and guides you through setup
- Simplified data loading logic
- Better backup/restore reliability

### Performance
- Infographics caching reduces recalculation overhead
- Data update tokens prevent unnecessary recomputations
- Optimized calendar refresh mechanism

### Developer Experience
- Comprehensive documentation for wizard improvements
- Quick fix summary for common issues
- Detailed Info.plist setup instructions

---

## 📋 Technical Details

### New Components
- `HomeView.swift`: Complete redesign with navigation callbacks
- `WizardLocationManager`: Dedicated location manager for wizard
- `PermissionsStepView`: New wizard step explaining required permissions
- `PermissionCard`: Reusable expandable card component

### Modified Files
- `FirstLaunchWizard.swift`: Enhanced location detection with timeout and error handling
- `DataStore.swift`: Removed Seed.json fallback, simplified initialization
- `StartTabView.swift`: Added navigation callbacks for HomeView
- `Info.plist`: Updated version and added required privacy keys

### Data Model
- No breaking changes to data model
- Existing backups fully compatible
- Country field added to Event model (optional, backward compatible)

---

## 🔧 Requirements

### Minimum iOS Version
- iOS 16.0 or later (unchanged)

### Required Info.plist Keys
Your Info.plist must include these three privacy keys:

1. `NSLocationWhenInUseUsageDescription`
2. `NSPhotoLibraryUsageDescription`
3. `NSContactsUsageDescription`

**See**: `INFOPLIST_SETUP_REQUIRED.md` for detailed setup instructions

---

## 🚀 Upgrade Instructions

### For Existing Users
1. Update app from the App Store (or rebuild if using TestFlight)
2. Your data will automatically migrate
3. No action required - all features work with existing data
4. The wizard will NOT appear for existing users

### For New Users
1. Install LocTrac
2. First Launch Wizard will appear automatically
3. Follow 4-step setup:
   - Welcome screen
   - Permissions explanation
   - Add your first location(s)
   - Add your activities
4. Start tracking your locations!

### For Developers
1. Pull latest from repository
2. Update Info.plist with version 4.2
3. Add required privacy keys if missing
4. Clean build folder (⇧⌘K)
5. Delete app from simulator/device
6. Build and run (⌘R)
7. Test wizard flow with fresh install

---

## 📊 What's Coming in 4.3

### Planned Features
- Enhanced trips management
- Golfshot CSV import
- Default location settings
- Photo management improvements
- Advanced filtering in Calendar view
- Export improvements (PDF, CSV options)

### Under Consideration
- iCloud sync
- Widget support
- Maps integration for location visualization
- Calendar integration
- Sharing location data

---

## 🐞 Known Issues

### Minor Issues
- Location detection may be slow in areas with poor GPS signal (expected behavior)
- First geocoding attempt may fail if offline (manual entry available as fallback)

### Workarounds
- **Location timeout**: Toggle off "Use Current Location" and enter city manually
- **Permission denied**: App works perfectly with manual location entry

---

## 📝 Migration Notes

### From 4.1 to 4.2
- **Data**: No migration required, fully backward compatible
- **Settings**: All settings preserved
- **Backup files**: Existing backups work with 4.2

### Breaking Changes
- None

---

## 🙏 Acknowledgments

### Testing
- Tested on iPhone SE, iPhone 16 Pro Max, iPad Pro
- Tested with location permission granted, denied, and not determined
- Tested with network offline and online
- Tested with empty data, small datasets, and large datasets (100+ events)

### Documentation
- Complete wizard documentation in `USER_GUIDE_FIRST_LAUNCH_WIZARD.md`
- Troubleshooting guide in `QUICK_FIX_SUMMARY.md`
- Info.plist setup in `INFOPLIST_SETUP_REQUIRED.md`

---

## 📞 Support

### Documentation
- See `README.md` for general app information
- See `USER_GUIDE_FIRST_LAUNCH_WIZARD.md` for wizard help
- See `WHY_PHOTOS_CONTACTS_NOT_IN_SETTINGS.md` for permission issues

### Issues
- Check existing documentation first
- Review `QUICK_FIX_SUMMARY.md` for common problems
- File issues with detailed reproduction steps

---

## 📈 Statistics

### Code Changes
- Files modified: ~8
- Files added: ~4 (documentation)
- Lines of code added: ~500
- Lines of documentation: ~1000

### Features
- New features: 5
- Bug fixes: 4
- Improvements: 8
- Performance optimizations: 3

---

## 🎯 Version History

### 4.2 (March 29, 2026)
- Enhanced Home View with quick actions and navigation
- Improved First Launch Wizard with better location handling
- Added Permissions step to wizard
- Fixed app hanging on location permission denial
- Performance improvements

### 4.1 (Previous)
- [Previous release notes here]

### 4.0 (Previous)
- [Previous release notes here]

---

**LocTrac 4.2** - Track your locations, cherish your memories  
© 2026 Tim Arey
