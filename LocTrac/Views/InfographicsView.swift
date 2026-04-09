//
//  InfographicsView.swift
//  LocTrac
//
//  Travel Statistics & Infographics with PDF Export
//

import SwiftUI
import Charts
import MapKit

// MARK: - Derived Data Model
/// Holds all precomputed data for a specific year
struct Derived {
    let filteredEvents: [Event]
    let eventTypeData: [(type: String, icon: String, count: Int, percentage: Int)]
    let topLocations: [(name: String, count: Int, color: Color)]
    let eventsWithCoordinates: [Event]
    let polylineCoordinates: [CLLocationCoordinate2D]
    let travelStats: TravelStatisticsCache
    let topActivities: [(name: String, count: Int)]
    let topPeople: [(name: String, count: Int)]
    let countriesVisited: Set<String>
    let detectedStates: Set<String>
    let usStaysCount: Int
    let internationalStaysCount: Int
    let totalStays: Int
    let uniqueLocationsCount: Int
    let totalDaysCount: Int
    let uniqueActivitiesCount: Int
    let uniquePeopleCount: Int
    let tripsCount: Int
    let dateRange: String?
    
    // Vacation-specific data (from "Other" location)
    let vacationStats: VacationStats
}

// MARK: - Vacation Statistics Model
struct VacationStats {
    let totalVacationDays: Int
    let uniqueVacationCities: Set<String>
    let vacationCountries: Set<String>
    let topVacationCities: [(city: String, days: Int)]
    let topVacationCountries: [(country: String, days: Int)]
    let longestVacation: (city: String?, days: Int)?
    let averageVacationLength: Double
    let vacationTripsCount: Int
}

