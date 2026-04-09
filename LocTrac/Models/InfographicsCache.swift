//
//  InfographicsCache.swift
//  LocTrac
//
//  Smart caching system for infographics data to prevent excessive recalculation
//

import Foundation
import SwiftUI

// MARK: - Cache Keys
enum InfographicsSectionType: String, Hashable {
    case overview
    case eventTypes
    case locations
    case travelReach
    case activities
    case people
    case journey
    case environmental
}

// MARK: - Cached Data Structures
struct CachedOverviewStats: Codable, Equatable {
    let totalStays: Int
    let uniqueLocations: Int
    let totalDays: Int
    let uniqueActivities: Int
    let uniquePeople: Int
    let trips: Int
}

struct CachedEventTypeData: Codable, Equatable {
    let types: [(type: String, icon: String, count: Int, percentage: Int)]
    
    // Custom Codable since tuples aren't Codable by default
    enum CodingKeys: String, CodingKey {
        case types
    }
    
    init(types: [(type: String, icon: String, count: Int, percentage: Int)]) {
        self.types = types
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeData = try container.decode([[String: AnyCodable]].self, forKey: .types)
        self.types = typeData.compactMap { dict in
            guard let type = dict["type"]?.value as? String,
                  let icon = dict["icon"]?.value as? String,
                  let count = dict["count"]?.value as? Int,
                  let percentage = dict["percentage"]?.value as? Int else {
                return nil
            }
            return (type: type, icon: icon, count: count, percentage: percentage)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let typeData: [[String: AnyCodable]] = types.map {
            [
                "type": AnyCodable($0.type),
                "icon": AnyCodable($0.icon),
                "count": AnyCodable($0.count),
                "percentage": AnyCodable($0.percentage)
            ]
        }
        try container.encode(typeData, forKey: .types)
    }
}

struct CachedLocationData: Codable, Equatable {
    let locations: [(name: String, count: Int, colorString: String)]
    
    enum CodingKeys: String, CodingKey {
        case locations
    }
    
    init(locations: [(name: String, count: Int, colorString: String)]) {
        self.locations = locations
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let locData = try container.decode([[String: AnyCodable]].self, forKey: .locations)
        self.locations = locData.compactMap { dict in
            guard let name = dict["name"]?.value as? String,
                  let count = dict["count"]?.value as? Int,
                  let colorString = dict["colorString"]?.value as? String else {
                return nil
            }
            return (name: name, count: count, colorString: colorString)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let locData: [[String: AnyCodable]] = locations.map {
            [
                "name": AnyCodable($0.name),
                "count": AnyCodable($0.count),
                "colorString": AnyCodable($0.colorString)
            ]
        }
        try container.encode(locData, forKey: .locations)
    }
}

struct CachedTravelReachData: Codable, Equatable {
    let countries: Set<String>
    let states: Set<String>
    let usStaysCount: Int
}

struct CachedActivitiesData: Codable, Equatable {
    let activities: [(name: String, count: Int)]
    
    enum CodingKeys: String, CodingKey {
        case activities
    }
    
    init(activities: [(name: String, count: Int)]) {
        self.activities = activities
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let actData = try container.decode([[String: AnyCodable]].self, forKey: .activities)
        self.activities = actData.compactMap { dict in
            guard let name = dict["name"]?.value as? String,
                  let count = dict["count"]?.value as? Int else {
                return nil
            }
            return (name: name, count: count)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let actData: [[String: AnyCodable]] = activities.map {
            ["name": AnyCodable($0.name), "count": AnyCodable($0.count)]
        }
        try container.encode(actData, forKey: .activities)
    }
}

struct CachedPeopleData: Codable, Equatable {
    let people: [(name: String, count: Int)]
    
    enum CodingKeys: String, CodingKey {
        case people
    }
    
    init(people: [(name: String, count: Int)]) {
        self.people = people
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pplData = try container.decode([[String: AnyCodable]].self, forKey: .people)
        self.people = pplData.compactMap { dict in
            guard let name = dict["name"]?.value as? String,
                  let count = dict["count"]?.value as? Int else {
                return nil
            }
            return (name: name, count: count)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let pplData: [[String: AnyCodable]] = people.map {
            ["name": AnyCodable($0.name), "count": AnyCodable($0.count)]
        }
        try container.encode(pplData, forKey: .people)
    }
}

struct CachedJourneyData: Codable, Equatable {
    let eventsWithCoordinates: Int
    let firstEventID: String?
    let lastEventID: String?
    let totalDistance: Double
}

struct CachedEnvironmentalData: Codable, Equatable {
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

// MARK: - AnyCodable Helper
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}

// MARK: - Cache Manager
@MainActor
class InfographicsCache: ObservableObject {
    // Cache storage by year and section
    @Published private var overviewCache: [String: CachedOverviewStats] = [:]
    @Published private var eventTypeCache: [String: CachedEventTypeData] = [:]
    @Published private var locationCache: [String: CachedLocationData] = [:]
    @Published private var travelReachCache: [String: CachedTravelReachData] = [:]
    @Published private var activitiesCache: [String: CachedActivitiesData] = [:]
    @Published private var peopleCache: [String: CachedPeopleData] = [:]
    @Published private var journeyCache: [String: CachedJourneyData] = [:]
    @Published private var environmentalCache: [String: CachedEnvironmentalData] = [:]
    
