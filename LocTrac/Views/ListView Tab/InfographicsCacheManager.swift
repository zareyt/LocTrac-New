//
//  InfographicsCacheManager.swift
//  LocTrac
//
//  Comprehensive caching system for infographics calculations
//  Persistent storage with selective invalidation
//

import Foundation
import CoreLocation

/// Cache manager for infographics data with persistent storage
actor InfographicsCacheManager {
    
    // MARK: - Cache Storage (Persistent Backing)
    
    /// Main cache storage (backing store for disk persistence)
    private var cache: InfographicsCache
    
    /// File URL for persistent storage
    private let cacheURL: URL
    
    // MARK: - In-Actor Memory Front (Fast Path)
    // These mirror the persistent store but allow faster access and cheap invalidation.
    private var memTravelStatistics: [String: TravelStatisticsCache] = [:]
    private var memEventTypeData: [String: [EventTypeDataCache]] = [:]
    private var memLocationStats: [String: [LocationStatCache]] = [:]
    private var memActivities: [String: [ActivityCache]] = [:]
    private var memPeople: [String: [PersonCache]] = [:]
    private var memStates: [String: Set<String>] = [:]
    private var memLastUpdated: [String: Date] = [:]
    
    // MARK: - Initialization
    
    init() {
        // Set up cache file location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheURL = documentsPath.appendingPathComponent("infographics_cache.json")
        
        // Load existing cache or create new
        if let loadedCache = Self.loadCache(from: cacheURL) {
            self.cache = loadedCache
            // Populate memory front from disk
            memTravelStatistics = loadedCache.travelStatistics
            memEventTypeData = loadedCache.eventTypeData
            memLocationStats = loadedCache.locationStats
            memActivities = loadedCache.activities
            memPeople = loadedCache.people
            memStates = loadedCache.states
            memLastUpdated = loadedCache.lastUpdated
            #if DEBUG
            print("🗄️ Loaded Infographics cache from disk. Years: \(loadedCache.lastUpdated.keys.sorted())")
            #endif
        } else {
            self.cache = InfographicsCache()
            #if DEBUG
            print("🆕 Created new Infographics cache (no existing file).")
            #endif
        }
    }
    
    // MARK: - Cache Access
    
    /// Get cached travel statistics for a specific year
    func getTravelStatistics(for year: String) -> TravelStatisticsCache? {
        if let hit = memTravelStatistics[year] {
            #if DEBUG
            print("✅ [Cache] TravelStatistics HIT for '\(year)'")
            #endif
            return hit
        }
        #if DEBUG
        print("❌ [Cache] TravelStatistics MISS for '\(year)'")
        #endif
        // Read-through from persistent backing (if present)
        if let fromDisk = cache.travelStatistics[year] {
            memTravelStatistics[year] = fromDisk
            return fromDisk
        }
        return nil
    }
    
    /// Get cached event type data for a specific year
    func getEventTypeData(for year: String) -> [EventTypeDataCache]? {
        if let hit = memEventTypeData[year] {
            #if DEBUG
            print("✅ [Cache] EventTypeData HIT for '\(year)'")
            #endif
            return hit
        }
        #if DEBUG
        print("❌ [Cache] EventTypeData MISS for '\(year)'")
        #endif
        if let fromDisk = cache.eventTypeData[year] {
            memEventTypeData[year] = fromDisk
            return fromDisk
        }
        return nil
    }
    
    /// Get cached location statistics for a specific year
    func getLocationStats(for year: String) -> [LocationStatCache]? {
        if let hit = memLocationStats[year] {
            #if DEBUG
            print("✅ [Cache] LocationStats HIT for '\(year)'")
            #endif
            return hit
        }
        #if DEBUG
        print("❌ [Cache] LocationStats MISS for '\(year)'")
        #endif
        if let fromDisk = cache.locationStats[year] {
            memLocationStats[year] = fromDisk
            return fromDisk
        }
        return nil
    }
    
    /// Get cached activities for a specific year
    func getActivities(for year: String) -> [ActivityCache]? {
        if let hit = memActivities[year] {
            #if DEBUG
            print("✅ [Cache] Activities HIT for '\(year)'")
            #endif
            return hit
        }
        #if DEBUG
        print("❌ [Cache] Activities MISS for '\(year)'")
        #endif
        if let fromDisk = cache.activities[year] {
            memActivities[year] = fromDisk
            return fromDisk
        }
        return nil
    }
    
    /// Get cached people for a specific year
    func getPeople(for year: String) -> [PersonCache]? {
        if let hit = memPeople[year] {
            #if DEBUG
            print("✅ [Cache] People HIT for '\(year)'")
            #endif
            return hit
        }
        #if DEBUG
        print("❌ [Cache] People MISS for '\(year)'")
        #endif
        if let fromDisk = cache.people[year] {
            memPeople[year] = fromDisk
            return fromDisk
        }
        return nil
    }
    
    /// Get cached states for a specific year
    func getStates(for year: String) -> Set<String>? {
        if let hit = memStates[year] {
            #if DEBUG
            print("✅ [Cache] States HIT for '\(year)'")
            #endif
            return hit
        }
        #if DEBUG
        print("❌ [Cache] States MISS for '\(year)'")
        #endif
        if let fromDisk = cache.states[year] {
            memStates[year] = fromDisk
            return fromDisk
        }
        return nil
    }
    
    // MARK: - Cache Updates (Write-Through)
    
    /// Update travel statistics cache
    func updateTravelStatistics(_ stats: TravelStatisticsCache, for year: String) async {
        memTravelStatistics[year] = stats
        cache.travelStatistics[year] = stats
        memLastUpdated[year] = Date()
        cache.lastUpdated[year] = memLastUpdated[year]
        #if DEBUG
        print("📝 [Cache] Updated TravelStatistics for '\(year)'")
        #endif
        await save()
    }
    
    /// Update event type data cache
    func updateEventTypeData(_ data: [EventTypeDataCache], for year: String) async {
        memEventTypeData[year] = data
        cache.eventTypeData[year] = data
        memLastUpdated[year] = Date()
        cache.lastUpdated[year] = memLastUpdated[year]
        #if DEBUG
        print("📝 [Cache] Updated EventTypeData for '\(year)' (\(data.count) items)")
        #endif
        await save()
    }
    
    /// Update location statistics cache
    func updateLocationStats(_ stats: [LocationStatCache], for year: String) async {
        memLocationStats[year] = stats
        cache.locationStats[year] = stats
        memLastUpdated[year] = Date()
        cache.lastUpdated[year] = memLastUpdated[year]
        #if DEBUG
        print("📝 [Cache] Updated LocationStats for '\(year)' (\(stats.count) items)")
        #endif
        await save()
    }
    
    /// Update activities cache
    func updateActivities(_ activities: [ActivityCache], for year: String) async {
        memActivities[year] = activities
        cache.activities[year] = activities
        memLastUpdated[year] = Date()
        cache.lastUpdated[year] = memLastUpdated[year]
        #if DEBUG
        print("📝 [Cache] Updated Activities for '\(year)' (\(activities.count) items)")
        #endif
        await save()
    }
    
    /// Update people cache
    func updatePeople(_ people: [PersonCache], for year: String) async {
        memPeople[year] = people
        cache.people[year] = people
        memLastUpdated[year] = Date()
        cache.lastUpdated[year] = memLastUpdated[year]
        #if DEBUG
        print("📝 [Cache] Updated People for '\(year)' (\(people.count) items)")
        #endif
        await save()
    }
    
    /// Update states cache
    func updateStates(_ states: Set<String>, for year: String) async {
        memStates[year] = states
        cache.states[year] = states
        memLastUpdated[year] = Date()
        cache.lastUpdated[year] = memLastUpdated[year]
        #if DEBUG
        print("📝 [Cache] Updated States for '\(year)' (\(states.count) states)")
        #endif
        await save()
    }
    
    // MARK: - Cache Invalidation
    
    /// Invalidate specific sections for specific years based on data changes
    func invalidate(affectedYears: [String], sections: [InfographicsSection]) async {
        #if DEBUG
        print("🧹 [Cache] Invalidate requested. Years: \(affectedYears), Sections: \(sections)")
        #endif
        for year in affectedYears {
            for section in sections {
                invalidateSection(section, for: year)
            }
        }
        await save()
    }
    
    /// Invalidate all cache for a specific year
    func invalidateYear(_ year: String) async {
        #if DEBUG
        print("🧹 [Cache] Invalidate YEAR '\(year)' (all sections)")
        #endif
        memTravelStatistics.removeValue(forKey: year)
        memEventTypeData.removeValue(forKey: year)
        memLocationStats.removeValue(forKey: year)
        memActivities.removeValue(forKey: year)
        memPeople.removeValue(forKey: year)
        memStates.removeValue(forKey: year)
        memLastUpdated.removeValue(forKey: year)
        
        cache.travelStatistics.removeValue(forKey: year)
        cache.eventTypeData.removeValue(forKey: year)
        cache.locationStats.removeValue(forKey: year)
        cache.activities.removeValue(forKey: year)
        cache.people.removeValue(forKey: year)
        cache.states.removeValue(forKey: year)
        cache.lastUpdated.removeValue(forKey: year)
        await save()
    }
    
    /// Clear all cached data
    func clearAll() async {
        #if DEBUG
        print("🗑️ [Cache] Clear ALL")
        #endif
        memTravelStatistics.removeAll()
        memEventTypeData.removeAll()
        memLocationStats.removeAll()
        memActivities.removeAll()
        memPeople.removeAll()
        memStates.removeAll()
        memLastUpdated.removeAll()
        
        cache = InfographicsCache()
        await save()
    }
    
    // MARK: - Private Helpers
    
    private func invalidateSection(_ section: InfographicsSection, for year: String) {
        #if DEBUG
        print("🧹 [Cache] Invalidate section '\(section)' for year '\(year)'")
        #endif
        switch section {
        case .travelStatistics:
            memTravelStatistics.removeValue(forKey: year)
            cache.travelStatistics.removeValue(forKey: year)
        case .eventTypes:
            memEventTypeData.removeValue(forKey: year)
            cache.eventTypeData.removeValue(forKey: year)
        case .locations:
            memLocationStats.removeValue(forKey: year)
            cache.locationStats.removeValue(forKey: year)
        case .activities:
            memActivities.removeValue(forKey: year)
            cache.activities.removeValue(forKey: year)
        case .people:
            memPeople.removeValue(forKey: year)
            cache.people.removeValue(forKey: year)
        case .states:
            memStates.removeValue(forKey: year)
            cache.states.removeValue(forKey: year)
        }
        memLastUpdated.removeValue(forKey: year)
        cache.lastUpdated.removeValue(forKey: year)
    }
    
    // MARK: - Persistence
    
    private func save() async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            try data.write(to: cacheURL)
            #if DEBUG
            print("💾 [Cache] Saved to disk at \(cacheURL.lastPathComponent) (\(Date()))")
            #endif
        } catch {
            print("⚠️ Failed to save infographics cache: \(error)")
        }
    }
    
    private static func loadCache(from url: URL) -> InfographicsCache? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(InfographicsCache.self, from: data)
        } catch {
            print("⚠️ Failed to load infographics cache: \(error)")
            return nil
        }
    }
}

