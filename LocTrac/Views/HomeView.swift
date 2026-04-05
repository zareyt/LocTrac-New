import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: DataStore
    
    // Callbacks provided by StartTabView
    let onAddEvent: () -> Void
    let onAddLocation: () -> Void
    let onShowOtherCities: () -> Void
    let onOpenCalendar: () -> Void
    let onOpenLocations: () -> Void
    let onOpenInfographics: () -> Void
    
    // MARK: - Date helpers
    private var now: Date { Date() }
    private var startOfToday: Date { Calendar.current.startOfDay(for: now) }
    private var twelveMonthsAgo: Date {
        Calendar.current.date(byAdding: .month, value: -12, to: now) ?? now
    }
    
    // MARK: - Derived data
    private var todayEvents: [Event] {
        store.events
            .filter { Calendar.current.isDate($0.date, inSameDayAs: now) }
            .sorted { $0.date < $1.date }
    }
    
    private var nextUpcomingEvent: Event? {
        store.events
            .filter { $0.date > now }
            .sorted { $0.date < $1.date }
            .first
    }
    
    private var recentEvents: [Event] {
        Array(store.events.sorted { $0.date > $1.date }.prefix(5))
    }
    
    private var topLocationsOverall: [(location: Location, count: Int)] {
        let counts = Dictionary(grouping: store.events, by: { $0.location.id })
            .mapValues { $0.count }
        let pairs: [(Location, Int)] = counts.compactMap { id, count in
            guard let loc = store.locations.first(where: { $0.id == id }) else { return nil }
            return (loc, count)
        }
        return Array(pairs.sorted { $0.1 > $1.1 }.prefix(5))
    }
    
    private var topActivitiesRolling12M: [(activity: Activity, count: Int)] {
        let windowEvents = store.events.filter { $0.date >= twelveMonthsAgo && $0.date <= now }
        var counts: [String: Int] = [:]
        for event in windowEvents {
            for id in event.activityIDs {
                counts[id, default: 0] += 1
            }
        }
        let pairs: [(Activity, Int)] = counts.compactMap { id, count in
            guard let act = store.activities.first(where: { $0.id == id }) else { return nil }
            return (act, count)
        }
        return Array(pairs.sorted { $0.1 > $1.1 }.prefix(5))
    }
    
    private var otherLocation: Location? {
        store.locations.first(where: { $0.name == "Other" })
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    quickActions
                    todayUpcomingSection
                    recentActivitySection
                    topActivitiesSection
                    topLocationsSection
                    otherCitiesSection
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
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
        HStack(spacing: 12) {
            Button {
                onAddEvent()
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                    Text("Add Event")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Button {
                onAddLocation()
            } label: {
                HStack {
                    Image(systemName: "mappin.circle.fill") // CHANGED from "mappin.circle.badge.plus"
                    Text("Add Location")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var todayUpcomingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today & Upcoming")
                    .font(.headline)
                Spacer()
                Button {
                    onOpenCalendar()
                } label: {
                    Label("Open Calendar", systemImage: "chevron.right.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
            }
            
            if todayEvents.isEmpty && nextUpcomingEvent == nil {
                emptyCard(text: "No events today or upcoming.")
            } else {
                VStack(spacing: 8) {
                    if !todayEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today").font(.subheadline).bold()
                            ForEach(todayEvents) { event in
                                eventRow(event)
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }
                    if let next = nextUpcomingEvent {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Next").font(.subheadline).bold()
                            eventRow(next)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }
                }
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                Button {
                    onOpenCalendar()
                } label: {
                    Label("Open Calendar", systemImage: "chevron.right.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
            }
            if recentEvents.isEmpty {
                emptyCard(text: "No recent events.")
            } else {
                VStack(spacing: 8) {
                    ForEach(recentEvents) { event in
                        eventRow(event)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
        }
    }
    
    private var topActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Top Activities (last 12 months)")
                    .font(.headline)
                Spacer()
                Button {
                    onOpenInfographics()
                } label: {
                    Label("Open Infographic", systemImage: "chevron.right.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
            }
            if topActivitiesRolling12M.isEmpty {
                emptyCard(text: "No activities recorded.")
            } else {
                VStack(spacing: 8) {
                    ForEach(topActivitiesRolling12M.indices, id: \.self) { idx in
                        let item = topActivitiesRolling12M[idx]
                        HStack {
                            Label(item.activity.name, systemImage: "figure.walk")
                                .foregroundColor(.green)
                            Spacer()
                            Text("\(item.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        Divider().opacity(idx == topActivitiesRolling12M.indices.last ? 0 : 1)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
        }
    }
    
    private var topLocationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Top Locations")
                    .font(.headline)
                Spacer()
                Button {
                    onOpenLocations()
                } label: {
                    Label("Open Locations", systemImage: "chevron.right.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
            }
            if topLocationsOverall.isEmpty {
                emptyCard(text: "No locations yet.")
            } else {
                VStack(spacing: 8) {
                    ForEach(topLocationsOverall.indices, id: \.self) { idx in
                        let item = topLocationsOverall[idx]
                        HStack {
                            Circle()
                                .fill(item.location.theme.mainColor)
                                .frame(width: 12, height: 12)
                            Text(item.location.name)
                            Spacer()
                            Text("\(item.count) days")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        Divider().opacity(idx == topLocationsOverall.indices.last ? 0 : 1)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
        }
    }
    
    private var otherCitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Other Cities")
                    .font(.headline)
                Spacer()
                if otherLocation != nil {
                    Button {
                        onShowOtherCities()
                    } label: {
                        Label("View", systemImage: "chevron.right.circle")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let other = otherLocation {
                let cities = uniqueCities(forOtherLocation: other).prefix(5)
                if cities.isEmpty {
                    emptyCard(text: "No cities recorded under Other.")
                } else {
                    VStack(spacing: 4) {
                        ForEach(Array(cities), id: \.self) { city in
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.secondary)
                                Text(city)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                }
            } else {
                emptyCard(text: "No 'Other' location found.")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func eventRow(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                Spacer()
                Text(Event.EventType(rawValue: event.eventType)?.icon ?? "🔲")
            }
            Text(event.location.name)
                .font(.body).bold()
            HStack(spacing: 8) {
                if let city = event.city, !city.isEmpty {
                    Label(city, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !event.activityIDs.isEmpty {
                    Label("\(event.activityIDs.count) act.", systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !event.people.isEmpty {
                    Label("\(event.people.count) ppl.", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemBackground)))
    }
    
    private func uniqueCities(forOtherLocation other: Location) -> [String] {
        let cities = store.events
            .filter { $0.location.id == other.id }
            .compactMap { $0.city?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(cities)).sorted()
    }
    
    private func emptyCard(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}
