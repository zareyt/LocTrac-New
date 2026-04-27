import Testing
import Foundation
@testable import LocTrac

@Suite("HealthKit & Exercise Tests")
struct HealthKitTests {

    // MARK: - Helpers

    private static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func makeEntry(
        type: ExerciseEntry.WorkoutType = .running,
        date: Date = Date(),
        duration: Double = 30,
        distance: Double? = 3.0,
        calories: Double? = 250,
        sourceID: String? = nil
    ) -> ExerciseEntry {
        ExerciseEntry(
            date: date,
            workoutType: type,
            durationMinutes: duration,
            distanceMiles: distance,
            caloriesBurned: calories,
            sourceWorkoutID: sourceID
        )
    }

    // MARK: - ExerciseEntry Model

    @Test("ExerciseEntry initializes with correct defaults")
    func entryInit() {
        let entry = Self.makeEntry()
        #expect(!entry.id.isEmpty)
        #expect(entry.workoutType == .running)
        #expect(entry.durationMinutes == 30)
        #expect(entry.distanceMiles == 3.0)
        #expect(entry.caloriesBurned == 250)
    }

    @Test("ExerciseEntry encodes and decodes correctly")
    func entryCodable() throws {
        let entry = Self.makeEntry(type: .cycling, distance: 10.5, sourceID: "hk-123")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ExerciseEntry.self, from: data)
        #expect(decoded.id == entry.id)
        #expect(decoded.workoutType == .cycling)
        #expect(decoded.distanceMiles == 10.5)
        #expect(decoded.sourceWorkoutID == "hk-123")
    }

    @Test("WorkoutType has correct display names")
    func workoutTypeDisplayNames() {
        #expect(ExerciseEntry.WorkoutType.walking.displayName == "Walking")
        #expect(ExerciseEntry.WorkoutType.cycling.displayName == "Cycling")
        #expect(ExerciseEntry.WorkoutType.strengthTraining.displayName == "Strength Training")
        #expect(ExerciseEntry.WorkoutType.otherWorkout.displayName == "Other Workout")
    }

    @Test("WorkoutType has SF symbols")
    func workoutTypeSFSymbols() {
        #expect(ExerciseEntry.WorkoutType.running.sfSymbol == "figure.run")
        #expect(ExerciseEntry.WorkoutType.cycling.sfSymbol == "bicycle")
        #expect(ExerciseEntry.WorkoutType.yoga.sfSymbol == "figure.yoga")
    }

    @Test("WorkoutType CaseIterable has all 8 types")
    func workoutTypeCount() {
        #expect(ExerciseEntry.WorkoutType.allCases.count == 8)
    }

    // MARK: - ExerciseSummary

    @Test("ExerciseSummary returns nil for empty entries")
    func summaryEmpty() {
        let result = ExerciseSummary.compute(from: [])
        #expect(result == nil)
    }

    @Test("ExerciseSummary computes totals correctly")
    func summaryTotals() {
        let entries = [
            Self.makeEntry(type: .running, duration: 30, distance: 3.0, calories: 300),
            Self.makeEntry(type: .walking, duration: 45, distance: 2.5, calories: 150),
            Self.makeEntry(type: .yoga, duration: 60, distance: nil, calories: 100)
        ]
        let summary = ExerciseSummary.compute(from: entries)!
        #expect(summary.totalMinutes == 135)
        #expect(summary.totalCalories == 550)
        #expect(summary.totalDistanceMiles == 5.5)
    }

    @Test("ExerciseSummary counts active days correctly")
    func summaryActiveDays() {
        let day1 = Self.makeDate(year: 2026, month: 4, day: 1)
        let day2 = Self.makeDate(year: 2026, month: 4, day: 2)
        let entries = [
            Self.makeEntry(type: .running, date: day1),
            Self.makeEntry(type: .walking, date: day1),
            Self.makeEntry(type: .cycling, date: day2)
        ]
        let summary = ExerciseSummary.compute(from: entries)!
        #expect(summary.activeDays == 2)
    }

    @Test("ExerciseSummary computes avg minutes per active day")
    func summaryAvgPerDay() {
        let day1 = Self.makeDate(year: 2026, month: 4, day: 1)
        let day2 = Self.makeDate(year: 2026, month: 4, day: 2)
        let entries = [
            Self.makeEntry(type: .running, date: day1, duration: 60),
            Self.makeEntry(type: .walking, date: day2, duration: 40)
        ]
        let summary = ExerciseSummary.compute(from: entries)!
        #expect(summary.avgMinutesPerDay == 50.0)
    }

    @Test("ExerciseSummary workout breakdown sorted by count")
    func summaryBreakdown() {
        let entries = [
            Self.makeEntry(type: .running),
            Self.makeEntry(type: .running),
            Self.makeEntry(type: .running),
            Self.makeEntry(type: .cycling),
            Self.makeEntry(type: .yoga)
        ]
        let summary = ExerciseSummary.compute(from: entries)!
        #expect(summary.workoutTypeBreakdown.first?.type == .running)
        #expect(summary.workoutTypeBreakdown.first?.count == 3)
    }

    @Test("ExerciseSummary cycling CO2 offset calculation")
    func summaryCyclingCO2() {
        let entries = [
            Self.makeEntry(type: .cycling, distance: 10.0),
            Self.makeEntry(type: .cycling, distance: 5.0)
        ]
        let summary = ExerciseSummary.compute(from: entries)!
        #expect(summary.cyclingMiles == 15.0)
        #expect(summary.cyclingRideCount == 2)
        // 15 miles * 0.363 lbs/mile = 5.445
        #expect(abs(summary.co2SavedLbs - 5.445) < 0.001)
    }

    @Test("ExerciseSummary handles nil calories and distance")
    func summaryNilFields() {
        let entries = [
            Self.makeEntry(type: .yoga, duration: 60, distance: nil, calories: nil)
        ]
        let summary = ExerciseSummary.compute(from: entries)!
        #expect(summary.totalCalories == 0)
        #expect(summary.totalDistanceMiles == 0)
        #expect(summary.cyclingMiles == 0)
        #expect(summary.co2SavedLbs == 0)
    }

    @Test("CO2 per mile constant is EPA standard")
    func co2Constant() {
        #expect(ExerciseSummary.co2PerMile == 0.363)
    }

    @Test("ExerciseSummary per-type miles computed separately")
    func summaryPerTypeMiles() {
        let entries = [
            Self.makeEntry(type: .walking, distance: 2.0),
            Self.makeEntry(type: .walking, distance: 1.5),
            Self.makeEntry(type: .running, distance: 5.0),
            Self.makeEntry(type: .cycling, distance: 12.0),
            Self.makeEntry(type: .swimming, distance: 0.5),
            Self.makeEntry(type: .hiking, distance: 3.0),
            Self.makeEntry(type: .yoga, distance: nil)
        ]
        let summary = ExerciseSummary.compute(from: entries)!
        #expect(summary.walkingMiles == 3.5)
        #expect(summary.runningMiles == 5.0)
        #expect(summary.cyclingMiles == 12.0)
        #expect(summary.swimmingMiles == 0.5)
        #expect(summary.hikingMiles == 3.0)
    }

    @Test("ExerciseSummary breakdown includes totalMiles per type")
    func summaryBreakdownMiles() {
        let entries = [
            Self.makeEntry(type: .running, distance: 3.0),
            Self.makeEntry(type: .running, distance: 4.0)
        ]
        let summary = ExerciseSummary.compute(from: entries)!
        let runningItem = summary.workoutTypeBreakdown.first { $0.type == .running }
        #expect(runningItem != nil)
        #expect(runningItem?.totalMiles == 7.0)
    }

    @Test("UserProfile ignoredWorkoutTypes defaults to empty")
    func profileIgnoredDefaults() {
        let profile = UserProfile(displayName: "Test")
        #expect(profile.ignoredWorkoutTypesForActivities.isEmpty)
    }

    @Test("UserProfile ignoredWorkoutTypes encodes/decodes")
    func profileIgnoredCodable() throws {
        var profile = UserProfile(displayName: "Test")
        profile.ignoredWorkoutTypesForActivities = ["yoga", "otherWorkout"]
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        #expect(decoded.ignoredWorkoutTypesForActivities == ["yoga", "otherWorkout"])
    }

    // MARK: - DataStore CRUD

    @MainActor
    @Test("DataStore addExerciseEntry persists")
    func dataStoreAdd() {
        let store = DataStore()
        let entry = Self.makeEntry(type: .running)
        store.addExerciseEntry(entry)
        #expect(store.exerciseEntries.count == 1)
        #expect(store.exerciseEntries.first?.workoutType == .running)
    }

    @MainActor
    @Test("DataStore deleteExerciseEntry removes by ID")
    func dataStoreDelete() {
        let store = DataStore()
        let entry = Self.makeEntry(type: .cycling)
        store.addExerciseEntry(entry)
        #expect(store.exerciseEntries.count == 1)
        store.deleteExerciseEntry(entry)
        #expect(store.exerciseEntries.isEmpty)
    }

    @MainActor
    @Test("DataStore deleteExerciseEntries(for:) removes by date")
    func dataStoreDeleteByDate() {
        let store = DataStore()
        let day1 = Self.makeDate(year: 2026, month: 4, day: 10)
        let day2 = Self.makeDate(year: 2026, month: 4, day: 11)
        store.addExerciseEntry(Self.makeEntry(date: day1))
        store.addExerciseEntry(Self.makeEntry(date: day1))
        store.addExerciseEntry(Self.makeEntry(date: day2))
        #expect(store.exerciseEntries.count == 3)
        store.deleteExerciseEntries(for: day1)
        #expect(store.exerciseEntries.count == 1)
        #expect(store.exerciseEntries.first?.date.startOfDay == day2.startOfDay)
    }

    @MainActor
    @Test("DataStore exerciseEntries(for:) filters by date")
    func dataStoreFilterByDate() {
        let store = DataStore()
        let day1 = Self.makeDate(year: 2026, month: 4, day: 10)
        let day2 = Self.makeDate(year: 2026, month: 4, day: 11)
        store.addExerciseEntry(Self.makeEntry(type: .running, date: day1))
        store.addExerciseEntry(Self.makeEntry(type: .cycling, date: day2))
        store.addExerciseEntry(Self.makeEntry(type: .yoga, date: day1))
        let day1Entries = store.exerciseEntries(for: day1)
        #expect(day1Entries.count == 2)
        let day2Entries = store.exerciseEntries(for: day2)
        #expect(day2Entries.count == 1)
        #expect(day2Entries.first?.workoutType == .cycling)
    }

    // MARK: - UserProfile HealthKit Fields

    @Test("UserProfile healthKit fields default correctly")
    func profileDefaults() {
        let profile = UserProfile(displayName: "Test User")
        #expect(profile.healthKitEnabled == false)
        #expect(profile.healthKitSyncReminderDays == 7)
        #expect(profile.lastHealthKitSync == nil)
    }

    @Test("UserProfile healthKit fields encode/decode")
    func profileCodable() throws {
        var profile = UserProfile(displayName: "Test User")
        profile.healthKitEnabled = true
        profile.healthKitSyncReminderDays = 14
        profile.lastHealthKitSync = Date()

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        #expect(decoded.healthKitEnabled == true)
        #expect(decoded.healthKitSyncReminderDays == 14)
        #expect(decoded.lastHealthKitSync != nil)
    }

    @Test("UserProfile backward compat — missing healthKit fields decode to defaults")
    func profileBackwardCompat() throws {
        // Simulate a profile.json from before HealthKit was added
        let json = """
        {"id":"123","displayName":"Old User","signInMethod":"none","distanceUnit":"miles"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        #expect(decoded.healthKitEnabled == false)
        #expect(decoded.healthKitSyncReminderDays == 7)
        #expect(decoded.lastHealthKitSync == nil)
    }
}
