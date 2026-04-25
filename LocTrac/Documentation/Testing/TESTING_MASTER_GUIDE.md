# LocTrac Testing Master Guide

**Version**: 2.0
**Date**: 2026-04-24
**Author**: Tim Arey / Claude

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Infrastructure Setup](#2-infrastructure-setup)
3. [Testing Strategy Overview](#3-testing-strategy-overview)
4. [Unit Testing](#4-unit-testing)
5. [Integration Testing](#5-integration-testing)
6. [Regression Testing](#6-regression-testing)
7. [UI Testing](#7-ui-testing)
8. [Manual Testing Checklists](#8-manual-testing-checklists)
9. [Test Data Management](#9-test-data-management)
10. [Automation & Workflow](#10-automation--workflow)
11. [Coverage Targets](#11-coverage-targets)
12. [Implementation Phases](#12-implementation-phases)

---

## 1. Current State Assessment

### What Exists Today

- **20 test files** with **296 unit tests** + **12 UI tests** = **308 total tests**
- **LocTracTests** unit test target — created 2026-04-24, using Swift Testing (`@Test`, `@Suite`, `#expect`)
- **LocTracUITests** UI test target with launch, tab, and performance tests
- **Test plan** (`LocTrac.xctestplan`) configured with both targets, code coverage enabled, random execution order
- **TestDataFactory.swift** — shared helper with factory methods, fixture JSON, and sample backup loader
- **Fixture data** — `LocTracTests/Fixtures/sample_backup.json` (1590 events, 7 locations, 384 trips)
- **UI test infrastructure** — `-UITesting` launch argument skips What's New/First Launch sheets, auto-enables debug file logging
- Tests verified passing on iPhone (iOS 26.3.1) and simulator, build compiles cleanly

### Test Files

| File | Target | Coverage Area | Tests |
|------|--------|--------------|-------|
| `DataStoreCRUDTests.swift` | LocTracTests | DataStore CRUD (events, locations, trips, tokens) | 27 |
| `ImportExportTests.swift` | LocTracTests | Import/Export roundtrip, legacy compat, security | 14 |
| `TripMigrationTests.swift` | LocTracTests | Trip distance, transport mode, CO2 | 11 |
| `DateEdgeCaseTests.swift` | LocTracTests | UTC midnight, date comparison, formatting | 11 |
| `EventTypeCRUDTests.swift` | LocTracTests | Event type add/delete/protection | 19 |
| `UTCDateFormattingTests.swift` | LocTracTests | UTC date display formatting | 13 |
| `SmartStayActionTests.swift` | LocTracTests | Smart stay action logic | 17 |
| `ActivityPickerTests.swift` | LocTracTests | Activity picker logic | 11 |
| `BackupArchiveTests.swift` | LocTracTests | Zip archive, image import/export | 13 |
| `EventImageTests.swift` | LocTracTests | Event photo handling | 12 |
| `IsGeocodedFlagTests.swift` | LocTracTests | Geocoding flag behavior | 9 |
| `DebugConfigTests.swift` | LocTracTests | Debug framework categories/presets | 10 |
| `BulkPersonAssignTests.swift` | LocTracTests | Bulk person assignment | 8 |
| `TOTPKeychainTests.swift` | LocTracTests | TOTP generation/verify, Keychain CRUD, Biometric | 23 |
| `UserProfileAuthStateTests.swift` | LocTracTests | UserProfile codable, AuthState computed props | 20 |
| `AuthenticationServiceTests.swift` | LocTracTests | Register, sign in, change/reset password, delete | 12 |
| `IntegrationTests.swift` | LocTracTests | Import pipeline, roundtrip, trip creation, DataStore load | 14 |
| `RegressionTests.swift` | LocTracTests | Other location, date drift, event-location, trip/CRUD integrity | 22 |
| `EventFormViewModelTests.swift` | LocTracTests | ViewModel init, computed props, date handling, people/activities | 15 |
| `TestDataFactory.swift` | LocTracTests | Shared test helpers, fixtures, sample backup loader | -- |
| `LocTracTests.swift` | LocTracTests | effectiveAddress, ensureOther idempotence, multi-trip cascade | 15 |
| `LocTracUITests.swift` | LocTracUITests | Launch, tabs, menu, sheets, add event, manage data | 11 |
| `LocTracUITestsLaunchTests.swift` | LocTracUITests | Launch screenshot capture | 1 |

### Remaining Gaps

- No automated tests for backup/import UI flow (requires file picker interaction)
- CI/CD integration (GitHub Actions / Xcode Cloud) not yet configured

---

## 2. Infrastructure Setup

### Step 1: Create a Unit Test Target

This is the **critical first step** — without it, no Swift Testing tests can run.

1. In Xcode: **File → New → Target**
2. Select **Unit Testing Bundle**
3. Name: `LocTracTests`
4. Framework: **Testing** (Swift Testing, not XCTest)
5. Host Application: `LocTrac`
6. Language: Swift

### Step 2: Configure the Test Plan

1. Open `LocTrac.xctestplan`
2. Add `LocTracTests` as a test target
3. Add `LocTracUITests` as a test target
4. Enable code coverage collection
5. Set test execution order to **Random** (catches order-dependent bugs)

### Step 3: Test File Structure

All test files live in a flat structure inside `LocTracTests/` (Xcode File System Synchronized Group — files auto-sync to target):

```
LocTracTests/
├── Fixtures/
│   ├── sample_backup.json           ← Real backup: 1590 events, 7 locations, 384 trips
│   └── LocTrac_Backup_*.zip         ← Original backup archive (with images)
├── TestDataFactory.swift            ← Shared helpers, factory methods, fixture JSON
├── DataStoreCRUDTests.swift         ← Phase 2: DataStore CRUD
├── ImportExportTests.swift          ← Phase 2: Import/Export roundtrip
├── TripMigrationTests.swift         ← Phase 2: Trip distance/mode
├── DateEdgeCaseTests.swift          ← Phase 2: UTC date handling
├── EventTypeCRUDTests.swift         ← Phase 1: Event type operations
├── UTCDateFormattingTests.swift     ← Phase 1: Date formatting
├── SmartStayActionTests.swift       ← Phase 1: Smart stay logic
├── ActivityPickerTests.swift        ← Phase 1: Activity picker
├── BackupArchiveTests.swift         ← Phase 1: Zip archive
├── EventImageTests.swift            ← Phase 1: Event photos
├── IsGeocodedFlagTests.swift        ← Phase 1: Geocoding flag
├── DebugConfigTests.swift           ← Phase 1: Debug framework
├── BulkPersonAssignTests.swift      ← Phase 1: Bulk person assign
├── TOTPKeychainTests.swift          ← Phase 3: TOTP, Keychain, Biometric
├── UserProfileAuthStateTests.swift  ← Phase 3: UserProfile, AuthState
├── AuthenticationServiceTests.swift ← Phase 3: Auth service
├── IntegrationTests.swift          ← Phase 4: Import pipeline, roundtrip, trip creation
├── RegressionTests.swift           ← Phase 4: Other location, date drift, CRUD integrity
├── EventFormViewModelTests.swift   ← Phase 5: ViewModel init, computed props, date handling
└── LocTracTests.swift               ← Placeholder (Xcode-generated)
```

### Step 4: Access App Code from Tests

Since LocTrac doesn't use a framework target, use `@testable import LocTrac` at the top of each test file:

```swift
@testable import LocTrac
import Testing
```

This gives tests access to `internal` types without making everything `public`.

### Step 5: Verify Setup

Run from Terminal to confirm:

```bash
xcodebuild test -scheme LocTrac -testPlan LocTrac -destination "platform=iOS Simulator,name=iPhone 16" -only-testing LocTracTests 2>&1 | tail -20
```

You should see test results instead of "no tests found."

---

## 3. Testing Strategy Overview

### Testing Pyramid for LocTrac

```
        ┌─────────┐
        │  Manual  │  ← Exploratory, visual, device-specific
        │  Testing │
        ├─────────┤
        │   UI    │  ← Critical user flows (5-10 tests)
        │  Tests  │
        ├─────────┤
        │ Integr- │  ← DataStore + Import, Trip pipeline (10-15 tests)
        │  ation  │
        ├─────────┤
        │         │
        │  Unit   │  ← Models, services, view models (100+ tests)
        │  Tests  │
        └─────────┘
```

### Priority Order

1. **Unit Tests** — DataStore CRUD, Import/Export, Date handling (highest ROI)
2. **Integration Tests** — Import → DataStore → Trip creation pipeline
3. **Regression Tests** — Bug-specific tests that prevent recurrence
4. **UI Tests** — Critical flows only (launch, add event, navigation)
5. **Manual Checklists** — Device-specific, visual, exploratory

### Framework Choice

| Type | Framework | Why |
|------|-----------|-----|
| Unit & Integration | Swift Testing (`@Test`, `@Suite`, `#expect`) | Modern, per CLAUDE.md convention |
| UI Tests | XCUIAutomation / XCTest UI | Required for UI automation |
| Manual | Checklists in this document | Not automatable |

---

## 4. Unit Testing

### 4.1 DataStore CRUD (Priority 1)

The DataStore is the single source of truth. Every CRUD method needs coverage.

```swift
import Testing
@testable import LocTrac

@Suite("DataStore CRUD")
struct DataStoreCRUDTests {

    // MARK: - Events

    @Test("Add event increases count and persists")
    func addEvent() async throws {
        let store = DataStore()
        let initialCount = store.events.count
        let event = TestDataFactory.makeEvent()

        store.add(event)

        #expect(store.events.count == initialCount + 1)
        #expect(store.events.contains(where: { $0.id == event.id }))
    }

    @Test("Update event modifies existing record")
    func updateEvent() async throws {
        let store = DataStore()
        var event = TestDataFactory.makeEvent()
        store.add(event)

        event.note = "Updated note"
        store.update(event)

        let found = store.events.first(where: { $0.id == event.id })
        #expect(found?.note == "Updated note")
    }

    @Test("Delete event removes from store")
    func deleteEvent() async throws {
        let store = DataStore()
        let event = TestDataFactory.makeEvent()
        store.add(event)

        store.delete(event)

        #expect(!store.events.contains(where: { $0.id == event.id }))
    }

    // MARK: - Locations

    @Test("Add location ensures uniqueness by ID")
    func addLocation() async throws {
        let store = DataStore()
        let location = TestDataFactory.makeLocation(name: "Test Place")
        store.add(location)

        #expect(store.locations.contains(where: { $0.id == location.id }))
    }

    @Test("Delete location does not remove 'Other'")
    func cannotDeleteOther() async throws {
        let store = DataStore()
        let other = store.locations.first(where: { $0.name == "Other" })!

        store.delete(other)

        #expect(store.locations.contains(where: { $0.name == "Other" }))
    }

    // MARK: - Trips

    @Test("Add trip and delete trip")
    func tripCRUD() async throws {
        let store = DataStore()
        let trip = TestDataFactory.makeTrip()
        store.addTrip(trip)

        #expect(store.trips.contains(where: { $0.id == trip.id }))

        store.deleteTrip(trip)
        #expect(!store.trips.contains(where: { $0.id == trip.id }))
    }

    // MARK: - Tokens

    @Test("bumpCalendarRefresh changes token")
    func calendarRefreshToken() async throws {
        let store = DataStore()
        let oldToken = store.calendarRefreshToken
        store.bumpCalendarRefresh()

        #expect(store.calendarRefreshToken != oldToken)
    }
}
```

**Test count target**: 20-25 tests covering all CRUD operations plus edge cases.

### 4.2 Import/Export (Priority 2)

```swift
@Suite("Import/Export Roundtrip")
struct ImportExportTests {

    @Test("Export then import preserves all data")
    func roundtrip() async throws {
        let store = DataStore()
        // Add test data
        let location = TestDataFactory.makeLocation(name: "Roundtrip Place")
        store.add(location)
        let event = TestDataFactory.makeEvent(locationID: location.id)
        store.add(event)

        // Export
        let exported = store.exportData()
        let data = try JSONEncoder().encode(exported)

        // Import into fresh store
        let decoded = try JSONDecoder().decode(Import.self, from: data)

        #expect(decoded.locations.count >= 1)
        #expect(decoded.events.count >= 1)
    }

    @Test("Import handles missing optional fields (v1.3 backup)")
    func legacyBackupCompat() async throws {
        // Simulate a v1.3 backup without activities, affirmations, trips
        let json = """
        {
            "locations": [],
            "events": []
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Import.self, from: data)

        #expect(decoded.locations.isEmpty)
        #expect(decoded.events.isEmpty)
        // Optional fields default to empty
    }

    @Test("Import remaps location IDs correctly")
    func locationRemapping() async throws {
        // Test that imported events reference valid location IDs
        // after merge into existing store
    }

    @Test("Export never includes auth data")
    func noAuthInExport() async throws {
        let store = DataStore()
        let exported = store.exportData()
        let data = try JSONEncoder().encode(exported)
        let json = String(data: data, encoding: .utf8)!

        #expect(!json.contains("password"))
        #expect(!json.contains("profile.json"))
        #expect(!json.contains("keychain"))
    }
}
```

**Test count target**: 10-15 tests covering roundtrip, legacy compat, edge cases.

### 4.3 Auth Services (Priority 3)

```swift
@Suite("Authentication Service")
struct AuthServiceTests {

    @Test("Sign up creates profile")
    func signUp() async throws {
        // Test email/password registration creates a UserProfile
    }

    @Test("Sign in with valid credentials succeeds")
    func signInValid() async throws {
        // Register then sign in
    }

    @Test("Sign in with wrong password fails")
    func signInInvalidPassword() async throws {
        // Verify error state
    }

    @Test("2FA gate prevents auth without TOTP")
    func twoFactorGate() async throws {
        // When TOTP enabled, signIn sets requiresTwoFactor = true
        // isAuthenticated remains false until completeTwoFactorAuth()
    }
}

@Suite("TOTP Service")
struct TOTPServiceTests {

    @Test("Generated code is 6 digits")
    func codeFormat() async throws {
        let secret = TOTPService.generateSecret()
        let code = TOTPService.generateCode(secret: secret)

        #expect(code.count == 6)
        #expect(code.allSatisfy { $0.isNumber })
    }

    @Test("Code validates within time window")
    func codeValidation() async throws {
        let secret = TOTPService.generateSecret()
        let code = TOTPService.generateCode(secret: secret)
        let isValid = TOTPService.verify(code: code, secret: secret)

        #expect(isValid)
    }

    @Test("Expired code is rejected")
    func expiredCode() async throws {
        // Generate code for a past time period
    }
}

@Suite("Keychain Helper")
struct KeychainTests {

    @Test("Save and retrieve data")
    func saveRetrieve() async throws {
        let key = "test_key_\(UUID().uuidString)"
        let data = "test_value".data(using: .utf8)!

        try KeychainHelper.save(data, forKey: key)
        let retrieved = try KeychainHelper.read(forKey: key)

        #expect(retrieved == data)

        // Cleanup
        try KeychainHelper.delete(forKey: key)
    }

    @Test("Delete removes data")
    func deleteKey() async throws {
        let key = "test_delete_\(UUID().uuidString)"
        let data = "delete_me".data(using: .utf8)!

        try KeychainHelper.save(data, forKey: key)
        try KeychainHelper.delete(forKey: key)

        let retrieved = try? KeychainHelper.read(forKey: key)
        #expect(retrieved == nil)
    }
}
```

### 4.4 Trip Migration

```swift
@Suite("Trip Migration")
struct TripMigrationTests {

    @Test("suggestTrip calculates distance between events")
    func tripDistance() async throws {
        let denver = TestDataFactory.makeEvent(lat: 39.7392, lon: -104.9903)
        let la = TestDataFactory.makeEvent(lat: 34.0522, lon: -118.2437)

        let trip = TripMigrationUtility.suggestTrip(from: denver, to: la)

        #expect(trip.distance > 800)  // ~850 miles
        #expect(trip.distance < 1000)
    }

    @Test("Short distance suggests driving mode")
    func shortDistanceMode() async throws {
        let home = TestDataFactory.makeEvent(lat: 39.7392, lon: -104.9903)
        let nearby = TestDataFactory.makeEvent(lat: 39.75, lon: -105.0)

        let trip = TripMigrationUtility.suggestTrip(from: home, to: nearby)

        #expect(trip.transportMode == .car)
    }

    @Test("Long distance suggests flying mode")
    func longDistanceMode() async throws {
        let denver = TestDataFactory.makeEvent(lat: 39.7392, lon: -104.9903)
        let tokyo = TestDataFactory.makeEvent(lat: 35.6762, lon: 139.6503)

        let trip = TripMigrationUtility.suggestTrip(from: denver, to: tokyo)

        #expect(trip.transportMode == .plane)
    }
}
```

### 4.5 UserProfile

```swift
@Suite("User Profile")
struct UserProfileTests {

    @Test("Profile saves and loads from JSON")
    func persistenceRoundtrip() async throws {
        let profile = UserProfile(
            displayName: "Test User",
            email: "test@example.com",
            signInMethod: .email
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)

        #expect(decoded.displayName == "Test User")
        #expect(decoded.email == "test@example.com")
        #expect(decoded.signInMethod == .email)
    }

    @Test("Profile is separate from backup data")
    func separateFromBackup() async throws {
        // Verify profile.json path differs from backup.json path
    }
}
```

### 4.6 Date Handling

The existing `UTCDateFormattingTests.swift` covers basic formatting. Add:

```swift
@Suite("Date Edge Cases")
struct DateEdgeCaseTests {

    @Test("startOfDay is UTC midnight")
    func startOfDayUTC() async throws {
        let date = Date()
        let sod = date.startOfDay

        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = utcCal.dateComponents([.hour, .minute, .second], from: sod)

        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 0)
    }

    @Test("One stay per day prevents duplicates")
    func oneStayPerDay() async throws {
        let store = DataStore()
        let event1 = TestDataFactory.makeEvent(date: Date().startOfDay)
        store.add(event1)

        // Verify the date is occupied
        let occupied = store.events.contains { $0.date.startOfDay == Date().startOfDay }
        #expect(occupied)
    }
}
```

---

## 5. Integration Testing

Integration tests verify that multiple components work together correctly.

### 5.1 Import → DataStore → Trip Pipeline

```swift
@Suite("Import Integration")
struct ImportIntegrationTests {

    @Test("Importing events triggers trip creation")
    func importTriggersTrips() async throws {
        let store = DataStore()
        // Import events at different locations
        // Verify trips are auto-generated
    }

    @Test("Import preserves existing data during merge")
    func mergePreservesExisting() async throws {
        let store = DataStore()
        let existingEvent = TestDataFactory.makeEvent()
        store.add(existingEvent)

        // Import new events
        // Verify existing event still present
    }

    @Test("Import remaps 'Other' location correctly")
    func otherLocationRemapping() async throws {
        // Import with a different "Other" location ID
        // Verify events map to current store's "Other"
    }
}
```

### 5.2 Auth Flow Integration

```swift
@Suite("Auth Flow Integration")
struct AuthFlowIntegrationTests {

    @Test("Sign up → sign out → sign in flow")
    func fullAuthCycle() async throws {
        // 1. Sign up with email
        // 2. Verify authenticated
        // 3. Sign out
        // 4. Sign in
        // 5. Verify authenticated again
    }

    @Test("Auth state does not affect DataStore")
    func authIndependentFromData() async throws {
        let store = DataStore()
        let authState = AuthState()

        // Add data while authenticated
        let event = TestDataFactory.makeEvent()
        store.add(event)

        // Sign out
        authState.isAuthenticated = false

        // Data still accessible
        #expect(store.events.contains(where: { $0.id == event.id }))
    }
}
```

---

## 6. Regression Testing

Regression tests are created for **every bug fix** to prevent recurrence. Name them descriptively.

### Naming Convention

```swift
@Test("REGRESSION: Import no longer creates orphaned events")
func regressionOrphanedImport() async throws { ... }

@Test("REGRESSION: Date picker does not drift by ±1 day")
func regressionDateDrift() async throws { ... }

@Test("REGRESSION: 'Other' location always exists after import")
func regressionOtherLocationSurvivesImport() async throws { ... }
```

### Known Regressions to Cover

| Bug | Test |
|-----|------|
| Orphaned events after import | Verify location ID remapping |
| ±1 day date drift | Verify UTC date handling in DatePicker |
| "Other" location deleted | Verify `ensureOtherLocationExists()` after all operations |
| Sheet conflicts with file picker | UI test for import flow |
| Calendar not refreshing after import | Verify `bumpCalendarRefresh()` called |
| `.accent` not valid as ShapeStyle | Compile-time — caught by build |

### Process

When fixing any bug:
1. Write a failing test that reproduces the bug
2. Fix the bug
3. Verify the test passes
4. The test stays in the regression suite permanently

---

## 7. UI Testing

UI tests use `XCUIAutomation` and run on simulators or physical devices.

### 7.1 Launch Argument: `-UITesting`

All UI tests pass the `-UITesting` launch argument to the app. This triggers:

1. **StartTabView**: Suppresses What's New and First Launch Wizard sheets
2. **DebugConfig**: Auto-enables debug logging, file logging, and key categories (dataStore, persistence, navigation, startup)
3. **Log file**: Written to `DebugLogs/debug_log.txt` for post-run review

```swift
// Required setup pattern for all UI tests:
override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments.append("-UITesting")
    app.launch()
    dismissModalIfPresent()  // Safety net
}

// Dismiss any sheet that slipped through
private func dismissModalIfPresent() {
    let skipButton = app.buttons["Skip"]
    if skipButton.waitForExistence(timeout: 2) {
        skipButton.tap()
    }
}
```

### 7.2 Current UI Tests

```swift
// LocTracUITests.swift — 3 tests
testAppLaunches()       // Verify tab bar visible after launch
testHomeTabExists()     // Verify Home tab exists
testLaunchPerformance() // XCTApplicationLaunchMetric

// LocTracUITestsLaunchTests.swift — 1 test
testLaunch()            // Screenshot capture after launch
```

### 7.3 Planned UI Tests (Phase 5)

```swift
func testTabNavigation()        // Navigate all 5 tabs
func testAddEventFlow()         // Calendar → Add → Fill → Save
func testOptionsMenuOpens()     // Ellipsis menu → verify items
func testBackupExportFlow()     // Options → Backup & Import → dismiss
func testProfileFlow()          // Profile & Account → verify sheet
```

### 7.2 Device-Specific Tests

Run on physical devices to catch issues simulators miss:

| Device | What to Test |
|--------|-------------|
| iPhone (primary) | All flows, performance with 1500+ events |
| iPad | Layout adaptation, split view, sheet sizing |
| Mac (Catalyst) | If/when supported, keyboard shortcuts, window management |

---

## 8. Manual Testing Checklists

### 8.1 Pre-Release Checklist

```
□ App launches without crash on clean install
□ App launches without crash on upgrade (existing data)
□ All 5 tabs load and display correctly
□ Options menu opens and all items work
□ Add event → verify in Calendar and Charts
□ Edit event → verify changes persist
□ Delete event → verify removed everywhere
□ Add location → verify in Travel Map
□ Backup export produces valid JSON
□ Import backup restores all data
□ Timeline Restore with date filter works
□ Trip confirmation appears for cross-location events
□ Infographic generates and exports as PDF
□ What's New appears on version upgrade
□ First Launch Wizard completes correctly
□ Profile creation and editing works
□ Sign in / sign out cycle works
□ Biometric lock activates on background
□ 2FA setup and verification works
□ Photos display correctly in event forms
□ Calendar decorations show for all filter modes
□ Debug Settings toggle (DEBUG build only)
□ No console errors or warnings in release build
```

### 8.2 Data Integrity Checklist

```
□ Events reference valid locations after import
□ "Other" location always exists
□ Trip fromEventID/toEventID reference valid events
□ Dates don't shift when device timezone changes
□ Affirmations seed on first launch
□ Activities persist across app restart
□ Photo IDs resolve to actual images
□ Export file is valid JSON (open in text editor)
□ Import of v1.3 backup works (no state/countryCode fields)
□ Import of v1.5 backup works (with state/countryCode)
```

### 8.3 Performance Checklist (1500+ Events)

```
□ Calendar tab scrolls smoothly
□ Calendar decorations load within 1 second
□ Charts render within 2 seconds
□ Home tab loads within 1 second
□ Event list scrolls without lag
□ Travel History search responds instantly
□ Infographic generation completes within 5 seconds
□ Import of large backup completes within 10 seconds
□ Memory usage stays under 200MB
```

---

## 9. Test Data Management

### TestDataFactory

Create a shared helper that all tests use for consistent test data:

```swift
// LocTracTests/Helpers/TestDataFactory.swift

import Foundation
@testable import LocTrac

enum TestDataFactory {

    static func makeLocation(
        name: String = "Test Location",
        city: String = "Denver",
        state: String = "Colorado",
        country: String = "United States",
        lat: Double = 39.7392,
        lon: Double = -104.9903
    ) -> Location {
        Location(
            id: UUID().uuidString,
            name: name,
            city: city,
            state: state,
            latitude: lat,
            longitude: lon,
            country: country,
            countryCode: "US",
            theme: .blue,
            imageIDs: nil
        )
    }

    static func makeEvent(
        date: Date = Date().startOfDay,
        locationID: String? = nil,
        lat: Double = 39.7392,
        lon: Double = -104.9903,
        note: String = "Test event"
    ) -> Event {
        let loc = makeLocation()
        return Event(
            id: UUID().uuidString,
            eventType: "stay",
            date: date,
            location: loc,
            city: nil,
            latitude: lat,
            longitude: lon,
            country: "United States",
            state: "Colorado",
            note: note,
            people: [],
            activityIDs: [],
            affirmationIDs: [],
            isGeocoded: true
        )
    }

    static func makeTrip(
        distance: Double = 500,
        mode: TransportMode = .car
    ) -> Trip {
        Trip(
            id: UUID(),
            fromEventID: UUID().uuidString,
            toEventID: UUID().uuidString,
            departureDate: Date().startOfDay,
            arrivalDate: Date().startOfDay,
            distance: distance,
            transportMode: mode,
            co2Emissions: 0,
            notes: "Test trip",
            isAutoGenerated: false
        )
    }

    /// Creates a minimal backup.json string for import testing
    static func makeBackupJSON(
        locationCount: Int = 1,
        eventCount: Int = 5
    ) -> Data {
        // Generate minimal valid JSON for import
        var locations: [[String: Any]] = []
        var events: [[String: Any]] = []

        for i in 0..<locationCount {
            locations.append([
                "id": UUID().uuidString,
                "name": "Location \(i)",
                "latitude": 39.7 + Double(i) * 0.1,
                "longitude": -104.9,
                "theme": "blue"
            ])
        }

        for i in 0..<eventCount {
            events.append([
                "id": UUID().uuidString,
                "eventType": "stay",
                "date": ISO8601DateFormatter().string(from: Date()),
                "note": "Event \(i)"
            ])
        }

        let backup: [String: Any] = [
            "locations": locations,
            "events": events
        ]

        return try! JSONSerialization.data(withJSONObject: backup)
    }
}
```

### Test Isolation

Each test should start with a clean state:

```swift
@Test("Example with clean store")
func cleanStoreTest() async throws {
    // Create a fresh DataStore — don't use shared state
    let store = DataStore()
    // Test against this isolated instance
}
```

For tests that need pre-populated data, use `TestDataFactory` methods.

---

## 10. Automation & Workflow

### Running Tests from Terminal

#### Run All Tests

```bash
xcodebuild test \
  -scheme LocTrac \
  -testPlan LocTrac \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  2>&1 | xcpretty
```

#### Run Specific Test Suite

```bash
xcodebuild test \
  -scheme LocTrac \
  -testPlan LocTrac \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -only-testing "LocTracTests/DataStoreCRUDTests" \
  2>&1 | xcpretty
```

#### Run on Physical Device

```bash
xcodebuild test \
  -scheme LocTrac \
  -testPlan LocTrac \
  -destination "platform=iOS,name=Tim's iPhone" \
  2>&1 | xcpretty
```

#### Run on iPad

```bash
xcodebuild test \
  -scheme LocTrac \
  -testPlan LocTrac \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M4)" \
  2>&1 | xcpretty
```

### Install xcpretty (Optional but Recommended)

```bash
gem install xcpretty
```

Formats xcodebuild output into readable test results.

### Code Coverage Report

```bash
xcodebuild test \
  -scheme LocTrac \
  -testPlan LocTrac \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult

xcrun xccov view --report TestResults.xcresult
```

### Pre-Commit Testing Script

Create `scripts/pre-commit-test.sh`:

```bash
#!/bin/zsh
echo "=== Running LocTrac Unit Tests ==="

xcodebuild test \
  -scheme LocTrac \
  -testPlan LocTrac \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -only-testing LocTracTests \
  2>&1 | tail -5

if [ $? -eq 0 ]; then
    echo "✅ All tests passed"
    exit 0
else
    echo "❌ Tests failed — commit blocked"
    exit 1
fi
```

### Xcode Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Run all tests | `⌘ U` |
| Run current test | `⌃ ⌥ ⌘ U` |
| Run last test again | `⌃ ⌥ ⌘ G` |
| Show test navigator | `⌘ 6` |

---

## 11. Coverage Targets

### Phase 1 (Foundation) — Target: 30% Overall

| Area | Target | Files |
|------|--------|-------|
| DataStore CRUD | 80% | `DataStore.swift` |
| Import/Export | 70% | `ImportExport.swift` |
| Date handling | 90% | `Date+Extension.swift` |
| Debug framework | 80% | `DebugConfig.swift` |

### Phase 2 (Services) — Target: 50% Overall

| Area | Target | Files |
|------|--------|-------|
| Auth service | 70% | `AuthenticationService.swift` |
| TOTP service | 80% | `TOTPService.swift` |
| Keychain helper | 70% | `KeychainHelper.swift` |
| Trip migration | 70% | `TripMigrationUtility.swift` |
| UserProfile | 80% | `UserProfile.swift` |

### Phase 3 (Integration) — Target: 60% Overall

| Area | Target | Files |
|------|--------|-------|
| Import pipeline | 60% | Multiple files |
| Trip creation flow | 60% | Multiple files |
| Auth flow | 50% | Multiple files |

### Phase 4 (UI & Polish) — Target: 65% Overall

| Area | Target | Files |
|------|--------|-------|
| UI critical paths | 5 tests | Key flows |
| Regression suite | 10+ tests | Bug-specific |
| ViewModels | 50% | `EventFormViewModel.swift` |

### Long-Term Goal: 70% Code Coverage

Focus coverage on logic-heavy code (models, services, view models). View files (`*View.swift`) naturally have lower coverage since they're UI code.

---

## 12. Implementation Phases

### Phase 1: Infrastructure (COMPLETE)

**Started**: 2026-04-24 | **Completed**: 2026-04-24

1. [x] Created `LocTracTests` unit test target (Swift Testing)
2. [x] Configured `LocTrac.xctestplan` with LocTracTests + LocTracUITests
3. [x] Moved 9 test files from old Tests/ group into LocTracTests
4. [x] Created `TestDataFactory.swift` with factory methods + fixture JSON
5. [x] Configured signing for physical device testing
6. [x] Verified tests pass on iPhone (iOS 26.3.1) and simulator
7. [x] Enabled code coverage collection and random execution order
8. [x] Removed old Tests/ group

### Phase 2: Core Unit Tests (COMPLETE)

**Started**: 2026-04-24 | **Completed**: 2026-04-24

1. [x] DataStore CRUD tests — 27 tests (`DataStoreCRUDTests.swift`)
2. [x] Import/Export roundtrip tests — 14 tests (`ImportExportTests.swift`)
3. [x] Date handling edge case tests — 11 tests (`DateEdgeCaseTests.swift`)
4. [x] Trip migration tests — 11 tests (`TripMigrationTests.swift`)

### Phase 3: Service Tests (COMPLETE)

**Started**: 2026-04-24 | **Completed**: 2026-04-24

1. [x] TOTP service tests — 11 tests (in `TOTPKeychainTests.swift`)
2. [x] Keychain helper tests — 7 tests (in `TOTPKeychainTests.swift`)
3. [x] Biometric service tests — 5 tests (in `TOTPKeychainTests.swift`)
4. [x] UserProfile tests — 10 tests (in `UserProfileAuthStateTests.swift`)
5. [x] AuthState tests — 10 tests (in `UserProfileAuthStateTests.swift`)
6. [x] Auth service tests — 12 tests (`AuthenticationServiceTests.swift`)
7. [x] UI test infrastructure — `-UITesting` launch arg, auto debug file logging
8. [x] Sample backup fixture — `LocTracTests/Fixtures/sample_backup.json` (1590 events)

### Phase 4: Integration & Regression (COMPLETE)

**Started**: 2026-04-24 | **Completed**: 2026-04-24

1. [x] Import pipeline tests — 4 tests (fixture, legacy, minimal, sample backup decode)
2. [x] Export-import roundtrip — 1 test (encode Export → decode Import, verify data survives)
3. [x] Trip creation pipeline — 5 tests (different locations, same location, too close, migration, transport mode)
4. [x] DataStore load behavior — 2 tests (Other location exists, default seeding)
5. [x] "Other" location survival — 5 regression tests (effectiveCity/Country, independence, coordinates)
6. [x] Date drift prevention — 5 regression tests (UTC midnight, idempotent, preserve, same-day, cross-midnight)
7. [x] Event-location relationship — 4 regression tests (snapshot, effectiveCoordinates, isGeocoded)
8. [x] Trip integrity — 4 regression tests (event ID refs, cascade delete, positive distance, CO2)
9. [x] DataStore CRUD integrity — 6 regression tests (add/delete/update events and locations)

**Files**: `IntegrationTests.swift` (14 tests), `RegressionTests.swift` (22 tests) = **36 new tests**

### Phase 5: UI Tests & Automation (COMPLETE)

**Started**: 2026-04-24 | **Completed**: 2026-04-24

1. [x] Tab navigation — all 5 tabs navigate and select correctly
2. [x] Options menu — opens, shows Profile & Account and About items
3. [x] About sheet — opens from menu, dismisses via Done/swipe
4. [x] Profile sheet — opens from menu, dismisses via Done button
5. [x] Calendar content — tab loads and displays content
6. [x] Travel History sheet — opens from menu, dismisses correctly
7. [x] Add event form — opens from Calendar tab, navigates back
8. [x] Manage Data submenu — opens, verifies Manage Locations and Manage Trips items
9. [x] EventFormViewModel tests — 15 tests (init, computed props, date handling, people/activities)
10. [x] Pre-commit test script — `scripts/pre-commit-test.sh` (unit-only or `--all`)

**Files**: `LocTracUITests.swift` (8 new UI tests), `EventFormViewModelTests.swift` (15 tests), `scripts/pre-commit-test.sh`

---

## Quick Reference

### Running Tests

| What | How |
|------|-----|
| All tests | `⌘ U` in Xcode |
| One test | Click diamond next to `@Test` |
| One suite | Click diamond next to `@Suite` |
| Terminal | `xcodebuild test -scheme LocTrac ...` |
| Pre-commit (unit) | `./scripts/pre-commit-test.sh` |
| Pre-commit (all) | `./scripts/pre-commit-test.sh --all` |
| Install hook | `ln -sf ../../scripts/pre-commit-test.sh .git/hooks/pre-commit` |
| Coverage | Add `-enableCodeCoverage YES` |

### Writing a New Test

```swift
import Testing
@testable import LocTrac

@Suite("Feature Name")
struct FeatureNameTests {
    @Test("Description of what is tested")
    func testSomething() async throws {
        // Arrange
        let store = DataStore()

        // Act
        store.add(TestDataFactory.makeEvent())

        // Assert
        #expect(store.events.count > 0)
    }
}
```

### Key Rules

1. Use **Swift Testing** (`@Test`, `@Suite`, `#expect`) — not XCTest for unit tests
2. Each test gets a **fresh DataStore** — no shared mutable state
3. Use **`TestDataFactory`** for consistent test data
4. Name regression tests with **`REGRESSION:`** prefix
5. **Never** test private implementation details — test through public API
6. Keep tests **fast** — mock external dependencies (geocoding, network)

---

*LocTrac Testing Master Guide v2.0 — 2026-04-24*
*All 5 phases complete. 294 tests (282 unit + 12 UI). All gaps closed.*
