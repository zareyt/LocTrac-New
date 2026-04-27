//
//  ImportExportTests.swift
//  LocTracTests
//
//  Tests for Import/Export encoding, decoding, legacy compatibility,
//  data integrity, security, and edge cases.
//

import Testing
import Foundation
@testable import LocTrac

@Suite("Import/Export Tests")
struct ImportExportTests {

    // MARK: - Helpers

    /// Shared JSON decoder configured the same way the app uses internally.
    private var decoder: JSONDecoder { JSONDecoder() }
    private var encoder: JSONEncoder { JSONEncoder() }

    // MARK: - Roundtrip Tests

    @Test("Export struct encodes to valid JSON")
    func exportEncodesToValidJSON() throws {
        let location = TestDataFactory.makeLocation(id: "loc-1", name: "Denver")
        let event = TestDataFactory.makeEvent(id: "evt-1", location: location)
        let activity = TestDataFactory.makeActivity(name: "Golf")
        let eventType = TestDataFactory.makeEventType(name: "stay", displayName: "Stay")

        let export = Export(
            locations: [location],
            events: [event],
            activities: [activity],
            affirmations: [],
            trips: [],
            eventTypes: [eventType],
            exerciseEntries: [],
            cars: []
        )

        let data = try encoder.encode(export)
        // Verify it's valid JSON by parsing with JSONSerialization
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        let dict = try #require(jsonObject as? [String: Any])
        #expect(dict["locations"] != nil)
        #expect(dict["events"] != nil)
        #expect(dict["activities"] != nil)
        #expect(dict["eventTypes"] != nil)
    }

    @Test("Decode Import from fixtureBackupJSON succeeds with correct counts")
    func decodeFixtureBackupJSON() throws {
        let imported = try decoder.decode(Import.self, from: TestDataFactory.fixtureBackupJSON)

        #expect(imported.locations.count == 2)
        #expect(imported.events.count == 3)
        #expect(imported.activities?.count == 2)
        #expect(imported.affirmations?.count == 1)
        #expect(imported.trips?.count == 1)
        #expect(imported.eventTypes?.count == 2)
    }

    @Test("Export encode then decode preserves data")
    func exportEncodeDecodeRoundtrip() throws {
        let location = TestDataFactory.makeLocation(
            id: "loc-rt",
            name: "Roundtrip Place",
            city: "Boulder",
            state: "Colorado",
            country: "United States",
            countryCode: "US"
        )
        let event = TestDataFactory.makeEvent(
            id: "evt-rt",
            eventType: .vacation,
            location: location,
            note: "Roundtrip note"
        )
        let activity = TestDataFactory.makeActivity(name: "Skiing")
        let eventType = TestDataFactory.makeEventType(
            name: "vacation",
            displayName: "Vacation",
            sfSymbol: "airplane",
            colorName: "green"
        )

        let export = Export(
            locations: [location],
            events: [event],
            activities: [activity],
            affirmations: [],
            trips: [],
            eventTypes: [eventType],
            exerciseEntries: [],
            cars: []
        )

        let data = try encoder.encode(export)
        let decoded = try decoder.decode(Export.self, from: data)

        #expect(decoded.locations.count == 1)
        #expect(decoded.locations.first?.name == "Roundtrip Place")
        #expect(decoded.locations.first?.city == "Boulder")
        #expect(decoded.locations.first?.state == "Colorado")
        #expect(decoded.events.count == 1)
        #expect(decoded.events.first?.note == "Roundtrip note")
        #expect(decoded.events.first?.eventType == "vacation")
        #expect(decoded.activities.count == 1)
        #expect(decoded.activities.first?.name == "Skiing")
        #expect(decoded.eventTypes.count == 1)
        #expect(decoded.eventTypes.first?.sfSymbol == "airplane")
    }

    // MARK: - Legacy Compatibility Tests

    @Test("Import v1.3 backup defaults missing collections to nil/empty")
    func importLegacyV13Backup() throws {
        let imported = try decoder.decode(Import.self, from: TestDataFactory.legacyV13BackupJSON)

        #expect(imported.locations.count == 1)
        #expect(imported.events.count == 1)
        // v1.3 backups have no activities, affirmations, trips, or eventTypes keys
        #expect(imported.activities == nil)
        #expect(imported.affirmations == nil)
        #expect(imported.trips == nil)
        #expect(imported.eventTypes == nil)

        // Verify the location decoded correctly without state/countryCode
        let loc = try #require(imported.locations.first)
        #expect(loc.name == "Legacy Place")
        #expect(loc.state == nil)
        #expect(loc.countryCode == nil)
    }

    @Test("Import minimal backup with only locations and events succeeds")
    func importMinimalBackup() throws {
        let imported = try decoder.decode(Import.self, from: TestDataFactory.minimalBackupJSON)

        #expect(imported.locations.isEmpty)
        #expect(imported.events.isEmpty)
        #expect(imported.activities == nil)
        #expect(imported.affirmations == nil)
        #expect(imported.trips == nil)
        #expect(imported.eventTypes == nil)
    }

    // MARK: - Data Integrity Tests

    @Test("Decoded locations have correct city/state/country")
    func decodedLocationsHaveCorrectGeo() throws {
        let imported = try decoder.decode(Import.self, from: TestDataFactory.fixtureBackupJSON)

        let home = try #require(imported.locations.first(where: { $0.id == "loc-home" }))
        #expect(home.city == "Denver")
        #expect(home.state == "Colorado")
        #expect(home.country == "United States")
        #expect(home.countryCode == "US")
    }

