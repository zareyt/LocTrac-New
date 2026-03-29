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
    @AppStorage("defaultLocationID") private var defaultLocationID: String = ""
    
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
            List {
                // Default Location Section
                defaultLocationSection
                
                // Search bar
                Section {
                    searchBar
                }
                
                // Sort options
                Section {
                    sortSection
                }
                
                // Stats
                Section {
                    statsSection
                }
                
                // Locations list sections
                if filteredLocations.isEmpty {
                    Section {
                        emptyState
                    }
                } else {
                    locationsListSections
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search locations...")
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
                LocationEditorSheet(location: location)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingLocationEditor) {
                // Use standard location form
                LocationFormView(viewModel: LocationFormViewModel())
                    .environmentObject(store)
            }
        }
    }
    
    // MARK: - Default Location Section
    private var defaultLocationSection: some View {
        Section {
            // Default Location Picker
            Picker("Default Location", selection: $defaultLocationID) {
                Text("None").tag("")
                ForEach(store.locations.filter { $0.name != "Other" }) { location in
                    HStack {
                        Circle()
                            .fill(location.theme.mainColor)
                            .frame(width: 12, height: 12)
                        Text(location.name)
                    }
                    .tag(location.id)
                }
            }
            
            // Current Default Display or Empty State
            if !defaultLocationID.isEmpty,
               let defaultLocation = store.locations.first(where: { $0.id == defaultLocationID }) {
                // Current Default
                HStack(spacing: 16) {
                    Circle()
                        .fill(defaultLocation.theme.mainColor)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(defaultLocation.name)
                            .font(.headline)
                        if let city = defaultLocation.city {
                            Text(city)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if let country = defaultLocation.country {
                            Text(country)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
                .padding(.vertical, 8)
                
                // Clear button
                Button(role: .destructive) {
                    defaultLocationID = ""
                } label: {
                    Label("Clear Default Location", systemImage: "xmark.circle")
                }
            } else {
                // No default set
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No Default Location Set")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Select a location above to set it as default")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            
            // Benefits Info
            VStack(alignment: .leading, spacing: 12) {
                Label("Benefits", systemImage: "star.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                InfoRow(icon: "bolt.fill", text: "Faster event creation", color: .blue)
                InfoRow(icon: "checkmark.circle.fill", text: "Consistent data entry", color: .green)
                InfoRow(icon: "house.fill", text: "Home location always ready", color: .purple)
                InfoRow(icon: "square.and.arrow.up.fill", text: "Can override when traveling", color: .orange)
            }
            .padding(.vertical, 8)
        } header: {
            Label("Default Location", systemImage: "mappin.circle.fill")
        } footer: {
            Text("This location will be automatically selected when creating new events.")
        }
    }
    
    private var searchBar: some View {
        // Search is now handled by .searchable modifier on the List
        EmptyView()
    }
    
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
                    .padding(.horizontal, 16)
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
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatBox(title: "Total", value: "\(filteredLocations.count)", color: .blue)
            StatBox(title: "Countries", value: "\(Set(filteredLocations.compactMap { $0.country }).count)", color: .green)
            StatBox(title: "Events", value: "\(store.events.count)", color: .orange)
        }
    }
    
    private var locationsListSections: some View {
        Group {
            if sortOrder == .country {
                ForEach(locationsByCountry, id: \.country) { section in
                    Section(header: Text(section.country)) {
                        ForEach(section.locations) { location in
                            LocationManagementRow(
                                location: location,
                                store: store
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
                Section {
                    ForEach(filteredLocations) { location in
                        LocationManagementRow(
                            location: location,
                            store: store
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedLocation = location
                        }
                    }
                    .onDelete(perform: deleteFilteredLocations)
                }
            }
        }
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
    
    private func deleteFilteredLocations(at offsets: IndexSet) {
        for index in offsets {
            let location = filteredLocations[index]
            
            // Don't allow deleting if events exist for this location
            let hasEvents = store.events.contains { $0.location.id == location.id }
            if hasEvents {
                // TODO: Show alert
                continue
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
            
            store.delete(location)
        }
    }
}

// MARK: - Location Management Row
struct LocationManagementRow: View {
    let location: Location
    let store: DataStore
    
    private var eventCount: Int {
        store.events.filter { $0.location.id == location.id }.count
    }
    
    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with location name
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(location.theme.mainColor)
                            .frame(width: 12, height: 12)
                        
                        Text(location.name)
                            .font(.headline)
                            .fontWeight(.semibold)
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
    
    @StateObject private var editor: LocationSheetEditorModel
    
    init(location: Location) {
        self.location = location
        self._editor = StateObject(wrappedValue: LocationSheetEditorModel(location: location, isDefault: false))
    }
    
    var body: some View {
        // Bridge Theme <-> Color for the ColorPicker (same as Add Location view)
        let colorBinding = Binding<Color>(
            get: { editor.selectedTheme.mainColor },
            set: { newColor in
                if let nearest = nearestTheme(to: newColor) {
                    editor.selectedTheme = nearest
                }
            }
        )
        
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
                
                // Theme (using ColorPicker like Add Location view)
                Section("Theme Color") {
                    ColorPicker("Color", selection: colorBinding, supportsOpacity: false)
                    
                    HStack {
                        Text("Preview")
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(editor.selectedTheme.mainColor)
                            .frame(width: 30, height: 30)
                    }
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
        dismiss()
    }
    
    // MARK: - Theme mapping helpers (same as Add Location view)
    
    // Find the nearest Theme to a picked Color by comparing sRGB components via UIColor
    private func nearestTheme(to color: Color) -> Theme? {
        guard let target = UIColorResolver.rgba(from: color) else { return nil }
        var best: (theme: Theme, distance: CGFloat)?
        for theme in Theme.allCases {
            if let c = UIColorResolver.rgba(from: theme.uiColor) {
                let d = squaredDistance(lhs: target, rhs: c)
                if best == nil || d < best!.distance {
                    best = (theme, d)
                }
            }
        }
        return best?.theme
    }
    
    private func squaredDistance(lhs: RGBA, rhs: RGBA) -> CGFloat {
        let dr = lhs.r - rhs.r
        let dg = lhs.g - rhs.g
        let db = lhs.b - rhs.b
        return dr*dr + dg*dg + db*db
    }
}


// MARK: - Color Utilities for Theme Mapping

private struct RGBA {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat
}

private enum UIColorResolver {
    // Extract RGBA from a SwiftUI Color by resolving to UIColor
    static func rgba(from color: Color) -> RGBA? {
        #if canImport(UIKit)
        let ui = ColorToUIColorResolver.resolve(color)
        return rgba(from: ui)
        #else
        return nil
        #endif
    }

    // Extract RGBA from a UIColor
    static func rgba(from ui: UIColor) -> RGBA? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return RGBA(r: r, g: g, b: b, a: a)
    }
}

// Helper that converts SwiftUI.Color to UIColor using the most compatible path
private enum ColorToUIColorResolver {
    static func resolve(_ color: Color) -> UIColor {
        #if canImport(UIKit)
        // Preferred: direct initializer if available on your SDK
        if let ui = tryUIColorInit(color) {
            return ui
        }
        // Fallback: host a tiny UIView and set backgroundColor via UIColor(Color)
        let host = UIHostingController(rootView: ColorUIView(color: color))
        host.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        _ = host.view // force load
        return host.view.backgroundColor ?? .clear
        #else
        return .clear
        #endif
    }

    private static func tryUIColorInit(_ color: Color) -> UIColor? {
        #if canImport(UIKit)
        return UIColor(color)
        #else
        return nil
        #endif
    }
}

// A tiny UIViewRepresentable that assigns UIColor(Color) to backgroundColor
private struct ColorUIView: UIViewRepresentable {
    let color: Color
    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.backgroundColor = UIColor(color)
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.backgroundColor = UIColor(color)
    }
}

// MARK: - Preview
struct LocationsManagementView_Previews: PreviewProvider {
    static var previews: some View {
        LocationsManagementView()
            .environmentObject(DataStore())
    }
}
