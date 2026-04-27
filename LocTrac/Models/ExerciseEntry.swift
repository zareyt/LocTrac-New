//
//  ExerciseEntry.swift
//  LocTrac
//
//  v2.1: Exercise data from Apple HealthKit
//  Persisted in backup.json alongside events, locations, etc.
//

import Foundation
import SwiftUI

struct ExerciseEntry: Identifiable, Codable, Hashable {
    let id: String
    var date: Date                      // UTC midnight (matches event dates)
    var workoutType: WorkoutType
    var durationMinutes: Double
    var distanceMiles: Double?          // nil for non-distance workouts (yoga, strength)
    var caloriesBurned: Double?         // Active energy burned
    var sourceWorkoutID: String?        // HKWorkout UUID for dedup

    init(
        id: String = UUID().uuidString,
        date: Date,
        workoutType: WorkoutType,
        durationMinutes: Double,
        distanceMiles: Double? = nil,
        caloriesBurned: Double? = nil,
        sourceWorkoutID: String? = nil
    ) {
        self.id = id
        self.date = date
        self.workoutType = workoutType
        self.durationMinutes = durationMinutes
        self.distanceMiles = distanceMiles
        self.caloriesBurned = caloriesBurned
        self.sourceWorkoutID = sourceWorkoutID
    }

    // MARK: - Workout Type

    enum WorkoutType: String, Codable, CaseIterable, Hashable, Identifiable {
        var id: String { rawValue }
        case walking
        case running
        case cycling
        case hiking
        case swimming
        case yoga
        case strengthTraining
        case otherWorkout

        var displayName: String {
            switch self {
            case .walking: return "Walking"
            case .running: return "Running"
            case .cycling: return "Cycling"
            case .hiking: return "Hiking"
            case .swimming: return "Swimming"
            case .yoga: return "Yoga"
            case .strengthTraining: return "Strength Training"
            case .otherWorkout: return "Other Workout"
            }
        }

        var sfSymbol: String {
            switch self {
            case .walking: return "figure.walk"
            case .running: return "figure.run"
            case .cycling: return "bicycle"
            case .hiking: return "figure.hiking"
            case .swimming: return "figure.pool.swim"
            case .yoga: return "figure.yoga"
            case .strengthTraining: return "dumbbell.fill"
            case .otherWorkout: return "figure.mixed.cardio"
            }
        }

        var color: Color {
            switch self {
            case .walking: return .green
            case .running: return .orange
            case .cycling: return .blue
            case .hiking: return .brown
            case .swimming: return .cyan
            case .yoga: return .purple
            case .strengthTraining: return .red
            case .otherWorkout: return .gray
            }
        }
    }
}

// MARK: - Exercise Summary (for Infographics)

struct ExerciseSummary {
    let totalMinutes: Double
    let totalCalories: Double
    let totalDistanceMiles: Double
    let activeDays: Int
    let avgMinutesPerDay: Double
    let workoutTypeBreakdown: [(type: ExerciseEntry.WorkoutType, count: Int, totalMinutes: Double, totalMiles: Double)]
    let walkingMiles: Double
    let runningMiles: Double
    let cyclingMiles: Double
    let swimmingMiles: Double
    let hikingMiles: Double
    let cyclingRideCount: Int
    let co2SavedLbs: Double             // cyclingMiles * 0.363

    /// EPA average: passenger vehicles emit ~0.363 lbs CO2 per mile
    static let co2PerMile: Double = 0.363

    /// Compute summary from a list of exercise entries
    static func compute(from entries: [ExerciseEntry]) -> ExerciseSummary? {
        guard !entries.isEmpty else { return nil }

        let totalMinutes = entries.reduce(0.0) { $0 + $1.durationMinutes }
        let totalCalories = entries.reduce(0.0) { $0 + ($1.caloriesBurned ?? 0) }
        let totalDistance = entries.reduce(0.0) { $0 + ($1.distanceMiles ?? 0) }
        let activeDays = Set(entries.map { $0.date.startOfDay }).count
        let avgPerDay = activeDays > 0 ? totalMinutes / Double(activeDays) : 0

        // Group by workout type
        let grouped = Dictionary(grouping: entries) { $0.workoutType }
        let breakdown = grouped.map { (type, items) in
            (type: type,
             count: items.count,
             totalMinutes: items.reduce(0.0) { $0 + $1.durationMinutes },
             totalMiles: items.reduce(0.0) { $0 + ($1.distanceMiles ?? 0) })
        }.sorted { $0.count > $1.count }

        // Per-type miles
        func miles(for type: ExerciseEntry.WorkoutType) -> Double {
            entries.filter { $0.workoutType == type }.reduce(0.0) { $0 + ($1.distanceMiles ?? 0) }
        }
        let cyclingMiles = miles(for: .cycling)
        let co2Saved = cyclingMiles * co2PerMile

        return ExerciseSummary(
            totalMinutes: totalMinutes,
            totalCalories: totalCalories,
            totalDistanceMiles: totalDistance,
            activeDays: activeDays,
            avgMinutesPerDay: avgPerDay,
            workoutTypeBreakdown: breakdown,
            walkingMiles: miles(for: .walking),
            runningMiles: miles(for: .running),
            cyclingMiles: cyclingMiles,
            swimmingMiles: miles(for: .swimming),
            hikingMiles: miles(for: .hiking),
            cyclingRideCount: entries.filter { $0.workoutType == .cycling }.count,
            co2SavedLbs: co2Saved
        )
    }
}
