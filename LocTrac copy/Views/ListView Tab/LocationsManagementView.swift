//
//  LocationsManagementView.swift
//  LocTrac
//
//  Comprehensive location management with default location support
//

import SwiftUI
import MapKit

struct LocationsManagementView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedLocation: Location?
    @State private var showingLocationEditor = false
    @State private var sortOrder: SortOrder = .alphabetical
    
    enum SortOrder: String, CaseIterable {
        case alphabetical = "A-Z"
        case mostUsed = "Most Used"
        case country = "Country"
        
        var icon: String {
            switch self {
            case .alphabetical: return "textformat.abc"
            case .mostUsed: return "chart.bar.fill"
            case .country: return "globe"
            }
        }
    }
    

    
    private var filteredLocations: [Location] {
        var locations = store.locations.filter { $0.name != "Other" } // Hide "Other" from management
        
        if !searchText.isEmpty {
            locations = locations.filter { location in
                location.name.localizedCaseInsensitiveContains(searchText) ||
                location.city?.localizedCaseInsensitiveContains(searchText) ?? false ||
                location.country?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        
        // Apply sorting
        switch sortOrder {
        case .alphabetical:
            locations.sort { $0.name < $1.name }
        case .mostUsed:
            let eventCounts = Dictionary(grouping: store.events) { $0.location.id }
                .mapValues { $0.count }
            locations.sort { (eventCounts[$0.id] ?? 0) > (eventCounts[$1.id] ?? 0) }
        case .country:
            locations.sort { ($0.country ?? "") < ($1.country ?? "") }
        }
        
        return locations
    }
    
    private var locationsByCountry: [(country: String, locations: [Location])] {
        let grouped = Dictionary(grouping: filteredLocations) { $0.country ?? "Unknown" }
        return grouped.map { (country: $0.key, locations: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.country < $1.country }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Sort options
                sortSection
                
                // Stats
                statsSection
                
                // Locations list
                if filteredLocations.isEmpty {
                    emptyState
                } else {
                    locationsList
                }
            }
            .navigationTitle("Manage Locations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingLocationEditor = true
                    } label: {
                        Label("Add Location", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $selectedLocation) { location in
                LocationEditorSheet(location: location, isDefault: store.isDefaultLocation(location))
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingLocationEditor) {
                // New location editor with default option
                NewLocationWithDefaultSheet()
                    .environmentObject(store)
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search locations...", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    private var sortSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(sortOrder == order ? Color.blue : Color(.tertiarySystemBackground))
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatBox(title: "Total", value: "\(filteredLocations.count)", color: .blue)
            StatBox(title: "Countries", value: "\(Set(filteredLocations.compactMap { $0.country }).count)", color: .green)
            StatBox(title: "Events", value: "\(store.events.count)", color: .orange)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    private var locationsList: some View {
        List {
            if sortOrder == .country {
                ForEach(locationsByCountry, id: \.country) { section in
                    Section(header: Text(section.country)) {
                        ForEach(section.locations) { location in
                            LocationManagementRow(
                                location: location,
                                store: store,
                                isDefault: store.isDefaultLocation(location),
                                onSetDefault: { setDefaultLocation(location) }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedLocation = location
                            }
                        }
                        .onDelete { offsets in
                            deleteLocations(section.locations, at: offsets)
                        }
                    }
                }
            } else {
                ForEach(filteredLocations) { location in
                    LocationManagementRow(
                        location: location,
                        store: store,
                        isDefault: store.isDefaultLocation(location),
                        onSetDefault: { setDefaultLocation(location) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedLocation = location
                    }
                }
                .onDelete(perform: deleteFilteredLocations)
            }
        }
        .listStyle(.plain)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("No Locations Found")
                .font(.title2)
                .fontWeight(.semibold)
            if !searchText.isEmpty {
                Text("Try a different search")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Button {
                    showingLocationEditor = true
                } label: {
                    Label("Add Your First Location", systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func setDefaultLocation(_ location: Location) {
        store.setDefaultLocation(location)
    }
    
    private func deleteFilteredLocations(at offsets: IndexSet) {
        for index in offsets {
            let location = filteredLocations[index]
            
            // Don't allow deleting if events exist for this location
            let hasEvents = store.events.contains { $0.location.id == location.id }
            if hasEvents {
                // TODO: Show alert
                continue
            }
            
            // Clear default if deleting default location
            if store.isDefaultLocation(location) {
                store.clearDefaultLocation()
            }
            
            store.delete(location)
        }
    }
    
    private func deleteLocations(_ locations: [Location], at offsets: IndexSet) {
        for index in offsets {
            let location = locations[index]
            
            // Don't allow deleting if events exist for this location
            let hasEvents = store.events.contains { $0.location.id == location.id }
            if hasEvents {
                // TODO: Show alert
                continue
            }
            
            // Clear default if deleting default location
            if store.isDefaultLocation(location) {
                store.clearDefaultLocation()
            }
            
            store.delete(location)
        }
    }
}

// MARK: - Location Management Row
struct LocationManagementRow: View {
    let location: Location
    let store: DataStore
    let isDefault: Bool
    let onSetDefault: () -> Void
    
    private var eventCount: Int {
        store.events.filter { $0.location.id == location.id }.count
    }
    
    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with location name and default badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(location.theme.mainColor)
                            .frame(width: 12, height: 12)
                        
                        Text(location.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if isDefault {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                Text("DEFAULT")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(4)
                        }
                    }
                    
                    if let city = location.city, let country = location.country {
                        Text("\(city), \(country)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if let city = location.city {
                        Text(city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if let country = location.country {
                        Text(country)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Set as default button
                if !isDefault {
                    Button {
                        onSetDefault()
                    } label: {
                        Image(systemName: "star")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Mini map preview
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))) {
                Annotation("", coordinate: coordinate) {
                    Circle()
                        .fill(location.theme.mainColor)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
            .mapStyle(.standard)
            .frame(height: 120)
            .cornerRadius(8)
            .allowsHitTesting(false)
            
            // Stats row
            HStack(spacing: 16) {
                Label("\(eventCount) events", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let imageIDs = location.imageIDs, !imageIDs.isEmpty {
                    Label("\(imageIDs.count) photos", systemImage: "photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Coordinates
                Label(String(format: "%.2f°, %.2f°", location.latitude, location.longitude), systemImage: "location")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Location Editor Sheet
struct LocationEditorSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    let location: Location
    let initialIsDefault: Bool
    
    @StateObject private var editor: LocationSheetEditorModel
    
    init(location: Location, isDefault: Bool) {
        self.location = location
        self.initialIsDefault = isDefault
        self._editor = StateObject(wrappedValue: LocationSheetEditorModel(location: location, isDefault: isDefault))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section("Location Details") {
                    TextField("Name", text: $editor.name)
                    TextField("City", text: $editor.city)
                    TextField("Country", text: $editor.country)
                }
                
                // Coordinates
                Section("Coordinates") {
                    HStack {
                        Text("Latitude")
                        Spacer()
                        TextField("Latitude", value: $editor.latitude, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Longitude")
                        Spacer()
                        TextField("Longitude", value: $editor.longitude, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Map preview
                Section("Preview") {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: editor.latitude, longitude: editor.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    ))) {
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: editor.latitude, longitude: editor.longitude)) {
                            Circle()
                                .fill(editor.selectedTheme.mainColor)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                    }
                    .frame(height: 200)
                    .cornerRadius(8)
                }
                
                // Theme
                Section("Color Theme") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Theme.allCases, id: \.self) { theme in
                                Button {
                                    editor.selectedTheme = theme
                                } label: {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(theme.mainColor)
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(editor.selectedTheme == theme ? Color.primary : Color.clear, lineWidth: 3)
                                            )
                                        Text(theme.rawValue)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Default setting
                Section {
                    Toggle(isOn: $editor.isDefault) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Set as Default Location")
                        }
                    }
                } footer: {
                    Text("The default location will be automatically selected when creating new events.")
                }
                
                // Location info
                Section("Location Info") {
                    HStack {
                        Text("Events")
                        Spacer()
                        Text("\(store.events.filter { $0.location.id == location.id }.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let imageIDs = location.imageIDs {
                        HStack {
                            Text("Photos")
                            Spacer()
                            Text("\(imageIDs.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(editor.name.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        // Create updated location (need to create new instance since Location is a struct)
        let updatedLocation = Location(
            id: location.id,
            name: editor.name,
            city: editor.city.isEmpty ? nil : editor.city,
            latitude: editor.latitude,
            longitude: editor.longitude,
            country: editor.country.isEmpty ? nil : editor.country,
            theme: editor.selectedTheme,
            imageIDs: location.imageIDs
        )
        
        store.update(updatedLocation)
        
        // Update default if needed
        if editor.isDefault {
            store.setDefaultLocation(updatedLocation)
        } else if store.isDefaultLocation(location) {
            // Only clear if this was the default
            store.clearDefaultLocation()
        }
        
        dismiss()
    }
}



// MARK: - New Location with Default Option
/// Wrapper around LocationFormView that adds default location option
struct NewLocationWithDefaultSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LocationFormViewModel()
    @State private var setAsDefault = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Use the existing LocationFormView
            LocationFormView(viewModel: viewModel)
                .environmentObject(store)
            
            // Add default location option at the bottom
            VStack(spacing: 0) {
                Divider()
                
                Toggle(isOn: $setAsDefault) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Set as Default Location")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
            }
        }
        .onDisappear {
            // If a new location was just added and should be default, set it
            if setAsDefault, let lastLocation = store.locations.last {
                store.setDefaultLocation(lastLocation)
            }
        }
    }
}

// MARK: - Preview
struct LocationsManagementView_Previews: PreviewProvider {
    static var previews: some View {
        LocationsManagementView()
            .environmentObject(DataStore())
    }
}
