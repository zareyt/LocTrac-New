//
//  LocationCoordinateReviewView.swift
//  LocTrac
//
//  Manual review interface for large location coordinate changes
//

import SwiftUI
import MapKit

struct LocationCoordinateReviewView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    let analysis: LocationCoordinateUpdater.UpdateAnalysis
    let location: Location
    let onApprove: () -> Void
    let onCancel: () -> Void
    
    @State private var selectedEvents: Set<String> = []
    @State private var showMap = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Warning header
                warningHeader
                
                // Coordinate change details
                coordinateDetails
                
                Divider()
                
                // Event list
                eventsList
                
                // Action buttons
                actionButtons
            }
            .navigationTitle("Review Coordinate Change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Auto-select all events
            selectedEvents = Set(analysis.affectedEvents.map { $0.id })
        }
    }
    
    // MARK: - Warning Header
    
    private var warningHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: analysis.distanceChange > 5 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(analysis.distanceChange > 5 ? .orange : .blue)
            
            Text("Coordinate Change Detected")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Text("The location '\(location.name)' coordinates have changed by \(String(format: "%.1f", analysis.distanceChange)) miles.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                
                if analysis.affectedEvents.count > 0 {
                    Text("This will affect \(analysis.affectedEvents.count) event\(analysis.affectedEvents.count == 1 ? "" : "s").")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background((analysis.distanceChange > 5 ? Color.orange : Color.blue).opacity(0.1))
    }
    
    // MARK: - Coordinate Details
    
    private var coordinateDetails: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                coordinateCard(
                    title: "Old Coordinates",
                    latitude: analysis.oldCoordinates.latitude,
                    longitude: analysis.oldCoordinates.longitude,
                    color: .red
                )
                
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                coordinateCard(
                    title: "New Coordinates",
                    latitude: analysis.newCoordinates.latitude,
                    longitude: analysis.newCoordinates.longitude,
                    color: .green
                )
            }
            .padding(.horizontal)
            
            Button {
                showMap.toggle()
            } label: {
                Label(showMap ? "Hide Map" : "Show Map Comparison", systemImage: "map")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            
            if showMap {
                mapComparison
            }
        }
        .padding(.vertical)
    }
    
    private func coordinateCard(title: String, latitude: Double, longitude: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Lat:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(String(format: "%.6f", latitude))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 4) {
                    Text("Lon:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(String(format: "%.6f", longitude))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var mapComparison: some View {
        VStack(spacing: 8) {
            Map {
                Annotation("Old", coordinate: analysis.oldCoordinates) {
                    ZStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 30, height: 30)
                        Image(systemName: "mappin")
                            .foregroundStyle(.white)
                    }
                }
                
                Annotation("New", coordinate: analysis.newCoordinates) {
                    ZStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 30, height: 30)
                        Image(systemName: "mappin")
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 200)
            .cornerRadius(12)
            .padding(.horizontal)
            
            Text("\(String(format: "%.2f", analysis.distanceChange)) miles apart")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Events List
    
    private var eventsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Affected Events (\(analysis.affectedEvents.count))")
                    .font(.headline)
                
                Spacer()
                
                Button(selectedEvents.count == analysis.affectedEvents.count ? "Deselect All" : "Select All") {
                    if selectedEvents.count == analysis.affectedEvents.count {
                        selectedEvents.removeAll()
                    } else {
                        selectedEvents = Set(analysis.affectedEvents.map { $0.id })
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Text("Select which events should have their coordinates updated")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            List {
                ForEach(analysis.affectedEvents.sorted(by: { $0.date > $1.date })) { event in
                    EventCoordinateRow(
                        event: event,
                        isSelected: selectedEvents.contains(event.id)
                    ) {
                        toggleSelection(event.id)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                applyUpdates()
            } label: {
                Label("Update \(selectedEvents.count) Events", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedEvents.isEmpty ? Color.gray : Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .disabled(selectedEvents.isEmpty)
            
            Button {
                onCancel()
                dismiss()
            } label: {
                Text("Keep Original Coordinates")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Functions
    
    private func toggleSelection(_ eventId: String) {
        if selectedEvents.contains(eventId) {
            selectedEvents.remove(eventId)
        } else {
            selectedEvents.insert(eventId)
        }
    }
    
    private func applyUpdates() {
        print("\n🔄 [Manual Review] Applying coordinate updates to \(selectedEvents.count) events")
        
        let eventsToUpdate = analysis.affectedEvents.filter { selectedEvents.contains($0.id) }
        
        LocationCoordinateUpdater.autoUpdateEventCoordinates(
            events: eventsToUpdate,
            newLatitude: analysis.newCoordinates.latitude,
            newLongitude: analysis.newCoordinates.longitude,
            newCity: location.city,
            newCountry: location.country,
            store: store
        )
        
        onApprove()
        dismiss()
    }
}

// MARK: - Event Row

struct EventCoordinateRow: View {
    let event: Event
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
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(event.city ?? "Unknown")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(formatDate(event.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("(\(String(format: "%.4f", event.latitude)), \(String(format: "%.4f", event.longitude)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    if !event.note.isEmpty {
                        Text(event.note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    LocationCoordinateReviewView(
        analysis: LocationCoordinateUpdater.UpdateAnalysis(
            affectedEvents: Event.sampleData,
            oldCoordinates: CLLocationCoordinate2D(latitude: 39.753, longitude: -104.999),
            newCoordinates: CLLocationCoordinate2D(latitude: 39.800, longitude: -105.050),
            distanceChange: 3.2,
            shouldAutoUpdate: false
        ),
        location: Location.sampleData[0],
        onApprove: {},
        onCancel: {}
    )
    .environmentObject(DataStore())
}
