# Location Management Integration Examples

## Quick Start Integration

### 1. Add to Settings/Menu View

If you have a settings view or menu, add this button:

```swift
struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @State private var showingLocationManagement = false
    
    var body: some View {
        List {
            Section("Data Management") {
                Button {
                    showingLocationManagement = true
                } label: {
                    Label("Manage Locations", systemImage: "mappin.circle.fill")
                }
                
                // Your other buttons...
            }
        }
        .sheet(isPresented: $showingLocationManagement) {
            LocationsManagementView()
                .environmentObject(store)
        }
    }
}
```

### 2. Add to Main Tab View Toolbar

```swift
struct ContentView: View {
    @EnvironmentObject var store: DataStore
    @State private var showingLocationManagement = false
    
    var body: some View {
        TabView {
            // Your tabs...
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingLocationManagement = true
                    } label: {
                        Label("Manage Locations", systemImage: "mappin.circle")
                    }
                    
                    // Other menu items...
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingLocationManagement) {
            LocationsManagementView()
                .environmentObject(store)
        }
    }
}
```

### 3. Use Default Location in Event Creation

#### Simple Approach
```swift
struct AddEventView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedLocation: Location
    
    init(store: DataStore) {
        // Initialize with default location if set
        if let defaultLocation = store.defaultLocation {
            _selectedLocation = State(initialValue: defaultLocation)
        } else {
            _selectedLocation = State(initialValue: store.locations.first ?? Location.sampleData[0])
        }
    }
    
    var body: some View {
        Form {
            Picker("Location", selection: $selectedLocation) {
                ForEach(store.locations) { location in
                    HStack {
                        Circle()
                            .fill(location.theme.mainColor)
                            .frame(width: 12, height: 12)
                        Text(location.name)
                        Spacer()
                        if store.isDefaultLocation(location) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    .tag(location)
                }
            }
        }
    }
}
```

#### With @EnvironmentObject Approach
```swift
struct AddEventView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedLocation: Location?
    
    var body: some View {
        Form {
            Picker("Location", selection: Binding(
                get: { selectedLocation ?? store.defaultLocation ?? store.locations.first },
                set: { selectedLocation = $0 }
            )) {
                ForEach(store.locations) { location in
                    LocationPickerRow(location: location, isDefault: store.isDefaultLocation(location))
                        .tag(location as Location?)
                }
            }
        }
        .onAppear {
            // Set default on appear if not already set
            if selectedLocation == nil {
                selectedLocation = store.defaultLocation
            }
        }
    }
}

struct LocationPickerRow: View {
    let location: Location
    let isDefault: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(location.theme.mainColor)
                .frame(width: 12, height: 12)
            Text(location.name)
            if isDefault {
                Spacer()
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
        }
    }
}
```

### 4. Add Quick Access from Map View

If you have a map view showing locations, add management access:

```swift
struct LocationsMapView: View {
    @EnvironmentObject var store: DataStore
    @State private var showingLocationManagement = false
    @State private var selectedLocation: Location?
    
    var body: some View {
        Map {
            ForEach(store.locations) { location in
                Annotation(location.name, coordinate: CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                )) {
                    Button {
                        selectedLocation = location
                    } label: {
                        Circle()
                            .fill(location.theme.mainColor)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(radius: 3)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingLocationManagement = true
                } label: {
                    Label("Manage", systemImage: "list.bullet.circle")
                }
            }
        }
        .sheet(item: $selectedLocation) { location in
            LocationEditorSheet(location: location, isDefault: store.isDefaultLocation(location))
                .environmentObject(store)
        }
        .sheet(isPresented: $showingLocationManagement) {
            LocationsManagementView()
                .environmentObject(store)
        }
    }
}
```

### 5. Show Default Indicator in List Views

```swift
struct LocationsListView: View {
    @EnvironmentObject var store: DataStore
    
    var body: some View {
        List(store.locations) { location in
            HStack {
                Circle()
                    .fill(location.theme.mainColor)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text(location.name)
                            .font(.headline)
                        
                        if store.isDefaultLocation(location) {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                Text("Default")
                                    .font(.caption2)
                            }
                            .foregroundColor(.yellow)
                        }
                    }
                    
                    if let city = location.city {
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
```

## Advanced Integration

### Context Menu on Location Items

```swift
struct LocationContextMenuView: View {
    @EnvironmentObject var store: DataStore
    let location: Location
    
    var body: some View {
        LocationRow(location: location)
            .contextMenu {
                Button {
                    store.setDefaultLocation(location)
                } label: {
                    Label("Set as Default", systemImage: "star.fill")
                }
                
                Button {
                    // Open in Maps
                } label: {
                    Label("Open in Maps", systemImage: "map")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    store.delete(location)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}
```

### Default Location Banner

Show a banner when no default is set:

```swift
struct DefaultLocationBanner: View {
    @EnvironmentObject var store: DataStore
    @State private var showingLocationManagement = false
    
    var body: some View {
        Group {
            if store.defaultLocation == nil && !store.locations.isEmpty {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Default Location Set")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Set a default to speed up event creation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Set") {
                        showingLocationManagement = true
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .sheet(isPresented: $showingLocationManagement) {
                    LocationsManagementView()
                        .environmentObject(store)
                }
            }
        }
    }
}
```

### Quick Default Selector

A compact view to quickly change default:

```swift
struct QuickDefaultSelector: View {
    @EnvironmentObject var store: DataStore
    
    var body: some View {
        Menu {
            ForEach(store.locations) { location in
                Button {
                    store.setDefaultLocation(location)
                } label: {
                    HStack {
                        Text(location.name)
                        if store.isDefaultLocation(location) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            Divider()
            
            Button("Manage All Locations...") {
                // Show LocationsManagementView
            }
        } label: {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Default: \(store.defaultLocation?.name ?? "None")")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
    }
}
```

## Migration Guide

If you have existing event creation code, here's how to migrate:

### Before
```swift
@State private var selectedLocation = Location.sampleData[0]
```

### After
```swift
@EnvironmentObject var store: DataStore
@State private var selectedLocation: Location?

var effectiveLocation: Location {
    selectedLocation ?? store.defaultLocation ?? store.locations.first ?? Location.sampleData[0]
}

// In body:
.onAppear {
    if selectedLocation == nil {
        selectedLocation = store.defaultLocation
    }
}
```

## User Experience Tips

1. **Show visual indicator** - Always show the star icon for the default location
2. **Toast confirmation** - Show a brief confirmation when default changes
3. **Onboarding** - Prompt users to set default during first run
4. **Quick access** - Add to frequently used screens
5. **Contextual help** - Explain what "default" means

## Testing Scenarios

Test these scenarios:
- [ ] Set a location as default
- [ ] Create new event - default is pre-selected
- [ ] Change default location
- [ ] Create another event - new default is used
- [ ] Delete default location - default is cleared
- [ ] App restart - default persists
- [ ] No locations - graceful handling
- [ ] Single location - automatically suggest as default
