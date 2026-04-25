//
//  TripFormView.swift
//  LocTrac
//
//  Form for adding/editing trips
//

import SwiftUI

struct TripFormView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var debugConfig: DebugConfig
    @Environment(\.dismiss) private var dismiss
    
    let trip: Trip?
    let fromEvent: Event
    let toEvent: Event
    
    @State private var transportMode: Trip.TransportMode
    @State private var distance: Double
    @State private var notes: String
    @State private var departureDate: Date
    @State private var arrivalDate: Date
    
    init(trip: Trip?, fromEvent: Event, toEvent: Event) {
        self.trip = trip
        self.fromEvent = fromEvent
        self.toEvent = toEvent
        
        if let trip = trip {
            _transportMode = State(initialValue: trip.mode)
            _distance = State(initialValue: trip.distance)
            _notes = State(initialValue: trip.notes)
            _departureDate = State(initialValue: trip.departureDate)
            _arrivalDate = State(initialValue: trip.arrivalDate)
        } else {
            _transportMode = State(initialValue: .driving)
            _distance = State(initialValue: 0)
            _notes = State(initialValue: "")
            _departureDate = State(initialValue: fromEvent.date)
            _arrivalDate = State(initialValue: toEvent.date)
        }
    }
    
    private var estimatedCO2: Double {
        distance * transportMode.co2PerMile
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Route Section
                Section("Route") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("From")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(fromEvent.location.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if let city = fromEvent.city {
                                Text(city)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("To")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(toEvent.location.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if let city = toEvent.city {
                                Text(city)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Transport Mode Section
                Section("Transport Mode") {
                    Picker("Mode", selection: $transportMode) {
                        ForEach(Trip.TransportMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Distance Section
                Section {
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("Miles", value: $distance, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("mi")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Distance")
                } footer: {
                    if distance > 0 {
                        Text("Estimated CO₂: \(Int(estimatedCO2)) lbs")
                            .foregroundColor(.orange)
                    }
                }
                
                // Dates Section
                Section("Travel Dates") {
                    DatePicker("Departure", selection: $departureDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Arrival", selection: $arrivalDate, in: departureDate..., displayedComponents: [.date, .hourAndMinute])
                }
                
                // Notes Section
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                // Environmental Impact
                if distance > 0 {
                    Section("Environmental Impact") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CO₂ Emissions")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(Int(estimatedCO2)) lbs")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Trees Needed")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(Int(estimatedCO2 / 48.0))")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(trip == nil ? "Add Trip" : "Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTrip()
                    }
                    .disabled(distance <= 0)
                }
            }
        }
        .debugViewName("TripFormView")
    }

    private func saveTrip() {
        if let existingTrip = trip {
            // Update existing trip
            existingTrip.mode = transportMode
            existingTrip.distance = distance
            existingTrip.notes = notes
            existingTrip.departureDate = departureDate
            existingTrip.arrivalDate = arrivalDate
            existingTrip.recalculateCO2()
        } else {
            // Create new trip
            let newTrip = Trip(
                fromEventID: fromEvent.id,
                toEventID: toEvent.id,
                departureDate: departureDate,
                arrivalDate: arrivalDate,
                distance: distance,
                transportMode: transportMode,
                notes: notes,
                isAutoGenerated: false
            )
            store.trips.append(newTrip)
        }
        
        store.save()
        dismiss()
    }
}

// MARK: - Preview
struct TripFormView_Previews: PreviewProvider {
    static var previews: some View {
        let store = DataStore()
        
        // Create sample location
        let sampleLocation = Location(
            name: "Home",
            city: "San Francisco",
            latitude: 37.7749,
            longitude: -122.4194,
            theme: .purple
        )
        
        // Create sample events
        let fromEvent = Event(
            eventType: .stay,
            date: Date().addingTimeInterval(-86400 * 7), // 7 days ago
            location: sampleLocation,
            city: "San Francisco",
            latitude: 37.7749,
            longitude: -122.4194,
            note: "Starting location"
        )
        
        let toEvent = Event(
            eventType: .vacation,
            date: Date(),
            location: sampleLocation,
            city: "Los Angeles",
            latitude: 34.0522,
            longitude: -118.2437,
            note: "Destination"
        )
        
        return TripFormView(
            trip: nil,
            fromEvent: fromEvent,
            toEvent: toEvent
        )
        .environmentObject(store)
    }
}
