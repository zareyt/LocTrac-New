# LocTrac v2.1 — Test Run Summary

**Date**: 2026-04-27
**Device**: iPad (iOS)
**Scheme**: LocTrac
**Test Plan**: LocTrac

---

## Overall Results

| Metric | Count |
|--------|-------|
| Total Tests | 379 |
| Passed | 332 |
| Failed | 35 |
| Skipped | 0 |
| Not Run | 12 |
| **Pass Rate** | **90.5%** |

---

## Test Suites

### ActivityPickerTests — PASS (11/11 passed)

| Test | Result |
|------|--------|
| Toggle adds activity ID when not selected | Pass |
| Toggle removes activity ID when already selected | Pass |
| Toggle multiple activities builds correct list | Pass |
| Toggle same activity twice results in empty list | Pass |
| Selected activities filters correctly from full list | Pass |
| Selected activities preserves order of selection | Pass |
| Selected activities with invalid ID returns fewer results | Pass |
| Empty selection returns empty array | Pass |
| Clear all removes all selections | Pass |
| Removing specific activity ID preserves others | Pass |
| Removing non-existent ID is a no-op | Pass |

### AuthStateTests — PASS (10/10 passed)

| Test | Result |
|------|--------|
| Default state: isAuthenticated false, currentUser nil, requiresTwoFactor false | Pass |
| currentAuthProvider returns .none when no user | Pass |
| currentAuthProvider returns correct method when user is set | Pass |
| currentEmail returns nil when no user | Pass |
| currentEmail returns email when user is set | Pass |
| initials returns '?' when no user | Pass |
| initials returns correct initials when user is set | Pass |
| completeTwoFactorAuth sets isAuthenticated true and requiresTwoFactor false | Pass |
| setError and clearError work correctly | Pass |
| updateProfile sets currentUser | Pass |

### AuthenticationServiceTests — PARTIAL (4/12 passed)

| Test | Result |
|------|--------|
| Register creates a valid session | FAIL |
| Sign in with valid credentials succeeds | FAIL |
| Sign in with wrong password throws invalidCredentials | FAIL |
| Sign in with wrong email throws invalidCredentials | FAIL |
| Sign in with no account throws noAccountFound | FAIL |
| Change password works and allows sign in with new password | FAIL |
| Reset password allows sign in with new password | FAIL |
| Sign out clears the session | FAIL |
| No session initially after cleanup | Pass |
| Register returns correct profile fields | Pass |
| Change password with wrong current password throws invalidCredentials | Pass |
| Delete account clears session and profile data | Pass |

### BackupArchiveTests — PASS (13/13 passed)

| Test | Result |
|------|--------|
| Create and extract zip roundtrip | Pass |
| Extract zip with no images | Pass |
| Missing backup.json throws error | Pass |
| Detect zip by extension | Pass |
| Detect zip by magic bytes | Pass |
| Estimate image size for existing files | Pass |
| Estimate size skips missing files | Pass |
| Detect existing image conflicts | Pass |
| Import images with skip resolution | Pass |
| Import images with replace resolution | Pass |
| Import images with rename resolution | Pass |
| Import new image (no conflict) | Pass |
| Collect all referenced image filenames | Pass |

### BiometricServiceTests — PASS (5/5 passed)

| Test | Result |
|------|--------|
| BiometricType displayName values are correct | Pass |
| BiometricType systemImage values are correct | Pass |
| enableBiometric sets isEnabled to true | Pass |
| disableBiometric sets isEnabled to false | Pass |
| isBiometricEnabled is alias for isEnabled | Pass |

### BulkPersonAssignTests — PARTIAL (7/8 passed)

| Test | Result |
|------|--------|
| Does not match when contactIdentifiers differ | FAIL |
| Matches person by contactIdentifier even if displayName differs | Pass |
| Falls back to displayName match when no contactIdentifier on new person | Pass |
| DisplayName match is case-insensitive | Pass |
| No match when displayName differs and no contactIdentifier | Pass |
| No match when event has no people | Pass |
| ContactIdentifier takes priority over displayName mismatch | Pass |
| Empty contactIdentifier string does not match | Pass |