// MARK: - Cache Models

/// Main cache structure
struct InfographicsCache: Codable {
    var travelStatistics: [String: TravelStatisticsCache] = [:]
    var eventTypeData: [String: [EventTypeDataCache]] = [:]
    var locationStats: [String: [LocationStatCache]] = [:]
    var activities: [String: [ActivityCache]] = [:]
    var people: [String: [PersonCache]] = [:]
    var states: [String: Set<String>] = [:]
    var lastUpdated: [String: Date] = [:]
}

/// Travel statistics cache
struct TravelStatisticsCache: Codable {
    let totalMiles: Double
    let totalCO2: Double
    let flyingMiles: Double
    let flyingCO2: Double
    let flyingTrips: Int
    let drivingMiles: Double
    let drivingCO2: Double
    let drivingTrips: Int
    let trainMiles: Double
    let trainCO2: Double
    let trainTrips: Int
    let busMiles: Double
    let busCO2: Double
    let busTrips: Int
    let treesNeeded: Double
    let kWhEquivalent: Double
    let earthCircumferences: Double
    let drivingCO2WithCar: Double  // Car-specific CO2 for driving (if cars exist)

    // Backward-compatible initializer for legacy cache entries
    init(
        totalMiles: Double, totalCO2: Double,
        flyingMiles: Double, flyingCO2: Double, flyingTrips: Int,
        drivingMiles: Double, drivingCO2: Double, drivingTrips: Int,
        trainMiles: Double = 0, trainCO2: Double = 0, trainTrips: Int = 0,
        busMiles: Double = 0, busCO2: Double = 0, busTrips: Int = 0,
        treesNeeded: Double, kWhEquivalent: Double, earthCircumferences: Double,
        drivingCO2WithCar: Double = 0
    ) {
        self.totalMiles = totalMiles
        self.totalCO2 = totalCO2
        self.flyingMiles = flyingMiles
        self.flyingCO2 = flyingCO2
        self.flyingTrips = flyingTrips
        self.drivingMiles = drivingMiles
        self.drivingCO2 = drivingCO2
        self.drivingTrips = drivingTrips
        self.trainMiles = trainMiles
        self.trainCO2 = trainCO2
        self.trainTrips = trainTrips
        self.busMiles = busMiles
        self.busCO2 = busCO2
        self.busTrips = busTrips
        self.treesNeeded = treesNeeded
        self.kWhEquivalent = kWhEquivalent
        self.earthCircumferences = earthCircumferences
        self.drivingCO2WithCar = drivingCO2WithCar
    }

