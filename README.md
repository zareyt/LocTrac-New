# LocTrac

![Platform](https://img.shields.io/badge/platform-iOS%2016.0%2B%20%7C%20iPadOS%2016.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.7-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-1.1-brightgreen)

A powerful, privacy-focused iOS app for tracking your locations, travels, and life events. Keep a detailed record of everywhere you've been with beautiful visualizations, statistics, and maps.

## ✨ Features

### 🗺️ Travel History
- **Comprehensive View**: See all your stays across all locations in one unified interface
- **Smart Filtering**: Toggle between viewing all locations or just "Other" location events
- **Multiple Sort Options**: Organize by Country, City, Most Visited, or Recent
- **Advanced Search**: Find stays by city, country, or location name
- **Statistics Dashboard**: Track total stays, cities visited, countries visited, and locations used
- **Event Details**: View full information for each stay with interactive maps
- **Share**: Export your travel history as formatted text

### 📍 Location Management
- **Custom Locations**: Create and manage locations with customizable color themes
- **Default Location**: Set a default location for faster event entry
- **Map Integration**: See all your locations on an interactive map
- **Statistics**: View event counts and visit frequencies per location
- **Color-Coded**: Assign unique colors to easily identify different locations

### 📅 Event & Stay Tracking
- **Detailed Events**: Record stays with dates, locations, cities, and coordinates
- **Event Types**: Categorize events (stay, vacation, family, business, etc.)
- **Photo Attachments**: Add photos to remember special moments
- **Contact Associations**: Link events to people from your contacts
- **Activity Logging**: Track what you did during each stay

### 🛫 Trip Management
- **Organize Trips**: Group multiple events into trips
- **CO2 Tracking**: Calculate carbon footprint for air travel
- **Trip Statistics**: View trip durations, distances, and costs
- **Visual Timeline**: See your trips in chronological order

### 📊 Analytics & Insights
- **Interactive Charts**: Visualize your travel patterns with pie charts and bar graphs
- **Infographics**: Generate beautiful summaries of your travel data
- **Year Filtering**: Focus on specific time periods
- **Country Statistics**: See which countries you've visited most

### 🔒 Privacy First
- **Local Storage**: All data stays on your device in local JSON files
- **No Cloud Sync**: Your privacy is protected (no third-party servers)
- **No Analytics**: We don't track or collect any user data
- **Full Control**: Export, import, and backup your data anytime

### 🎨 User Experience
- **Native SwiftUI**: Beautiful, modern iOS design
- **Dark Mode**: Full support for light and dark appearances
- **iPad Optimized**: Universal app with iPad-specific layouts
- **Onboarding Wizard**: Guided setup for new users
- **Intuitive Interface**: Clean, easy-to-navigate design

## 📱 Screenshots

<!-- Add screenshots here -->
<!-- 
![Travel History](screenshots/travel-history.png)
![Map View](screenshots/map-view.png)
![Statistics](screenshots/statistics.png)
-->

## 🚀 Getting Started

### Requirements

- **Xcode**: 14.0 or later
- **iOS Deployment Target**: 16.0+
- **Swift**: 5.7+
- **Platforms**: iOS, iPadOS (Universal)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/LocTrac.git
   cd LocTrac
   ```

2. **Open in Xcode**
   ```bash
   open LocTrac.xcodeproj
   ```

3. **Add Required Privacy Keys to Info.plist**

   The app requires three privacy permission keys. Add these to your `Info.plist`:

   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>LocTrac uses your location to automatically detect and populate location details when adding new places and events.</string>

   <key>NSPhotoLibraryUsageDescription</key>
   <string>LocTrac needs access to your photo library so you can add photos to your locations and events to remember special moments.</string>

   <key>NSContactsUsageDescription</key>
   <string>LocTrac uses your contacts to help you quickly add people to your events.</string>
   ```

4. **Build and Run**
   - Select your target device or simulator
   - Press `⌘R` or click the Run button

### First Launch

On first launch, the app will guide you through:
1. **Welcome**: Overview of features
2. **Permissions**: Explanation of required permissions
3. **Locations**: Add your first locations (manual or GPS-based)
4. **Activities**: Select default activities

## 📖 Usage

### Managing Locations

1. Open the menu (⋯) → **Manage Locations**
2. Tap **+** to add a new location
3. Enter location details (name, city, coordinates)
4. Choose a color theme
5. Optionally set as default location

### Adding Events/Stays

1. Navigate to the **Calendar** tab
2. Tap **+** to add a new event
3. Select a date and location
4. Choose event type and add details
5. Add photos or activities (optional)

### Viewing Travel History

1. Open the menu (⋯) → **Travel History**
2. Use the filter toggle: **All** | **Other**
3. Choose a sort mode: **Country**, **City**, **Most**, or **Recent**
4. Search for specific cities or countries
5. Tap any event to see details

### Setting Default Location

1. Open the menu (⋯) → **Manage Locations**
2. See the **Default Location** section at the top
3. Use the picker to select your default location
4. This location will be pre-selected when creating events

### Exporting Data

1. Open the menu (⋯) → **Backup & Import**
2. Tap **Export Backup**
3. Choose where to save your backup.json file
4. Import on another device or keep as backup

## 🏗️ Architecture

### Tech Stack

- **UI Framework**: SwiftUI 4.0
- **Maps**: MapKit
- **Location Services**: CoreLocation
- **Data Persistence**: JSON (Codable)
- **Contacts**: Contacts Framework
- **Photos**: PhotosUI
- **Date Handling**: Foundation (UTC-based)

### Project Structure

```
LocTrac/
├── Models/
│   ├── Location.swift          # Location data model
│   ├── Event.swift              # Event/stay data model
│   ├── Activity.swift           # Activity data model
│   ├── Trip.swift               # Trip data model
│   └── Person.swift             # Contact data model
├── Views/
│   ├── StartTabView.swift       # Main tab navigation
│   ├── HomeView.swift           # Home dashboard
│   ├── LocationsView.swift      # Map view
│   ├── TravelHistoryView.swift  # Travel history (v1.1)
│   └── ...
├── ViewModels/
│   ├── DataStore.swift          # Main data store
│   └── ...
├── Utilities/
│   ├── EventCountryGeocoder.swift  # Geocoding utility (v1.1)
│   └── ...
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

### Design Patterns

- **MVVM**: Model-View-ViewModel architecture
- **Observable Objects**: `@ObservableObject` for data stores
- **Environment Objects**: Shared state across views
- **Codable**: JSON serialization/deserialization
- **Async/Await**: Modern Swift concurrency

## 🔧 Key Components

### DataStore
Central data management with CRUD operations for:
- Locations
- Events
- Activities
- Trips
- Data persistence to JSON

### TravelHistoryView (v1.1)
Comprehensive travel analytics with:
- Filtering by location type
- Multiple sorting algorithms
- Real-time search
- Statistics calculations
- Performance optimization for large datasets (1500+ events)

### EventCountryGeocoder (v1.1)
Intelligent country detection:
- Parse from city strings ("Caen, France")
- Detect US states ("Denver, CO")
- Reverse geocode coordinates
- Batch update capabilities

### LocationsManagementView
Complete location management:
- Add, edit, delete locations
- Default location integration
- Color theme picker
- Search and sort
- Statistics per location

## 🧪 Testing

### Manual Testing

```bash
# Build and run
⌘R

# Test with sample data
# The app includes sample data for testing
```

### Performance Testing

Tested and optimized for:
- ✅ 1562 events
- ✅ 7 locations
- ✅ 50+ cities
- ✅ 385 trips
- ✅ Smooth scrolling and instant filtering

## 📊 Data Format

### backup.json Structure

```json
{
  "locations": [
    {
      "id": "UUID",
      "name": "Denver",
      "city": "Denver",
      "latitude": 39.7392,
      "longitude": -104.9903,
      "country": "United States",
      "theme": "magenta",
      "imageIDs": []
    }
  ],
  "events": [
    {
      "id": "UUID",
      "eventType": "stay",
      "date": "2026-03-29T00:00:00Z",
      "location": { /* Location object */ },
      "city": "Denver",
      "latitude": 39.7392,
      "longitude": -104.9903,
      "country": "United States",
      "note": "Event notes",
      "people": [],
      "activityIDs": []
    }
  ],
  "activities": [ /* ... */ ],
  "trips": [ /* ... */ ]
}
```

## 🛣️ Roadmap

### Version 1.2 (Planned)
- [ ] Date range filtering in Travel History
- [ ] Export to CSV and PDF
- [ ] Calendar heat map visualization
- [ ] Enhanced photo galleries per city
- [ ] Travel timeline view

### Version 2.0 (Future)
- [ ] iCloud sync across devices
- [ ] Home Screen widgets
- [ ] Apple Watch companion app
- [ ] Advanced trip planning features
- [ ] Social sharing capabilities
- [ ] Travel goals and achievements

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Commit your changes**
   ```bash
   git commit -m "Add amazing feature"
   ```
4. **Push to the branch**
   ```bash
   git push origin feature/amazing-feature
   ```
5. **Open a Pull Request**

### Code Style

- Follow Swift style guidelines
- Use SwiftUI best practices
- Comment complex logic
- Write descriptive commit messages
- Add documentation for new features

### Areas for Contribution

- 🐛 **Bug Fixes**: Report and fix bugs
- ✨ **Features**: Implement items from the roadmap
- 📝 **Documentation**: Improve docs and comments
- 🎨 **UI/UX**: Design improvements
- 🧪 **Testing**: Add unit and UI tests
- 🌍 **Localization**: Translate to other languages

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed release notes.

### Latest Release: v1.1 (March 29, 2026)

**New Features**:
- 🆕 Travel History view with comprehensive filtering and sorting
- 🎨 Native ColorPicker for location themes
- 📍 Integrated default location management
- 🌍 Event country geocoding utility
- ⚡ Performance optimizations for large datasets

**Improvements**:
- Reorganized menu structure
- Better color selection experience
- Smoother scrolling with 1500+ events
- Enhanced location management interface

## 🐛 Known Issues

- Some SF Symbol warnings in console (cosmetic, no impact)
- Keyboard notification warnings (iOS internal, benign)

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Tim Arey**

- GitHub: [@YOUR_USERNAME](https://github.com/YOUR_USERNAME)
- Email: your.email@example.com

## 🙏 Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Maps powered by [MapKit](https://developer.apple.com/documentation/mapkit/)
- Location services by [CoreLocation](https://developer.apple.com/documentation/corelocation/)

## 💡 Inspiration

LocTrac was created to help people keep detailed records of their travels and life experiences while maintaining complete privacy and control over their data.

## 📞 Support

### Documentation

- [User Guide](VERSION_1.1_RELEASE.md)
- [Travel History Guide](TRAVEL_HISTORY_IMPLEMENTATION.md)
- [Quick Reference](V1.1_QUICK_CARD.md)

### Getting Help

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/LocTrac/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/LocTrac/discussions)
- **Email**: support@example.com

### FAQ

**Q: Is my data sent to any servers?**
A: No! All data is stored locally on your device in JSON format.

**Q: Can I export my data?**
A: Yes, use the Backup & Import feature to export your data as JSON.

**Q: Does it work offline?**
A: Yes, everything works offline except initial geocoding for new locations.

**Q: What happens to "Other" location events?**
A: Use the Travel History filter to view only "Other" location events separately.

**Q: How do I update event countries?**
A: Use the EventCountryGeocoder utility to automatically detect countries from city names and coordinates.

## ⭐ Star History

If you find this project useful, please consider giving it a star!

[![Star History Chart](https://api.star-history.com/svg?repos=YOUR_USERNAME/LocTrac&type=Date)](https://star-history.com/#YOUR_USERNAME/LocTrac&Date)

---

**Made with ❤️ and SwiftUI**

*Keep track of your journey, one location at a time.*
