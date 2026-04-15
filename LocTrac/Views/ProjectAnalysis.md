# LocTrac Project Analysis

## Executive Summary
LocTrac is a comprehensive iOS travel tracking application built with SwiftUI that enables users to record, visualize, and analyze their travels and stays. The app focuses on calendar-date-based tracking (not precise timestamps) with rich metadata including locations, people, activities, and affirmations.

## Technical Stack

### Frameworks & Technologies
- **SwiftUI**: Primary UI framework (iOS 17.0+)
- **Swift 6.2**: Modern Swift with concurrency support
- **MapKit**: Location visualization and geocoding
- **CoreLocation**: Coordinate handling and reverse geocoding
- **Contacts**: People/contact integration
- **WidgetKit**: Home screen widgets for daily affirmations
- **UserNotifications**: Daily notification reminders
- **Swift Testing**: Modern testing framework with macros

### Architecture Pattern
- **MVVM-like**: SwiftUI views + ObservableObject DataStore
- **Single Source of Truth**: `DataStore` manages all app state
- **Codable Persistence**: JSON-based local storage
- **Reactive Updates**: Combine publishers for UI reactivity

## Core Components

### 1. Data Models

#### Event
The primary entity representing a stay or visit:
- `id: UUID` - Unique identifier
- `date: Date` - Calendar date (UTC, normalized to start of day)
- `location: Location` - Where the event occurred
- `city: String?` - City name (optional override)
- `state: String?` - State/province (v1.5+)
- `country: String?` - Country name (optional override)
- `eventType: String` - Type of stay (home, travel, work, etc.)
- `latitude: Double` - Coordinate
- `longitude: Double` - Coordinate
- `note: String` - User notes
- `people: [Person]` - Associated contacts
- `activityIDs: [String]` - Linked activities
- `affirmationIDs: [String]` - Linked affirmations

#### Location
Represents a place where events can occur:
- `id: UUID` - Unique identifier
- `name: String` - Location name
- `city: String?` - Default city
- `state: String?` - Default state/province (v1.5+)
- `country: String?` - Default country
- `latitude: Double` - Coordinates
- `longitude: Double` - Coordinates
- `theme: LocationTheme` - Custom color (full spectrum)
- `isDefault: Bool` - Default location flag (⭐)
- Special: "Other" location auto-created for non-stay events

#### Person
Contact-linked individual:
- `id: UUID` - Unique identifier
- `displayName: String` - Name to display
- `contactIdentifier: String` - Link to Contacts app
- Implements `Hashable` for Set operations

#### Activity
An activity that can be performed during a stay:
- `id: String` - Unique identifier (UUID string)
- `name: String` - Activity name
- User-definable and reusable across events

#### Affirmation
Motivational message:
- `id: String` - Unique identifier (UUID string)
- `text: String` - Affirmation text
- `category: Category` - Predefined category
- `color: UIColor` - Visual color coding
- `isFavorite: Bool` - User favorite flag

### 2. DataStore

Central `@MainActor class DataStore: ObservableObject`:

#### Published Properties
- `@Published var events: [Event]` - All events
- `@Published var locations: [Location]` - All locations
- `@Published var activities: [Activity]` - All activities
- `@Published var people: [Person]` - All people
- `@Published var affirmations: [Affirmation]` - All affirmations
- `@Published var changedEvent: Event?` - Signals single event change
- `@Published var movedEvent: Event?` - Signals event date change
- `@Published var calendarRefreshToken: UUID` - Forces calendar refresh

#### Persistence
- Local JSON files in Documents directory
- Separate files per entity type (events.json, locations.json, etc.)
- Automatic save on changes
- Backup/export support with date range filtering

#### Refresh Mechanism
```swift
func triggerCalendarRefresh() {
    calendarRefreshToken = UUID()
}
```
Used to force calendar decoration updates after bulk changes.

### 3. View Hierarchy

```
ContentView (TabView)
├── Calendar Tab
│   └── ModernEventsCalendarView
│       ├── Filter selector (Location/Activities/People)
│       ├── UICalendarView wrapper (ModernCalendarView)
│       └── Sheet: ModernDaysEventsListView
│           └── Sheet: ModernEventEditorSheet
│
├── Locations Tab
│   └── LocationsTabView
│       ├── Map view
│       ├── List view
│       └── Location management
│
├── Travel History Tab
│   └── TravelHistoryView
│       ├── Country grouping
│       ├── City filtering
│       └── Search & sort
│
├── Infographics Tab
│   └── InfographicsView
│       ├── Full-year charts
│       ├── Multi-year comparisons
│       └── US state detection
│
└── Settings Tab
    └── Settings & management
```

