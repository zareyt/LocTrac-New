//
//  HealthKitService.swift
//  LocTrac
//
//  v2.1: Read-only HealthKit integration for exercise data
//  Queries workouts and converts to ExerciseEntry for local storage
//

import Foundation
import HealthKit

/// Read-only HealthKit integration service.
/// Queries workout data and converts to ExerciseEntry models.
/// Never writes to HealthKit — only NSHealthShareUsageDescription needed.
actor HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    /// HealthKit data types we request read access for
    private var readTypes: Set<HKObjectType> {
        [
            HKWorkoutType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.appleExerciseTime)
        ]
    }

    // MARK: - Device Support

    /// Check if HealthKit is available on this device
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    /// Request read-only authorization for workout data.
    /// Call this when user enables HealthKit in Preferences.
    func requestAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }
        // Read-only: toShare is empty set
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        #if DEBUG
        await DebugConfig.shared.log(.healthKit, "Authorization requested successfully")
        #endif
    }

    // MARK: - Querying Workouts

    /// Fetch workouts between two dates and convert to ExerciseEntry.
    /// - Parameters:
    ///   - startDate: Start of date range (inclusive)
    ///   - endDate: End of date range (exclusive)
    /// - Returns: Array of ExerciseEntry models
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [ExerciseEntry] {
        guard isAvailable else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        let workouts = try await descriptor.result(for: healthStore)
        #if DEBUG
        await DebugConfig.shared.log(.healthKit, "Fetched \(workouts.count) workouts from \(startDate) to \(endDate)")
        #endif
        return workouts.map { mapWorkoutToEntry($0) }
    }

    // MARK: - Sync

    /// Result of a sync operation
    struct SyncResult {
        let addedCount: Int
        let duplicateSkippedCount: Int
        let skippedNoStayCount: Int
        let activitiesLinkedCount: Int
        let unmatchedWorkoutTypes: [ExerciseEntry.WorkoutType]  // Types with no matching activity
    }

    /// Incremental sync — fetch workouts since last sync date, add to store,
    /// and auto-link matching activities to events.
    /// - Parameters:
    ///   - lastSync: Date of last sync (or earliest event date for first sync)
    ///   - store: DataStore to add entries to (must be accessed on MainActor)
    ///   - ignoredTypes: Workout type rawValues the user chose to ignore for activity linking
    ///   - workoutMappings: Persisted workout type rawValue -> activity name mappings
    /// - Returns: SyncResult with detailed counts
    @MainActor
    func syncNewWorkouts(since lastSync: Date, store: DataStore, ignoredTypes: [String] = [], workoutMappings: [String: String] = [:]) async throws -> SyncResult {
        let newWorkouts = try await fetchWorkouts(from: lastSync, to: Date())

        // Get existing source IDs for dedup
        let existingIDs = Set(store.exerciseEntries.compactMap { $0.sourceWorkoutID })

        // Get dates that have stays
        let stayDates = Set(store.events.map { $0.date.startOfDay })

        // Build activity lookup: lowercased name -> Activity
        let activityLookup = Dictionary(
            store.activities.map { ($0.name.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let ignoredSet = Set(ignoredTypes)

        #if DEBUG
        // Log workout type breakdown for debugging
        let typeCounts = Dictionary(grouping: newWorkouts, by: { $0.workoutType }).mapValues { $0.count }
        DebugConfig.shared.log(.healthKit, "Fetched workout types: \(typeCounts.map { "\($0.key.displayName): \($0.value)" }.joined(separator: ", "))")
        DebugConfig.shared.log(.healthKit, "Activity lookup keys: \(activityLookup.keys.sorted().joined(separator: ", "))")
        DebugConfig.shared.log(.healthKit, "Ignored types: \(ignoredSet.sorted().joined(separator: ", "))")
        #endif

        var addedCount = 0
        var duplicateCount = 0
        var skippedCount = 0
        var activitiesLinkedCount = 0
        var unmatchedTypes = Set<ExerciseEntry.WorkoutType>()

        // Track which events we've already modified this sync to avoid repeated saves
        var modifiedEventIDs = Set<String>()

        for entry in newWorkouts {
            // Skip duplicates
            if let sourceID = entry.sourceWorkoutID, existingIDs.contains(sourceID) {
                duplicateCount += 1
                continue
            }

            // Only add if a stay exists for this date
            guard stayDates.contains(entry.date) else {
                skippedCount += 1
                continue
            }

            store.addExerciseEntry(entry)
            addedCount += 1

            // Activity auto-linking
            let typeName = entry.workoutType.displayName
            if ignoredSet.contains(entry.workoutType.rawValue) {
                continue  // User chose to ignore this type
            }

            // Check persisted mapping first (e.g., "otherWorkout" -> "Golfing")
            let lookupName: String
            if let mappedName = workoutMappings[entry.workoutType.rawValue] {
                lookupName = mappedName.lowercased()
            } else {
                lookupName = typeName.lowercased()
            }

            if let matchedActivity = activityLookup[lookupName] {
                #if DEBUG
                DebugConfig.shared.log(.healthKit, "Matched '\(typeName)' -> activity '\(matchedActivity.name)' (lookup: '\(lookupName)')")
                #endif
                // Find the event for this date and add the activity if not already linked
                if let eventIndex = store.events.firstIndex(where: { $0.date.startOfDay == entry.date }) {
                    if !store.events[eventIndex].activityIDs.contains(matchedActivity.id) {
                        store.events[eventIndex].activityIDs.append(matchedActivity.id)
                        modifiedEventIDs.insert(store.events[eventIndex].id)
                        activitiesLinkedCount += 1
                    }
                }
            } else {
                #if DEBUG
                DebugConfig.shared.log(.healthKit, "UNMATCHED type: '\(typeName)' (lookup key: '\(lookupName)')")
                #endif
                unmatchedTypes.insert(entry.workoutType)
            }
        }

        // Save once for all event modifications
        if !modifiedEventIDs.isEmpty {
            store.storeData()
        }

        #if DEBUG
        DebugConfig.shared.log(.healthKit, "Sync complete: \(addedCount) added, \(duplicateCount) dupes, \(skippedCount) no-stay, \(activitiesLinkedCount) activities linked, \(unmatchedTypes.count) unmatched types")
        #endif

        return SyncResult(
            addedCount: addedCount,
            duplicateSkippedCount: duplicateCount,
            skippedNoStayCount: skippedCount,
            activitiesLinkedCount: activitiesLinkedCount,
            unmatchedWorkoutTypes: Array(unmatchedTypes).sorted { $0.displayName < $1.displayName }
        )
    }

    // MARK: - Mapping

    /// Convert an HKWorkout to an ExerciseEntry
    private func mapWorkoutToEntry(_ workout: HKWorkout) -> ExerciseEntry {
        let workoutType = mapActivityType(workout.workoutActivityType)
        let distance = extractDistance(from: workout)
        let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())

        return ExerciseEntry(
            id: UUID().uuidString,
            date: workout.startDate.startOfDay,
            workoutType: workoutType,
            durationMinutes: workout.duration / 60.0,
            distanceMiles: distance,
            caloriesBurned: calories,
            sourceWorkoutID: workout.uuid.uuidString
        )
    }

    /// Map HKWorkoutActivityType to our WorkoutType enum
    private func mapActivityType(_ type: HKWorkoutActivityType) -> ExerciseEntry.WorkoutType {
        switch type {
        case .walking: return .walking
        case .running: return .running
        case .cycling: return .cycling
        case .hiking: return .hiking
        case .swimming: return .swimming
        case .yoga: return .yoga
        case .functionalStrengthTraining, .traditionalStrengthTraining: return .strengthTraining
        default: return .otherWorkout
        }
    }

    /// Extract distance in miles from a workout.
    /// Returns nil for workouts without distance data.
    private func extractDistance(from workout: HKWorkout) -> Double? {
        guard let totalDistance = workout.totalDistance else { return nil }
        let meters = totalDistance.doubleValue(for: .meter())
        guard meters > 0 else { return nil }
        return meters / 1609.344  // Convert meters to miles
    }

    // MARK: - Errors

    enum HealthKitError: LocalizedError {
        case notAvailable

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "HealthKit is not available on this device."
            }
        }
    }
}