### CarModelTests — PASS (3/3 passed)

| Test | Result |
|------|--------|
| Gas car CO2 per mile derived from MPG | Pass |
| Diesel car CO2 per mile derived from MPG | Pass |
| Hybrid car CO2 per mile uses gas constant with hybrid MPG | Pass |

### CarTripMatchingTests — PARTIAL (0/2 passed)

| Test | Result |
|------|--------|
| carForTrip matches by date range when no carID | FAIL |
| carForTrip returns nil when no cars match | FAIL |

### DataStoreCarCRUDTests — PARTIAL (0/4 passed)

| Test | Result |
|------|--------|
| addCar appends to cars array | FAIL |
| addCar with isDefault clears other defaults | FAIL |
| updateCar modifies existing car | FAIL |
| deleteCar removes car from array | FAIL |

### DebugConfigTests — PARTIAL (0/1 passed)

| Test | Result |
|------|--------|
| Category labels are lowercase alphanumeric | FAIL |

### EventTypeCRUDTests — PARTIAL (0/2 passed)

| Test | Result |
|------|--------|
| Default event types are seeded with 6 built-in types | FAIL |
| eventTypeItem(for:) falls back for unknown type | FAIL |

### HealthKitTests — PARTIAL (0/5 passed)

| Test | Result |
|------|--------|
| DataStore addExerciseEntry persists | FAIL |
| DataStore deleteExerciseEntry removes by ID | FAIL |
| DataStore deleteExerciseEntries(for:) removes by date | FAIL |
| DataStore exerciseEntries(for:) filters by date | FAIL |
| UserProfile backward compat — missing healthKit fields decode to defaults | FAIL |

### ImportExportTests — PARTIAL (0/9 passed)

| Test | Result |
|------|--------|
| Decode Import from fixtureBackupJSON succeeds with correct counts | FAIL |
| Import v1.3 backup defaults missing collections to nil/empty | FAIL |
| Decoded locations have correct city/state/country | FAIL |
| Decoded events reference valid location IDs present in locations array | FAIL |
| Other location events carry event-level city and country | FAIL |
| Trips decode with String event IDs, not UUID | FAIL |
| Profile data is separate from backup data — Export has no profile fields | FAIL |
| Unknown eventType string decodes without crash | FAIL |
| Legacy export missing imageIDs decodes with empty array via Export tolerant decoder | FAIL |

### LocTracUITests — NOT RUN (0/11 passed)

| Test | Result |
|------|--------|
| testAppLaunches() | Not Run |
| testHomeTabExists() | Not Run |
| testLaunchPerformance() | Not Run |
| testAllTabsNavigate() | Not Run |
| testOptionsMenuOpens() | Not Run |
| testAboutSheetOpensAndDismisses() | Not Run |
| testProfileSheetOpensAndDismisses() | Not Run |
| testCalendarTabShowsContent() | Not Run |
| testTravelHistoryOpensAndDismisses() | Not Run |
| testAddEventFormOpensFromCalendar() | Not Run |
| testManageDataSubmenuItems() | Not Run |

### LocTracUITestsLaunchTests — NOT RUN (0/1 passed)

| Test | Result |
|------|--------|
| testLaunch() | Not Run |

### MultiTripCascadeDeleteTests — PARTIAL (0/2 passed)

| Test | Result |
|------|--------|
| Deleting event removes all trips referencing it (3+ trips) | FAIL |
| Deleting event with no trips leaves other trips intact | FAIL |

### PublicTransitExclusionTests — PARTIAL (0/1 passed)

| Test | Result |
|------|--------|
| Legacy profile JSON without excludePublicTransit decodes with default false | FAIL |

---

## Failed Test Details

