//
//  TravelJourneyView.swift
//  LocTrac
//
//  Dynamic animated travel journey showing progression through all stays
//

import SwiftUI
import MapKit

struct TravelJourneyView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var vm: LocationsMapViewModel // Share the map's view model
    @EnvironmentObject var debugConfig: DebugConfig
    @Environment(\.dismiss) private var dismiss
    
    // Animation state
    @State private var currentEventIndex: Int = 0
    @State private var isPlaying: Bool = false
    @State private var animationSpeed: Double = 0.3 // seconds per event (faster default)
    @State private var showTrail: Bool = true
    @State private var zoomLevel: Double = 0.5 // Zoom level (0.1 = close, 5.0 = far)
    
    // Map state
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
        span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 60)
    )
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    
    // Computed sorted events - uses vm.selectedYear filter from map view
    private var sortedEvents: [Event] {
        var events = store.events.filter { event in
            // Include events that have coordinates (either on event or from location)
            let hasEventCoords = event.latitude != 0.0 && event.longitude != 0.0
            let hasLocationCoords = event.location.latitude != 0.0 && event.location.longitude != 0.0
            return hasEventCoords || hasLocationCoords
        }
        
        // Apply year filter from map view model (shared state)
        if let year = vm.selectedYear {
            events = events.filter { event in
                Calendar.current.component(.year, from: event.date) == year
            }
        }
        
        return events.sorted { $0.date < $1.date }
    }
    
    // Helper to get coordinates for an event (from event or location)
    private func coordinatesFor(_ event: Event) -> CLLocationCoordinate2D {
        if event.latitude != 0.0 && event.longitude != 0.0 {
            // Event has its own coordinates (e.g., "Other" events)
            return CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
        } else {
            // Use location's coordinates (regular location stays)
            return CLLocationCoordinate2D(latitude: event.location.latitude, longitude: event.location.longitude)
        }
    }
    
    private var availableYears: [Int] {
        let years = Set(store.events.map { Calendar.current.component(.year, from: $0.date) })
        return years.sorted(by: >)
    }
    
    // Simple navigation title showing current filter
    private var navigationTitle: String {
        if let year = vm.selectedYear {
            return "Journey - \(year)"
        }
        return "Travel Journey"
    }
    
    // Only show markers for events that should be visible (current + previous few)
    // This dramatically improves performance
    private var visibleEventIndices: [Int] {
        guard !sortedEvents.isEmpty else { return [] }
        
        // Show current and up to 20 previous events
        let startIndex = max(0, currentEventIndex - 20)
        let endIndex = currentEventIndex
        return Array(startIndex...endIndex)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Map with journey
                mapLayer
                
                // Year filter at the top
                VStack {
                    yearFilterBar
                        .padding(.top, 8)
                        .padding(.horizontal)
                    Spacer()
                }
                
                // Controls overlay
                VStack {
                    Spacer()
                    
                    if !sortedEvents.isEmpty {
                        controlsPanel
                            .padding()
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPlaying = false
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // Year filter section (shared with map view)
                        Section("Filter by Year") {
                            Picker("Year", selection: $vm.selectedYear) {
                                Text("All Years").tag(nil as Int?)
                                ForEach(vm.availableYears(), id: \.self) { year in
                                    Text(String(year)).tag(year as Int?)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Zoom level control
                        Section("Zoom Level") {
                            Picker("Zoom", selection: $zoomLevel) {
                                Text("Very Close").tag(0.1)
                                Text("Close").tag(0.3)
                                Text("Medium").tag(0.5)
                                Text("Far").tag(1.5)
                                Text("Very Far").tag(3.0)
                            }
                            .onChange(of: zoomLevel) { oldValue, newValue in
                                if !sortedEvents.isEmpty {
                                    centerOnEvent(at: currentEventIndex)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Speed control
                        Section("Playback Speed") {
                            Picker("Speed", selection: $animationSpeed) {
                                Text("Slow (2s)").tag(2.0)
                                Text("Normal (1s)").tag(1.0)
                                Text("Fast (0.5s)").tag(0.5)
                                Text("Very Fast (0.2s)").tag(0.2)
                            }
                        }
                        
                        Divider()
                        
                        // Display options
                        Section("Display") {
                            Toggle("Show Trail", isOn: $showTrail)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                if !sortedEvents.isEmpty {
                    centerOnEvent(at: 0)
                }
            }
            .onChange(of: vm.selectedYear) { oldValue, newValue in
                // Reset to start when filter changes
                isPlaying = false
                currentEventIndex = 0
                if !sortedEvents.isEmpty {
                    centerOnEvent(at: 0)
                }
            }
            .onChange(of: isPlaying) { oldValue, newValue in
                if newValue {
                    playAnimation()
                }
            }
        }
        .debugViewName("TravelJourneyView")
    }
}

// MARK: - Map Layer
extension TravelJourneyView {
    private var mapLayer: some View {
        Map(position: $mapCameraPosition) {
            // Trail lines connecting ALL events (not just up to current)
            // This prevents trail from disappearing when camera moves
            if showTrail && sortedEvents.count > 1 {
                // Draw entire trail at once for better performance
                let allCoordinates = sortedEvents.prefix(currentEventIndex + 1).map { coordinatesFor($0) }
                if allCoordinates.count > 1 {
                    MapPolyline(coordinates: allCoordinates)
                        .stroke(Color.blue.opacity(0.7), lineWidth: 3)
                }
            }
            
            // Only show markers for nearby events to improve performance
            ForEach(visibleEventIndices, id: \.self) { index in
                let event = sortedEvents[index]
                let isCurrent = index == currentEventIndex
                let isOtherEvent = event.location.name == "Other"
                
                Annotation("", coordinate: coordinatesFor(event)) {
                    VStack(spacing: 2) {
                        if isCurrent {
                            // Simplified current location marker (no animation for performance)
                            Image(systemName: "figure.walk")
                                .font(.title)
                                .foregroundColor(isOtherEvent ? .blue : .red)
                                .padding(8)
                                .background(Circle().fill(Color.white))
                                .overlay(Circle().stroke(isOtherEvent ? Color.blue : Color.red, lineWidth: 3))
                                .shadow(radius: 4)
                                .scaleEffect(1.3)
                        } else {
                            // Simplified past marker
                            Circle()
                                .fill(isOtherEvent ? Color.blue.opacity(0.6) : Color.green.opacity(0.6))
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        }
                        
                        // Only show label for current location
                        if isCurrent {
                            VStack(spacing: 2) {
                                if isOtherEvent {
                                    if let city = event.city, !city.isEmpty {
                                        Text(city)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    } else {
                                        Text("Other Location")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    }
                                } else {
                                    Text(event.location.name)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                                
                                if !isOtherEvent, let city = event.city, city != event.location.name {
                                    Text(city)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(event.date, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .mapStyle(.standard)
        .mapControlVisibility(.hidden) // Hide default controls for cleaner view
    }
    
    // Year filter bar at the top (synced with map view)
    private var yearFilterBar: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.blue)
            
            Picker("Year", selection: $vm.selectedYear) {
                Text("All Years").tag(nil as Int?)
                ForEach(vm.availableYears(), id: \.self) { year in
                    Text(String(year)).tag(year as Int?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            
            if vm.selectedYear != nil {
                Text("•")
                    .foregroundColor(.secondary)
                Text("\(sortedEvents.count) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(radius: 4)
    }
}

// MARK: - Controls Panel
extension TravelJourneyView {
    private var controlsPanel: some View {
        VStack(spacing: 12) {
            // Event info card
            if sortedEvents.indices.contains(currentEventIndex) {
                eventInfoCard
            }
            
            // Speed control slider (NEW - prominent and easy to adjust)
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Speed")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text(speedLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "hare.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $animationSpeed, in: 0.05...3.0, step: 0.05)
                        .tint(.orange)
                    
                    Image(systemName: "tortoise.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
            
            // Timeline slider
            if !sortedEvents.isEmpty {
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { Double(currentEventIndex) },
                            set: { newValue in
                                currentEventIndex = Int(newValue)
                                centerOnEvent(at: currentEventIndex)
                            }
                        ),
                        in: 0...Double(max(0, sortedEvents.count - 1)),
                        step: 1
                    )
                    .tint(.blue)
                    
                    HStack {
                        Text("\(currentEventIndex + 1) of \(sortedEvents.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let firstDate = sortedEvents.first?.date,
                           let lastDate = sortedEvents.last?.date {
                            Text("\(firstDate.formatted(.dateTime.year())) - \(lastDate.formatted(.dateTime.year()))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Playback controls
            HStack(spacing: 20) {
                // Previous
                Button {
                    isPlaying = false
                    if currentEventIndex > 0 {
                        currentEventIndex -= 1
                        centerOnEvent(at: currentEventIndex)
                    }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.blue))
                }
                .disabled(currentEventIndex == 0)
                .opacity(currentEventIndex == 0 ? 0.5 : 1.0)
                
                // Play/Pause
                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.blue))
                }
                
                // Next
                Button {
                    isPlaying = false
                    if currentEventIndex < sortedEvents.count - 1 {
                        currentEventIndex += 1
                        centerOnEvent(at: currentEventIndex)
                    }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.blue))
                }
                .disabled(currentEventIndex >= sortedEvents.count - 1)
                .opacity(currentEventIndex >= sortedEvents.count - 1 ? 0.5 : 1.0)
                
                // Reset
                Button {
                    isPlaying = false
                    currentEventIndex = 0
                    centerOnEvent(at: 0)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.gray))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(radius: 10)
    }
    
    private var eventInfoCard: some View {
        let event = sortedEvents[currentEventIndex]
        let isOtherEvent = event.location.name == "Other"
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Event type icon
                let eventTypeItem = store.eventTypeItem(for: event.eventType)
                Image(systemName: eventTypeItem.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(eventTypeItem.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Show location name or city for "Other" events
                    if isOtherEvent {
                        if let city = event.city, !city.isEmpty {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                Text(city)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                Text("Other Location")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        }
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text(event.location.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        // Show city if different from location name
                        if let city = event.city, !city.isEmpty, city != event.location.name {
                            Text(city)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Text(event.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Note if available
            if !event.note.isEmpty {
                Text(event.note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // People if available
            if !event.people.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(event.people.map { $0.displayName }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Animation Logic
extension TravelJourneyView {
    // Speed label helper
    private var speedLabel: String {
        switch animationSpeed {
        case 0...0.1:
            return "Ultra Fast"
        case 0.1...0.3:
            return "Very Fast"
        case 0.3...0.7:
            return "Fast"
        case 0.7...1.5:
            return "Normal"
        case 1.5...2.5:
            return "Slow"
        default:
            return "Very Slow"
        }
    }
    
    private func playAnimation() {
        guard isPlaying, currentEventIndex < sortedEvents.count - 1 else {
            isPlaying = false
            // Journey complete - zoom out to show all locations
            if currentEventIndex >= sortedEvents.count - 1 {
                zoomToShowAllLocations()
            }
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationSpeed) {
            if isPlaying {
                // Simpler animation without nested withAnimation
                currentEventIndex += 1
                centerOnEvent(at: currentEventIndex)
                playAnimation() // Recursive call for next event
            }
        }
    }
    
    private func centerOnEvent(at index: Int) {
        guard sortedEvents.indices.contains(index) else { return }
        
        let event = sortedEvents[index]
        let coordinate = coordinatesFor(event)
        
        // Faster animation for better performance
        withAnimation(.easeOut(duration: 0.3)) {
            // Update the camera position to center on this coordinate
            mapCameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: zoomLevel, longitudeDelta: zoomLevel)
            ))
        }
    }
    
    // Zoom out to show all visited locations (finale view)
    private func zoomToShowAllLocations() {
        guard !sortedEvents.isEmpty else { return }
        
        // Get all coordinates
        let coordinates = sortedEvents.map { coordinatesFor($0) }
        
        // Calculate bounding box
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else { return }
        
        // Calculate center and span
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = (maxLat - minLat) * 1.3 // 30% padding
        let spanLon = (maxLon - minLon) * 1.3
        
        // Ensure minimum span for single location or close locations
        let finalSpanLat = max(spanLat, 1.0)
        let finalSpanLon = max(spanLon, 1.0)
        
        // Animate to show all locations
        withAnimation(.easeInOut(duration: 2.0)) {
            mapCameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: finalSpanLat, longitudeDelta: finalSpanLon)
            ))
        }
    }
}

// MARK: - Preview
struct TravelJourneyView_Previews: PreviewProvider {
    static var previews: some View {
        TravelJourneyView()
            .environmentObject(DataStore())
            .environmentObject(LocationsMapViewModel())
    }
}
