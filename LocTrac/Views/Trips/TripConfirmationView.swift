//
//  TripConfirmationView.swift
//  LocTrac
//
//  Confirmation dialog for newly created trips
//

import SwiftUI

struct TripConfirmationView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    let trip: Trip
    let fromEvent: Event
    let toEvent: Event
    let onConfirm: (Trip.TransportMode, String) -> Void
    let onCancel: () -> Void
    
    @State private var selectedMode: Trip.TransportMode
    @State private var notes: String
    
    init(trip: Trip, fromEvent: Event, toEvent: Event,
         onConfirm: @escaping (Trip.TransportMode, String) -> Void,
         onCancel: @escaping () -> Void) {
        self.trip = trip
        self.fromEvent = fromEvent
        self.toEvent = toEvent
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        
        _selectedMode = State(initialValue: trip.mode)
        _notes = State(initialValue: trip.notes)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundStyle(.blue)
                        Text("From")
                        Spacer()
                        Text(fromEvent.location.name)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundStyle(.green)
                        Text("To")
                        Spacer()
                        Text(toEvent.location.name)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "arrow.left.and.right")
                            .foregroundStyle(.orange)
                        Text("Distance")
                        Spacer()
                        Text("\(trip.formattedDistance) mi")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.purple)
                        Text("Date")
                        Spacer()
                        Text(trip.departureDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Picker("Transport Mode", selection: $selectedMode) {
                        ForEach(Trip.TransportMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.blue)
                        Text("Auto-detected: \(trip.mode.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Transportation")
                } footer: {
                    Text("Based on the distance (\(trip.formattedDistance) mi), \(trip.mode.rawValue) was suggested. You can change it if needed.")
                }
                
                Section {
                    TextField("Add notes about this trip...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes (Optional)")
                } footer: {
                    Text("Add any details about this trip, like purpose, route, or companions.")
                }
                
                Section("Environmental Impact") {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(.green)
                        Text("Est. CO2 Emissions")
                        Spacer()
                        Text("\(Int(trip.distance * selectedMode.co2PerMile)) lbs")
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("\(selectedMode.rawValue): ~\(String(format: "%.2f", selectedMode.co2PerMile)) lbs CO2 per mile")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("New Trip Created")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Delete Trip") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onConfirm(selectedMode, notes)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    TripConfirmationView(
        trip: Trip(
            fromEventID: "1",
            toEventID: "2",
            departureDate: Date(),
            arrivalDate: Date().addingTimeInterval(3600),
            distance: 95.5,
            transportMode: .driving,
            notes: ""
        ),
        fromEvent: Event.sampleData[0],
        toEvent: Event.sampleData[0],
        onConfirm: { _, _ in },
        onCancel: {}
    )
    .environmentObject(DataStore())
}