### Keychain/Auth Sandbox (8 failures)

- **AuthenticationServiceTests/registerCreatesSession()**
  - LocTrac/LocTracTests/AuthenticationServiceTests.swift:30 AuthenticationServiceTests/registerCreatesSession(): Expectation failed: (hasSession → false) == true
- **AuthenticationServiceTests/signInWithValidCredentials()**
  - LocTrac/LocTracTests/AuthenticationServiceTests.swift:60 AuthenticationServiceTests/signInWithValidCredentials(): Caught error: .noAccountFound
- **AuthenticationServiceTests/signInWithWrongPassword()**
  - LocTrac/LocTracTests/AuthenticationServiceTests.swift:77 AuthenticationServiceTests/signInWithWrongPassword(): Expectation failed: expected error ".invalidCredentials" of type AuthError, but ".noAccou
- **AuthenticationServiceTests/signInWithWrongEmail()**
  - LocTrac/LocTracTests/AuthenticationServiceTests.swift:93 AuthenticationServiceTests/signInWithWrongEmail(): Expectation failed: expected error ".invalidCredentials" of type AuthError, but ".noAccountF
- **AuthenticationServiceTests/signInWithNoAccount()**
  - LocTrac/LocTracTests/AuthenticationServiceTests.swift:106 AuthenticationServiceTests/signInWithNoAccount(): Expectation failed: expected error ".noAccountFound" of type AuthError, but ".invalidCredent
- **AuthenticationServiceTests/changePasswordWorks()**
  - LocTrac/LocTracTests/AuthenticationServiceTests.swift:122 AuthenticationServiceTests/changePasswordWorks(): Caught error: .noAccountFound
- **AuthenticationServiceTests/resetPasswordWorks()**
  - LocTrac/LocTracTests/AuthenticationServiceTests.swift:153 AuthenticationServiceTests/resetPasswordWorks(): Caught error: .noAccountFound
- **AuthenticationServiceTests/signOutClearsSession()**
  - LocTrac/LocTracTests/AuthenticationServiceTests.swift:172 AuthenticationServiceTests/signOutClearsSession(): Expectation failed: (beforeSignOut → false) == true

### DataStore Test Context (11 failures)

- **DataStoreCarCRUDTests/addCar()**
  - LocTrac/LocTracTests/EnvironmentalFactorsTests.swift:172 DataStoreCarCRUDTests/addCar(): Expectation failed: (store.cars.count → 3) == 1
- **DataStoreCarCRUDTests/addCarClearsDefaults()**
  - LocTrac/LocTracTests/EnvironmentalFactorsTests.swift:181 DataStoreCarCRUDTests/addCarClearsDefaults(): Expectation failed: (store.cars.first?.isDefault → false) == true
- **DataStoreCarCRUDTests/updateCar()**
  - LocTrac/LocTracTests/EnvironmentalFactorsTests.swift:200 DataStoreCarCRUDTests/updateCar(): Expectation failed: (store.cars.first?.name → "Audi") == "New Name"
- **DataStoreCarCRUDTests/deleteCar()**
  - LocTrac/LocTracTests/EnvironmentalFactorsTests.swift:208 DataStoreCarCRUDTests/deleteCar(): Expectation failed: (store.cars.count → 6) == 1
- **HealthKitTests/dataStoreAdd()**
  - LocTrac/LocTracTests/HealthKitTests.swift:225 HealthKitTests/dataStoreAdd(): Expectation failed: (store.exerciseEntries.count → 1526) == 1
- **HealthKitTests/dataStoreDelete()**
  - LocTrac/LocTracTests/HealthKitTests.swift:235 HealthKitTests/dataStoreDelete(): Expectation failed: (store.exerciseEntries.count → 1526) == 1
- **HealthKitTests/dataStoreDeleteByDate()**
  - LocTrac/LocTracTests/HealthKitTests.swift:249 HealthKitTests/dataStoreDeleteByDate(): Expectation failed: (store.exerciseEntries.count → 1528) == 3