    // Tolerant decoder for cached data missing new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalMiles = try container.decode(Double.self, forKey: .totalMiles)
        totalCO2 = try container.decode(Double.self, forKey: .totalCO2)
        flyingMiles = try container.decode(Double.self, forKey: .flyingMiles)
        flyingCO2 = try container.decode(Double.self, forKey: .flyingCO2)
        flyingTrips = try container.decode(Int.self, forKey: .flyingTrips)
        drivingMiles = try container.decode(Double.self, forKey: .drivingMiles)
        drivingCO2 = try container.decode(Double.self, forKey: .drivingCO2)
        drivingTrips = try container.decode(Int.self, forKey: .drivingTrips)
        trainMiles = (try? container.decode(Double.self, forKey: .trainMiles)) ?? 0
        trainCO2 = (try? container.decode(Double.self, forKey: .trainCO2)) ?? 0
        trainTrips = (try? container.decode(Int.self, forKey: .trainTrips)) ?? 0
        busMiles = (try? container.decode(Double.self, forKey: .busMiles)) ?? 0
        busCO2 = (try? container.decode(Double.self, forKey: .busCO2)) ?? 0
        busTrips = (try? container.decode(Int.self, forKey: .busTrips)) ?? 0
        treesNeeded = try container.decode(Double.self, forKey: .treesNeeded)
        kWhEquivalent = try container.decode(Double.self, forKey: .kWhEquivalent)
        earthCircumferences = try container.decode(Double.self, forKey: .earthCircumferences)
        drivingCO2WithCar = (try? container.decode(Double.self, forKey: .drivingCO2WithCar)) ?? 0
    }
}

