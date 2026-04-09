//
//  TravelHistoryView.swift
//  LocTrac
//
//  Comprehensive view of all stays organized by country and city
//

import SwiftUI
import MapKit

struct TravelHistoryView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var locationFilter: LocationFilter = .locations
    @State private var sortOrder: SortOrder = .country
    @State private var selectedStay: Event?
    @State private var shareText: String = ""
    @State private var expandedSections: Set<String> = []  // Track expanded sections by ID
    
    enum LocationFilter: String, CaseIterable {
        case locations = "Locations"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .locations: return "map"
            case .other: return "mappin.and.ellipse"
            }
        }
    }
    
    enum SortOrder: String, CaseIterable {
        case country = "Country"
        case city = "City"
        case mostVisited = "Most"
        case recent = "Recent"
        
        var icon: String {
            switch self {
            case .country: return "globe"
            case .city: return "building.2"
            case .mostVisited: return "chart.bar.fill"
            case .recent: return "clock.fill"
            }
        }
    }
    
    // UTC calendar for consistent date handling
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    // Date formatter (internal so other views in this file can access it)
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        df.calendar = cal
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()
    
    // Filter events by location filter and search text
    private var filteredEvents: [Event] {
        var events = store.events
        
        // Apply location filter
        switch locationFilter {
        case .locations:
            // Show only user-added locations (exclude "Other")
            events = events.filter { $0.location.name != "Other" }
        case .other:
            // Show only "Other" location events
            events = events.filter { $0.location.name == "Other" }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            events = events.filter { event in
                event.city?.localizedCaseInsensitiveContains(searchText) ?? false ||
                (event.country ?? event.location.country)?.localizedCaseInsensitiveContains(searchText) ?? false ||
                event.location.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return events
    }
    
    // Group stays by location (for "Locations" filter)
    private var staysByLocation: [(location: Location, stays: [Event])] {
        let byLocation: [String: [Event]] = Dictionary(grouping: filteredEvents) { event in
            event.location.id
        }
        
        var result = byLocation.compactMap { (locationID: String, events: [Event]) -> (location: Location, stays: [Event])? in
            guard let location = events.first?.location else { return nil }
            return (location: location, stays: events.sorted { $0.date > $1.date })
        }
        
        // Sort based on sortOrder
        switch sortOrder {
        case .country:
            result.sort { ($0.location.country ?? "") < ($1.location.country ?? "") }
        case .city:
            result.sort { ($0.location.city ?? "") < ($1.location.city ?? "") }
        case .mostVisited:
            result.sort { $0.stays.count > $1.stays.count }
        case .recent:
            result.sort { ($0.stays.first?.date ?? Date.distantPast) > ($1.stays.first?.date ?? Date.distantPast) }
        }
        
        return result
    }
    
    // Group stays by country
    private var staysByCountry: [(country: String, cities: [(city: String, stays: [Event])])] {
        // Group by country first - prioritize event.country over location.country
        let byCountry = Dictionary(grouping: filteredEvents) { event -> String in
            event.country ?? event.location.country ?? "Unknown"
        }
        
        return byCountry.map { countryName, countryEvents in
            // Within each country, group by city
            let byCity = Dictionary(grouping: countryEvents) { event -> String in
                event.city ?? "Unknown"
            }
            
            let cities = byCity.map { cityName, cityEvents in
                (city: cityName, stays: cityEvents.sorted { $0.date > $1.date })
            }.sorted { sortOrder == .mostVisited ? $0.stays.count > $1.stays.count : $0.city < $1.city }
            
            return (country: countryName, cities: cities)
        }.sorted { $0.country < $1.country }
    }
    
    // Group stays by city (all countries)
    private var staysByCity: [(city: String, stays: [Event])] {
        let byCity = Dictionary(grouping: filteredEvents) { event -> String in
            event.city ?? "Unknown"
        }
        
        var result = byCity.map { (city: $0.key, stays: $0.value.sorted { $0.date > $1.date }) }
        
        switch sortOrder {
        case .mostVisited:
            result.sort { $0.stays.count > $1.stays.count }
        case .recent:
            result.sort { ($0.stays.first?.date ?? Date.distantPast) > ($1.stays.first?.date ?? Date.distantPast) }
        default:
            result.sort { $0.city < $1.city }
        }
        
        return result
    }
    
    // Statistics
    private var totalStays: Int {
        filteredEvents.count
    }
    
    private var totalCountries: Int {
        Set(filteredEvents.compactMap { $0.country ?? $0.location.country }).count
    }
    
    private var totalCities: Int {
        Set(filteredEvents.compactMap { $0.city }).count
    }
    
    private var totalLocations: Int {
        Set(filteredEvents.map { $0.location.id }).count
    }
    
    private var totalActivities: Int {
        Set(filteredEvents.flatMap { $0.activityIDs }).count
    }
    
    private var totalPeople: Int {
        Set(filteredEvents.flatMap { $0.people.map { $0.id } }).count
    }
    
    private var totalAffirmations: Int {
        Set(filteredEvents.flatMap { $0.affirmationIDs }).count
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Statistics Section
                Section {
                    statsSection
                }
                
                // Location Filter (Other vs All)
                Section {
                    locationFilterSection
                }
                
                // Sort Options
                Section {
                    sortSection
                }
                
                // Content based on sort order
                if filteredEvents.isEmpty {
                    Section {
                        emptyState
                    }
                } else {
                    contentSections
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search cities, countries, locations...")
            .navigationTitle("Travel History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: generateShareText()) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(item: $selectedStay) { stay in
                StayDetailSheet(event: stay)
                    .environmentObject(store)
            }
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                StatBox(title: "Stays", value: "\(totalStays)", color: .blue)
                StatBox(title: "Cities", value: "\(totalCities)", color: .green)
                StatBox(title: "Countries", value: "\(totalCountries)", color: .orange)
                StatBox(title: "Locations", value: "\(totalLocations)", color: .purple)
            }
            
            HStack(spacing: 12) {
                StatBox(title: "Activities", value: "\(totalActivities)", color: .orange)
                StatBox(title: "People", value: "\(totalPeople)", color: .purple)
                StatBox(title: "Affirmations", value: "\(totalAffirmations)", color: .green)
            }
        }
    }
    
    // MARK: - Location Filter Section
    private var locationFilterSection: some View {
        Picker("Filter", selection: $locationFilter) {
            ForEach(LocationFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: locationFilter) { oldValue, newValue in
            // Force refresh when filter changes
            print("Filter changed from \(oldValue.rawValue) to \(newValue.rawValue)")
        }
    }
    
    // MARK: - Sort Section
    private var sortSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: order.icon)
                                .font(.system(size: 16))
                            Text(order.rawValue)
                                .font(.caption2)
                        }
                        .foregroundColor(sortOrder == order ? .white : .primary)
                        .frame(width: 70, height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(sortOrder == order ? Color.blue : Color(.tertiarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Content Sections
    @ViewBuilder
    private var contentSections: some View {
        // For "Locations" filter, group by location
        if locationFilter == .locations {
            locationGroupedView
        } else {
            // For "Other" filter, group by country/city as before
            switch sortOrder {
            case .country:
                countryGroupedView
            case .city, .mostVisited, .recent:
                cityGroupedView
            }
        }
    }
    
    // Location-grouped view (for user-added locations)
    private var locationGroupedView: some View {
        ForEach(staysByLocation, id: \.location.id) { locationGroup in
            let sectionID: String = locationGroup.location.id
            let isExpanded = expandedSections.contains(sectionID)
            
            Section {
                // Header row - always visible, tap to expand/collapse
                Button {
                    withAnimation {
                        if isExpanded {
                            expandedSections.remove(sectionID)
                        } else {
                            expandedSections.insert(sectionID)
                        }
                    }
                } label: {
                    LocationHeaderRow(
                        location: locationGroup.location,
                        stayCount: locationGroup.stays.count,
                        activityCount: countActivities(in: locationGroup.stays),
                        peopleCount: countPeople(in: locationGroup.stays),
                        affirmationCount: countAffirmations(in: locationGroup.stays),
                        mostRecentDate: locationGroup.stays.first?.date,
                        isExpanded: isExpanded
                    )
                }
                .buttonStyle(.plain)
                
                // Individual stays - only shown when expanded
                if isExpanded {
                    ForEach(locationGroup.stays) { stay in
                        StayRow(
                            event: stay,
                            activityCount: stay.activityIDs.count,
                            peopleCount: stay.people.count,
                            affirmationCount: stay.affirmationIDs.count
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedStay = stay
                        }
                    }
                }
            }
        }
    }
    
    // Country-grouped view (optimized) - for "Other" filter
    private var countryGroupedView: some View {
        ForEach(Array(staysByCountry.enumerated()), id: \.offset) { index, countryGroup in
            Section {
                ForEach(Array(countryGroup.cities.enumerated()), id: \.offset) { cityIndex, cityGroup in
                    let sectionID = "\(countryGroup.country)-\(cityGroup.city)"
                    let isExpanded = expandedSections.contains(sectionID)
                    
                    // City header - collapsible
                    Button {
                        withAnimation {
                            if isExpanded {
                                expandedSections.remove(sectionID)
                            } else {
                                expandedSections.insert(sectionID)
                            }
                        }
                    } label: {
                        CityRow(
                            city: cityGroup.city,
                            country: countryGroup.country,
                            stayCount: cityGroup.stays.count,
                            activityCount: countActivities(in: cityGroup.stays),
                            peopleCount: countPeople(in: cityGroup.stays),
                            affirmationCount: countAffirmations(in: cityGroup.stays),
                            mostRecentDate: cityGroup.stays.first?.date,
                            location: cityGroup.stays.first?.location,
                            isExpanded: isExpanded
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Show individual stays when expanded
                    if isExpanded {
                        ForEach(cityGroup.stays) { stay in
                            StayRow(
                                event: stay,
                                activityCount: stay.activityIDs.count,
                                peopleCount: stay.people.count,
                                affirmationCount: stay.affirmationIDs.count
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedStay = stay
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Image(systemName: "globe")
                    Text(countryGroup.country)
                }
            }
        }
    }
    
    // City-grouped view (optimized) - for "Other" filter
    private var cityGroupedView: some View {
        ForEach(Array(staysByCity.enumerated()), id: \.offset) { index, cityGroup in
            let sectionID = cityGroup.city
            let isExpanded = expandedSections.contains(sectionID)
            
            Section {
                // City header - collapsible
                Button {
                    withAnimation {
                        if isExpanded {
                            expandedSections.remove(sectionID)
                        } else {
                            expandedSections.insert(sectionID)
                        }
                    }
                } label: {
                    CityRow(
                        city: cityGroup.city,
                        country: cityGroup.stays.first?.country ?? cityGroup.stays.first?.location.country ?? "Unknown",
                        stayCount: cityGroup.stays.count,
                        activityCount: countActivities(in: cityGroup.stays),
                        peopleCount: countPeople(in: cityGroup.stays),
                        affirmationCount: countAffirmations(in: cityGroup.stays),
                        mostRecentDate: cityGroup.stays.first?.date,
                        location: cityGroup.stays.first?.location,
                        isExpanded: isExpanded
                    )
                }
                .buttonStyle(.plain)
                
                // Show individual stays when expanded
                if isExpanded {
                    ForEach(cityGroup.stays) { stay in
                        StayRow(
                            event: stay,
                            activityCount: stay.activityIDs.count,
                            peopleCount: stay.people.count,
                            affirmationCount: stay.affirmationIDs.count
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedStay = stay
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func countActivities(in events: [Event]) -> Int {
        Set(events.flatMap { $0.activityIDs }).count
    }
    
    private func countPeople(in events: [Event]) -> Int {
        Set(events.flatMap { $0.people.map { $0.id } }).count
    }
    
    private func countAffirmations(in events: [Event]) -> Int {
        Set(events.flatMap { $0.affirmationIDs }).count
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("No Travel History")
                .font(.title2)
                .fontWeight(.semibold)
            if !searchText.isEmpty {
                Text("No stays match '\(searchText)'")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Your stays will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Share Function
    private func generateShareText() -> String {
        // Generate a text summary respecting current filter and search
        var text = "📍 Travel History"
        
        // Add filter context
        switch locationFilter {
        case .locations:
            text += " (Locations)"
        case .other:
            text += " (Other)"
        }
        
        if !searchText.isEmpty {
            text += " - Search: \"\(searchText)\""
        }
        
        text += "\n\n"
        text += "📊 Statistics:\n"
        text += "• Total Stays: \(totalStays)\n"
        text += "• Cities Visited: \(totalCities)\n"
        text += "• Countries Visited: \(totalCountries)\n"
        text += "• Locations: \(totalLocations)\n"
        text += "• Activities: \(totalActivities)\n"
        text += "• People: \(totalPeople)\n"
        text += "• Affirmations: \(totalAffirmations)\n\n"
        
        // Different format based on filter
        if locationFilter == .locations {
            // Group by location for Locations filter
            text += "📍 By Location:\n"
            for locationGroup in staysByLocation {
                let loc = locationGroup.location
                let stays = locationGroup.stays
                let activities = countActivities(in: stays)
                let people = countPeople(in: stays)
                let affirmations = countAffirmations(in: stays)
                
                text += "\n\(loc.name)\n"
                if let city = loc.city, let country = loc.country {
                    text += "  \(city), \(country)\n"
                } else if let city = loc.city {
                    text += "  \(city)\n"
                } else if let country = loc.country {
                    text += "  \(country)\n"
                }
                text += "  • \(stays.count) stay(s)"
                if activities > 0 { text += " • 🏃 \(activities)" }
                if people > 0 { text += " • 👥 \(people)" }
                if affirmations > 0 { text += " • 💬 \(affirmations)" }
                text += "\n"
            }
        } else {
            // Group by country/city for Other filter
            text += "🌍 By Country:\n"
            for countryGroup in staysByCountry {
                text += "\n\(countryGroup.country)\n"
                for cityGroup in countryGroup.cities {
                    let activities = countActivities(in: cityGroup.stays)
                    let people = countPeople(in: cityGroup.stays)
                    let affirmations = countAffirmations(in: cityGroup.stays)
                    
                    text += "  • \(cityGroup.city): \(cityGroup.stays.count) stay(s)"
                    if activities > 0 { text += " • 🏃 \(activities)" }
                    if people > 0 { text += " • 👥 \(people)" }
                    if affirmations > 0 { text += " • 💬 \(affirmations)" }
                    text += "\n"
                }
            }
        }
        
        text += "\n\nGenerated by LocTrac"
        return text
    }
}

// MARK: - Location Header Row (for Locations filter)
struct LocationHeaderRow: View {
    let location: Location
    let stayCount: Int
    let activityCount: Int
    let peopleCount: Int
    let affirmationCount: Int
    let mostRecentDate: Date?
    let isExpanded: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Location color indicator
            Circle()
                .fill(location.theme.mainColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    if let city = location.city {
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let country = location.country {
                        if location.city != nil {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(country)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Counts row
                HStack(spacing: 8) {
                    if activityCount > 0 {
                        Label("\(activityCount)", systemImage: "figure.walk")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    if peopleCount > 0 {
                        Label("\(peopleCount)", systemImage: "person.2")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                    if affirmationCount > 0 {
                        Label("\(affirmationCount)", systemImage: "quote.bubble")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(stayCount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let date = mostRecentDate {
                    Text(TravelHistoryView.dateFormatter.string(from: date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - City Row
struct CityRow: View {
    let city: String
    let country: String
    let stayCount: Int
    let activityCount: Int
    let peopleCount: Int
    let affirmationCount: Int
    let mostRecentDate: Date?
    let location: Location?
    let isExpanded: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Location color indicator
            if let location = location {
                Circle()
                    .fill(location.theme.mainColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "building.2")
                            .foregroundColor(.white)
                    )
            } else {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "building.2")
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(city)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    if let location = location {
                        Text(location.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(country)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Counts row
                HStack(spacing: 8) {
                    if activityCount > 0 {
                        Label("\(activityCount)", systemImage: "figure.walk")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    if peopleCount > 0 {
                        Label("\(peopleCount)", systemImage: "person.2")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                    if affirmationCount > 0 {
                        Label("\(affirmationCount)", systemImage: "quote.bubble")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(stayCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let date = mostRecentDate {
                    Text(TravelHistoryView.dateFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Stay Row
struct StayRow: View {
    let event: Event
    let activityCount: Int
    let peopleCount: Int
    let affirmationCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Calendar icon with date
            VStack(spacing: 2) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(TravelHistoryView.dateFormatter.string(from: event.date))
                    .font(.subheadline)
                
                HStack(spacing: 4) {
                    if !event.eventType.isEmpty {
                        Text(event.eventType.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Counts inline
                    if activityCount > 0 || peopleCount > 0 || affirmationCount > 0 {
                        if !event.eventType.isEmpty {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            if activityCount > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "figure.walk")
                                        .font(.system(size: 10))
                                    Text("\(activityCount)")
                                        .font(.caption2)
                                }
                                .foregroundColor(.orange)
                            }
                            if peopleCount > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "person.2")
                                        .font(.system(size: 10))
                                    Text("\(peopleCount)")
                                        .font(.caption2)
                                }
                                .foregroundColor(.purple)
                            }
                            if affirmationCount > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "quote.bubble")
                                        .font(.system(size: 10))
                                    Text("\(affirmationCount)")
                                        .font(.caption2)
                                }
                                .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Location indicator
            Circle()
                .fill(event.location.theme.mainColor)
                .frame(width: 8, height: 8)
        }
        .padding(.leading, 20)
    }
}

// MARK: - Stay Detail Sheet
struct StayDetailSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let event: Event
    
    // Computed properties for related data
    private var activities: [Activity] {
        event.activityIDs.compactMap { id in
            store.activities.first(where: { $0.id == id })
        }
    }
    
    private var affirmations: [Affirmation] {
        event.affirmationIDs.compactMap { id in
            store.affirmations.first(where: { $0.id == id })
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Location") {
                    HStack {
                        Text("City")
                        Spacer()
                        Text(event.city ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Country")
                        Spacer()
                        Text(event.country ?? event.location.country ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Location")
                        Spacer()
                        HStack(spacing: 8) {
                            Circle()
                                .fill(event.location.theme.mainColor)
                                .frame(width: 12, height: 12)
                            Text(event.location.name)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Details") {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(TravelHistoryView.dateFormatter.string(from: event.date))
                            .foregroundColor(.secondary)
                    }
                    
                    if !event.eventType.isEmpty {
                        HStack {
                            Text("Event Type")
                            Spacer()
                            Text(event.eventType.capitalized)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if event.latitude != 0 || event.longitude != 0 {
                        HStack {
                            Text("Coordinates")
                            Spacer()
                            Text(String(format: "%.4f, %.4f", event.latitude, event.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Notes section
                if !event.note.isEmpty {
                    Section("Notes") {
                        Text(event.note)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                
                // Activities section
                if !activities.isEmpty {
                    Section {
                        ForEach(activities) { activity in
                            Label {
                                Text(activity.name)
                            } icon: {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(.orange)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "figure.walk")
                            Text("Activities (\(activities.count))")
                        }
                    }
                }
                
                // People section
                if !event.people.isEmpty {
                    Section {
                        ForEach(event.people) { person in
                            Label {
                                Text(person.displayName)
                            } icon: {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "person.2")
                            Text("People (\(event.people.count))")
                        }
                    }
                }
                
                // Affirmations section
                if !affirmations.isEmpty {
                    Section {
                        ForEach(affirmations) { affirmation in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "quote.bubble.fill")
                                        .foregroundColor(.green)
                                    Text(affirmation.category.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if affirmation.isFavorite {
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }
                                
                                Text(affirmation.text)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .padding(.leading, 24)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "quote.bubble")
                            Text("Affirmations (\(affirmations.count))")
                        }
                    }
                }
                
                // Map preview if coordinates available
                if event.latitude != 0 && event.longitude != 0 {
                    Section("Map") {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude),
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        ))) {
                            Annotation("", coordinate: CLLocationCoordinate2D(
                                latitude: event.latitude,
                                longitude: event.longitude
                            )) {
                                Circle()
                                    .fill(event.location.theme.mainColor)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("Stay Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct TravelHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        TravelHistoryView()
            .environmentObject(DataStore(preview: true))
    }
}
