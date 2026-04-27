//
//  WidgetData.swift
//  LocTrac
//
//  Shared data model between main app and widget extension.
//  Main app writes this after each save; widgets read it via App Group.
//
//  v2.1: Travel, Exercise, Environment, and Affirmation stats
//

import Foundation

/// Lightweight snapshot of app data for widget display.
/// Written by the main app to the App Group container after each save.
struct WidgetData: Codable {
    let lastUpdated: Date

    // MARK: - Travel Stats

    let totalCountries: Int
    let totalCities: Int
    let totalStays: Int
    let daysAwayFromHomeThisYear: Int
    let topCountries: [CountryStat]
    let recentLocationName: String?
    let currentYearTripCount: Int
    let totalMilesTraveled: Double

    // MARK: - Exercise Stats

    let activeMinutesThisWeek: Double
    let activeDaysThisWeek: Int
    let totalCaloriesThisWeek: Double
    let workoutCountThisWeek: Int
    let topWorkoutTypeThisWeek: String?

    // MARK: - Environment Stats

    let cyclingCO2SavedLbsAllTime: Double
    let drivingCO2ThisMonthLbs: Double
    let totalMilesCycledAllTime: Double

    // MARK: - Affirmation

    let todaysAffirmationText: String?
    let todaysAffirmationCategory: String?
    let todaysAffirmationColor: String?

    // MARK: - Nested Types

    struct CountryStat: Codable {
        let name: String
        let stayCount: Int
    }
}

// MARK: - App Group Constants

enum AppGroupConstants {
    static let groupID = "group.TimOrg.LocTrac"
    static let widgetDataFilename = "widget_data.json"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    static var widgetDataURL: URL? {
        containerURL?.appendingPathComponent(widgetDataFilename)
    }
}

// MARK: - WidgetData Read/Write

extension WidgetData {

    /// Write widget data to the App Group shared container.
    func save() {
        guard let url = AppGroupConstants.widgetDataURL else {
            #if DEBUG
            print("[Widget] No App Group container URL — is the App Group capability configured?")
            #endif
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("[Widget] Failed to write widget data: \(error.localizedDescription)")
            #endif
        }
    }

    /// Read widget data from the App Group shared container.
    static func load() -> WidgetData? {
        guard let url = AppGroupConstants.widgetDataURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WidgetData.self, from: data)
        } catch {
            #if DEBUG
            print("[Widget] Failed to read widget data: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Placeholder data for widget previews and when no data is available.
    static let placeholder = WidgetData(
        lastUpdated: Date(),
        totalCountries: 3,
        totalCities: 8,
        totalStays: 142,
        daysAwayFromHomeThisYear: 21,
        topCountries: [
            CountryStat(name: "United States", stayCount: 120),
            CountryStat(name: "Mexico", stayCount: 14),
            CountryStat(name: "Canada", stayCount: 8)
        ],
        recentLocationName: "Home",
        currentYearTripCount: 5,
        totalMilesTraveled: 12_450,
        activeMinutesThisWeek: 185,
        activeDaysThisWeek: 4,
        totalCaloriesThisWeek: 1240,
        workoutCountThisWeek: 6,
        topWorkoutTypeThisWeek: "Walking",
        cyclingCO2SavedLbsAllTime: 42.5,
        drivingCO2ThisMonthLbs: 156.3,
        totalMilesCycledAllTime: 117,
        todaysAffirmationText: "I am grateful for the journey ahead.",
        todaysAffirmationCategory: "Gratitude",
        todaysAffirmationColor: "green"
    )
}
