import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: DataStore
    
    // Callbacks provided by StartTabView
    let onAddEvent: () -> Void
    let onShowOtherCities: () -> Void
    let onOpenCalendar: () -> Void
    let onOpenLocationsManagement: () -> Void  // CHANGED: From onOpenLocations to manage locations
    let onOpenInfographics: () -> Void
    let onSwitchToMapTab: () -> Void
    
    // NEW: Expandable sections state
    @State private var showAllAffirmations = false
    @State private var showAllPeople = false
    @State private var showAllActivities = false
    @State private var showAllVacationPlaces = false
    
    // MARK: - Date helpers
    private var now: Date { Date() }
    private var startOfToday: Date { Calendar.current.startOfDay(for: now) }
    private var twelveMonthsAgo: Date {
        Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
    }
    
    // MARK: - Derived data (Rolling 12 months)
    private var rolling12MonthEvents: [Event] {
        store.events.filter { $0.date >= twelveMonthsAgo && $0.date <= now }
    }
    
    // Top Locations (Rolling 12 months, INCLUDING "Other") - Count unique DAYS
    private var topLocations12M: [(location: Location, days: Int)] {
        // Don't filter out "Other" - include all locations
        let filteredEvents = rolling12MonthEvents
        
        // Group by location
        let byLocation = Dictionary(grouping: filteredEvents, by: { $0.location.id })
        
        // Count unique days for each location
        let counts: [(String, Int)] = byLocation.map { locationID, events in
            // Get unique days (strip time from dates)
            let uniqueDays = Set(events.map { event in
                Calendar.current.startOfDay(for: event.date)
            })
            return (locationID, uniqueDays.count)
        }
        
        let pairs: [(Location, Int)] = counts.compactMap { id, dayCount in
            guard let loc = store.locations.first(where: { $0.id == id }) else { return nil }
            return (loc, dayCount)
        }
        return Array(pairs.sorted { $0.1 > $1.1 }.prefix(5))
    }
    
    // Top Vacation Places (Rolling 12 months, only "Other" location cities) - Return all for expandable UI
    private var topVacationPlaces12M: [(city: String, count: Int)] {
        let otherEvents = rolling12MonthEvents.filter { $0.location.name == "Other" }
        let cityCounts = Dictionary(grouping: otherEvents, by: { $0.city ?? "Unknown" })
            .mapValues { $0.count }
        // Return all, sorted - UI will show top 3 with expand option
        return cityCounts.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }
    
    // Top People (Rolling 12 months) - Return all for expandable UI
    private var topPeople12M: [(person: Person, count: Int)] {
        // Flatten all people from all events
        let allPeople = rolling12MonthEvents.flatMap { $0.people }
        guard !allPeople.isEmpty else {
            return []
        }
        
        // Group by displayName (not by ID, since same person can have multiple IDs)
        let grouped = Dictionary(grouping: allPeople) { $0.displayName }
        
        // Map to person/count pairs
        let pairs: [(person: Person, count: Int)] = grouped.map { (name, people) in
            // Use the first person object we find with this name
            let person = people.first!
            return (person: person, count: people.count)
        }
        
        // Return all, sorted by count - UI will show top 3 with expand option
        return pairs.sorted { $0.count > $1.count }
    }
    
    // Top Affirmations (Rolling 12 months)
    private var topAffirmations12M: [(affirmation: Affirmation, count: Int)] {
        var affirmationCounts: [String: Int] = [:]
        
        for event in rolling12MonthEvents {
            for affirmationID in event.affirmationIDs {
                affirmationCounts[affirmationID, default: 0] += 1
            }
        }
        
        let pairs: [(Affirmation, Int)] = affirmationCounts.compactMap { id, count in
            guard let affirmation = store.affirmations.first(where: { $0.id == id }) else { return nil }
            return (affirmation, count)
        }
        return Array(pairs.sorted { $0.1 > $1.1 })  // Return all, not just top 5
    }
    
    // Top Activities (Rolling 12 months)
    private var topActivities12M: [(activity: Activity, count: Int)] {
        var activityCounts: [String: Int] = [:]
        
        for event in rolling12MonthEvents {
            for activityID in event.activityIDs {
                activityCounts[activityID, default: 0] += 1
            }
        }
        
        let pairs: [(Activity, Int)] = activityCounts.compactMap { id, count in
            guard let activity = store.activities.first(where: { $0.id == id }) else { return nil }
            return (activity, count)
        }
        return Array(pairs.sorted { $0.1 > $1.1 })  // Return all
    }
    
    // Random Daily Affirmation
    private var randomAffirmation: Affirmation? {
        // Return a truly random affirmation each time
        guard !store.affirmations.isEmpty else { return nil }
        return store.affirmations.randomElement()
    }
    
    // Environment Impact Statistics (Rolling 12 months)
    private var totalCO2_12M: Double {
        // Get event IDs from rolling 12 months
        let eventIDs = Set(rolling12MonthEvents.map { $0.id })
        
        // Find trips where the destination event is in our 12-month window
        let relevantTrips = store.trips.filter { trip in
            eventIDs.contains(trip.toEventID)  // Both are Strings now!
        }
        
        return relevantTrips.reduce(0) { $0 + $1.co2Emissions }
    }
    
    private var totalMiles_12M: Double {
        // Get event IDs from rolling 12 months
        let eventIDs = Set(rolling12MonthEvents.map { $0.id })
        
        // Find trips where the destination event is in our 12-month window
        let relevantTrips = store.trips.filter { trip in
            eventIDs.contains(trip.toEventID)  // Both are Strings now!
        }
        
        return relevantTrips.reduce(0) { $0 + $1.distance }
    }
    
    private var countriesVisited_12M: Int {
        Set(rolling12MonthEvents.compactMap { $0.country ?? $0.location.country }).count
    }
    
    private var citiesVisited_12M: Int {
        Set(rolling12MonthEvents.compactMap { $0.city }).count
    }
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                quickActions
                dailyAffirmationSection
                environmentImpactSection
                topLocationsSection
                vacationPlacesSection
                topAffirmationsSection  // Moved up, before people
                topPeopleSection
                topActivitiesSection  // NEW: Added activities section
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    NotificationSettingsView()
                        .environmentObject(store)
                } label: {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Welcome back")
                .font(.title2).bold()
            Text(now.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var quickActions: some View {
        Button {
            onAddEvent()
        } label: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                Text("Add Stay")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    
    // Daily Affirmation Section
    private var dailyAffirmationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Daily Affirmation")
                    .font(.headline)
            }
            
            if let affirmation = randomAffirmation {
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
                        .italic()
                        .foregroundColor(.primary)
                        .padding(.leading, 8)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
            } else {
                emptyCard(text: "Add affirmations to see daily inspiration.")
            }
        }
    }
    
    // Environment Impact Section
    private var environmentImpactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                Text("Environment Impact (Last 12 Months)")
                    .font(.headline)
            }
            
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    impactBox(
                        icon: "airplane",
                        value: String(format: "%.0f", totalMiles_12M),
                        label: "Miles",
                        color: .blue
                    )
                    impactBox(
                        icon: "cloud.fill",
                        value: String(format: "%.0f", totalCO2_12M),
                        label: "lbs CO₂",
                        color: .orange
                    )
                }
                
                HStack(spacing: 12) {
                    impactBox(
                        icon: "globe",
                        value: "\(countriesVisited_12M)",
                        label: "Countries",
                        color: .purple
                    )
                    impactBox(
                        icon: "building.2",
                        value: "\(citiesVisited_12M)",
                        label: "Cities",
                        color: .indigo
                    )
                }
            }
        }
    }
    
    // Locations Section (Rolling 12 months)
    private var topLocationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Locations (Last 12 Months)")
                    .font(.headline)
                Spacer()
                Button {
                    onOpenLocationsManagement()
                } label: {
                    Label("Manage", systemImage: "chevron.right.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
            }
            
            if topLocations12M.isEmpty {
                emptyCard(text: "No locations visited in the last 12 months.")
            } else {
                VStack(spacing: 8) {
                    ForEach(topLocations12M.indices, id: \.self) { idx in
                        let item = topLocations12M[idx]
                        HStack {
                            Circle()
                                .fill(item.location.effectiveColor)
                                .frame(width: 12, height: 12)
                            Text(item.location.name)
                            Spacer()
                            Text("\(item.days) day\(item.days == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        if idx != topLocations12M.indices.last {
                            Divider()
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
        }
    }
    
    // Vacation Places Section (Top "Other" cities, Rolling 12 months) - Expandable
    private var vacationPlacesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Top Vacation Places (Last 12 Months)")
                    .font(.headline)
                Spacer()
                if topVacationPlaces12M.count > 3 {
                    Button {
                        withAnimation {
                            showAllVacationPlaces.toggle()
                        }
                    } label: {
                        Label(showAllVacationPlaces ? "Show Less" : "Show All", systemImage: showAllVacationPlaces ? "chevron.up.circle" : "chevron.down.circle")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if topVacationPlaces12M.isEmpty {
                emptyCard(text: "No vacation places visited in the last 12 months.")
            } else {
                let displayedPlaces = showAllVacationPlaces ? topVacationPlaces12M : Array(topVacationPlaces12M.prefix(3))
                
                VStack(spacing: 8) {
                    ForEach(displayedPlaces.indices, id: \.self) { idx in
                        let item = displayedPlaces[idx]
                        HStack {
                            Image(systemName: "airplane.departure")
                                .foregroundColor(.blue)
                            Text(item.city)
                            Spacer()
                            Text("\(item.count) stay\(item.count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        if idx != displayedPlaces.indices.last {
                            Divider()
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
        }
    }
    
    // Top People Section (Rolling 12 months) - Expandable, show top 3
    private var topPeopleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                Text("People You've Spent Time With (Last 12 Months)")
                    .font(.headline)
                Spacer()
                if topPeople12M.count > 3 {
                    Button {
                        withAnimation {
                            showAllPeople.toggle()
                        }
                    } label: {
                        Label(showAllPeople ? "Show Less" : "Show All", systemImage: showAllPeople ? "chevron.up.circle" : "chevron.down.circle")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if topPeople12M.isEmpty {
                emptyCard(text: "No people recorded in the last 12 months.")
            } else {
                let displayedPeople = showAllPeople ? topPeople12M : Array(topPeople12M.prefix(3))
                
                VStack(spacing: 8) {
                    ForEach(displayedPeople.indices, id: \.self) { idx in
                        let item = displayedPeople[idx]
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.purple)
                            Text(item.person.displayName)
                            Spacer()
                            Text("\(item.count) visit\(item.count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        if idx != displayedPeople.indices.last {
                            Divider()
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
        }
    }
    
    // Top Affirmations Section (Rolling 12 months) - Expandable, show top 3
    private var topAffirmationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "quote.bubble.fill")
                    .foregroundColor(.green)
                Text("Top Affirmations (Last 12 Months)")
                    .font(.headline)
                Spacer()
                if topAffirmations12M.count > 3 {
                    Button {
                        withAnimation {
                            showAllAffirmations.toggle()
                        }
                    } label: {
                        Label(showAllAffirmations ? "Show Less" : "Show All", systemImage: showAllAffirmations ? "chevron.up.circle" : "chevron.down.circle")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if topAffirmations12M.isEmpty {
                emptyCard(text: "No affirmations used in the last 12 months.")
            } else {
                let displayedAffirmations = showAllAffirmations ? topAffirmations12M : Array(topAffirmations12M.prefix(3))
                
                VStack(spacing: 12) {
                    ForEach(displayedAffirmations.indices, id: \.self) { idx in
                        let item = displayedAffirmations[idx]
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "quote.bubble")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(item.affirmation.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(item.count)×")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if item.affirmation.isFavorite {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                }
                            }
                            
                            Text(item.affirmation.text)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 6)
                        if idx != displayedAffirmations.indices.last {
                            Divider()
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
        }
    }
    
    // Top Activities Section (Rolling 12 months) - Expandable, show top 3
    private var topActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundColor(.orange)
                Text("Top Activities (Last 12 Months)")
                    .font(.headline)
                Spacer()
                if topActivities12M.count > 3 {
                    Button {
                        withAnimation {
                            showAllActivities.toggle()
                        }
                    } label: {
                        Label(showAllActivities ? "Show Less" : "Show All", systemImage: showAllActivities ? "chevron.up.circle" : "chevron.down.circle")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if topActivities12M.isEmpty {
                emptyCard(text: "No activities recorded in the last 12 months.")
            } else {
                let displayedActivities = showAllActivities ? topActivities12M : Array(topActivities12M.prefix(3))
                
                VStack(spacing: 8) {
                    ForEach(displayedActivities.indices, id: \.self) { idx in
                        let item = displayedActivities[idx]
                        HStack {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.orange)
                            Text(item.activity.name)
                            Spacer()
                            Text("\(item.count) time\(item.count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        if idx != displayedActivities.indices.last {
                            Divider()
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
        }
    }
    
    // MARK: - Helpers
    
    private func impactBox(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
    
    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}
