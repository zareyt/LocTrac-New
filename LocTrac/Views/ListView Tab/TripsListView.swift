//
//  TripsListView.swift
//  LocTrac
//
//  View displaying all trips with year filtering
//

import SwiftUI

struct TripsListView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedYear: String = "All Time"
    @State private var showingTripForm = false
    @State private var selectedTrip: Trip?
    
    private var availableYears: [String] {
        let years = Set(store.trips.map { Calendar.current.component(.year, from: $0.departureDate) })
        return ["All Time"] + years.sorted(by: >).map { String($0) }
    }
    
    private var filteredTrips: [Trip] {
        let trips = selectedYear == "All Time" 
            ? store.trips 
            : store.trips.filter { Calendar.current.component(.year, from: $0.departureDate) == Int(selectedYear) }
        return trips.sorted { $0.departureDate > $1.departureDate }
    }
    
    private var tripStats: (totalMiles: Double, totalCO2: Double, tripCount: Int) {
        let miles = filteredTrips.reduce(0.0) { $0 + $1.distance }
        let co2 = filteredTrips.reduce(0.0) { $0 + $1.co2Emissions }
        return (miles, co2, filteredTrips.count)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Year filter
                yearFilterSection
                
                // Stats summary
                statsSection
                
                // Trips list
                if filteredTrips.isEmpty {
                    emptyState
                } else {
                    tripsList
                }
            }
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        selectedTrip = nil
                        showingTripForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingTripForm) {
                if let trip = selectedTrip,
                   let fromEvent = store.events.first(where: { $0.id == trip.fromEventID }),
                   let toEvent = store.events.first(where: { $0.id == trip.toEventID }) {
                    TripFormView(trip: trip, fromEvent: fromEvent, toEvent: toEvent)
                }
            }
        }
    }
    
    private var yearFilterSection: some View {
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
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            VStack {
                Text("\(tripStats.tripCount)")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Trips")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 40)
            
            VStack {
                Text("\(Int(tripStats.totalMiles))")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Miles")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 40)
            
            VStack {
                Text("\(Int(tripStats.totalCO2))")
                    .font(.title)
                    .fontWeight(.bold)
                Text("lbs CO₂")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    private var tripsList: some View {
        List {
            ForEach(filteredTrips) { trip in
                TripRowView(trip: trip, store: store)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTrip = trip
                        showingTripForm = true
                    }
            }
            .onDelete(perform: deleteTrips)
        }
        .listStyle(.plain)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Trips Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Trips are automatically created when you travel between locations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            store.deleteTrip(filteredTrips[index])
        }
    }
}

// MARK: - Trip Row View
struct TripRowView: View {
    let trip: Trip
    let store: DataStore
    
    private var fromEvent: Event? {
        store.events.first(where: { $0.id == trip.fromEventID })
    }
    
    private var toEvent: Event? {
        store.events.first(where: { $0.id == trip.toEventID })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date and mode
            HStack {
                Text(trip.departureDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: trip.mode.icon)
                        .foregroundColor(.blue)
                    Text(trip.mode.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Route
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fromEvent?.location.name ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let city = fromEvent?.city {
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(toEvent?.location.name ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if let city = toEvent?.city {
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Stats
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "road.lanes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(trip.distance)) mi")
                        .font(.caption)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "cloud.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(Int(trip.co2Emissions)) lbs CO₂")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if trip.isAutoGenerated {
                    Text("Auto")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            // Notes if available
            if !trip.notes.isEmpty {
                Text(trip.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
struct TripsListView_Previews: PreviewProvider {
    static var previews: some View {
        TripsListView()
            .environmentObject(DataStore())
    }
}
