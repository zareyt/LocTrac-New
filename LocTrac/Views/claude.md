# LocTrac Development Guide for Claude

## Project Overview
LocTrac is an iOS travel tracking application that helps users record and visualize their stays, travels, and experiences. The app emphasizes simplicity, privacy, and beautiful data visualization.

## Core Architecture

### Data Model
- **DataStore**: Central observable object managing all app data
- **Event**: Represents a single stay/visit at a location
- **Location**: Represents a place where events can occur
- **Person**: Contact-linked person who can be associated with events
- **Activity**: Activity that can be performed during a stay
- **Affirmation**: Motivational message that can be linked to events

### Key Technologies
- **SwiftUI**: Primary UI framework
- **Swift Concurrency**: async/await for all asynchronous operations
- **Combine**: Used sparingly, primarily for DataStore observation
- **MapKit**: For location visualization and geocoding
- **CoreLocation**: For coordinate handling and reverse geocoding
- **Contacts**: For people integration

## Date, Time, and Timezone Handling

### Philosophy
LocTrac tracks **calendar dates only**, not specific times. The app focuses on "which day you were somewhere" rather than precise timestamps.

### Implementation Strategy

#### 1. **Storage Format**
- All dates are stored as `Date` objects in UTC timezone
- Dates are normalized to **start of day (00:00:00) in UTC**
- This ensures consistent date comparisons regardless of user's local timezone

#### 2. **Date Creation and Editing**
```swift
// Always use UTC calendar for date operations
private var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
}

// Normalize dates to start of day
let normalizedDate = someDate.startOfDay
```

#### 3. **Date Pickers**
All `DatePicker` instances must:
- Display only `.date` component (no time)
- Use UTC calendar: `.environment(\.calendar, utcCalendar)`
- Use UTC timezone: `.environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)`

#### 4. **Date Formatting**
- **Display**: Use `.formatted(date: .long, time: .omitted)` or similar
- **Never show time**: The user should never see "6:00 PM" or any time component
- **Comparisons**: Always use `startOfDay` for date comparisons

#### 5. **Date Extension Helper**
```swift
extension Date {
    var startOfDay: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.startOfDay(for: self)
    }
}
```

#### 6. **Why UTC?**
- **Consistency**: Same date regardless of where the user is
- **No DST issues**: UTC has no daylight saving time transitions
- **Simplicity**: No timezone conversion needed
- **Data integrity**: Dates don't shift when traveling or changing device timezone

### Common Patterns

#### Creating a new event date
```swift
// From DatePicker
@State private var eventDate: Date = Date().startOfDay

DatePicker("Event Date", selection: $eventDate, displayedComponents: .date)
    .environment(\.calendar, utcCalendar)
    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
```

#### Comparing dates
```swift
// Compare two events by date
let sameDay = event1.date.startOfDay == event2.date.startOfDay

// Filter events for a specific date
let eventsForDate = events.filter { 
    $0.date.startOfDay == selectedDate.startOfDay 
}
```

#### Date components for calendar
```swift
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let components = calendar.dateComponents([.year, .month, .day], from: date)
```

### Anti-Patterns to Avoid

❌ **Don't use local timezone for storage**
```swift
// WRONG - will cause date shifts
let date = Date() // This is fine
Calendar.current.startOfDay(for: date) // This uses local timezone!
```

❌ **Don't show time components**
```swift
// WRONG - users should never see times
Text(event.date.formatted(date: .omitted, time: .shortened))
```

❌ **Don't use DatePicker with time**
```swift
// WRONG - allows time selection
DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
```

✅ **Correct patterns**
```swift
// RIGHT - UTC normalized dates
let date = Date().startOfDay

// RIGHT - display date only
Text(event.date.formatted(date: .long, time: .omitted))

// RIGHT - date-only picker with UTC
DatePicker("Date", selection: $date, displayedComponents: .date)
    .environment(\.calendar, utcCalendar)
    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
```

## UI Guidelines

### Locations
- Each location has a customizable color (full spectrum, not limited to theme)
- "Other" location is auto-created and serves as default for non-stay events
- Default location marked with ⭐ badge

### Calendar
- Three filter modes: Location, Activities, People
- Different decoration icons for each mode
- Supports multiple events per day
- Smart refresh system to avoid performance issues

### Travel History
- Organized by country → city hierarchy
- Supports search, filtering, and sorting
- Shows mini map previews

### Infographics
- Dedicated tab for visual insights
- Full-year and multi-year views
- Smart US state detection for domestic travel

## Testing Strategy

### Swift Testing Framework
Use the modern `@Test` and `@Suite` macros for all new tests:

```swift
import Testing

@Suite("Date Handling Tests")
struct DateHandlingTests {
    
    @Test("Dates normalize to start of day in UTC")
    func dateNormalization() async throws {
        let now = Date()
        let normalized = now.startOfDay
        
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let components = utcCal.dateComponents([.hour, .minute, .second], from: normalized)
        
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }
}
```

## Performance Considerations

### Calendar Decorations
- Use targeted refresh for single-date changes
- Use 3-month window refresh for filter changes
- Avoid full calendar reloads when possible

### Map Views
- Use mini previews for list views
- Full map only when explicitly requested
- Cache geocoding results

## Common Development Tasks

### Adding a New Feature to "What's New"
1. Open `WhatsNewFeature.swift`
2. Add a new case for the version number
3. Define feature highlights with SF Symbol, color, title, and description

### Adding a New Location
- Locations auto-populate city, state, country from coordinates
- "Other" location requires manual coordinate entry or GPS
- Custom colors are preserved in the theme system

### Working with Events
- Always initialize `eventDate` to `.startOfDay`
- Use UTC calendar for all date operations
- Remember to save coordinates for "Other" location events

## Debug Logging

Use conditional compilation for debug logs:
```swift
#if DEBUG
print("📅 [ComponentName] Action: \(details)")
#endif
```

Common emoji prefixes:
- 📅 Date/calendar operations
- 🔍 Location/coordinate operations
- 🔄 Refresh/reload operations
- ⚠️ Warnings
- ✅ Success confirmations

## Terminal Commands Best Practices

**⚠️ IMPORTANT**: When providing terminal/shell commands:

### ❌ DON'T Use Comments in Multi-Line Command Blocks
```bash
# BAD - zsh interprets # as command
echo "Step 1"
# This is a comment  ← zsh error: "command not found: #"
echo "Step 2"
```

### ✅ DO Use Echo Statements for Documentation
```bash
# GOOD - Use echo for section labels
echo "=== Step 1: Create folders ==="
mkdir -p folder1 folder2
echo "✅ Folders created"

echo "=== Step 2: Move files ==="
mv file1 folder1/
echo "✅ Files moved"
```

### ✅ DO Provide Single-Line Commands with Comments Above
```bash
# Create archive structure
mkdir -p Archived/v1.1 Archived/v1.2

# Move files to archive
mv Documentation/old.md Archived/v1.1/
```

### Rationale
- zsh (default macOS shell) treats `#` at the start of a line as a command
- Comments work in scripts with `#!/bin/zsh` shebang, but not in copy-paste blocks
- `echo` statements provide clear progress feedback and documentation

## Version Control

Current stable version: **1.5**

See `Changelog.md` for detailed version history and feature additions.

## Future Considerations

- Trip grouping and itineraries
- Photo attachments to events
- Export to various formats (PDF, CSV)
- iCloud sync
- Widget enhancements
- Watch app companion

---

*Last updated: Version 1.5 - April 2026*
