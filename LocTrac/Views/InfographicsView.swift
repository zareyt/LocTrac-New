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
}

struct InfographicsView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedYear: String = "All Time"
    @State private var showShareSheet = false
    @State private var pdfData: Data?
    
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
        NavigationStack {
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
            .navigationTitle("Travel Infographic")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        generatePDF()
                    } label: {
                        Label("Export PDF", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let pdfData = pdfData {
                    ShareSheet(activityItems: [pdfData])
                }
            }
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
        
        // Overview stats
        let totalStays = filtered.count
        let uniqueLocationsCount = Set(filtered.map { $0.location.id }).count
        let totalDaysCount = filtered.count
        let uniqueActivitiesCount = Set(filtered.flatMap { $0.activityIDs }).count
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
            dateRange: dateRange
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
                    
                    Text("\(item.count) days")
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
                        
                        Text("\(item.count) days")
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
        
        let renderer = ImageRenderer(content: pdfContentView(derived: derived))
        renderer.scale = 2.0 // High resolution
        
        // 8.5 x 11 inches at 72 DPI
        let pageWidth: CGFloat = 8.5 * 72
        let pageHeight: CGFloat = 11 * 72
        renderer.proposedSize = ProposedViewSize(width: pageWidth, height: pageHeight)
        
        if let image = renderer.uiImage {
            if let pdfData = createPDFFromImage(image, pageSize: CGSize(width: pageWidth, height: pageHeight)) {
                self.pdfData = pdfData
                self.showShareSheet = true
            }
        }
    }
    
    @ViewBuilder
    private func pdfContentView(derived: Derived) -> some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text("LocTrac Travel Infographic")
                    .font(.system(size: 24, weight: .bold))
                Text(selectedYear)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                if let dateRange = derived.dateRange {
                    Text(dateRange)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 20)
            
            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                PDFStatCard(title: "Total Stays", value: "\(derived.totalStays)", icon: "calendar", color: .blue)
                PDFStatCard(title: "Locations", value: "\(derived.uniqueLocationsCount)", icon: "mappin.circle.fill", color: .green)
                PDFStatCard(title: "Countries", value: "\(derived.countriesVisited.count)", icon: "globe", color: .orange)
                PDFStatCard(title: "Activities", value: "\(derived.uniqueActivitiesCount)", icon: "figure.run", color: .purple)
            }
            .padding(.horizontal, 20)
            
            // Event types
            let data = derived.eventTypeData
            if !data.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Event Types")
                        .font(.system(size: 16, weight: .semibold))
                    
                    ForEach(data.sorted(by: { $0.count > $1.count }).prefix(5), id: \.type) { item in
                        HStack {
                            Text(item.icon)
                            Text(item.type)
                                .font(.system(size: 14))
                            Spacer()
                            Text("\(item.count) (\(item.percentage)%)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
            
            // Top locations
            if !derived.topLocations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Locations")
                        .font(.system(size: 16, weight: .semibold))
                    
                    ForEach(derived.topLocations.prefix(8), id: \.name) { item in
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 6, height: 6)
                            Text(item.name)
                                .font(.system(size: 14))
                            Spacer()
                            Text("\(item.count)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
            
            // Environmental Impact
            if derived.eventsWithCoordinates.count > 1 && derived.travelStats.totalMiles > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                        Text("Environmental Impact")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(derived.travelStats.totalMiles)) miles")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Total traveled")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(derived.travelStats.totalCO2)) lbs CO₂")
                                .font(.system(size: 14, weight: .semibold))
                            Text("\(Int(derived.travelStats.treesNeeded)) trees to offset")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
            
            // Footer
            Text("Generated by LocTrac • \(Date().formatted(date: .abbreviated, time: .omitted))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
            
            Spacer()
        }
        .frame(width: 8.5 * 72, height: 11 * 72)
        .background(Color.white)
    }
    
    private func createPDFFromImage(_ image: UIImage, pageSize: CGSize) -> Data? {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        
        return pdfRenderer.pdfData { context in
            context.beginPage()
            image.draw(in: CGRect(origin: .zero, size: pageSize))
        }
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

struct PDFStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
            
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
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