/// Event type data cache
struct EventTypeDataCache: Codable, Identifiable {
    let id: String
    let type: String
    let icon: String
    let count: Int
    let percentage: Int
}

/// Location statistics cache
struct LocationStatCache: Codable, Identifiable {
    let id: String
    let name: String
    let count: Int
    let colorHex: String
}

/// Activity cache
struct ActivityCache: Codable, Identifiable {
    let id: String
    let name: String
    let count: Int
}

/// Person cache
struct PersonCache: Codable, Identifiable {
    let id: String
    let name: String
    let count: Int
}

/// Sections that can be cached
enum InfographicsSection {
    case travelStatistics
    case eventTypes
    case locations
    case activities
    case people
    case states
}

// MARK: - Change Tracking

/// Tracks what data has changed and needs recalculation
struct InfographicsChangeTracker {
    var affectedYears: Set<String> = []
    var affectedSections: Set<InfographicsSection> = []
    
    /// Track an event change
    mutating func trackEventChange(_ event: Event, isDelete: Bool = false) {
        let year = Calendar.current.component(.year, from: event.date)
        affectedYears.insert(String(year))
        affectedYears.insert("All Time")
        
        // Events affect multiple sections
        affectedSections.insert(.travelStatistics)
        affectedSections.insert(.eventTypes)
        affectedSections.insert(.locations)
        
        if !event.activityIDs.isEmpty {
            affectedSections.insert(.activities)
        }
        
        if !event.people.isEmpty {
            affectedSections.insert(.people)
        }
        
        if let country = event.country, country.uppercased().contains("UNITED STATES") {
            affectedSections.insert(.states)
        }
    }
    
    /// Track an activity change
    mutating func trackActivityChange(affectedEventYears: [Int]) {
        affectedSections.insert(.activities)
        for year in affectedEventYears {
            affectedYears.insert(String(year))
        }
        affectedYears.insert("All Time")
    }
    
    /// Track a location change
    mutating func trackLocationChange(affectedEventYears: [Int]) {
        affectedSections.insert(.locations)
        affectedSections.insert(.travelStatistics)
        affectedSections.insert(.states)
        
        for year in affectedEventYears {
            affectedYears.insert(String(year))
        }
        affectedYears.insert("All Time")
    }
    
    /// Track a person change
    mutating func trackPersonChange(affectedEventYears: [Int]) {
        affectedSections.insert(.people)
        for year in affectedEventYears {
            affectedYears.insert(String(year))
        }
        affectedYears.insert("All Time")
    }
    
    /// Get years and sections to invalidate
    func getInvalidations() -> (years: [String], sections: [InfographicsSection]) {
        return (Array(affectedYears), Array(affectedSections))
    }
}