struct InfographicsView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedYear: String = "All Time"
    
    // MEMOIZATION: Store derived data per year
    @State private var derivedByYear: [String: Derived] = [:]
    @State private var isCalculating = false
    
    // State detection (still async due to geocoding)
    @State private var stateDetectionTask: Task<Void, Never>?
    private let stateDetector = StateDetector()
    
    private var availableYears: [String] {
        let years = Set(store.events.map { Calendar.current.component(.year, from: $0.date) })
        return ["All Time"] + years.sorted(by: >).map { String($0) }
    }
    
    var body: some View {
        // ⚠️ NO NavigationStack - this view is embedded in StartTabView's NavigationStack
        ScrollView {
            VStack(spacing: 24) {
                // Year filter picker
                yearFilterSection
                
                // Show content if derived data is ready
                if let derived = derivedByYear[selectedYear] {
                    // Header with year selector
                    headerSection(derived: derived)
                    
                    // Overview stats cards
                    overviewStatsSection(derived: derived)
                    
                    // Event type breakdown chart
                    eventTypeSection(derived: derived)
                    
                    // Location statistics
                    locationStatsSection(derived: derived)
                    
                    // Travel reach (countries & states)
                    travelReachSection(derived: derived)
                    
                    // Vacation highlights
                    vacationSection(derived: derived)
                    
                    // Activities breakdown
                    activitiesSection(derived: derived)
                    
                    // People connections
                    peopleSection(derived: derived)
                    
                    // Journey map
                    journeyMapSection(derived: derived)
                    
                    // Environmental impact
                    environmentalImpactSection(derived: derived)
                } else {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Calculating statistics for \(selectedYear)...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 300)
                }
            }
            .padding()
        }
        // Listen for share button taps from StartTabView toolbar
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GeneratePDF"))) { _ in
            print("📨 Received GeneratePDF notification")
            generatePDF()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShareScreenshot"))) { _ in
            print("📨 Received ShareScreenshot notification")
            shareScreenshot()
        }
        .task(id: selectedYear) {
            // Check if we already have derived data for this year
            if derivedByYear[selectedYear] != nil {
                print("✅ Derived data already computed for \(selectedYear)")
                return
            }
            
            // Compute derived data in background
            isCalculating = true
            await computeDerivedData(for: selectedYear)
            isCalculating = false
        }
        .onChange(of: store.dataUpdateToken) { _, _ in
            // Data changed - clear memoization
            print("🔄 Data updated - clearing memoization cache")
            derivedByYear.removeAll()
            
            // Recompute current year
            Task {
                await computeDerivedData(for: selectedYear)
            }
        }
    }
    
    // MARK: - Derived Data Computation
    
    /// Compute all derived data for a specific year
    private func computeDerivedData(for year: String) async {
        print("🔄 Computing derived data for \(year)...")
        let startTime = Date()
        
        // Step 1: Filter events
        let filtered = computeFilteredEvents(for: year)
        
        // Step 2: Compute all derived values concurrently where possible
        async let eventTypeData = computeEventTypeData(from: filtered)
        async let topLocations = computeTopLocations(from: filtered)
        async let topActivities = computeTopActivities(from: filtered, store: store)
        async let topPeople = computeTopPeople(from: filtered)
        
        // Events with coordinates (needed for map and travel stats)
        let eventsWithCoords = filtered.filter { event in
            let hasEventCoords = event.latitude != 0.0 && event.longitude != 0.0
            let hasLocationCoords = event.location.latitude != 0.0 && event.location.longitude != 0.0
            return hasEventCoords || hasLocationCoords
        }.sorted { $0.date < $1.date }
        
        // Polyline coordinates
        let polylineCoords = eventsWithCoords.map { event -> CLLocationCoordinate2D in
            if event.latitude != 0.0 && event.longitude != 0.0 {
                return CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
            } else {
                return CLLocationCoordinate2D(
                    latitude: event.location.latitude,
                    longitude: event.location.longitude
                )
            }
        }
        
        // Travel statistics
        let travelStats = await computeTravelStatistics(from: eventsWithCoords)
        
        // Travel reach
        let countriesVisited = Set(filtered.compactMap { $0.country }.filter { !$0.isEmpty })
        let usStaysCount = filtered.filter { event in
            let country = event.country?.uppercased() ?? ""
            return country == "UNITED STATES" || country == "US" || country == "USA"
        }.count
        let internationalStaysCount = filtered.filter { event in
            let country = event.country?.uppercased() ?? ""
            return !country.isEmpty && country != "UNITED STATES" && country != "US" && country != "USA"
        }.count
        
        // State detection (async, may take time)
        let detectedStates = await detectStates(from: filtered, for: year)
        
        // Vacation statistics (from "Other" location)
        let vacationStats = await computeVacationStats(from: filtered)
        
        // Overview stats
        let totalStays = filtered.count
        // Exclude "Other" location from unique locations count
        let uniqueLocationsCount = Set(filtered.filter { $0.location.name != "Other" }.map { $0.location.id }).count
        let totalDaysCount = filtered.count
        let uniqueActivitiesCount = Set(filtered.flatMap { $0.activityIDs }).count
        // Ensure people are unique by displayName
        let uniquePeopleCount = Set(filtered.flatMap { $0.people.map { $0.displayName } }).count
        
        // Get trips count for this year
        let tripsCount: Int
        if year == "All Time" {
            tripsCount = await MainActor.run { store.trips.count }
        } else if let y = Int(year) {
            tripsCount = await MainActor.run {
                store.trips.filter { Calendar.current.component(.year, from: $0.departureDate) == y }.count
            }
        } else {
            tripsCount = 0
        }
        
        // Date range
        let dateRange: String?
        if !filtered.isEmpty {
            let dates = filtered.map { $0.date }
            if let earliest = dates.min(), let latest = dates.max() {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                dateRange = "\(formatter.string(from: earliest)) - \(formatter.string(from: latest))"
            } else {
                dateRange = nil
            }
        } else {
            dateRange = nil
        }
        
        // Await concurrent computations
        let eventTypes = await eventTypeData
        let locations = await topLocations
        let activities = await topActivities
        let people = await topPeople
        
        // Create derived object
        let derived = Derived(
            filteredEvents: filtered,
            eventTypeData: eventTypes,
            topLocations: locations,
            eventsWithCoordinates: eventsWithCoords,
            polylineCoordinates: polylineCoords,
            travelStats: travelStats,
            topActivities: activities,
            topPeople: people,
            countriesVisited: countriesVisited,
            detectedStates: detectedStates,
            usStaysCount: usStaysCount,
            internationalStaysCount: internationalStaysCount,
            totalStays: totalStays,
            uniqueLocationsCount: uniqueLocationsCount,
            totalDaysCount: totalDaysCount,
            uniqueActivitiesCount: uniqueActivitiesCount,
            uniquePeopleCount: uniquePeopleCount,
            tripsCount: tripsCount,
            dateRange: dateRange,
            vacationStats: vacationStats
        )
        
        // Store in state
        await MainActor.run {
            derivedByYear[year] = derived
            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ Derived data computed for \(year) in \(String(format: "%.2f", elapsed))s")
        }
    }
    
    // Filter events for a specific year
    private func computeFilteredEvents(for year: String) -> [Event] {
        if year == "All Time" {
            return store.events
        } else if let y = Int(year) {
            return store.events.filter { Calendar.current.component(.year, from: $0.date) == y }
        }
        return store.events
    }
    
    // Compute event type data
    private func computeEventTypeData(from events: [Event]) async -> [(type: String, icon: String, count: Int, percentage: Int)] {
        guard !events.isEmpty else { return [] }
        
        let grouped = Dictionary(grouping: events) { event in
            Event.EventType(rawValue: event.eventType) ?? .unspecified
        }
        
        return grouped.map { (key, value) in
            let percentage = Int((Double(value.count) / Double(events.count)) * 100)
            return (
                type: key.rawValue.capitalized,
                icon: key.icon,
                count: value.count,
                percentage: percentage
            )
        }
    }
    
    // Compute top locations
    private func computeTopLocations(from events: [Event]) async -> [(name: String, count: Int, color: Color)] {
        guard !events.isEmpty else { return [] }
        
        let grouped = Dictionary(grouping: events) { $0.location.id }
        
        return grouped.compactMap { (_, value) -> (name: String, count: Int, color: Color)? in
            guard let firstEvent = value.first else { return nil }
            let location = firstEvent.location
            return (
                name: location.name,
                count: value.count,
                color: location.theme.mainColor
            )
        }.sorted { $0.count > $1.count }
    }
    
    // Compute travel statistics
    private func computeTravelStatistics(from events: [Event]) async -> TravelStatisticsCache {
        guard events.count > 1 else {
            return TravelStatisticsCache(
                totalMiles: 0, totalCO2: 0, flyingMiles: 0, flyingCO2: 0,
                flyingTrips: 0, drivingMiles: 0, drivingCO2: 0, drivingTrips: 0,
                treesNeeded: 0, kWhEquivalent: 0, earthCircumferences: 0
            )
        }
        
        var totalMiles = 0.0
        var flyingMiles = 0.0
        var drivingMiles = 0.0
        var flyingTrips = 0
        var drivingTrips = 0
        
        for i in 0..<(events.count - 1) {
            guard i + 1 < events.count else { break }
            let current = events[i]
            let next = events[i + 1]
            
            let currentLocationID = current.location.id
            let nextLocationID = next.location.id
            
            let currentIsOther = current.location.name == "Other"
            let nextIsOther = next.location.name == "Other"
            
            let isActuallyDifferentLocation: Bool
            if currentIsOther && nextIsOther {
                let currentCoord = coordinatesFor(current)
                let nextCoord = coordinatesFor(next)
                let distance = distanceBetween(currentCoord, and: nextCoord)
                isActuallyDifferentLocation = distance > 1.0
            } else if currentIsOther || nextIsOther {
                isActuallyDifferentLocation = true
            } else {
                isActuallyDifferentLocation = currentLocationID != nextLocationID
            }
            
            if isActuallyDifferentLocation {
                let currentCoord = coordinatesFor(current)
                let nextCoord = coordinatesFor(next)
                let distance = distanceBetween(currentCoord, and: nextCoord)
                totalMiles += distance
                
                if distance > 100 {
                    flyingMiles += distance
                    flyingTrips += 1
                } else {
                    drivingMiles += distance
                    drivingTrips += 1
                }
            }
        }
        
        let flyingCO2 = flyingMiles * 0.9
        let drivingCO2 = drivingMiles * 0.89
        let totalCO2 = flyingCO2 + drivingCO2
        
        let treesNeeded = totalCO2 / 48.0
        let kWhEquivalent = totalCO2 * 0.12
        let earthCircumferences = totalMiles / 24901.0
        
        return TravelStatisticsCache(
            totalMiles: totalMiles,
            totalCO2: totalCO2,
            flyingMiles: flyingMiles,
            flyingCO2: flyingCO2,
            flyingTrips: flyingTrips,
            drivingMiles: drivingMiles,
            drivingCO2: drivingCO2,
            drivingTrips: drivingTrips,
            treesNeeded: treesNeeded,
            kWhEquivalent: kWhEquivalent,
            earthCircumferences: earthCircumferences
        )
    }
    
    // Compute top activities
    private func computeTopActivities(from events: [Event], store: DataStore) async -> [(name: String, count: Int)] {
        guard !events.isEmpty else { return [] }
        
        let allActivityIDs = events.flatMap { $0.activityIDs }
        guard !allActivityIDs.isEmpty else { return [] }
        
        let grouped = Dictionary(grouping: allActivityIDs) { $0 }
        
        return grouped.compactMap { (id, ids) in
            guard let activity = store.activities.first(where: { $0.id == id }) else { return nil }
            return (name: activity.name, count: ids.count)
        }.sorted { $0.count > $1.count }
    }
    
    // Compute top people
    private func computeTopPeople(from events: [Event]) async -> [(name: String, count: Int)] {
        guard !events.isEmpty else { return [] }
        
        let allPeople = events.flatMap { $0.people }
        guard !allPeople.isEmpty else { return [] }
        
        let grouped = Dictionary(grouping: allPeople) { $0.displayName }
        
        return grouped.map { (name, people) in
            (name: name, count: people.count)
        }.sorted { $0.count > $1.count }
    }
    
    // Detect states (async, uses geocoding)
    private func detectStates(from events: [Event], for year: String) async -> Set<String> {
        // Try cache first
        let cache = DataStore.infographicsCache
        if let cached = await cache.getStates(for: year) {
            print("✅ Cache hit (states) for year: \(year) -> \(cached.count) states")
            return cached
        }
        
        // Filter US events
        let usEvents = events.filter { event in
            let country = event.country?.uppercased() ?? ""
            return country == "UNITED STATES" || country == "US" || country == "USA"
        }
        
        guard !usEvents.isEmpty else { return [] }
        
        print("🔍 Starting state detection for \(usEvents.count) US events...")
        
        var states = Set<String>()
        
        // Quick extract from city
        for event in usEvents {
            if let state = StateDetector.extractStateFromCity(event.city) {
                states.insert(state)
            }
        }
        
        // Geocode remaining
        let needingGeocode = usEvents.filter { StateDetector.extractStateFromCity($0.city) == nil }
        if !needingGeocode.isEmpty {
            print("  🌍 Geocoding \(needingGeocode.count) events without state in city field...")
            for event in needingGeocode {
                let lat = event.latitude != 0.0 ? event.latitude : event.location.latitude
                let lon = event.longitude != 0.0 ? event.longitude : event.location.longitude
                
                if let state = await stateDetector.detectState(latitude: lat, longitude: lon) {
                    states.insert(state)
                }
            }
        }
        
        print("🔍 Final states detected: \(states.sorted())")
        
        // Cache for next time
        await cache.updateStates(states, for: year)
        
        return states
    }
    
    // Compute vacation statistics from "Other" location events
    private func computeVacationStats(from events: [Event]) async -> VacationStats {
        // Filter only "Other" location events (vacations)
        let vacationEvents = events.filter { $0.location.name == "Other" }
        
        guard !vacationEvents.isEmpty else {
            return VacationStats(
                totalVacationDays: 0,
                uniqueVacationCities: [],
                vacationCountries: [],
                topVacationCities: [],
                topVacationCountries: [],
                longestVacation: nil,
                averageVacationLength: 0,
                vacationTripsCount: 0
            )
        }
        
        let totalVacationDays = vacationEvents.count
        
        // Unique cities and countries
        let uniqueCities = Set(vacationEvents.compactMap { $0.city }.filter { !$0.isEmpty })
        let uniqueCountries = Set(vacationEvents.compactMap { $0.country }.filter { !$0.isEmpty })
        
        // Top vacation cities by days
        let cityGroups = Dictionary(grouping: vacationEvents) { $0.city ?? "Unknown" }
        let topCities = cityGroups.map { (city: $0.key, days: $0.value.count) }
            .sorted { $0.days > $1.days }
        
        // Top vacation countries by days
        let countryGroups = Dictionary(grouping: vacationEvents) { $0.country ?? "Unknown" }
        let topCountries = countryGroups.map { (country: $0.key, days: $0.value.count) }
            .sorted { $0.days > $1.days }
        
        // Find longest vacation (consecutive days in same city)
        var longestVacation: (city: String?, days: Int)? = nil
        var currentCity: String? = nil
        var currentStreak = 0
        
        let sortedVacations = vacationEvents.sorted { $0.date < $1.date }
        for event in sortedVacations {
            if event.city == currentCity {
                currentStreak += 1
            } else {
                if let longest = longestVacation, currentStreak > longest.days {
                    longestVacation = (city: currentCity, days: currentStreak)
                } else if longestVacation == nil && currentStreak > 0 {
                    longestVacation = (city: currentCity, days: currentStreak)
                }
                currentCity = event.city
                currentStreak = 1
            }
        }
        // Check final streak
        if let longest = longestVacation, currentStreak > longest.days {
            longestVacation = (city: currentCity, days: currentStreak)
        } else if longestVacation == nil && currentStreak > 0 {
            longestVacation = (city: currentCity, days: currentStreak)
        }
        
        // Count vacation trips (number of unique city visits)
        let vacationTripsCount = uniqueCities.count
        
        // Average vacation length
        let averageLength = vacationTripsCount > 0 ? Double(totalVacationDays) / Double(vacationTripsCount) : 0
        
        return VacationStats(
            totalVacationDays: totalVacationDays,
            uniqueVacationCities: uniqueCities,
            vacationCountries: uniqueCountries,
            topVacationCities: Array(topCities.prefix(10)),
            topVacationCountries: Array(topCountries.prefix(10)),
            longestVacation: longestVacation,
            averageVacationLength: averageLength,
            vacationTripsCount: vacationTripsCount
        )
    }
}