    // Track data hashes to detect changes
    private var eventHashCache: [String: Int] = [:]
    private var activityHashCache: [String: Int] = [:]
    private var personHashCache: [String: Int] = [:]
    private var tripHashCache: [String: Int] = [:]
    
    // MARK: - Cache Invalidation
    
    func invalidateSection(_ section: InfographicsSectionType, forYear year: String) {
        switch section {
        case .overview:
            overviewCache.removeValue(forKey: year)
        case .eventTypes:
            eventTypeCache.removeValue(forKey: year)
        case .locations:
            locationCache.removeValue(forKey: year)
        case .travelReach:
            travelReachCache.removeValue(forKey: year)
        case .activities:
            activitiesCache.removeValue(forKey: year)
        case .people:
            peopleCache.removeValue(forKey: year)
        case .journey:
            journeyCache.removeValue(forKey: year)
        case .environmental:
            environmentalCache.removeValue(forKey: year)
        }
    }
    
    func invalidateYear(_ year: String) {
        overviewCache.removeValue(forKey: year)
        eventTypeCache.removeValue(forKey: year)
        locationCache.removeValue(forKey: year)
        travelReachCache.removeValue(forKey: year)
        activitiesCache.removeValue(forKey: year)
        peopleCache.removeValue(forKey: year)
        journeyCache.removeValue(forKey: year)
        environmentalCache.removeValue(forKey: year)
    }
    
    func invalidateAll() {
        overviewCache.removeAll()
        eventTypeCache.removeAll()
        locationCache.removeAll()
        travelReachCache.removeAll()
        activitiesCache.removeAll()
        peopleCache.removeAll()
        journeyCache.removeAll()
        environmentalCache.removeAll()
        eventHashCache.removeAll()
        activityHashCache.removeAll()
        personHashCache.removeAll()
        tripHashCache.removeAll()
    }
    
    // MARK: - Smart Invalidation Based on Changes
    
    func handleEventsChanged(_ events: [Event], forYear year: String) {
        let newHash = events.map { "\($0.id)\($0.date)\($0.location.id)\($0.eventType)" }.joined().hashValue
        if eventHashCache[year] != newHash {
            eventHashCache[year] = newHash
            // Invalidate sections affected by event changes
            invalidateSection(.overview, forYear: year)
            invalidateSection(.eventTypes, forYear: year)
            invalidateSection(.locations, forYear: year)
            invalidateSection(.travelReach, forYear: year)
            invalidateSection(.journey, forYear: year)
            invalidateSection(.environmental, forYear: year)
            // Also invalidate "All Time"
            invalidateSection(.overview, forYear: "All Time")
            invalidateSection(.eventTypes, forYear: "All Time")
            invalidateSection(.locations, forYear: "All Time")
            invalidateSection(.travelReach, forYear: "All Time")
            invalidateSection(.journey, forYear: "All Time")
            invalidateSection(.environmental, forYear: "All Time")
        }
    }
    
    func handleActivitiesChanged(_ activities: [Activity]) {
        let newHash = activities.map { $0.id + $0.name }.joined().hashValue
        let allYearsHash = "activities_all"
        if activityHashCache[allYearsHash] != newHash {
            activityHashCache[allYearsHash] = newHash
            // Invalidate activities section for all years
            activitiesCache.removeAll()
            // Also invalidate overview for activity count
            overviewCache.removeAll()
        }
    }
    
    func handlePeopleChanged() {
        // People changes affect people section and overview
        peopleCache.removeAll()
        overviewCache.removeAll()
    }
    
    func handleTripsChanged() {
        // Trips affect environmental section
        environmentalCache.removeAll()
    }
    
    // MARK: - Cache Getters/Setters
    
    func getOverview(forYear year: String) -> CachedOverviewStats? {
        return overviewCache[year]
    }
    
    func setOverview(_ data: CachedOverviewStats, forYear year: String) {
        overviewCache[year] = data
    }
    
    func getEventTypes(forYear year: String) -> CachedEventTypeData? {
        return eventTypeCache[year]
    }
    
    func setEventTypes(_ data: CachedEventTypeData, forYear year: String) {
        eventTypeCache[year] = data
    }
    
    func getLocations(forYear year: String) -> CachedLocationData? {
        return locationCache[year]
    }
    
    func setLocations(_ data: CachedLocationData, forYear year: String) {
        locationCache[year] = data
    }
    
    func getTravelReach(forYear year: String) -> CachedTravelReachData? {
        return travelReachCache[year]
    }
    
    func setTravelReach(_ data: CachedTravelReachData, forYear year: String) {
        travelReachCache[year] = data
    }
    
    func getActivities(forYear year: String) -> CachedActivitiesData? {
        return activitiesCache[year]
    }
    
    func setActivities(_ data: CachedActivitiesData, forYear year: String) {
        activitiesCache[year] = data
    }
    
    func getPeople(forYear year: String) -> CachedPeopleData? {
        return peopleCache[year]
    }
    
    func setPeople(_ data: CachedPeopleData, forYear year: String) {
        peopleCache[year] = data
    }
    
    func getJourney(forYear year: String) -> CachedJourneyData? {
        return journeyCache[year]
    }
    
    func setJourney(_ data: CachedJourneyData, forYear year: String) {
        journeyCache[year] = data
    }
    
    func getEnvironmental(forYear year: String) -> CachedEnvironmentalData? {
        return environmentalCache[year]
    }
    
    func setEnvironmental(_ data: CachedEnvironmentalData, forYear year: String) {
        environmentalCache[year] = data
    }
}
