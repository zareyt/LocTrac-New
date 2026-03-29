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
    
    // MARK: - Cache Storage
    
    /// Main cache storage
    private var cache: InfographicsCache
    
    /// File URL for persistent storage
    private let cacheURL: URL
    
    // MARK: - Initialization
    
    init() {
        // Set up cache file location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheURL = documentsPath.appendingPathComponent("infographics_cache.json")
        
        // Load existing cache or create new
        if let loadedCache = Self.loadCache(from: cacheURL) {
            self.cache = loadedCache
        } else {
            self.cache = InfographicsCache()
        }
    }
    
    // MARK: - Cache Access
    
    /// Get cached travel statistics for a specific year
    func getTravelStatistics(for year: String) -> TravelStatisticsCache? {
        return cache.travelStatistics[year]
    }
    
    /// Get cached event type data for a specific year
    func getEventTypeData(for year: String) -> [EventTypeDataCache]? {
        return cache.eventTypeData[year]
    }
    
    /// Get cached location statistics for a specific year
    func getLocationStats(for year: String) -> [LocationStatCache]? {
        return cache.locationStats[year]
    }
    
    /// Get cached activities for a specific year
    func getActivities(for year: String) -> [ActivityCache]? {
        return cache.activities[year]
    }
    
    /// Get cached people for a specific year
    func getPeople(for year: String) -> [PersonCache]? {
        return cache.people[year]
    }
    
    /// Get cached states for a specific year
    func getStates(for year: String) -> Set<String>? {
        return cache.states[year]
    }
    
    // MARK: - Cache Updates
    
    /// Update travel statistics cache
    func updateTravelStatistics(_ stats: TravelStatisticsCache, for year: String) async {
        cache.travelStatistics[year] = stats
        cache.lastUpdated[year] = Date()
        await save()
    }
    
    /// Update event type data cache
    func updateEventTypeData(_ data: [EventTypeDataCache], for year: String) async {
        cache.eventTypeData[year] = data
        cache.lastUpdated[year] = Date()
        await save()
    }
    
    /// Update location statistics cache
    func updateLocationStats(_ stats: [LocationStatCache], for year: String) async {
        cache.locationStats[year] = stats
        cache.lastUpdated[year] = Date()
        await save()
    }
    
    /// Update activities cache
    func updateActivities(_ activities: [ActivityCache], for year: String) async {
        cache.activities[year] = activities
        cache.lastUpdated[year] = Date()
        await save()
    }
    
    /// Update people cache
    func updatePeople(_ people: [PersonCache], for year: String) async {
        cache.people[year] = people
        cache.lastUpdated[year] = Date()
        await save()
    }
    
    /// Update states cache
    func updateStates(_ states: Set<String>, for year: String) async {
        cache.states[year] = states
        cache.lastUpdated[year] = Date()
        await save()
    }
    
    // MARK: - Cache Invalidation
    
    /// Invalidate specific sections for specific years based on data changes
    func invalidate(affectedYears: [String], sections: [InfographicsSection]) async {
        for year in affectedYears {
            for section in sections {
                invalidateSection(section, for: year)
            }
        }
        await save()
    }
    
    /// Invalidate all cache for a specific year
    func invalidateYear(_ year: String) async {
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
        cache = InfographicsCache()
        await save()
    }
    
    // MARK: - Private Helpers
    
    private func invalidateSection(_ section: InfographicsSection, for year: String) {
        switch section {
        case .travelStatistics:
            cache.travelStatistics.removeValue(forKey: year)
        case .eventTypes:
            cache.eventTypeData.removeValue(forKey: year)
        case .locations:
            cache.locationStats.removeValue(forKey: year)
        case .activities:
            cache.activities.removeValue(forKey: year)
        case .people:
            cache.people.removeValue(forKey: year)
        case .states:
            cache.states.removeValue(forKey: year)
        }
    }
    
    // MARK: - Persistence
    
    private func save() async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            try data.write(to: cacheURL)
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
    let treesNeeded: Double
    let kWhEquivalent: Double
    let earthCircumferences: Double
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