## Date, Time, and Timezone Architecture

### Design Philosophy
**LocTrac tracks calendar dates, not timestamps.** The app answers "What day were you there?" not "What time did you arrive?"

### Implementation Details

#### Storage Strategy
1. **All dates stored in UTC timezone**
2. **Normalized to start of day (00:00:00)**
3. **No time component ever shown to user**

#### UTC Calendar Pattern
Used throughout the app:
```swift
private var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
}
```

#### Date Extension
Critical helper for normalization:
```swift
extension Date {
    var startOfDay: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.startOfDay(for: self)
    }
}
```

#### DatePicker Configuration
Every date picker in the app uses:
```swift
DatePicker("Event Date", selection: $eventDate, displayedComponents: .date)
    .environment(\.calendar, utcCalendar)
    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
```

#### Why UTC?
1. **Consistency**: Same date everywhere, regardless of user location
2. **No DST**: UTC has no daylight saving time transitions
3. **Simplicity**: No timezone math needed
4. **Data Integrity**: Dates don't shift during travel or timezone changes
5. **Server Ready**: If backend integration added, UTC is standard

#### Date Comparison
Always use normalized dates:
```swift
// Correct
event1.date.startOfDay == event2.date.startOfDay

// Also correct - filtering
events.filter { $0.date.startOfDay == selectedDate.startOfDay }
```

#### Display Format
Always omit time:
```swift
// Correct
Text(event.date.formatted(date: .long, time: .omitted))

// Also acceptable
Text(event.date.formatted(date: .abbreviated, time: .omitted))

// WRONG - never show time
Text(event.date.formatted(date: .omitted, time: .shortened)) // ❌
```

### Common Pitfalls and Solutions

#### Pitfall 1: Using Local Calendar
```swift
// ❌ WRONG - uses device timezone
Calendar.current.startOfDay(for: date)

// ✅ CORRECT - uses UTC
var utcCal = Calendar(identifier: .gregorian)
utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
utcCal.startOfDay(for: date)

// ✅ BETTER - use extension
date.startOfDay
```

#### Pitfall 2: Displaying Time
```swift
// ❌ WRONG - shows "6:00 PM" or similar
event.date.formatted(date: .omitted, time: .shortened)

// ✅ CORRECT - shows date only
event.date.formatted(date: .long, time: .omitted)
```

#### Pitfall 3: Date Components Without Timezone
```swift
// ❌ WRONG - may use local timezone
let components = Calendar.current.dateComponents([.year, .month, .day], from: date)

// ✅ CORRECT - explicit UTC
var utcCal = Calendar(identifier: .gregorian)
utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
let components = utcCal.dateComponents([.year, .month, .day], from: date)
```

## Performance Optimizations

### Calendar View
**Challenge**: UICalendarView decorations can cause performance issues with many events.

**Solutions**:
1. **Targeted Refresh**: Single-date changes only reload that date
2. **3-Month Window**: Filter changes reload visible month ± 1 month
3. **Refresh Tokens**: Avoid redundant full-calendar reloads
4. **Coordinator Pattern**: Efficient UIKit integration

```swift
// Targeted refresh for single event
if let changedEvent = store.changedEvent {
    uiView.reloadDecorations(forDateComponents: [changedEvent.dateComponents], animated: true)
}

// Window refresh for filter changes
func reloadThreeMonthWindow() {
    // Only reload prev month, current month, next month
}
```

### Map Views
- Use mini previews in list views
- Lazy loading for map annotations
- Debounced search/filter updates

### Travel History
- Group by country first (reduces initial render load)
- Lazy VStack/List rendering
- Cached stay counts

## Feature Evolution

### Version History
- **1.0**: Initial release with basic tracking
- **1.1-1.2**: Core improvements
- **1.3**: Affirmations, smarter imports, calendar fixes
- **1.4**: Travel History, unified Locations, Infographics, widgets, notifications
- **1.5**: State/province support, date handling fixes, documentation