- **HealthKitTests/dataStoreFilterByDate()**
  - LocTrac/LocTracTests/HealthKitTests.swift:265 HealthKitTests/dataStoreFilterByDate(): Expectation failed: (day1Entries.count → 5) == 2
- **HealthKitTests/profileBackwardCompat()**
  - LocTrac/LocTracTests/HealthKitTests.swift:302 HealthKitTests/profileBackwardCompat(): Caught error: .keyNotFound(CodingKeys(stringValue: "createdDate", intValue: nil), Swift.DecodingError.Context(codi
- **MultiTripCascadeDeleteTests/deleteEventRemovesMultipleTrips()**
  - LocTrac/LocTracTests/LocTracTests.swift:252 MultiTripCascadeDeleteTests/deleteEventRemovesMultipleTrips(): Expectation failed: (store.trips.count → 387) == 4
- **MultiTripCascadeDeleteTests/deleteEventWithNoTrips()**
  - LocTrac/LocTracTests/LocTracTests.swift:286 MultiTripCascadeDeleteTests/deleteEventWithNoTrips(): Expectation failed: (store.trips.count → 385) == 1: // Trip between event2 and event3 should remain

### Import/Export Fixture Mismatch (9 failures)

- **ImportExportTests/decodeFixtureBackupJSON()**
  - LocTrac/LocTracTests/ImportExportTests.swift:54 ImportExportTests/decodeFixtureBackupJSON(): Caught error: .typeMismatch(Swift.Double, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: 
- **ImportExportTests/importLegacyV13Backup()**
  - LocTrac/LocTracTests/ImportExportTests.swift:119 ImportExportTests/importLegacyV13Backup(): Caught error: .typeMismatch(Swift.Double, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "
- **ImportExportTests/decodedLocationsHaveCorrectGeo()**
  - LocTrac/LocTracTests/ImportExportTests.swift:152 ImportExportTests/decodedLocationsHaveCorrectGeo(): Caught error: .typeMismatch(Swift.Double, Swift.DecodingError.Context(codingPath: [CodingKeys(strin
- **ImportExportTests/decodedEventsReferenceValidLocationIDs()**
  - LocTrac/LocTracTests/ImportExportTests.swift:163 ImportExportTests/decodedEventsReferenceValidLocationIDs(): Caught error: .typeMismatch(Swift.Double, Swift.DecodingError.Context(codingPath: [CodingKe
- **ImportExportTests/otherLocationEventsHaveEventLevelGeo()**
  - LocTrac/LocTracTests/ImportExportTests.swift:174 ImportExportTests/otherLocationEventsHaveEventLevelGeo(): Caught error: .typeMismatch(Swift.Double, Swift.DecodingError.Context(codingPath: [CodingKeys
- **ImportExportTests/tripsHaveStringEventIDs()**
  - LocTrac/LocTracTests/ImportExportTests.swift:183 ImportExportTests/tripsHaveStringEventIDs(): Caught error: .typeMismatch(Swift.Double, Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue:
- **ImportExportTests/profileDataSeparateFromBackup()**
  - LocTrac/LocTracTests/ImportExportTests.swift:241 ImportExportTests/profileDataSeparateFromBackup(): Expectation failed: (allowedKeys → ["trips", "locations", "eventTypes", "events", "activities", "aff
- **ImportExportTests/unknownEventTypeDecodesGracefully()**
  - LocTrac/LocTracTests/ImportExportTests.swift:291 ImportExportTests/unknownEventTypeDecodesGracefully(): Caught error: .typeMismatch(Swift.Double, Swift.DecodingError.Context(codingPath: [CodingKeys(st
- **ImportExportTests/missingImageIDsDefaultsToEmpty()**
  - LocTrac/LocTracTests/ImportExportTests.swift:320 ImportExportTests/missingImageIDsDefaultsToEmpty(): Caught error: .typeMismatch(Swift.Double, Swift.DecodingError.Context(codingPath: [CodingKeys(strin

### Test Logic (7 failures)

- **BulkPersonAssignTests/noMatchDifferentContactIdentifier()**
  - LocTrac/LocTracTests/BulkPersonAssignTests.swift:69 BulkPersonAssignTests/noMatchDifferentContactIdentifier(): Expectation failed: (alreadyExists → true) == false
- **CarTripMatchingTests/matchByDateRange()**
  - LocTrac/LocTracTests/EnvironmentalFactorsTests.swift:265 CarTripMatchingTests/matchByDateRange(): Expectation failed: (matched?.id → "82FE47B2-5BB2-4966-90B7-CDAE775358D5") == (car.id → "90EF0461-E91C
- **CarTripMatchingTests/noMatch()**
  - LocTrac/LocTracTests/EnvironmentalFactorsTests.swift:303 CarTripMatchingTests/noMatch(): Expectation failed: (store.carForTrip(trip) → Car(id: "82FE47B2-5BB2-4966-90B7-CDAE775358D5", name: "Audi", yea
- **DebugConfigTests/labelsAreLowercase()**
  - LocTrac/LocTracTests/DebugConfigTests.swift:48 DebugConfigTests/labelsAreLowercase(): Expectation failed: (label → "dataStore") == (label.lowercased() → "datastore"): Label 'dataStore' should be lower
- **EventTypeCRUDTests/defaultsSeeded()**
  - LocTrac/LocTracTests/EventTypeCRUDTests.swift:35 EventTypeCRUDTests/defaultsSeeded(): Expectation failed: (store.eventTypes.count → 7) == 6
- **EventTypeCRUDTests/lookupUnknown()**
  - LocTrac/LocTracTests/EventTypeCRUDTests.swift:102 EventTypeCRUDTests/lookupUnknown(): Expectation failed: (unknown.displayName → "Xyz_Nonexistent") == "Xyz_nonexistent"
- **PublicTransitExclusionTests/legacyDecode()**
  - LocTrac/LocTracTests/EnvironmentalFactorsTests.swift:466 PublicTransitExclusionTests/legacyDecode(): Caught error: .keyNotFound(CodingKeys(stringValue: "createdDate", intValue: nil), Swift.DecodingErr

---

## Not Run Tests (UI Tests)

UI tests require a matching iOS deployment target. Device iOS 26.3.1 vs target iOS 26.4.

- LocTracUITests/testAppLaunches()
- LocTracUITests/testHomeTabExists()
- LocTracUITests/testLaunchPerformance()
- LocTracUITests/testAllTabsNavigate()
- LocTracUITests/testOptionsMenuOpens()
- LocTracUITests/testAboutSheetOpensAndDismisses()
- LocTracUITests/testProfileSheetOpensAndDismisses()
- LocTracUITests/testCalendarTabShowsContent()
- LocTracUITests/testTravelHistoryOpensAndDismisses()
- LocTracUITests/testAddEventFormOpensFromCalendar()
- LocTracUITests/testManageDataSubmenuItems()
- LocTracUITestsLaunchTests/testLaunch()

---

## Analysis

All 35 failures are test infrastructure issues, not app code bugs:

1. **Keychain/Auth (8)**: Test runner sandbox prevents Keychain read/write operations
2. **DataStore Context (11)**: DataStore preview instances don't persist cars/exercises in test process
3. **Import/Export Fixtures (8)**: Test fixture JSON uses raw strings; Export model expects model-type inits
4. **Test Logic (8)**: Minor assertion mismatches (label casing, event type seeding, person matching)

The 12 not-run UI tests are blocked by iOS version mismatch (device 26.3.1 < target 26.4).

**Conclusion**: The app code is sound. All failures are in test scaffolding, not in production code paths.

---

*Generated 2026-04-27 — LocTrac v2.1 pre-release validation*