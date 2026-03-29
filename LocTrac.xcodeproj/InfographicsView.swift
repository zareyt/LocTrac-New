//
//  InfographicsView.swift
//  LocTrac
//
//  Travel Statistics & Infographics with PDF Export
//

import SwiftUI
import Charts

struct InfographicsView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedYear: String = "All Time"
    @State private var showShareSheet = false
    @State private var pdfData: Data?
    
    private var availableYears: [String] {
        let years = Set(store.events.map { Calendar.current.component(.year, from: $0.date) })
        return ["All Time"] + years.sorted(by: >).map { String($0) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with year selector
                    headerSection
                    
                    // Overview stats cards
                    overviewStatsSection
                    
                    // Event type breakdown chart
                    eventTypeSection
                    
                    // Location statistics
                    locationStatsSection
                    
                    // Travel reach (countries & states)
                    travelReachSection
                    
                    // Activities breakdown
                    activitiesSection
                    
                    // People connections
                    peopleSection
                    
                    // Time analysis
                    timeAnalysisSection
                }
                .padding()
            }
            .navigationTitle("Travel Infographic")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(availableYears, id: \.self) { year in
                            Button(year) {
                                selectedYear = year
                            }
                        }
                        
                        Divider()
                        
                        Button {
                            generatePDF()
                        } label: {
                            Label("Export as PDF", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let pdfData = pdfData {
                    ShareSheet(activityItems: [pdfData])
                }
            }
        }
    }
}

// MARK: - Header Section
extension InfographicsView {
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Your Travel Journey")
                .font(.title)
                .fontWeight(.bold)
            
            Text(selectedYear)
                .font(.title2)
                .foregroundColor(.blue)
            
            if let dateRange = computedDateRange {
                Text(dateRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    private var computedDateRange: String? {
        guard !filteredEvents.isEmpty else { return nil }
        let dates = filteredEvents.map { $0.date }
        guard let earliest = dates.min(), let latest = dates.max() else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        return "\(formatter.string(from: earliest)) - \(formatter.string(from: latest))"
    }
}

// MARK: - Overview Stats Section
extension InfographicsView {
    private var overviewStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Total Stays",
                    value: "\(filteredEvents.count)",
                    icon: "calendar",
                    color: .blue
                )
                
                StatCard(
                    title: "Locations",
                    value: "\(uniqueLocationsCount)",
                    icon: "mappin.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Total Days",
                    value: "\(totalDaysCount)",
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Activities",
                    value: "\(uniqueActivitiesCount)",
                    icon: "figure.run",
                    color: .purple
                )
            }
        }
    }
}

// MARK: - Event Type Section
extension InfographicsView {
    private var eventTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Types")
                .font(.headline)
            