### Version 1.5 Key Changes
1. **State/Province Field**: Added to Location and Event models
2. **Date Handling Refinements**: Removed all time displays from calendar events
3. **Documentation**: Comprehensive date/time/timezone guidelines
4. **Project Structure**: Added `claude.md` and this analysis

## Widget & Notifications

### Daily Affirmation Widget
- Small/medium/large sizes
- Updates at midnight daily
- Random non-favorite affirmation
- Tapping opens full affirmation browser

### Daily Notifications
- Opt-in feature
- Scheduled at user-chosen time
- Shows daily affirmation
- Reminds to log stays
- Deep links to calendar

## Location System

### Special Locations

#### "Other" Location
- Auto-created on first launch
- Required for events without specific location
- Requires manual coordinates or GPS
- City/state/country derived from coordinates

#### Default Location (⭐)
- One location can be marked default
- Shows star badge in picker
- Represents "home base"
- Can be changed by user

### Custom Colors
- Full color spectrum (not limited to themes)
- Preserved across app restarts
- Visible on: maps, lists, calendar, charts

## Import/Export System

### Backup Export
- JSON format
- Date range filtering with timeline slider
- Includes: events, people, activities, trips
- Preserves all metadata

### Backup Import
- Cherry-pick date ranges
- Merges with existing data
- Duplicate detection
- Validation before import

## Testing Strategy

### Swift Testing Framework
```swift
@Suite("Event Date Handling")
struct EventDateTests {
    @Test("New events start at beginning of day")
    func eventCreation() {
        let event = Event(...)
        #expect(event.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) == 0)
    }
}
```

### Key Test Areas
1. Date normalization
2. UTC consistency
3. Event CRUD operations
4. Location geocoding
5. Import/export integrity

## Future Roadmap Ideas

### Short Term
- Trip/itinerary grouping
- Photo attachments
- CSV export
- Enhanced search filters

### Medium Term
- iCloud sync
- Shared trips/events
- Watch app companion
- Enhanced widgets (interactive)

### Long Term
- Backend integration
- Social features
- AI-powered insights
- AR location visualization

## Code Organization

### File Structure
```
LocTrac/
├── Models/
│   ├── Event.swift
│   ├── Location.swift
│   ├── Person.swift
│   ├── Activity.swift
│   └── Affirmation.swift
│
├── Views/
│   ├── Calendar/
│   ├── Locations/
│   ├── TravelHistory/
│   ├── Infographics/
│   └── Settings/
│
├── Data/
│   └── DataStore.swift
│
├── Utilities/
│   ├── Extensions/
│   └── Helpers/
│
├── Widgets/
│   └── LocTracWidget.swift
│
└── Documentation/
    ├── claude.md
    ├── ProjectAnalysis.md
    ├── Changelog.md
    └── README.md
```

## Dependencies

### Native Only
LocTrac uses **only Apple frameworks** - no third-party dependencies:
- SwiftUI
- MapKit
- CoreLocation
- Contacts
- WidgetKit
- UserNotifications
- Foundation

**Benefits**:
- No dependency management
- Full platform integration
- Smaller app size
- Better privacy
- Long-term stability

## Privacy & Data

### Privacy First
- All data stored locally
- No analytics
- No tracking
- No ads
- Optional Contacts access (for People feature)
- Optional Location access (for GPS coordinates)
- Optional Notifications (for reminders)

### Data Storage
- Documents directory
- JSON format
- No encryption (user data stays on device)
- Backed up by iOS/iTunes/iCloud (device backup)

## Debug Logging Conventions

### Emoji Prefixes
- 📅 Calendar/date operations
- 🔍 Location/coordinate operations
- 🔄 Refresh/reload operations
- 💾 Save/load operations
- ⚠️ Warnings
- ❌ Errors
- ✅ Success confirmations

### Example
```swift
#if DEBUG
print("📅 [ModernEventEditorSheet] Saving event:")
print("   Event ID: \(event.id)")
print("   Date (normalized): \(event.date.startOfDay)")
#endif
```

## Accessibility Considerations

- VoiceOver support for all interactive elements
- Dynamic Type support
- High contrast color options
- Semantic labels for SF Symbols
- Logical navigation hierarchy

---

**Document Version**: 1.0  
**LocTrac Version**: 1.5  
**Last Updated**: April 14, 2026  
**Maintained By**: Development Team