    @Test("Decoded events reference valid location IDs present in locations array")
    func decodedEventsReferenceValidLocationIDs() throws {
        let imported = try decoder.decode(Import.self, from: TestDataFactory.fixtureBackupJSON)

        let locationIDs = Set(imported.locations.map { $0.id })
        for event in imported.events {
            #expect(locationIDs.contains(event.locationID),
                    "Event \(event.id) references unknown locationID '\(event.locationID)'")
        }
    }

    @Test("Other location events carry event-level city and country")
    func otherLocationEventsHaveEventLevelGeo() throws {
        let imported = try decoder.decode(Import.self, from: TestDataFactory.fixtureBackupJSON)

        let otherEvent = try #require(imported.events.first(where: { $0.locationID == "loc-other" }))
        #expect(otherEvent.city == "Cabo San Lucas")
        #expect(otherEvent.country == "Mexico")
    }

    @Test("Trips decode with String event IDs, not UUID")
    func tripsHaveStringEventIDs() throws {
        let imported = try decoder.decode(Import.self, from: TestDataFactory.fixtureBackupJSON)

        let trip = try #require(imported.trips?.first)
        #expect(trip.fromEventID == "evt-002")
        #expect(trip.toEventID == "evt-003")
        // Verify they are plain Strings (not UUID representations that differ)
        #expect(trip.fromEventID == "evt-002")
    }

    // MARK: - Security Tests

    @Test("Exported JSON never contains password or auth-related keys")
    func exportedJSONContainsNoAuthData() throws {
        let location = TestDataFactory.makeLocation()
        let event = TestDataFactory.makeEvent(location: location)

        let export = Export(
            locations: [location],
            events: [event],
            activities: [],
            affirmations: [],
            trips: [],
            eventTypes: [],
            exerciseEntries: [],
            cars: []
        )

        let data = try encoder.encode(export)
        let jsonString = try #require(String(data: data, encoding: .utf8))

        let forbiddenKeys = ["password", "token", "secret", "keychain", "credential", "auth"]
        for key in forbiddenKeys {
            #expect(!jsonString.lowercased().contains(key),
                    "Export JSON should never contain '\(key)'")
        }
    }

    @Test("Profile data is separate from backup data — Export has no profile fields")
    func profileDataSeparateFromBackup() throws {
        let data = try encoder.encode(
            Export(
                locations: [],
                events: [],
                activities: [],
                affirmations: [],
                trips: [],
                eventTypes: [],
                exerciseEntries: [],
                cars: []
            )
        )
        let dict = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        // Export should only contain these top-level keys
        let allowedKeys: Set<String> = ["locations", "events", "activities", "affirmations", "trips", "eventTypes"]
        for key in dict.keys {
            #expect(allowedKeys.contains(key),
                    "Unexpected key '\(key)' found in export — profile data must stay separate")
        }
    }

    // MARK: - Edge Case Tests

    @Test("Empty arrays decode correctly via Export tolerant decoder")
    func emptyArraysDecodeCorrectly() throws {
        let json = Data("""
        {
            "locations": [],
            "events": []
        }
        """.utf8)

        // Export's tolerant init(from decoder:) defaults missing arrays to []
        let decoded = try decoder.decode(Export.self, from: json)
        #expect(decoded.locations.isEmpty)
        #expect(decoded.events.isEmpty)
        #expect(decoded.activities.isEmpty)
        #expect(decoded.affirmations.isEmpty)
        #expect(decoded.trips.isEmpty)
        #expect(decoded.eventTypes.isEmpty)
    }

    @Test("Unknown eventType string decodes without crash")
    func unknownEventTypeDecodesGracefully() throws {
        let json = Data("""
        {
            "locations": [
                {"id": "loc-1", "name": "Place", "latitude": 0, "longitude": 0, "theme": "blue"}
            ],
            "events": [
                {
                    "locationID": "loc-1",
                    "id": "evt-1",
                    "eventType": "totally_unknown_type",
                    "date": "2026-03-01T00:00:00Z",
                    "latitude": 0,
                    "longitude": 0,
                    "note": "Unknown type event",
                    "activityIDs": [],
                    "affirmationIDs": []
                }
            ]
        }
        """.utf8)

        // Import struct stores eventType as a raw String, so any value is valid
        let imported = try decoder.decode(Import.self, from: json)
        let event = try #require(imported.events.first)
        #expect(event.eventType == "totally_unknown_type")
    }

    @Test("Legacy export missing imageIDs decodes with empty array via Export tolerant decoder")
    func missingImageIDsDefaultsToEmpty() throws {
        let json = Data("""
        {
            "locations": [
                {"id": "loc-1", "name": "Place", "latitude": 0, "longitude": 0, "theme": "blue"}
            ],
            "events": [
                {
                    "locationID": "loc-1",
                    "id": "evt-1",
                    "eventType": "stay",
                    "date": "2026-03-01T00:00:00Z",
                    "latitude": 0,
                    "longitude": 0,
                    "note": "No imageIDs key",
                    "activityIDs": [],
                    "affirmationIDs": []
                }
            ]
        }
        """.utf8)

        // Export.EventData's init(from decoder:) defaults imageIDs to []
        let decoded = try decoder.decode(Export.self, from: json)
        let event = try #require(decoded.events.first)
        #expect(event.imageIDs.isEmpty)
    }
}
