# LocTrac Changelog

## Version 1.1 (March 29, 2026)

### 🎉 New Features

#### Travel History
- **NEW**: Comprehensive travel history view showing all your stays
- **Filter**: Toggle between "All locations" and "Other location" events
- **Sort**: Four sorting options - Country, City, Most Visited, Recent
- **Search**: Find stays by city, country, or location name
- **Statistics**: See total stays, cities visited, countries visited, and locations used
- **Details**: Tap any stay to see full information with interactive map
- **Share**: Export your travel history as text

#### Enhanced Location Management
- **Integrated Default Location**: Set default location directly in Manage Locations (no separate menu needed)
- **Benefits Display**: See why using a default location is helpful
- **Cleaner Interface**: Removed star icons and DEFAULT badges for simpler view
- **Better Color Selection**: Use native iOS color picker with Grid, Spectrum, and Sliders modes

#### Event Country Detection
- **Auto-detect Countries**: New utility can automatically detect countries from city names and coordinates
- **Eliminates "Unknown"**: Parse countries from entries like "Caen, France" or "Castle Rock, CO"
- **Batch Update**: Process all events at once to fill in missing country data

### 🎨 UI/UX Improvements

- **Reorganized Menu**: More logical grouping of features
- **Travel History**: Now appears under "About LocTrac" for quick access
- **Removed Clutter**: Simplified menu by removing redundant items
- **Better Performance**: Optimized for datasets with 1500+ events
- **Smooth Scrolling**: No more hangs or freezes with large amounts of data
- **Color-Coded**: Location colors help identify which location each stay belongs to

### 🚀 Performance

- **Optimized Rendering**: Faster view updates when switching filters and sorts
- **Better Memory Usage**: Efficient handling of large datasets
- **Responsive UI**: Instant search and filter responses
- **Smooth Animations**: Removed stuttering when interacting with lists

### 📱 Menu Changes

**Added**:
- Travel History (under About LocTrac)

**Moved**:
- Travel History now appears near top of menu

**Removed**:
- View Other Cities (replaced by more powerful Travel History)
- Default Location (integrated into Manage Locations)
- Import Golfshot CSV (still available, just hidden from main menu)

**New Menu Structure**:
```
About LocTrac
Travel History        ← NEW!
─────────────
Manage Locations      ← Now includes Default Location
Manage Activities
Manage Trips
─────────────
Backup & Import
```

### 🐛 Bug Fixes

- Fixed color picker inconsistency between add and edit location views
- Fixed performance issues when sorting large datasets
- Fixed filter toggle not responding in some cases
- Fixed sort button text wrapping on smaller screens
- Fixed layout issues with default location management

### 🔧 Technical Improvements

- Added `EventCountryGeocoder` utility class for data enrichment
- Optimized ForEach loops for better performance
- Improved view refresh logic
- Better separation of concerns in location management
- Reduced code duplication

### 📖 Documentation

- Complete Travel History user guide
- Default Location integration documentation
- Color Picker usage guide
- Performance optimization notes
- Git commit and release summaries

### ⚠️ Known Issues

- Some SF Symbol warnings in console (cosmetic, no impact on functionality)
- Keyboard notification warnings on iOS (internal iOS behavior, benign)

### 🔄 Compatibility

- **Fully backward compatible** with version 1.0
- All existing data preserved
- No migration required
- Works with iOS 16.0+

### 💾 Data

- Default location preference automatically migrated
- All locations, events, trips, and activities preserved
- "Other" location remains fully functional
- Country data can be enriched using new geocoding utility

---

## Version 1.0 (Initial Release)

### Features

- Location management with customizable themes
- Event/stay tracking with dates and details
- Activity logging
- Trip management
- Statistics and charts
- Map integration
- Photo attachments
- Contact associations
- Backup and import functionality
- First-launch wizard
- About screen
- Data persistence with local JSON storage

### Platforms

- iOS 16.0+
- iPadOS 16.0+
- iPhone and iPad universal app

---

## How to Update

### App Store
1. Open App Store
2. Tap your profile icon
3. Scroll to find LocTrac
4. Tap "Update"

### TestFlight
1. Open TestFlight app
2. Find LocTrac
3. Tap "Install" on latest build

### Manual Build
```bash
# Pull latest code
git pull origin main

# Checkout version 1.1
git checkout v1.1

# Clean build
⌘⇧K

# Build and run
⌘R
```

---

## What's Next?

### Planned for Version 1.2
- Date range filtering in Travel History
- Export to CSV and PDF
- Calendar heat map visualization
- Enhanced photo galleries
- Travel timeline view
- More statistics and analytics

### Ideas for Version 2.0
- iCloud sync across devices
- Home Screen widgets
- Apple Watch companion app
- Advanced trip planning
- Travel goals and achievements
- Social sharing features

---

## Feedback & Support

### Report Issues
- Open GitHub issue
- Email: support@loctrac.app (if applicable)
- TestFlight feedback

### Feature Requests
- Submit via GitHub issues
- Tag with "enhancement"
- Provide use case details

### Contributing
- Fork repository
- Create feature branch
- Submit pull request
- Follow code style guidelines

---

## Credits

**Development**: Tim Arey

**Frameworks**:
- SwiftUI (Apple)
- MapKit (Apple)
- CoreLocation (Apple)
- Foundation (Apple)

**Special Thanks**:
- Beta testers
- Early users
- Feedback providers

---

**Last Updated**: March 29, 2026
**Current Version**: 1.1
**Build**: Production Ready
