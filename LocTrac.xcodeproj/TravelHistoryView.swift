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
    @State private var sortOrder: SortOrder = .country
    @State private var selectedStay: Event?
    
    enum SortOrder: String, CaseIterable {
        case country = "Country"
        case city = "City"
        case mostVisited = "Most Visited"
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
    
    // Date formatter
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        df.calendar = cal
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()
    
    // Filter events by search text
    private var filteredEvents: [Event] {
        var events = store.events
        
        if !searchText.isEmpty {
            events = events.filter { event in
                event.city?.localizedCaseInsensitiveContains(searchText) ?? false ||
                event.location.country?.localizedCaseInsensitiveContains(searchText) ?? false ||
                event.location.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return events
    }
    
    // Group stays by country
    private var staysByCountry: [(country: String, cities: [(city: String, stays: [Event])])] {
        // Group by country first
        let byCountry = Dictionary(grouping: filteredEvents) { event -> String in
            event.location.country ?? "Unknown"
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
        Set(filteredEvents.compactMap { $0.location.country }).count
    }
    
    private var totalCities: Int {
        Set(filteredEvents.compactMap { $0.city }).count
    }
    
    private var totalLocations: Int {
        Set(filteredEvents.map { $0.location.id }).count
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Statistics Section
                Section {
                    statsSection
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
                    Button {
                        shareHistory()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
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
        HStack(spacing: 12) {
            StatBox(title: "Stays", value: "\(totalStays)", color: .blue)
            StatBox(title: "Cities", value: "\(totalCities)", color: .green)
            StatBox(title: "Countries", value: "\(totalCountries)", color: .orange)
            StatBox(title: "Locations", value: "\(totalLocations)", color: .purple)
        }
    }
    
    // MARK: - Sort Section
    private var sortSection: some View {
        HStack(spacing: 12) {
            ForEach(SortOrder.allCases, id: \.self) { order in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        sortOrder = order
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: order.icon)
                            .font(.caption)
                        Text(order.rawValue)
                            .font(.subheadline)
                    }
                    .fontWeight(sortOrder == order ? .semibold : .regular)
                    .foregroundColor(sortOrder == order ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(sortOrder == order ? Color.blue : Color(.tertiarySystemBackground))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Content Sections
    @ViewBuilder
    private var contentSections: some View {
        switch sortOrder {
        case .country:
            countryGroupedView
        case .city:
            cityGroupedView
        case .mostVisited:
            cityGroupedView
        case .recent:
            cityGroupedView
        }
    }
    
    // Country-grouped view
    private var countryGroupedView: some View {
        ForEach(staysByCountry, id: \.country) { countryGroup in
            Section {
                ForEach(countryGroup.cities, id: \.city) { cityGroup in
                    CityRow(
                        city: cityGroup.city,
                        country: countryGroup.country,
                        stayCount: cityGroup.stays.count,
                        mostRecentDate: cityGroup.stays.first?.date,
                        location: cityGroup.stays.first?.location
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Show all stays for this city
                        selectedStay = cityGroup.stays.first
                    }
                    
                    // Show individual stays
                    ForEach(cityGroup.stays) { stay in
                        StayRow(event: stay)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedStay = stay
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
    
    // City-grouped view (flat)
    private var cityGroupedView: some View {
        ForEach(staysByCity, id: \.city) { cityGroup in
            Section {
                CityRow(
                    city: cityGroup.city,
                    country: cityGroup.stays.first?.location.country ?? "Unknown",
                    stayCount: cityGroup.stays.count,
                    mostRecentDate: cityGroup.stays.first?.date,
                    location: cityGroup.stays.first?.location
                )
                
                // Show individual stays
                ForEach(cityGroup.stays) { stay in
                    StayRow(event: stay)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedStay = stay
                        }
                }
            }
        }
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
    private func shareHistory() {
        // Generate a simple text summary
        var text = "Travel History\n\n"
        text += "📊 Statistics:\n"
        text += "• Total Stays: \(totalStays)\n"
        text += "• Cities Visited: \(totalCities)\n"
        text += "• Countries Visited: \(totalCountries)\n"
        text += "• Locations: \(totalLocations)\n\n"
        
        text += "🌍 By Country:\n"
        for countryGroup in staysByCountry {
            text += "\n\(countryGroup.country)\n"
            for cityGroup in countryGroup.cities {
                text += "  • \(cityGroup.city): \(cityGroup.stays.count) stay(s)\n"
            }
        }
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            activityVC.popoverPresentationController?.sourceView = window
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: window.bounds.midX,
                y: window.safeAreaInsets.top + 44,
                width: 1,
                height: 1
            )
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - City Row
struct CityRow: View {
    let city: String
    let country: String
    let stayCount: Int
    let mostRecentDate: Date?
    let location: Location?
    
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
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(stayCount) stay\(stayCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
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
                
                if let stayType = event.stayType, !stayType.isEmpty {
                    Text(stayType)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                        Text(event.location.country ?? "Unknown")
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
                    
                    if let stayType = event.stayType, !stayType.isEmpty {
                        HStack {
                            Text("Stay Type")
                            Spacer()
                            Text(stayType)
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
