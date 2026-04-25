import Testing
@testable import LocTrac

@Suite("Activity Picker Logic Tests")
struct ActivityPickerTests {

    // MARK: - Test Data

    private static let sampleActivities = [
        Activity(id: "a1", name: "Golf"),
        Activity(id: "a2", name: "Hiking"),
        Activity(id: "a3", name: "Swimming"),
        Activity(id: "a4", name: "Dining"),
        Activity(id: "a5", name: "Sightseeing"),
    ]

    // MARK: - Toggle Logic

    @Test("Toggle adds activity ID when not selected")
    func toggleAddsActivity() {
        var selectedIDs: [String] = []
        toggleActivity("a1", in: &selectedIDs)
        #expect(selectedIDs == ["a1"])
    }

    @Test("Toggle removes activity ID when already selected")
    func toggleRemovesActivity() {
        var selectedIDs: [String] = ["a1", "a2"]
        toggleActivity("a1", in: &selectedIDs)
        #expect(selectedIDs == ["a2"])
    }

    @Test("Toggle multiple activities builds correct list")
    func toggleMultiple() {
        var selectedIDs: [String] = []
        toggleActivity("a1", in: &selectedIDs)
        toggleActivity("a3", in: &selectedIDs)
        toggleActivity("a5", in: &selectedIDs)
        #expect(selectedIDs == ["a1", "a3", "a5"])
    }

    @Test("Toggle same activity twice results in empty list")
    func toggleSameTwice() {
        var selectedIDs: [String] = []
        toggleActivity("a1", in: &selectedIDs)
        toggleActivity("a1", in: &selectedIDs)
        #expect(selectedIDs.isEmpty)
    }

    // MARK: - Selection Filtering

    @Test("Selected activities filters correctly from full list")
    func selectedActivitiesFiltering() {
        let selectedIDs = ["a2", "a4"]
        let result = selectedIDs.compactMap { id in
            Self.sampleActivities.first { $0.id == id }
        }
        #expect(result.count == 2)
        #expect(result[0].name == "Hiking")
        #expect(result[1].name == "Dining")
    }

    @Test("Selected activities preserves order of selection")
    func selectedActivitiesOrder() {
        let selectedIDs = ["a5", "a1", "a3"]
        let result = selectedIDs.compactMap { id in
            Self.sampleActivities.first { $0.id == id }
        }
        #expect(result.map(\.name) == ["Sightseeing", "Golf", "Swimming"])
    }

    @Test("Selected activities with invalid ID returns fewer results")
    func selectedActivitiesInvalidID() {
        let selectedIDs = ["a1", "nonexistent", "a3"]
        let result = selectedIDs.compactMap { id in
            Self.sampleActivities.first { $0.id == id }
        }
        #expect(result.count == 2)
    }

    @Test("Empty selection returns empty array")
    func emptySelection() {
        let selectedIDs: [String] = []
        let result = selectedIDs.compactMap { id in
            Self.sampleActivities.first { $0.id == id }
        }
        #expect(result.isEmpty)
    }

    // MARK: - Clear All

    @Test("Clear all removes all selections")
    func clearAll() {
        var selectedIDs = ["a1", "a2", "a3"]
        selectedIDs.removeAll()
        #expect(selectedIDs.isEmpty)
    }

    // MARK: - Remove Single Chip

    @Test("Removing specific activity ID preserves others")
    func removeSpecificActivity() {
        var selectedIDs = ["a1", "a2", "a3"]
        selectedIDs.removeAll { $0 == "a2" }
        #expect(selectedIDs == ["a1", "a3"])
    }

    @Test("Removing non-existent ID is a no-op")
    func removeNonExistentID() {
        var selectedIDs = ["a1", "a2"]
        selectedIDs.removeAll { $0 == "a9" }
        #expect(selectedIDs == ["a1", "a2"])
    }

    // MARK: - Helpers

    private func toggleActivity(_ id: String, in selectedIDs: inout [String]) {
        if let idx = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: idx)
        } else {
            selectedIDs.append(id)
        }
    }
}
