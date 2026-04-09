//
//  LocationSyncUtilityView.swift
//  LocTrac
//
//  Utility to fix existing events with outdated coordinates
//

import SwiftUI

struct LocationSyncUtilityView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewState: ViewState = .initial
    @State private var syncResults: SyncResults?
    @State private var selectedUpdates: Set<String> = [] // Location IDs
    
    enum ViewState {
        case initial
        case analyzing
        case preview
        case applying
        case complete
    }
    
    struct SyncResults {
        var locationUpdates: [LocationSyncInfo] = []
        var totalEventsOutOfSync: Int = 0
    }
    
    struct LocationSyncInfo: Identifiable {
        let id: String // Location ID
        let location: Location
        let outOfSyncEvents: [Event]
        var distanceFromLocation: Double // Average distance events are from location
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch viewState {
                case .initial:
                    initialView
                case .analyzing:
                    analyzingView
                case .preview:
                    if let results = syncResults {
                        previewView(results: results)
                    }
                case .applying:
                    applyingView
                case .complete:
                    completeView
                }
            }
            .navigationTitle("Sync Event Coordinates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Initial View
    
    private var initialView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath.circle")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Sync Event Coordinates")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Find and fix events with outdated coordinates that don't match their location.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                infoRow(icon: "clock.arrow.circlepath", text: "Fix historical data issues", color: .orange)
                infoRow(icon: "location.fill", text: "Sync events to current location coordinates", color: .blue)
                infoRow(icon: "checkmark.circle", text: "Review before applying changes", color: .green)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            VStack(spacing: 8) {
                Text("Common Scenarios")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("Location coordinates were updated in the past without updating events")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("GPS data was refined but events still have old coordinates")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("Events were created with incorrect coordinates")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            Button {
                analyzeData()
            } label: {
                Label("Scan for Issues", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private func infoRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
    
    // MARK: - Analyzing View
    
    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Scanning locations and events...")
                .font(.headline)
            
            Text("Checking for coordinate mismatches")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    // MARK: - Preview View
    
    private func previewView(results: SyncResults) -> some View {
        VStack(spacing: 0) {
            // Summary
            if results.locationUpdates.isEmpty {
                noIssuesView
            } else {
                issuesFoundView(results: results)
            }
        }
    }
    
    private var noIssuesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("All Events in Sync!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("All event coordinates match their location coordinates. No fixes needed.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private func issuesFoundView(results: SyncResults) -> some View {
        VStack(spacing: 0) {
            // Summary header
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    summaryCard(
                        count: results.locationUpdates.count,
                        label: "Locations",
                        color: .orange,
                        icon: "mappin.circle.fill"
                    )
                    
                    summaryCard(
                        count: results.totalEventsOutOfSync,
                        label: "Events",
                        color: .red,
                        icon: "exclamationmark.circle.fill"
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            // List of locations with issues
            List {
                Section {
                    ForEach(results.locationUpdates) { locationInfo in
                        LocationSyncRow(
                            locationInfo: locationInfo,
                            isSelected: selectedUpdates.contains(locationInfo.id)
                        ) {
                            toggleSelection(locationInfo.id)
                        }
                    }
                } header: {
                    HStack {
                        Text("Locations Needing Sync")
                        Spacer()
                        Button(selectedUpdates.count == results.locationUpdates.count ? "Deselect All" : "Select All") {
                            if selectedUpdates.count == results.locationUpdates.count {
                                selectedUpdates.removeAll()
                            } else {
                                selectedUpdates = Set(results.locationUpdates.map { $0.id })
                            }
                        }
                        .font(.caption)
                    }
                }
            }
            
            // Action button
            VStack(spacing: 12) {
                let selectedCount = results.locationUpdates
                    .filter { selectedUpdates.contains($0.id) }
                    .reduce(0) { $0 + $1.outOfSyncEvents.count }
                
                Button {
                    applySync()
                } label: {
                    Label("Sync \(selectedCount) Events", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedUpdates.isEmpty ? Color.gray : Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
                .disabled(selectedUpdates.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private func summaryCard(count: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.title.bold())
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Applying View
    
    private var applyingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Syncing coordinates...")
                .font(.headline)
        }
        .padding()
    }
    
    // MARK: - Complete View
    
    private var completeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Sync Complete")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let results = syncResults {
                let syncedCount = results.locationUpdates
                    .filter { selectedUpdates.contains($0.id) }
                    .reduce(0) { $0 + $1.outOfSyncEvents.count }
                
                Text("Successfully synced \(syncedCount) events to their location coordinates")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    
    private func analyzeData() {
        viewState = .analyzing
        
        Task {
            let results = await performAnalysis()
            
            await MainActor.run {
                self.syncResults = results
                
                // Auto-select all locations
                selectedUpdates = Set(results.locationUpdates.map { $0.id })
                
                viewState = .preview
            }
        }
    }
    
    private func performAnalysis() async -> SyncResults {
        print("\n🔍 === LOCATION SYNC ANALYSIS START ===")
        print("📊 Scanning \(store.locations.count) locations and \(store.events.count) events")
        
        var results = SyncResults()
        
        for location in store.locations {
            let outOfSyncEvents = LocationCoordinateUpdater.findEventsNeedingSync(
                location: location,
                events: store.events
            )
            
            if !outOfSyncEvents.isEmpty {
                print("\n📍 Location: \(location.name)")
                print("   Coordinates: (\(location.latitude), \(location.longitude))")
                print("   Out-of-sync events: \(outOfSyncEvents.count)")
                
                // DEBUG: Show first 3 events to see what's wrong
                for (index, event) in outOfSyncEvents.prefix(3).enumerated() {
                    print("   [DEBUG Event \(index + 1)]")
                    print("      Event coords: (\(event.latitude), \(event.longitude))")
                    print("      City: \(event.city ?? "nil")")
                    print("      Date: \(event.date.formatted(date: .abbreviated, time: .omitted))")
                    print("      Diff from location: lat=\(abs(event.latitude - location.latitude)), lon=\(abs(event.longitude - location.longitude))")
                }
                
                // Calculate average distance
                var totalDistance = 0.0
                for event in outOfSyncEvents {
                    let eventLat = event.latitude
                    let eventLon = event.longitude
                    let locLat = location.latitude
                    let locLon = location.longitude
                    
                    let latDiff = abs(eventLat - locLat)
                    let lonDiff = abs(eventLon - locLon)
                    let distance = sqrt(latDiff * latDiff + lonDiff * lonDiff) * 69.0 // Rough miles
                    totalDistance += distance
                }
                let avgDistance = outOfSyncEvents.isEmpty ? 0 : totalDistance / Double(outOfSyncEvents.count)
                
                print("   Average distance from location: \(String(format: "%.2f", avgDistance)) miles")
                
                results.locationUpdates.append(LocationSyncInfo(
                    id: location.id,
                    location: location,
                    outOfSyncEvents: outOfSyncEvents,
                    distanceFromLocation: avgDistance
                ))
                
                results.totalEventsOutOfSync += outOfSyncEvents.count
            }
        }
        
        print("\n📊 === ANALYSIS COMPLETE ===")
        print("   Locations with issues: \(results.locationUpdates.count)")
        print("   Total events out of sync: \(results.totalEventsOutOfSync)")
        print("=========================\n")
        
        return results
    }
    
    private func toggleSelection(_ locationId: String) {
        if selectedUpdates.contains(locationId) {
            selectedUpdates.remove(locationId)
        } else {
            selectedUpdates.insert(locationId)
        }
    }
    
    private func applySync() {
        guard let results = syncResults else { return }
        
        viewState = .applying
        
        Task {
            print("\n🔄 === APPLYING SYNC ===")
            
            var totalSynced = 0
            
            for locationInfo in results.locationUpdates where selectedUpdates.contains(locationInfo.id) {
                print("\n📍 Syncing location: \(locationInfo.location.name)")
                
                LocationCoordinateUpdater.autoUpdateEventCoordinates(
                    events: locationInfo.outOfSyncEvents,
                    newLatitude: locationInfo.location.latitude,
                    newLongitude: locationInfo.location.longitude,
                    newCity: locationInfo.location.city,
                    newCountry: locationInfo.location.country,
                    store: store
                )
                
                totalSynced += locationInfo.outOfSyncEvents.count
            }
            
            print("\n✅ Sync complete: \(totalSynced) events updated")
            
            await MainActor.run {
                viewState = .complete
            }
        }
    }
}

// MARK: - Location Sync Row

struct LocationSyncRow: View {
    let locationInfo: LocationSyncUtilityView.LocationSyncInfo
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(locationInfo.location.name)
                            .font(.headline)
                        
                        Spacer()
                        
                        Circle()
                            .fill(locationInfo.location.theme.mainColor)
                            .frame(width: 12, height: 12)
                    }
                    
                    HStack(spacing: 16) {
                        Label("\(locationInfo.outOfSyncEvents.count) events", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        
                        if locationInfo.distanceFromLocation > 0.1 {
                            Label("~\(String(format: "%.1f", locationInfo.distanceFromLocation)) mi off", systemImage: "location.slash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else {
                            Label("< 0.1 mi off", systemImage: "location.slash")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    Text("Current: (\(String(format: "%.4f", locationInfo.location.latitude)), \(String(format: "%.4f", locationInfo.location.longitude)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LocationSyncUtilityView()
        .environmentObject(DataStore())
}
