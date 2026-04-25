//
//  IntegrationTests.swift
//  LocTracTests
//
//  Phase 4A integration tests covering the import pipeline,
//  export-import roundtrip, trip creation pipeline, and
//  DataStore load behavior.
//
//  Uses Swift Testing framework (@Suite, @Test, #expect).
//

import Testing
import Foundation
@testable import LocTrac

@Suite("Integration Tests")
struct IntegrationTests {

    // MARK: - Shared Helpers

    /// JSON decoder configured the same way the app decodes backup files.
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// JSON encoder configured with ISO 8601 dates for roundtrip consistency.
    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    // MARK: - 1. Import Pipeline Tests

    @Test("Decode fixtureBackupJSON produces correct counts for all collections")
    func testDecodeFixtureBackup() throws {
        let imported = try decoder.decode(Import.self, from: TestDataFactory.fixtureBackupJSON)

        #expect(imported.locations.count == 2,
                "Expected 2 locations, got \(imported.locations.count)")
        #expect(imported.events.count == 3,
                "Expected 3 events, got \(imported.events.count)")
        #expect(imported.activities?.count == 2,
                "Expected 2 activities, got \(imported.activities?.count ?? 0)")
        #expect(imported.affirmations?.count == 1,
                "Expected 1 affirmation, got \(imported.affirmations?.count ?? 0)")
        #expect(imported.trips?.count == 1,
                "Expected 1 trip, got \(imported.trips?.count ?? 0)")
        #expect(imported.eventTypes?.count == 2,
                "Expected 2 eventTypes, got \(imported.eventTypes?.count ?? 0)")
    }

    @Test("Decode legacyV13BackupJSON has nil for optional collections")
    func testDecodeLegacyV13Backup() throws {
        let imported = try decoder.decode(Import.self, from: TestDataFactory.legacyV13BackupJSON)

        #expect(imported.locations.count == 1,
                "Expected 1 location, got \(imported.locations.count)")
        #expect(imported.events.count == 1,
                "Expected 1 event, got \(imported.events.count)")

        // v1.3 backups have no activities, affirmations, trips, or eventTypes keys
        #expect(imported.activities == nil,
                "Legacy backup should have nil activities")
        #expect(imported.affirmations == nil,
                "Legacy backup should have nil affirmations")
        #expect(imported.trips == nil,
                "Legacy backup should have nil trips")
        #expect(imported.eventTypes == nil,
                "Legacy backup should have nil eventTypes")
    }

    @Test("Decode minimalBackupJSON has empty arrays and nil optionals")
    func testDecodeMinimalBackup() throws {
        let imported = try decoder.decode(Import.self, from: TestDataFactory.minimalBackupJSON)

        #expect(imported.locations.isEmpty,
                "Minimal backup should have empty locations")
        #expect(imported.events.isEmpty,
                "Minimal backup should have empty events")
        #expect(imported.activities == nil,
                "Minimal backup should have nil activities")
        #expect(imported.affirmations == nil,
                "Minimal backup should have nil affirmations")
        #expect(imported.trips == nil,
                "Minimal backup should have nil trips")
        #expect(imported.eventTypes == nil,
                "Minimal backup should have nil eventTypes")
    }

    @Test("Decode sampleBackupData produces expected production-scale counts")
    func testDecodeSampleBackup() throws {
        guard let data = TestDataFactory.sampleBackupData else {
            // Skip if sample_backup.json fixture is not available
            return
        }

        let imported = try decoder.decode(Import.self, from: data)

        #expect(imported.events.count == 1590,
                "Expected 1590 events, got \(imported.events.count)")
        #expect(imported.locations.count == 7,
                "Expected 7 locations, got \(imported.locations.count)")
        #expect(imported.trips?.count == 384,
                "Expected 384 trips, got \(imported.trips?.count ?? 0)")
        #expect(imported.activities?.count == 13,
                "Expected 13 activities, got \(imported.activities?.count ?? 0)")
        #expect(imported.affirmations?.count == 25,
                "Expected 25 affirmations, got \(imported.affirmations?.count ?? 0)")
        #expect(imported.eventTypes?.count == 6,
                "Expected 6 eventTypes, got \(imported.eventTypes?.count ?? 0)")
    }

    // MARK: - 2. Export-Import Roundtrip

    @Test("Export encode then decode as Import preserves collection counts")
    func testExportImportRoundtrip() throws {
        // Build known model data
        let location1 = TestDataFactory.makeLocation(id: "loc-rt1", name: "Denver Home")
        let location2 = TestDataFactory.makeLocation(
            id: "loc-rt2", name: "Beach",
            city: "Cabo", latitude: 22.8905, longitude: -109.9167,
            country: "Mexico", theme: .green
        )
        let event1 = TestDataFactory.makeEvent(
            id: "evt-rt1", eventType: .stay,
            date: Date().startOfDay, location: location1
        )
        let event2 = TestDataFactory.makeEvent(
            id: "evt-rt2", eventType: .vacation,
            date: Date().startOfDay, location: location2,
            latitude: 22.8905, longitude: -109.9167,
            country: "Mexico", note: "Beach vacation"
        )
        let activity = TestDataFactory.makeActivity(name: "Snorkeling")
        let affirmation = Affirmation(
            text: "Roundtrip test",
            category: .gratitude,
            color: "blue",
            isFavorite: false
        )
        let trip = TestDataFactory.makeTrip(
            fromEventID: event1.id,
            toEventID: event2.id,
            distance: 1200,
            transportMode: .flying
        )
        let eventType = TestDataFactory.makeEventType(
            name: "vacation",
            displayName: "Vacation",
            sfSymbol: "airplane",
            colorName: "green"
        )

        // Encode via Export init that maps model arrays
        let export = Export(
            locations: [location1, location2],
            events: [event1, event2],
            activities: [activity],
            affirmations: [affirmation],
            trips: [trip],
            eventTypes: [eventType]
        )
        let jsonData = try encoder.encode(export)

        // Decode back as Import
        let imported = try decoder.decode(Import.self, from: jsonData)

        #expect(imported.locations.count == 2,
                "Roundtrip should preserve 2 locations")
        #expect(imported.events.count == 2,
                "Roundtrip should preserve 2 events")
        #expect(imported.activities?.count == 1,
                "Roundtrip should preserve 1 activity")
        #expect(imported.affirmations?.count == 1,
                "Roundtrip should preserve 1 affirmation")
        #expect(imported.trips?.count == 1,
                "Roundtrip should preserve 1 trip")
        #expect(imported.eventTypes?.count == 1,
                "Roundtrip should preserve 1 eventType")

        // Verify key data survived the roundtrip
        let importedLoc = try #require(imported.locations.first(where: { $0.id == "loc-rt1" }))
        #expect(importedLoc.name == "Denver Home")

        let importedEvt = try #require(imported.events.first(where: { $0.id == "evt-rt2" }))
        #expect(importedEvt.note == "Beach vacation")
        #expect(importedEvt.country == "Mexico")
    }

    // MARK: - 3. Trip Creation Pipeline

    @Test("suggestTrip returns trip for events at different distant locations")
    func testTripSuggestionDifferentLocations() {
        // Denver
        let denverLoc = TestDataFactory.makeLocation(
            id: "loc-denver", name: "Denver Home",
            latitude: 39.7392, longitude: -104.9903
        )
        let denverEvent = TestDataFactory.makeEvent(
            id: "evt-denver", location: denverLoc,
            latitude: 39.7392, longitude: -104.9903
        )

        // Cabo San Lucas
        let caboLoc = TestDataFactory.makeLocation(
            id: "loc-cabo", name: "Cabo",
            city: "Cabo San Lucas",
            latitude: 22.8905, longitude: -109.9167,
            country: "Mexico"
        )
        let caboEvent = TestDataFactory.makeEvent(
            id: "evt-cabo", location: caboLoc,
            latitude: 22.8905, longitude: -109.9167,
            country: "Mexico"
        )

        let trip = TripMigrationUtility.suggestTrip(from: denverEvent, to: caboEvent)

        #expect(trip != nil, "Trip should be suggested between Denver and Cabo")
        if let trip = trip {
            #expect(trip.fromEventID == "evt-denver")
            #expect(trip.toEventID == "evt-cabo")
            #expect(trip.distance > 100,
                    "Denver to Cabo should be well over 100 miles, got \(trip.distance)")
        }
    }

    @Test("suggestTrip returns nil for events at the same named location")
    func testTripSuggestionSameLocation() {
        let loc = TestDataFactory.makeLocation(
            id: "loc-same", name: "Home",
            latitude: 39.7392, longitude: -104.9903
        )
        let event1 = TestDataFactory.makeEvent(
            id: "evt-same1", location: loc,
            latitude: 39.7392, longitude: -104.9903
        )
        let event2 = TestDataFactory.makeEvent(
            id: "evt-same2", location: loc,
            latitude: 39.7392, longitude: -104.9903
        )

        let trip = TripMigrationUtility.suggestTrip(from: event1, to: event2)
        #expect(trip == nil,
                "No trip should be suggested for events at the same location")
    }

    @Test("suggestTrip returns nil for events less than 0.5 miles apart")
    func testTripSuggestionTooClose() {
        // Two "Other" locations very close together (< 0.5 miles)
        let loc1 = TestDataFactory.makeLocation(
            id: "loc-close1", name: "Other",
            latitude: 39.7392, longitude: -104.9903
        )
        let loc2 = TestDataFactory.makeLocation(
            id: "loc-close2", name: "Other",
            latitude: 39.7395, longitude: -104.9900  // ~0.02 miles away
        )
        let event1 = TestDataFactory.makeEvent(
            id: "evt-close1", location: loc1,
            latitude: 39.7392, longitude: -104.9903
        )
        let event2 = TestDataFactory.makeEvent(
            id: "evt-close2", location: loc2,
            latitude: 39.7395, longitude: -104.9900
        )

        let trip = TripMigrationUtility.suggestTrip(from: event1, to: event2)
        #expect(trip == nil,
                "No trip should be suggested for events < 0.5 miles apart")
    }

    @Test("migrateEventsToTrips generates correct trips for alternating locations")
    func testTripMigrationMultipleEvents() {
        let denverLoc = TestDataFactory.makeLocation(
            id: "loc-denver", name: "Denver",
            latitude: 39.7392, longitude: -104.9903
        )
        let caboLoc = TestDataFactory.makeLocation(
            id: "loc-cabo", name: "Cabo",
            city: "Cabo San Lucas",
            latitude: 22.8905, longitude: -109.9167,
            country: "Mexico"
        )

        // 4 events alternating: Denver, Cabo, Denver, Cabo
        let cal = Calendar(identifier: .gregorian)
        let baseDate = Date().startOfDay
        let events = [
            TestDataFactory.makeEvent(
                id: "evt-m1", location: denverLoc,
                date: cal.date(byAdding: .day, value: 0, to: baseDate)!.startOfDay,
                latitude: 39.7392, longitude: -104.9903
            ),
            TestDataFactory.makeEvent(
                id: "evt-m2", location: caboLoc,
                date: cal.date(byAdding: .day, value: 5, to: baseDate)!.startOfDay,
                latitude: 22.8905, longitude: -109.9167, country: "Mexico"
            ),
            TestDataFactory.makeEvent(
                id: "evt-m3", location: denverLoc,
                date: cal.date(byAdding: .day, value: 10, to: baseDate)!.startOfDay,
                latitude: 39.7392, longitude: -104.9903
            ),
            TestDataFactory.makeEvent(
                id: "evt-m4", location: caboLoc,
                date: cal.date(byAdding: .day, value: 15, to: baseDate)!.startOfDay,
                latitude: 22.8905, longitude: -109.9167, country: "Mexico"
            ),
        ]

        let trips = TripMigrationUtility.migrateEventsToTrips(events: events)

        // Each pair of consecutive events at different locations should produce a trip:
        // Denver->Cabo, Cabo->Denver, Denver->Cabo = 3 trips
        #expect(trips.count == 3,
                "4 alternating events should produce 3 trips, got \(trips.count)")

        // All trips should be auto-generated
        for trip in trips {
            #expect(trip.isAutoGenerated,
                    "Migrated trips should be marked as auto-generated")
            #expect(trip.distance > 0,
                    "Each trip should have a positive distance")
        }
    }

    @Test("TransportMode.detectMode returns correct mode for distance thresholds")
    func testTransportModeDetection() {
        // Short distance (<= 3 miles) -> walking
        let walkMode = Trip.TransportMode.detectMode(distance: 2.0)
        #expect(walkMode == .walking,
                "Distance of 2 miles should suggest walking, got \(walkMode)")

        // Boundary at exactly 3 miles -> walking
        let boundaryWalk = Trip.TransportMode.detectMode(distance: 3.0)
        #expect(boundaryWalk == .walking,
                "Distance of exactly 3 miles should suggest walking, got \(boundaryWalk)")

        // Medium distance (3-100 miles) -> driving
        let driveMode = Trip.TransportMode.detectMode(distance: 50.0)
        #expect(driveMode == .driving,
                "Distance of 50 miles should suggest driving, got \(driveMode)")

        // Boundary at exactly 100 miles -> driving
        let boundaryDrive = Trip.TransportMode.detectMode(distance: 100.0)
        #expect(boundaryDrive == .driving,
                "Distance of exactly 100 miles should suggest driving, got \(boundaryDrive)")

        // Long distance (> 100 miles) -> flying
        let flyMode = Trip.TransportMode.detectMode(distance: 500.0)
        #expect(flyMode == .flying,
                "Distance of 500 miles should suggest flying, got \(flyMode)")

        // Very long distance -> flying
        let longFlyMode = Trip.TransportMode.detectMode(distance: 5000.0)
        #expect(longFlyMode == .flying,
                "Distance of 5000 miles should suggest flying, got \(longFlyMode)")
    }

    // MARK: - 4. DataStore Load Behavior

    @Test("DataStore preview mode always contains an 'Other' location")
    @MainActor
    func testOtherLocationAlwaysExists() {
        let store = DataStore(preview: true)
        let hasOther = store.locations.contains {
            $0.name.caseInsensitiveCompare("Other") == .orderedSame
        }
        #expect(hasOther,
                "DataStore(preview: true) must seed the 'Other' location")
    }

    @Test("DataStore preview mode seeds default activities and affirmations")
    @MainActor
    func testDefaultSeedingOnEmptyLoad() {
        let store = DataStore(preview: true)

        #expect(store.activities.count > 0,
                "DataStore should seed default activities on empty load, got \(store.activities.count)")
        #expect(store.affirmations.count > 0,
                "DataStore should seed default affirmations on empty load, got \(store.affirmations.count)")
    }
}