// MARK: - Year Filter Section
extension InfographicsView {
    private var yearFilterSection: some View {
        VStack(spacing: 12) {
            Text("Filter by Year")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(availableYears, id: \.self) { year in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedYear = year
                            }
                        } label: {
                            Text(year)
                                .font(.subheadline)
                                .fontWeight(selectedYear == year ? .semibold : .regular)
                                .foregroundColor(selectedYear == year ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedYear == year ? Color.blue : Color(.tertiarySystemBackground))
                                )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Header Section
extension InfographicsView {
    @ViewBuilder
    private func headerSection(derived: Derived) -> some View {
        VStack(spacing: 8) {
            Text("Your Travel Journey")
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 4) {
                Image(systemName: selectedYear == "All Time" ? "calendar" : "calendar.badge.clock")
                    .foregroundColor(.blue)
                Text(selectedYear)
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            if let dateRange = derived.dateRange {
                Text(dateRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !derived.filteredEvents.isEmpty {
                Text("\(derived.filteredEvents.count) event\(derived.filteredEvents.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
    }
}

// MARK: - Overview Stats Section
extension InfographicsView {
    @ViewBuilder
    private func overviewStatsSection(derived: Derived) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Total Stays",
                    value: "\(derived.totalStays)",
                    icon: "calendar",
                    color: .blue
                )
                
                StatCard(
                    title: "Locations",
                    value: "\(derived.uniqueLocationsCount)",
                    icon: "mappin.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Total Days",
                    value: "\(derived.totalDaysCount)",
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Trips Taken",
                    value: "\(derived.tripsCount)",
                    icon: "airplane.departure",
                    color: .cyan
                )
                
                StatCard(
                    title: "Activities",
                    value: "\(derived.uniqueActivitiesCount)",
                    icon: "figure.run",
                    color: .purple
                )
                
                StatCard(
                    title: "People",
                    value: "\(derived.uniquePeopleCount)",
                    icon: "person.2.fill",
                    color: .pink
                )
            }
            
            if derived.tripsCount > 0 {
                tripTypesBreakdown(derived: derived)
            }
        }
    }
    
    @ViewBuilder
    private func tripTypesBreakdown(derived: Derived) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trips by Type")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.top, 8)
            
            FlowLayout(spacing: 8) {
                ForEach(tripsByMode(derived: derived), id: \.mode) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.caption)
                        Text(item.mode)
                            .font(.caption)
                        Text("(\(item.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(item.color.opacity(0.2))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func tripsByMode(derived: Derived) -> [(mode: String, icon: String, color: Color, count: Int)] {
        let trips: [Trip]
        if selectedYear == "All Time" {
            trips = store.trips
        } else if let year = Int(selectedYear) {
            trips = store.trips.filter { Calendar.current.component(.year, from: $0.departureDate) == year }
        } else {
            trips = []
        }
        
        let grouped = Dictionary(grouping: trips) { $0.transportMode }
        
        return grouped.compactMap { (modeString, trips) in
            guard let mode = Trip.TransportMode(rawValue: modeString) else { return nil }
            let color: Color = {
                switch mode {
                case .flying: return .blue
                case .driving: return .green
                case .train: return .purple
                case .bus: return .orange
                case .boat: return .cyan
                case .bicycle: return .mint
                case .walking: return .teal
                case .other: return .gray
                }
            }()
            return (mode: mode.rawValue, icon: mode.icon, color: color, count: trips.count)
        }.sorted { $0.count > $1.count }
    }
}

// MARK: - Event Type Section
extension InfographicsView {
    @ViewBuilder
    private func eventTypeSection(derived: Derived) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Types")
                .font(.headline)
            
            let data = derived.eventTypeData
            if !data.isEmpty {
                Chart(data, id: \.type) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Type", item.type))
                    .cornerRadius(4)
                    .annotation(position: .overlay) {
                        Text("\(item.count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                .frame(height: 250)
                .chartLegend(position: .bottom, alignment: .center)
                
                ForEach(data.sorted(by: { $0.count > $1.count }), id: \.type) { item in
                    HStack {
                        Text(item.icon)
                        Text(item.type)
                            .font(.subheadline)
                        Spacer()
                        Text("\(item.count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("(\(item.percentage)%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            } else {
                Text("No event data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Location Stats Section
extension InfographicsView {
    @ViewBuilder
    private func locationStatsSection(derived: Derived) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Locations")
                .font(.headline)
            
            let topLocs = derived.topLocations
            let maxCount = topLocs.first?.count ?? 1
            
            ForEach(topLocs.prefix(10), id: \.name) { item in
                HStack {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8, height: 8)
                    
                    Text(item.name)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(item.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Rectangle()
                        .fill(item.color.opacity(0.3))
                        .frame(width: CGFloat(item.count) / CGFloat(maxCount) * 80, height: 20)
                        .cornerRadius(4)
                }
            }
            
            if topLocs.isEmpty {
                Text("No location data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Travel Reach Section
extension InfographicsView {
    @ViewBuilder
    private func travelReachSection(derived: Derived) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Travel Reach")
                .font(.headline)
            
            HStack(spacing: 12) {
                VStack {
                    Text("\(derived.countriesVisited.count)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.blue)
                    Text("Countries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
                
                VStack {
                    Text("\(derived.detectedStates.count)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.green)
                    Text("US States")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
            }
            
            if !derived.detectedStates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("US States Visited:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(derived.detectedStates.sorted(), id: \.self) { state in
                            Text(state)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            if !derived.countriesVisited.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Countries Visited:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(Array(derived.countriesVisited.sorted()), id: \.self) { country in
                            Text(country)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("US Stays")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(derived.usStaysCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
                
                VStack(alignment: .leading) {
                    Text("International")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(derived.internationalStaysCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Vacation Section
extension InfographicsView {
    @ViewBuilder
    private func vacationSection(derived: Derived) -> some View {
        let stats = derived.vacationStats
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "airplane.departure")
                    .foregroundColor(.orange)
                Text("Vacation Highlights")
                    .font(.headline)
            }
            
            if stats.totalVacationDays > 0 {
                // Vacation overview stats
                HStack(spacing: 12) {
                    VStack {
                        Text("\(stats.totalVacationDays)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Vacation Days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                    
                    VStack {
                        Text("\(stats.uniqueVacationCities.count)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.blue)
                        Text("Destinations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Country count and average length
                HStack(spacing: 12) {
                    VStack {
                        Text("\(stats.vacationCountries.count)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.purple)
                        Text("Countries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                    
                    VStack {
                        Text(String(format: "%.1f", stats.averageVacationLength))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                        Text("Avg Days/Trip")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Longest vacation
                if let longest = stats.longestVacation, longest.days > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                            Text("Longest Vacation")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text(longest.city ?? "Unknown")
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(longest.days) days")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Top vacation cities
                if !stats.topVacationCities.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Vacation Destinations")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        let maxDays = stats.topVacationCities.first?.days ?? 1
                        ForEach(stats.topVacationCities.prefix(8), id: \.city) { item in
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                
                                Text(item.city)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text("\(item.days)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("days")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Rectangle()
                                    .fill(Color.orange.opacity(0.3))
                                    .frame(width: CGFloat(item.days) / CGFloat(maxDays) * 60, height: 16)
                                    .cornerRadius(4)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Vacation countries visited
                if !stats.vacationCountries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vacation Countries:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(Array(stats.vacationCountries.sorted()), id: \.self) { country in
                                HStack(spacing: 4) {
                                    Image(systemName: "globe.americas.fill")
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                    Text(country)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
            } else {
                Text("No vacation data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Activities Section
extension InfographicsView {
    @ViewBuilder
    private func activitiesSection(derived: Derived) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Activities")
                .font(.headline)
            
            if !derived.topActivities.isEmpty {
                Chart(derived.topActivities.prefix(10), id: \.name) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Activity", item.name)
                    )
                    .foregroundStyle(.purple.gradient)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text("\(item.count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: CGFloat(min(derived.topActivities.count, 10)) * 40)
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            } else {
                Text("No activity data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - People Section
extension InfographicsView {
    @ViewBuilder
    private func peopleSection(derived: Derived) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People Met/Stayed With")
                .font(.headline)
            
            if !derived.topPeople.isEmpty {
                ForEach(derived.topPeople.prefix(10), id: \.name) { item in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        
                        Text(item.name)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(item.count) visit\(item.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No companion data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Journey Map Section
extension InfographicsView {
    @ViewBuilder
    private func journeyMapSection(derived: Derived) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Journey Map")
                    .font(.headline)
                Spacer()
                Text("\(derived.eventsWithCoordinates.count) locations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !derived.eventsWithCoordinates.isEmpty {
                Map(initialPosition: .automatic) {
                    if derived.polylineCoordinates.count > 1 {
                        MapPolyline(coordinates: derived.polylineCoordinates)
                            .stroke(Color.blue, lineWidth: 3)
                    }
                    
                    ForEach(derived.eventsWithCoordinates) { event in
                        let isOtherEvent = event.location.name == "Other"
                        
                        Annotation("", coordinate: coordinatesFor(event)) {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(isOtherEvent ? Color.blue : event.location.theme.mainColor)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .shadow(radius: 2)
                                
                                if event.id == derived.eventsWithCoordinates.first?.id || event.id == derived.eventsWithCoordinates.last?.id {
                                    VStack(spacing: 2) {
                                        if isOtherEvent {
                                            if let city = event.city, !city.isEmpty {
                                                Text(city)
                                                    .font(.caption2)
                                                    .fontWeight(.semibold)
                                            }
                                        } else {
                                            Text(event.location.name)
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                        }
                                        
                                        Text(event.date.formatted(.dateTime.month().year()))
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                .mapStyle(.standard)
                .frame(height: 300)
                .cornerRadius(12)
                
                VStack(spacing: 12) {
                    Divider()
                    
                    HStack(spacing: 16) {
                        if let firstEvent = derived.eventsWithCoordinates.first {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text("Start")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(firstEvent.location.name == "Other" ? (firstEvent.city ?? "Other") : firstEvent.location.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                Text(firstEvent.date.formatted(.dateTime.month().year()))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if let lastEvent = derived.eventsWithCoordinates.last {
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("End")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "flag.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                Text(lastEvent.location.name == "Other" ? (lastEvent.city ?? "Other") : lastEvent.location.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                Text(lastEvent.date.formatted(.dateTime.month().year()))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    if let duration = journeyDuration(from: derived.eventsWithCoordinates) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Journey Span:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(duration)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.top, 8)
                
            } else {
                Text("No journey data available - locations need coordinates")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    nonisolated private func coordinatesFor(_ event: Event) -> CLLocationCoordinate2D {
        if event.latitude != 0.0 && event.longitude != 0.0 {
            return CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
        } else {
            return CLLocationCoordinate2D(latitude: event.location.latitude, longitude: event.location.longitude)
        }
    }
    
    private func journeyDuration(from events: [Event]) -> String? {
        guard let firstDate = events.first?.date,
              let lastDate = events.last?.date else {
            return nil
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .month, .year], from: firstDate, to: lastDate)
        
        if let years = components.year, years > 0 {
            if let months = components.month, months > 0 {
                return "\(years)y \(months)mo"
            }
            return "\(years) year\(years == 1 ? "" : "s")"
        } else if let months = components.month, months > 0 {
            return "\(months) month\(months == 1 ? "" : "s")"
        } else if let days = components.day {
            return "\(days) day\(days == 1 ? "" : "s")"
        }
        
        return nil
    }
}

// MARK: - Environmental Impact Section
extension InfographicsView {
    @ViewBuilder
    private func environmentalImpactSection(derived: Derived) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                Text("Environmental Impact")
                    .font(.headline)
            }
            
            let stats = derived.travelStats
            if derived.eventsWithCoordinates.count < 2 {
                Text("Not enough location data to calculate travel impact")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if stats.totalMiles > 0 {
                environmentalImpactContent(stats: stats)
            } else {
                Text("No travel data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func environmentalImpactContent(stats: TravelStatisticsCache) -> some View {
        carbonFootprintRating(co2: stats.totalCO2)
        
        Divider().padding(.vertical, 8)
        
        HStack(spacing: 12) {
            VStack {
                Image(systemName: "road.lanes")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("\(Int(stats.totalMiles))")
                    .font(.system(size: 32, weight: .bold))
                Text("Total Miles")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
            
            VStack {
                Image(systemName: "cloud.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("\(Int(stats.totalCO2))")
                    .font(.system(size: 32, weight: .bold))
                Text("lbs CO₂")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
        }
        
        VStack(spacing: 12) {
            Divider()
            if stats.flyingMiles > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "airplane")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Flying").font(.subheadline).fontWeight(.semibold)
                        Text("\(stats.flyingTrips) trips").font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(stats.flyingMiles)) mi").font(.subheadline).fontWeight(.semibold)
                        Text("\(Int(stats.flyingCO2)) lbs CO₂").font(.caption2).foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground).opacity(0.5))
                .cornerRadius(8)
            }
            if stats.drivingMiles > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "car.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Driving").font(.subheadline).fontWeight(.semibold)
                        Text("\(stats.drivingTrips) trips").font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(stats.drivingMiles)) mi").font(.subheadline).fontWeight(.semibold)
                        Text("\(Int(stats.drivingCO2)) lbs CO₂").font(.caption2).foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground).opacity(0.5))
                .cornerRadius(8)
            }
        }
        
        VStack(spacing: 8) {
            Divider()
            HStack {
                Image(systemName: "info.circle").font(.caption).foregroundColor(.blue)
                Text("That's equivalent to:").font(.caption).foregroundColor(.secondary)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text("🌳"); Text("\(Int(stats.treesNeeded)) trees needed to offset CO₂ for 1 year").font(.caption2).foregroundColor(.secondary) }
                HStack { Text("⚡️"); Text("\(Int(stats.kWhEquivalent)) kWh of electricity").font(.caption2).foregroundColor(.secondary) }
                HStack { Text("🌍"); Text("\(String(format: "%.1f", stats.earthCircumferences)) times around Earth").font(.caption2).foregroundColor(.secondary) }
            }
            .padding(.horizontal, 8)
        }
    }
    
    @ViewBuilder
    private func carbonFootprintRating(co2: Double) -> some View {
        let rating = calculateCarbonRating(co2: co2)
        
        VStack(spacing: 12) {
            HStack {
                Text("Carbon Footprint Score").font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text(rating.grade)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(rating.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(rating.color.opacity(0.2))
                    .cornerRadius(8)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.green, .yellow, .orange, .red], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * rating.percentage, height: 8)
                }
            }
            .frame(height: 8)
            Text(rating.description).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    private func calculateCarbonRating(co2: Double) -> (grade: String, percentage: Double, color: Color, description: String) {
        let annualizedCO2 = co2
        if annualizedCO2 < 500 { return ("A+", 0.1, .green, "Excellent! Your travel footprint is very low.") }
        else if annualizedCO2 < 1000 { return ("A", 0.2, .green, "Great! You're doing well with sustainable travel.") }
        else if annualizedCO2 < 2000 { return ("B", 0.35, .mint, "Good! Your travel footprint is below average.") }
        else if annualizedCO2 < 3000 { return ("C", 0.5, .yellow, "Average travel footprint. Consider greener options.") }
        else if annualizedCO2 < 5000 { return ("D", 0.7, .orange, "Above average. Try reducing flights or driving.") }
        else if annualizedCO2 < 8000 { return ("E", 0.85, .red, "High impact. Significant reduction recommended.") }
        else { return ("F", 1.0, .red, "Very high impact. Major changes needed.") }
    }
    
    // Calculate distance between two coordinates in miles
    nonisolated private func distanceBetween(_ coord1: CLLocationCoordinate2D, and coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        let distanceInMeters = location1.distance(from: location2)
        return distanceInMeters * 0.000621371
    }
}

// MARK: - Placeholder
extension InfographicsView {
    // No longer needed - using derived data
}

// MARK: - PDF Generation
extension InfographicsView {
    private func generatePDF() {
        guard let derived = derivedByYear[selectedYear] else {
            print("⚠️ No derived data for PDF generation")
            return
        }
        
        print("📄 Starting PDF generation for \(selectedYear)...")
        
        // Check if we need to generate a map snapshot first
        if !derived.eventsWithCoordinates.isEmpty {
            Task {
                await generatePDFWithMapSnapshot(derived: derived)
            }
        } else {
            // No map needed, generate PDF directly
            createPDFContent(derived: derived, mapSnapshot: nil)
        }
    }
    
    /// Generate PDF with an actual MapKit snapshot
    private func generatePDFWithMapSnapshot(derived: Derived) async {
        print("🗺️ Generating map snapshot...")
        
        // Calculate map region from coordinates
        let coordinates = derived.polylineCoordinates
        guard !coordinates.isEmpty else {
            createPDFContent(derived: derived, mapSnapshot: nil)
            return
        }
        
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let latDelta = (maxLat - minLat) * 1.3  // 30% padding
        let lonDelta = (maxLon - minLon) * 1.3
        
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        let span = MKCoordinateSpan(latitudeDelta: max(latDelta, 0.1), longitudeDelta: max(lonDelta, 0.1))
        let region = MKCoordinateRegion(center: center, span: span)
        
        // Create snapshot options
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: 600, height: 400)  // High resolution
        options.mapType = .standard
        
        // Create snapshotter
        let snapshotter = MKMapSnapshotter(options: options)
        
        do {
            let snapshot = try await snapshotter.start()
            print("✅ Map snapshot generated")
            
            // Draw route and markers on the snapshot
            let image = await drawRouteOnSnapshot(snapshot: snapshot, derived: derived)
            
            // Continue with PDF generation on main thread
            await MainActor.run {
                createPDFContent(derived: derived, mapSnapshot: image)
            }
        } catch {
            print("❌ Map snapshot failed: \(error.localizedDescription)")
            await MainActor.run {
                createPDFContent(derived: derived, mapSnapshot: nil)
            }
        }
    }
    
    /// Draw the route and markers on top of the map snapshot
    private func drawRouteOnSnapshot(snapshot: MKMapSnapshotter.Snapshot, derived: Derived) async -> UIImage {
        let image = snapshot.image
        
        return await Task.detached {
            let renderer = UIGraphicsImageRenderer(size: image.size)
            
            return renderer.image { context in
                // Draw the base map
                image.draw(at: .zero)
                
                let ctx = context.cgContext
                
                // Draw route line
                if derived.polylineCoordinates.count > 1 {
                    ctx.setStrokeColor(UIColor.systemBlue.cgColor)
                    ctx.setLineWidth(4)
                    ctx.setLineCap(.round)
                    ctx.setLineJoin(.round)
                    
                    for (index, coordinate) in derived.polylineCoordinates.enumerated() {
                        let point = snapshot.point(for: coordinate)
                        
                        if index == 0 {
                            ctx.move(to: point)
                        } else {
                            ctx.addLine(to: point)
                        }
                    }
                    
                    ctx.strokePath()
                }
                
                // Draw markers
                for (index, event) in derived.eventsWithCoordinates.enumerated() {
                    let coordinate = derived.polylineCoordinates[index]
                    let point = snapshot.point(for: coordinate)
                    
                    let isFirst = index == 0
                    let isLast = index == derived.eventsWithCoordinates.count - 1
                    let isOther = event.location.name == "Other"
                    
                    // Marker circle
                    let markerSize: CGFloat = isFirst || isLast ? 20 : 12
                    let markerRect = CGRect(
                        x: point.x - markerSize / 2,
                        y: point.y - markerSize / 2,
                        width: markerSize,
                        height: markerSize
                    )
                    
                    // Fill color
                    let color = isOther ? UIColor.systemBlue : UIColor(event.location.theme.mainColor)
                    ctx.setFillColor(color.cgColor)
                    ctx.fillEllipse(in: markerRect)
                    
                    // White border
                    ctx.setStrokeColor(UIColor.white.cgColor)
                    ctx.setLineWidth(3)
                    ctx.strokeEllipse(in: markerRect)
                }
            }
        }.value
    }
    
    /// Create the actual PDF content with optional map snapshot
    private func createPDFContent(derived: Derived, mapSnapshot: UIImage?) {
        let pdfContent = VStack(spacing: 20) {
            // Header with branding and year
            VStack(spacing: 8) {
                Text("LocTrac Travel Infographic")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Image(systemName: selectedYear == "All Time" ? "calendar" : "calendar.badge.clock")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text(selectedYear)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                if let dateRange = derived.dateRange {
                    Text(dateRange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            
            // All content sections
            overviewStatsSection(derived: derived)
            eventTypeSection(derived: derived)
            locationStatsSection(derived: derived)
            travelReachSection(derived: derived)
            
            // Only include vacation section if there's vacation data
            if derived.vacationStats.totalVacationDays > 0 {
                vacationSection(derived: derived)
            }
            
            // Only include if there are activities
            if !derived.topActivities.isEmpty {
                activitiesSection(derived: derived)
            }
            
            // Only include if there are people
            if !derived.topPeople.isEmpty {
                peopleSection(derived: derived)
            }
            
            // Journey map - use actual snapshot if available
            if !derived.eventsWithCoordinates.isEmpty {
                if let mapImage = mapSnapshot {
                    journeyMapWithSnapshot(derived: derived, mapImage: mapImage)
                } else {
                    journeyMapSectionForExport(derived: derived)
                }
            }
            
            // Environmental impact (if travel data exists)
            if derived.eventsWithCoordinates.count > 1 && derived.travelStats.totalMiles > 0 {
                environmentalImpactSection(derived: derived)
            }
            
            // Footer with generation timestamp
            VStack(spacing: 4) {
                Divider()
                    .padding(.horizontal, 40)
                    .padding(.top, 12)
                
                Text("Generated by LocTrac")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(Date().formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .padding(24)
        .frame(width: 8.5 * 72) // Standard US Letter width in points
        .background(Color.white)
        
        // Render to image
        let renderer = ImageRenderer(content: pdfContent)
        renderer.scale = 2.0 // Retina quality
        
        // Use automatic height to accommodate all content
        renderer.proposedSize = ProposedViewSize(width: 8.5 * 72, height: .infinity)
        
        guard let image = renderer.uiImage else {
            print("❌ Failed to render PDF content to image")
            return
        }
        
        print("✅ Image rendered: \(Int(image.size.width)) x \(Int(image.size.height)) pixels")
        
        // Convert image to PDF
        guard let pdfData = createPDFFromImage(image, pageSize: image.size) else {
            print("❌ Failed to create PDF from image")
            return
        }
        
        print("✅ PDF created: \(pdfData.count / 1024) KB")
        
        // Save to temporary location
        let fileName = "LocTrac_Infographic_\(selectedYear.replacingOccurrences(of: " ", with: "_")).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: tempURL)
            print("✅ PDF saved to: \(tempURL.path)")
            
            // Present share sheet
            presentShareSheet(for: tempURL, fileType: "PDF")
            
        } catch {
            print("❌ Error saving PDF: \(error.localizedDescription)")
        }
    }
    
    /// Journey map section with actual map snapshot
    @ViewBuilder
    private func journeyMapWithSnapshot(derived: Derived, mapImage: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Journey Map")
                    .font(.headline)
                Spacer()
                Text("\(derived.eventsWithCoordinates.count) locations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Display the map snapshot
            Image(uiImage: mapImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 320)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Journey summary
            VStack(spacing: 12) {
                Divider()
                
                HStack(spacing: 16) {
                    if let firstEvent = derived.eventsWithCoordinates.first {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("Start")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(firstEvent.location.name == "Other" ? (firstEvent.city ?? "Other") : firstEvent.location.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text(firstEvent.date.formatted(.dateTime.month().year()))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let lastEvent = derived.eventsWithCoordinates.last {
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("End")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "flag.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            Text(lastEvent.location.name == "Other" ? (lastEvent.city ?? "Other") : lastEvent.location.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text(lastEvent.date.formatted(.dateTime.month().year()))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let duration = journeyDuration(from: derived.eventsWithCoordinates) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Journey Duration: \(duration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    /// Journey map section optimized for PDF/screenshot export
    /// Uses static map representation instead of interactive Map view
    @ViewBuilder
    private func journeyMapSectionForExport(derived: Derived) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Journey Map")
                    .font(.headline)
                Spacer()
                Text("\(derived.eventsWithCoordinates.count) locations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Visual route map with map-style overlay
            GeometryReader { geometry in
                ZStack {
                    // Map-style background with terrain feel
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.96, blue: 0.93),  // Light tan
                            Color(red: 0.92, green: 0.94, blue: 0.90),  // Light green-gray
                            Color(red: 0.90, green: 0.92, blue: 0.88)   // Slightly darker
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Fine grid overlay (map coordinates feel)
                    Path { path in
                        let gridSpacing: CGFloat = 30
                        // Vertical lines
                        for i in stride(from: 0, through: geometry.size.width, by: gridSpacing) {
                            path.move(to: CGPoint(x: i, y: 0))
                            path.addLine(to: CGPoint(x: i, y: geometry.size.height))
                        }
                        // Horizontal lines
                        for i in stride(from: 0, through: geometry.size.height, by: gridSpacing) {
                            path.move(to: CGPoint(x: 0, y: i))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: i))
                        }
                    }
                    .stroke(Color.gray.opacity(0.08), lineWidth: 0.5)
                    
                    // Random "terrain" features for map realism
                    ForEach(0..<8, id: \.self) { i in
                        Circle()
                            .fill(Color.green.opacity(0.03))
                            .frame(width: CGFloat.random(in: 60...120), height: CGFloat.random(in: 60...120))
                            .position(
                                x: CGFloat.random(in: 0...geometry.size.width),
                                y: CGFloat.random(in: 0...geometry.size.height)
                            )
                    }
                    
                    // Plot coordinates on the map
                    if !derived.polylineCoordinates.isEmpty {
                        // Calculate bounds
                        let lats = derived.polylineCoordinates.map { $0.latitude }
                        let lons = derived.polylineCoordinates.map { $0.longitude }
                        let minLat = lats.min() ?? 0
                        let maxLat = lats.max() ?? 0
                        let minLon = lons.min() ?? 0
                        let maxLon = lons.max() ?? 0
                        
                        let latRange = max(maxLat - minLat, 0.0001)
                        let lonRange = max(maxLon - minLon, 0.0001)
                        
                        // Add padding (15% on each side for better framing)
                        let padding: CGFloat = 0.15
                        
                        // Draw journey route path with glow effect
                        let routePath = Path { path in
                            for (index, coord) in derived.polylineCoordinates.enumerated() {
                                // Normalize coordinates to canvas
                                let x = ((coord.longitude - minLon) / lonRange) * geometry.size.width * (1 - padding * 2) + geometry.size.width * padding
                                let y = geometry.size.height - ((coord.latitude - minLat) / latRange) * geometry.size.height * (1 - padding * 2) - geometry.size.height * padding
                                
                                let point = CGPoint(x: x, y: y)
                                
                                if index == 0 {
                                    path.move(to: point)
                                } else {
                                    path.addLine(to: point)
                                }
                            }
                        }
                        
                        // Route glow (outer)
                        routePath
                            .stroke(Color.blue.opacity(0.2), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                        
                        // Main route line
                        routePath
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .cyan, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                            )
                        
                        // Draw location markers
                        ForEach(Array(derived.eventsWithCoordinates.enumerated()), id: \.element.id) { index, event in
                            let coord = derived.polylineCoordinates[index]
                            let x = ((coord.longitude - minLon) / lonRange) * geometry.size.width * (1 - padding * 2) + geometry.size.width * padding
                            let y = geometry.size.height - ((coord.latitude - minLat) / latRange) * geometry.size.height * (1 - padding * 2) - geometry.size.height * padding
                            
                            let isOtherEvent = event.location.name == "Other"
                            let isFirst = index == 0
                            let isLast = index == derived.eventsWithCoordinates.count - 1
                            let markerColor = isOtherEvent ? Color.blue : event.location.theme.mainColor
                            
                            // Glow effect for markers
                            Circle()
                                .fill(markerColor.opacity(0.3))
                                .frame(width: isFirst || isLast ? 24 : 14, height: isFirst || isLast ? 24 : 14)
                                .position(x: x, y: y)
                            
                            // Marker dot
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [markerColor.opacity(0.9), markerColor],
                                        center: .topLeading,
                                        startRadius: 2,
                                        endRadius: 10
                                    )
                                )
                                .frame(width: isFirst || isLast ? 18 : 10, height: isFirst || isLast ? 18 : 10)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2.5)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                                .position(x: x, y: y)
                            
                            // Start/End icons
                            if isFirst {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .position(x: x, y: y)
                            } else if isLast {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .position(x: x, y: y)
                            }
                        }
                    }
                    
                    // Map chrome - compass rose
                    VStack(spacing: 3) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                        Text("N")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black.opacity(0.7))
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(16)
                    
                    // Map info overlay
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Travel Route")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                            Text("\(derived.eventsWithCoordinates.count) waypoints")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
                    
                    // Scale bar (bottom left)
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 40, height: 3)
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 40, height: 3)
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 40, height: 3)
                    }
                    .overlay(
                        HStack(spacing: 0) {
                            Text("0")
                                .font(.system(size: 8))
                            Spacer()
                            Text("mi")
                                .font(.system(size: 8))
                        }
                        .padding(.horizontal, 2)
                        .frame(width: 120)
                        .offset(y: -8)
                    )
                    .frame(width: 120)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(16)
                }
            }
            .frame(height: 320)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            
            // Journey summary only
            VStack(spacing: 12) {
                Divider()
                
                HStack(spacing: 16) {
                    if let firstEvent = derived.eventsWithCoordinates.first {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("Start")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(firstEvent.location.name == "Other" ? (firstEvent.city ?? "Other") : firstEvent.location.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text(firstEvent.date.formatted(.dateTime.month().year()))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let lastEvent = derived.eventsWithCoordinates.last {
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("End")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "flag.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            Text(lastEvent.location.name == "Other" ? (lastEvent.city ?? "Other") : lastEvent.location.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text(lastEvent.date.formatted(.dateTime.month().year()))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let duration = journeyDuration(from: derived.eventsWithCoordinates) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Journey Duration: \(duration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private func shareScreenshot() {
        guard let derived = derivedByYear[selectedYear] else {
            print("⚠️ No derived data for screenshot")
            return
        }
        
        print("📸 Generating screenshot for \(selectedYear)...")
        
        // Render comprehensive infographic as high-resolution image
        let screenshotContent = VStack(spacing: 20) {
            // Header with branding
            VStack(spacing: 8) {
                Text("LocTrac Travel Infographic")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Image(systemName: selectedYear == "All Time" ? "calendar" : "calendar.badge.clock")
                        .foregroundColor(.blue)
                        .font(.system(size: 24))
                    Text(selectedYear)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                if let dateRange = derived.dateRange {
                    Text(dateRange)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            
            // All infographic sections
            overviewStatsSection(derived: derived)
            eventTypeSection(derived: derived)
            locationStatsSection(derived: derived)
            travelReachSection(derived: derived)
            
            // Conditional sections
            if derived.vacationStats.totalVacationDays > 0 {
                vacationSection(derived: derived)
            }
            
            if !derived.topActivities.isEmpty {
                activitiesSection(derived: derived)
            }
            
            if !derived.topPeople.isEmpty {
                peopleSection(derived: derived)
            }
            
            // Journey map - use export-friendly version
            if !derived.eventsWithCoordinates.isEmpty {
                journeyMapSectionForExport(derived: derived)
            }
            
            if derived.eventsWithCoordinates.count > 1 && derived.travelStats.totalMiles > 0 {
                environmentalImpactSection(derived: derived)
            }
            
            // Footer
            VStack(spacing: 4) {
                Divider()
                    .padding(.horizontal, 40)
                    .padding(.top, 12)
                
                Text("Generated by LocTrac")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(Date().formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .padding(28)
        .background(Color(.systemBackground))
        
        // Render at high resolution
        let renderer = ImageRenderer(content: screenshotContent)
        renderer.scale = 3.0 // Super high resolution for social media sharing
        
        guard let image = renderer.uiImage else {
            print("❌ Failed to render screenshot image")
            return
        }
        
        print("✅ Screenshot rendered: \(Int(image.size.width)) x \(Int(image.size.height)) pixels")
        
        // Present share sheet with descriptive text
        let shareText = "My \(selectedYear) travel statistics from LocTrac"
        presentShareSheet(for: [shareText, image], fileType: "Image")
    }
    
    /// Unified share sheet presentation for both PDF and images
    private func presentShareSheet(for items: Any, fileType: String) {
        let activityItems: [Any]
        if let url = items as? URL {
            activityItems = [url]
        } else if let array = items as? [Any] {
            activityItems = array
        } else {
            activityItems = [items]
        }
        
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Exclude activities that don't make sense for this content
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .markupAsPDF
        ]
        
        // Set completion handler for debugging
        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if let error = error {
                print("❌ Share error: \(error.localizedDescription)")
            } else if completed {
                print("✅ \(fileType) shared successfully via \(activityType?.rawValue ?? "unknown")")
            } else {
                print("ℹ️ Share cancelled")
            }
        }
        
        // Find the top-most view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Could not find root view controller")
            return
        }
        
        var topController = rootViewController
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        
        // Configure for iPad popover presentation
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(
                x: topController.view.bounds.midX,
                y: topController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        print("✅ Presenting share sheet for \(fileType)...")
        topController.present(activityVC, animated: true)
    }
    
    /// Convert UIImage to PDF data
    private func createPDFFromImage(_ image: UIImage, pageSize: CGSize) -> Data? {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        
        let data = pdfRenderer.pdfData { context in
            context.beginPage()
            
            // Draw the image to fill the page
            image.draw(in: CGRect(origin: .zero, size: pageSize))
        }
        
        return data
    }
}


// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

// Flow Layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview
struct InfographicsView_Previews: PreviewProvider {
    static var previews: some View {
        InfographicsView()
            .environmentObject(DataStore())
    }
}
