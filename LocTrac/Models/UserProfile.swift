//
//  UserProfile.swift
//  LocTrac
//
//  User profile model with Codable persistence to profile.json.
//  Completely separate from backup.json — auth data never leaks into exports.
//

import Foundation

struct UserProfile: Codable, Identifiable {
    var id: String
    var displayName: String
    var email: String?
    var photoData: Data?
    var signInMethod: SignInMethod
    var createdDate: Date
    var lastLoginDate: Date

    // Preferences
    var defaultLocationID: String?
    var distanceUnit: DistanceUnit
    var defaultTransportMode: String?
    var defaultEventType: String?

    // HealthKit (v2.1)
    var healthKitEnabled: Bool
    var healthKitSyncReminderDays: Int
    var lastHealthKitSync: Date?
    var ignoredWorkoutTypesForActivities: [String]  // WorkoutType rawValues the user chose to ignore
    var workoutTypeActivityMappings: [String: String]  // WorkoutType rawValue -> Activity name (e.g. "otherWorkout": "Golfing")

    // Environmental Factors (v2.1)
    var excludePublicTransitFromEnvironment: Bool

    init(
        id: String = UUID().uuidString,
        displayName: String,
        email: String? = nil,
        photoData: Data? = nil,
        signInMethod: SignInMethod = .none,
        createdDate: Date = Date(),
        lastLoginDate: Date = Date(),
        defaultLocationID: String? = nil,
        distanceUnit: DistanceUnit = .miles,
        defaultTransportMode: String? = nil,
        defaultEventType: String? = nil,
        healthKitEnabled: Bool = false,
        healthKitSyncReminderDays: Int = 7,
        lastHealthKitSync: Date? = nil,
        ignoredWorkoutTypesForActivities: [String] = [],
        workoutTypeActivityMappings: [String: String] = [:],
        excludePublicTransitFromEnvironment: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoData = photoData
        self.signInMethod = signInMethod
        self.createdDate = createdDate
        self.lastLoginDate = lastLoginDate
        self.defaultLocationID = defaultLocationID
        self.distanceUnit = distanceUnit
        self.defaultTransportMode = defaultTransportMode
        self.defaultEventType = defaultEventType
        self.healthKitEnabled = healthKitEnabled
        self.healthKitSyncReminderDays = healthKitSyncReminderDays
        self.lastHealthKitSync = lastHealthKitSync
        self.ignoredWorkoutTypesForActivities = ignoredWorkoutTypesForActivities
        self.workoutTypeActivityMappings = workoutTypeActivityMappings
        self.excludePublicTransitFromEnvironment = excludePublicTransitFromEnvironment
    }

    // MARK: - Codable (backward compat for HealthKit fields)

    enum CodingKeys: String, CodingKey {
        case id, displayName, email, photoData, signInMethod, createdDate, lastLoginDate
        case defaultLocationID, distanceUnit, defaultTransportMode, defaultEventType
        case healthKitEnabled, healthKitSyncReminderDays, lastHealthKitSync
        case ignoredWorkoutTypesForActivities
        case workoutTypeActivityMappings
        case excludePublicTransitFromEnvironment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        signInMethod = try container.decode(SignInMethod.self, forKey: .signInMethod)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        lastLoginDate = try container.decode(Date.self, forKey: .lastLoginDate)
        defaultLocationID = try container.decodeIfPresent(String.self, forKey: .defaultLocationID)
        distanceUnit = try container.decode(DistanceUnit.self, forKey: .distanceUnit)
        defaultTransportMode = try container.decodeIfPresent(String.self, forKey: .defaultTransportMode)
        defaultEventType = try container.decodeIfPresent(String.self, forKey: .defaultEventType)
        // v2.1: HealthKit fields — optional for backward compat with existing profile.json
        healthKitEnabled = (try? container.decode(Bool.self, forKey: .healthKitEnabled)) ?? false
        healthKitSyncReminderDays = (try? container.decode(Int.self, forKey: .healthKitSyncReminderDays)) ?? 7
        lastHealthKitSync = try container.decodeIfPresent(Date.self, forKey: .lastHealthKitSync)
        ignoredWorkoutTypesForActivities = (try? container.decode([String].self, forKey: .ignoredWorkoutTypesForActivities)) ?? []
        workoutTypeActivityMappings = (try? container.decode([String: String].self, forKey: .workoutTypeActivityMappings)) ?? [:]
        excludePublicTransitFromEnvironment = (try? container.decode(Bool.self, forKey: .excludePublicTransitFromEnvironment)) ?? false
    }

    // MARK: - Computed Properties

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var hasProfilePhoto: Bool {
        photoData != nil
    }

    // MARK: - Enums

    enum SignInMethod: String, Codable {
        case apple
        case email
        case none
    }

    enum DistanceUnit: String, Codable {
        case miles
        case kilometers

        var abbreviation: String {
            switch self {
            case .miles: return "mi"
            case .kilometers: return "km"
            }
        }

        var displayName: String {
            switch self {
            case .miles: return "Miles"
            case .kilometers: return "Kilometers"
            }
        }
    }

    // MARK: - Persistence

    private static let fileName = "profile.json"

    private static var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }

    /// Saves the profile to profile.json in the Documents directory.
    func save() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: Self.fileURL, options: .atomic)
        #if DEBUG
        print("🔐 [Profile] Saved profile for \(displayName) to profile.json")
        #endif
    }

    /// Loads a profile from profile.json. Returns nil if no profile exists.
    static func load() -> UserProfile? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            #if DEBUG
            print("🔐 [Profile] No profile.json found")
            #endif
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let profile = try decoder.decode(UserProfile.self, from: data)
            #if DEBUG
            print("🔐 [Profile] Loaded profile for \(profile.displayName)")
            #endif
            return profile
        } catch {
            #if DEBUG
            print("🔐 [Profile] Failed to load profile: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Deletes the profile.json file. Travel data (backup.json) is unaffected.
    static func deleteProfile() {
        try? FileManager.default.removeItem(at: fileURL)
        #if DEBUG
        print("🔐 [Profile] Deleted profile.json")
        #endif
    }

    /// Returns true if a profile.json file exists on disk.
    static var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
}
