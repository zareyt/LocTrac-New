# LocTrac Changelog

All notable changes to LocTrac will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.5] - 2026-04-14

### Added
- **State/Province Support**: Added state/province field to both Location and Event models for more precise location tracking
- **Comprehensive Documentation**: Added `claude.md` development guide and `ProjectAnalysis.md` technical documentation
- **Date Handling Documentation**: Detailed guidelines for date, time, and timezone handling throughout the codebase

### Changed
- **Calendar Event Display**: Removed time display from calendar event rows - now shows only date and location information
- **Date Normalization**: Enforced UTC start-of-day normalization throughout the app for consistent date handling
- **Location Fields**: Updated location detail forms to include state/province field with appropriate SF Symbol icon

### Fixed
- **Time Display Issue**: Fixed calendar events showing "6:00 PM" - LocTrac now correctly treats all events as calendar dates only (no time component)
- **Date Consistency**: Resolved timezone-related date shifting issues by enforcing UTC storage and UTC calendar operations
- **DatePicker Configuration**: All DatePicker instances now properly configured with UTC timezone and calendar

### Technical
- All date operations now use UTC timezone (`TimeZone(secondsFromGMT: 0)`)
- Date comparisons use normalized `startOfDay` extension
- Date formatting always uses `.formatted(date: .long, time: .omitted)` pattern
- Enhanced debug logging with consistent emoji prefixes for easier troubleshooting

---

## [1.4] - 2026-04-01

### Added
- **Travel History View**: New dedicated view showing all stays organized by country and city
  - Search and filter capabilities
  - Sort by date (newest/oldest) or alphabetically
  - Country-level grouping with expandable city lists
  - Stay count and date range for each city
  - Replaces old "Other Cities" view with richer experience

- **Unified Locations Tab**: Combined map and list views into single seamless experience
  - Toggle between map and list views
  - Automatic refresh as travels grow
  - Color-coded location pins matching custom themes

- **Infographics Tab**: New dedicated tab for visual insights
  - Full-year infographic views
  - Multi-year comparison charts
  - Smart US state detection for domestic travel
  - Beautiful visualizations of travel patterns

- **First Launch Wizard**: Step-by-step onboarding for new users
  - Guided location setup
  - Tutorial for adding first stays
  - Feature overview
  - Improves first-time user experience

- **Default Location Support**: Set one location as default (⭐ badge)
  - Quick identification in location picker
  - Represents user's "home base"
  - Easy to change via locations manager

- **Enhanced Location Management**:
  - Search functionality
  - Sorting options (alphabetical, most used)
  - Mini map previews for each location
  - Inline editing capabilities
  - Visual location count indicators

- **Markdown Documentation Rendering**:
  - README displays with beautiful formatting
  - Changelog shows styled markdown
  - License file renders properly
  - Improves in-app documentation readability

- **Custom Location Colors**: Full color spectrum support
  - No longer limited to predefined themes
  - Colors preserved everywhere: lists, maps, pins, charts
  - Color picker with full customization

- **Daily Affirmation Widget**: Home screen widget support
  - Small, medium, and large widget sizes
  - Updates automatically at midnight
  - Shows random daily affirmation
  - Tap to open affirmation browser

- **Daily Notifications**: Opt-in notification system
  - Daily reminder with affirmation
  - Gentle prompt to log missing stays
  - User-configurable time
  - Deep links to calendar view

### Changed
- Location pin colors now use full custom color spectrum
- Map views use consistent color coding across the app
- Improved performance for calendar decorations with large event counts
- Enhanced location picker with color preview dots

### Fixed
- Calendar decoration refresh now properly updates when switching between filter modes
- Map annotations correctly reflect custom location colors
- Location theme persistence across app launches

---

## [1.3] - 2026-03-01

### Added
- **Affirmations System**: Personal affirmations linked to stays
  - Browse by category (Peace, Gratitude, Strength, Growth, Joy, Confidence)
  - Set favorites for quick access
  - Link multiple affirmations to any stay
  - Beautiful color-coded categories

- **Smart Import with Timeline Slider**: Enhanced backup import
  - Visual timeline slider to select date range
  - Cherry-pick exact dates needed
  - Import people, activities, and trips
  - Better control over imported data

- **Auto-Created "Other" Location**:
  - Required "Other" location created automatically on first setup
  - Ensures non-stay events always have a location
  - Can use GPS or manual coordinate entry

### Fixed
- **Calendar Refresh Issue**: Switching between People, Activities, and Locations filter modes now refreshes instantly when changing month
- Calendar decorations update properly after filter changes
- Performance improvements for calendar with many events

---

## [1.2] - 2026-02-15

### Added
- Multi-event support for calendar days
- Enhanced event filtering options
- Activity tracking improvements

### Changed
- Improved calendar performance
- Better event list sorting

### Fixed
- Calendar decoration edge cases
- Event deletion confirmation

---

## [1.1] - 2026-02-01

### Added
- Contact integration for people tracking
- Activity management system
- Enhanced notes field

### Changed
- Improved location picker
- Better date handling in forms

### Fixed
- Location save persistence
- Event editing bugs

---

## [1.0] - 2026-01-15

### Added
- Initial release
- Core event tracking functionality
- Location management
- Calendar view with decorations
- Event notes and metadata
- Map integration
- Basic statistics
- Export/import capabilities

### Features
- Track stays at different locations
- Calendar visualization
- Map view of locations
- Event filtering
- Notes and metadata
- Local data storage
- Privacy-first design

---

## Version Numbering

LocTrac follows [Semantic Versioning](https://semver.org/):
- **Major** version (X.0.0): Incompatible API changes or major architectural changes
- **Minor** version (0.X.0): New features in a backwards-compatible manner
- **Patch** version (0.0.X): Backwards-compatible bug fixes

---

## Release Notes Format

Each version entry includes:
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Now removed features
- **Fixed**: Bug fixes
- **Security**: Security-related changes
- **Technical**: Developer-focused changes

---

*For development guidelines, see `claude.md`*  
*For technical architecture, see `ProjectAnalysis.md`*  
*For user-facing information, see `README.md`*