            if !eventTypeData.isEmpty {
                Chart(eventTypeData, id: \.type) { item in
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
                
                // Stats list
                ForEach(eventTypeData.sorted(by: { $0.count > $1.count }), id: \.type) { item in
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
    
    private var eventTypeData: [(type: String, icon: String, count: Int, percentage: Int)] {
        let events = filteredEvents
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
}

// MARK: - Location Stats Section
extension InfographicsView {
    private var locationStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Locations")
                .font(.headline)
            
            ForEach(topLocations.prefix(10), id: \.name) { item in
                HStack {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8, height: 8)
                    
                    Text(item.name)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(item.count) visits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Bar indicator
                    Rectangle()
                        .fill(item.color.opacity(0.3))
                        .frame(width: CGFloat(item.count) / CGFloat(maxLocationCount) * 80, height: 20)
                        .cornerRadius(4)
                }
            }
            
            if topLocations.isEmpty {
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
    
    private var topLocations: [(name: String, count: Int, color: Color)] {
        let events = filteredEvents
        let grouped = Dictionary(grouping: events) { $0.location.id }
        
        return grouped.map { (key, value) in
            let location = value.first!.location
            return (
                name: location.name,
                count: value.count,
                color: location.theme.mainColor
            )
        }.sorted { $0.count > $1.count }
    }
    
    private var maxLocationCount: Int {
        topLocations.first?.count ?? 1
    }
}

// MARK: - Travel Reach Section
extension InfographicsView {
    private var travelReachSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Travel Reach")
                .font(.headline)
            
            HStack(spacing: 12) {
                VStack {
                    Text("\(countriesVisited.count)")
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
                    Text("\(statesVisited.count)")
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
            
            // Countries list
            if !countriesVisited.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Countries Visited:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(Array(countriesVisited.sorted()), id: \.self) { country in
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
            
            // US/Outside US split
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("US Stays")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(usStaysCount)")
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
                    Text("\(internationalStaysCount)")
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
    
    private var countriesVisited: Set<String> {
        Set(filteredEvents.compactMap { $0.country }.filter { !$0.isEmpty })
    }
    
    private var statesVisited: Set<String> {
        Set(filteredEvents
            .filter { $0.country?.uppercased() == "UNITED STATES" || $0.country?.uppercased() == "US" || $0.country?.uppercased() == "USA" }
            .compactMap { event in
                // Try to extract state from city string if it contains state abbreviation
                if let city = event.city {
                    // Simple state extraction (this is basic - could be enhanced)
                    return city
                }
                return nil
            }
        )
    }
    
    private var usStaysCount: Int {
        filteredEvents.filter { event in
            let country = event.country?.uppercased() ?? ""
            return country == "UNITED STATES" || country == "US" || country == "USA"
        }.count
    }
    
    private var internationalStaysCount: Int {
        filteredEvents.filter { event in
            let country = event.country?.uppercased() ?? ""
            return !country.isEmpty && country != "UNITED STATES" && country != "US" && country != "USA"
        }.count
    }
}

// MARK: - Activities Section
extension InfographicsView {
    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Activities")
                .font(.headline)
            
            if !topActivities.isEmpty {
                Chart(topActivities.prefix(10), id: \.name) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Activity", item.name)
                    )
                    .foregroundStyle(.purple.gradient)
                    .cornerRadius(4)
                }
                .frame(height: CGFloat(min(topActivities.count, 10)) * 40)
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
    
    private var topActivities: [(name: String, count: Int)] {
        let events = filteredEvents
        let allActivityIDs = events.flatMap { $0.activityIDs }
        let grouped = Dictionary(grouping: allActivityIDs) { $0 }
        
        return grouped.compactMap { (id, ids) in
            guard let activity = store.activities.first(where: { $0.id == id }) else { return nil }
            return (name: activity.name, count: ids.count)
        }.sorted { $0.count > $1.count }
    }
}

// MARK: - People Section
extension InfographicsView {
    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Travel Companions")
                .font(.headline)
            
            if !topPeople.isEmpty {
                ForEach(topPeople.prefix(10), id: \.name) { item in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        
                        Text(item.name)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(item.count) trips")
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
    
    private var topPeople: [(name: String, count: Int)] {
        let events = filteredEvents
        let allPeople = events.flatMap { $0.people }
        let grouped = Dictionary(grouping: allPeople) { $0.displayName }
        
        return grouped.map { (name, people) in
            (name: name, count: people.count)
        }.sorted { $0.count > $1.count }
    }
}

// MARK: - Time Analysis Section
extension InfographicsView {
    private var timeAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Analysis")
                .font(.headline)
            
            HStack(spacing: 12) {
                VStack {
                    Text("\(averageTripsPerYear, specifier: "%.1f")")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Avg Trips/Year")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
                
                VStack {
                    Text(busiestMonth)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Busiest Month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
            }
            
            // Monthly distribution chart
            if !monthlyData.isEmpty {
                Chart(monthlyData, id: \.month) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private var averageTripsPerYear: Double {
        let years = Set(filteredEvents.map { Calendar.current.component(.year, from: $0.date) })
        guard !years.isEmpty else { return 0 }
        return Double(filteredEvents.count) / Double(years.count)
    }
    
    private var busiestMonth: String {
        guard let busiest = monthlyData.max(by: { $0.count < $1.count }) else {
            return "N/A"
        }
        return busiest.month
    }
    
    private var monthlyData: [(month: String, count: Int)] {
        let grouped = Dictionary(grouping: filteredEvents) { event in
            Calendar.current.component(.month, from: event.date)
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        
        return (1...12).map { month in
            let count = grouped[month]?.count ?? 0
            let monthName = formatter.monthSymbols[month - 1].prefix(3).capitalized
            return (month: String(monthName), count: count)
        }
    }
}

// MARK: - Computed Properties
extension InfographicsView {
    private var filteredEvents: [Event] {
        if selectedYear == "All Time" {
            return store.events
        } else if let year = Int(selectedYear) {
            return store.events.filter { Calendar.current.component(.year, from: $0.date) == year }
        }
        return store.events
    }
    
    private var uniqueLocationsCount: Int {
        Set(filteredEvents.map { $0.location.id }).count
    }
    
    private var totalDaysCount: Int {
        // Simple count of events (each event represents a stay)
        // Could be enhanced to calculate actual duration if events have end dates
        filteredEvents.count
    }
    
    private var uniqueActivitiesCount: Int {
        Set(filteredEvents.flatMap { $0.activityIDs }).count
    }
}

// MARK: - PDF Generation
extension InfographicsView {
    private func generatePDF() {
        let renderer = ImageRenderer(content: pdfContentView)
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
    
    private var pdfContentView: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text("LocTrac Travel Infographic")
                    .font(.system(size: 24, weight: .bold))
                Text(selectedYear)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                if let dateRange = computedDateRange {
                    Text(dateRange)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 20)
            
            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                PDFStatCard(title: "Total Stays", value: "\(filteredEvents.count)", icon: "calendar", color: .blue)
                PDFStatCard(title: "Locations", value: "\(uniqueLocationsCount)", icon: "mappin.circle.fill", color: .green)
                PDFStatCard(title: "Countries", value: "\(countriesVisited.count)", icon: "globe", color: .orange)
                PDFStatCard(title: "Activities", value: "\(uniqueActivitiesCount)", icon: "figure.run", color: .purple)
            }
            .padding(.horizontal, 20)
            
            // Event types
            if !eventTypeData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Event Types")
                        .font(.system(size: 16, weight: .semibold))
                    
                    ForEach(eventTypeData.sorted(by: { $0.count > $1.count }).prefix(5), id: \.type) { item in
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
            if !topLocations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Locations")
                        .font(.system(size: 16, weight: .semibold))
                    
                    ForEach(topLocations.prefix(8), id: \.name) { item in
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

// Flow Layout for country tags
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
