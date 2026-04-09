//
//  FirstLaunchWizard.swift
//  LocTrac
//
//  First-launch onboarding wizard to set up initial data
//

import SwiftUI
import CoreLocation

// MARK: - Location Manager for Current Location

class WizardLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var isLocating = false
    
    private var locationTimeout: Timer?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocation() {
        // Check current authorization status
        let currentStatus = locationManager.authorizationStatus
        
        guard currentStatus != .denied && currentStatus != .restricted else {
            DispatchQueue.main.async {
                self.locationError = "Location access denied. Toggle off to enter manually."
                self.isLocating = false
            }
            return
        }
        
        // Clear previous error
        locationError = nil
        isLocating = true
        
        // Request authorization if needed
        if currentStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        // Start timeout timer (5 seconds)
        locationTimeout?.invalidate()
        locationTimeout = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.currentLocation == nil {
                    self?.locationError = "Location timeout. Toggle off to enter manually."
                    self?.isLocating = false
                }
            }
        }
        
        // Request location
        locationManager.requestLocation()
    }
    
    func stopLocating() {
        locationTimeout?.invalidate()
        locationManager.stopUpdatingLocation()
        isLocating = false
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        locationTimeout?.invalidate()
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.isLocating = false
            self.locationError = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationTimeout?.invalidate()
        
        let nsError = error as NSError
        var errorMessage = "Unable to get location"
        
        if nsError.domain == kCLErrorDomain {
            switch nsError.code {
            case CLError.denied.rawValue:
                errorMessage = "Location access denied"
            case CLError.locationUnknown.rawValue:
                errorMessage = "Location currently unavailable"
            case CLError.network.rawValue:
                errorMessage = "Network error getting location"
            default:
                errorMessage = "Location error: \(error.localizedDescription)"
            }
        }
        
        print("Location error: \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            self.locationError = errorMessage
            self.isLocating = false
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            // If authorization changes to denied/restricted while locating, stop
            if (manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted) {
                self.locationError = "Location access denied"
                self.isLocating = false
                self.locationTimeout?.invalidate()
            }
            // If authorized, automatically request location
            else if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                if self.isLocating {
                    manager.requestLocation()
                }
            }
        }
    }
}

struct FirstLaunchWizard: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    @State private var isCompleting = false
    
    let totalSteps = 5 // Updated to 5 steps (Welcome, Permissions, Locations, Activities, Affirmations)
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    ProgressView(value: Double(currentStep), total: Double(totalSteps))
                        .padding()
                    
                    // Content
                    TabView(selection: $currentStep) {
                        WelcomeStepView()
                            .tag(0)
                        
                        PermissionsStepView()
                            .tag(1)
                        
                        LocationsStepView()
                            .tag(2)
                        
                        ActivitiesStepView()
                            .tag(3)
                        
                        AffirmationsStepView()
                            .tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .disabled(isCompleting)
                    
                    // Navigation buttons
                    HStack {
                        if currentStep > 0 {
                            Button(action: previousStep) {
                                Label("Back", systemImage: "chevron.left")
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Spacer()
                        
                        if currentStep < totalSteps - 1 {
                            Button(action: nextStep) {
                                Label("Next", systemImage: "chevron.right")
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(action: completeWizard) {
                                if isCompleting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Label("Get Started", systemImage: "checkmark")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isCompleting)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Setup Wizard")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }
    
    private func nextStep() {
        withAnimation {
            currentStep += 1
        }
    }
    
    private func previousStep() {
        withAnimation {
            currentStep -= 1
        }
    }
    
    private func completeWizard() {
        isCompleting = true
        
        print("🎯 Starting wizard completion...")
        
        // Create default data
        setupDefaultData()
        
        // Ensure required "Other" location exists for non-stay events
        store.ensureOtherLocationExists(saveIfAdded: false)
        print("📍 Locations after ensureOtherLocationExists: \(store.locations.count)")
        
        // Mark wizard as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedFirstLaunch")
        print("✅ Set hasCompletedFirstLaunch flag")
        
        // Save data to create backup.json
        store.storeData()
        print("💾 Called storeData() - backup.json should now exist")
        
        // Small delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isCompleting = false
            dismiss()
            print("✅ Wizard completed and dismissed")
        }
    }
    
    private func setupDefaultData() {
        // Add default activities if none exist
        if store.activities.isEmpty {
            let defaultActivities = ["Golfing", "Skiing", "Biking", "Yoga", "Exercise", "Pickleball"]
            store.activities = defaultActivities.map { Activity(name: $0) }
        }
        
        // Add sample location if none exist (optional - user can add their own later)
        if store.locations.isEmpty {
            // User will add their own locations through the app
            // We'll just ensure the data structures are initialized
        }
    }
}

// MARK: - Permissions Step

struct PermissionsStepView: View {
    @State private var locationStatus: String = "Not Requested"
    @State private var photosStatus: String = "Not Requested"
    @State private var contactsStatus: String = "Not Requested"
    
    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Enable Permissions")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("To get the most out of LocTrac, please enable these permissions in Settings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Permissions cards
                    VStack(spacing: 16) {
                        PermissionCard(
                            icon: "location.fill",
                            title: "Location Services",
                            description: "Automatically detect your current location when adding places and events",
                            status: locationStatus,
                            color: .blue,
                            steps: [
                                "Open Settings app",
                                "Tap Privacy & Security → Location Services",
                                "Find LocTrac and select 'While Using the App'"
                            ]
                        )
                        
                        PermissionCard(
                            icon: "photo.fill",
                            title: "Photo Library",
                            description: "Add photos to your locations to remember special moments",
                            status: photosStatus,
                            color: .green,
                            steps: [
                                "Open Settings app",
                                "Scroll down and tap LocTrac",
                                "Tap Photos and select 'Selected Photos' or 'All Photos'"
                            ]
                        )
                        
                        PermissionCard(
                            icon: "person.2.fill",
                            title: "Contacts",
                            description: "Easily add people to your events from your contacts",
                            status: contactsStatus,
                            color: .orange,
                            steps: [
                                "Open Settings app",
                                "Scroll down and tap LocTrac",
                                "Enable Contacts access"
                            ]
                        )
                    }
                    .padding(.horizontal)
                    
                    // Info callout
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Privacy Notice")
                                .font(.headline)
                        }
                        Text("All your data stays on your device. LocTrac never sends your location, photos, or contacts to any server.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal)
                    
                    Text("You can enable these permissions now or later in Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let status: String
    let color: Color
    let steps: [String]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "info.circle.fill")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                }
            }
            
            // Expandable steps
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to enable:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(step)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "map.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
            
            VStack(spacing: 12) {
                Text("Welcome to LocTrac")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your locations, events, and activities all in one place")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "location.fill", 
                          title: "Track Locations",
                          description: "Create and manage your favorite places")
                
                FeatureRow(icon: "calendar", 
                          title: "Log Events",
                          description: "Record stays, vacations, and visits")
                
                FeatureRow(icon: "figure.run", 
                          title: "Activities",
                          description: "Track what you do at each location")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .padding()
            
            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Locations Step

struct LocationsStepView: View {
    @EnvironmentObject var store: DataStore
    @StateObject private var locationManager = WizardLocationManager()
    @State private var newLocationName = ""
    @State private var newLocationCity = ""
    @State private var selectedTheme: Theme = .purple
    @State private var isGeocodingLocation = false
    @State private var useCurrentLocation = false // Default to manual entry
    @State private var manualLatitude = ""
    @State private var manualLongitude = ""
    
    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Add Your Locations")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Start by adding the places you visit most. You can always add more later.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Add location form
                    VStack(spacing: 16) {
                        TextField("Location Name (e.g., Home, Office)", text: $newLocationName)
                            .textFieldStyle(.roundedBorder)
                        
                        // Toggle for current location
                        Toggle("Use Current Location", isOn: $useCurrentLocation)
                            .onChange(of: useCurrentLocation) { oldValue, newValue in
                                if newValue {
                                    locationManager.requestLocation()
                                } else {
                                    locationManager.stopLocating()
                                }
                            }
                        
                        if useCurrentLocation {
                            // Show current location status
                            HStack {
                                if locationManager.isLocating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Detecting location...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if let error = locationManager.locationError {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else if locationManager.currentLocation != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Location detected")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                    Text("Waiting for location...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        } else {
                            // Manual city entry
                            TextField("City", text: $newLocationCity)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Picker("Theme Color", selection: $selectedTheme) {
                            ForEach(Theme.allCases) { theme in
                                HStack {
                                    Circle()
                                        .fill(theme.mainColor)
                                        .frame(width: 20, height: 20)
                                    Text(theme.name)
                                }
                                .tag(theme)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Button(action: addLocation) {
                            if isGeocodingLocation {
                                ProgressView()
                            } else {
                                Label("Add Location", systemImage: "plus.circle.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isButtonDisabled())
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal)
                    
                    // List of added locations
                    if !store.locations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Added Locations")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(store.locations) { location in
                                HStack {
                                    Circle()
                                        .fill(location.theme.mainColor)
                                        .frame(width: 30, height: 30)
                                    
                                    VStack(alignment: .leading) {
                                        Text(location.name)
                                            .font(.headline)
                                        if let city = location.city {
                                            Text(city)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: { deleteLocation(location) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemBackground))
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Text("Tip: You can skip this and add locations later from the Locations tab")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }
    
    private func addLocation() {
        guard !newLocationName.isEmpty else {
            return
        }
        
        isGeocodingLocation = true
        
        Task {
            if useCurrentLocation, let currentLoc = locationManager.currentLocation {
                // Use current location coordinates with timeout
                let city: String
                let country: String?
                
                do {
                    let geocoder = CLGeocoder()
                    
                    // Add timeout using Task
                    let placemarks = try await withThrowingTaskGroup(of: [CLPlacemark].self) { group in
                        group.addTask {
                            try await geocoder.reverseGeocodeLocation(currentLoc)
                        }
                        
                        // Timeout after 3 seconds
                        group.addTask {
                            try await Task.sleep(nanoseconds: 3_000_000_000)
                            throw NSError(domain: "Timeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Geocoding timeout"])
                        }
                        
                        // Return first result (either geocode result or timeout)
                        if let result = try await group.next() {
                            group.cancelAll()
                            return result
                        }
                        throw NSError(domain: "NoResult", code: -1)
                    }
                    
                    if let placemark = placemarks.first {
                        city = placemark.locality ?? placemark.administrativeArea ?? "Unknown"
                        country = placemark.country
                    } else {
                        city = "Unknown"
                        country = nil
                    }
                } catch {
                    city = "Unknown"
                    country = nil
                }
                
                let newLocation = Location(
                    name: newLocationName,
                    city: city,
                    latitude: currentLoc.coordinate.latitude,
                    longitude: currentLoc.coordinate.longitude,
                    country: country,
                    theme: selectedTheme
                )
                
                await MainActor.run {
                    store.add(newLocation)
                    isGeocodingLocation = false
                    resetForm()
                }
                
            } else if !newLocationCity.isEmpty {
                // Manual city entry - try to geocode with timeout, but don't block if it fails
                var latitude = 0.0
                var longitude = 0.0
                var country: String?
                
                do {
                    let geocoder = CLGeocoder()
                    
                    // Add timeout
                    let placemarks = try await withThrowingTaskGroup(of: [CLPlacemark].self) { group in
                        group.addTask {
                            try await geocoder.geocodeAddressString(self.newLocationCity)
                        }
                        
                        group.addTask {
                            try await Task.sleep(nanoseconds: 3_000_000_000)
                            throw NSError(domain: "Timeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Geocoding timeout"])
                        }
                        
                        if let result = try await group.next() {
                            group.cancelAll()
                            return result
                        }
                        throw NSError(domain: "NoResult", code: -1)
                    }
                    
                    if let placemark = placemarks.first,
                       let location = placemark.location {
                        latitude = location.coordinate.latitude
                        longitude = location.coordinate.longitude
                        country = placemark.country
                    }
                } catch {
                    // Keep default 0,0 coordinates
                }
                
                let newLocation = Location(
                    name: newLocationName,
                    city: newLocationCity,
                    latitude: latitude,
                    longitude: longitude,
                    country: country,
                    theme: selectedTheme
                )
                
                await MainActor.run {
                    store.add(newLocation)
                    isGeocodingLocation = false
                    resetForm()
                }
                
            } else {
                // No location data at all - shouldn't happen but handle gracefully
                let newLocation = Location(
                    name: newLocationName,
                    city: "Unknown",
                    latitude: 0.0,
                    longitude: 0.0,
                    country: nil,
                    theme: selectedTheme
                )
                
                await MainActor.run {
                    store.add(newLocation)
                    isGeocodingLocation = false
                    resetForm()
                }
            }
        }
    }
    
    private func resetForm() {
        newLocationName = ""
        newLocationCity = ""
        selectedTheme = .purple
        isGeocodingLocation = false
    }
    
    private func deleteLocation(_ location: Location) {
        store.delete(location)
    }
    
    private func isButtonDisabled() -> Bool {
        // Always disabled if name is empty or currently geocoding
        if newLocationName.isEmpty || isGeocodingLocation {
            return true
        }
        
        // If using current location, need location detected
        if useCurrentLocation {
            let hasLocation = locationManager.currentLocation != nil
            let hasError = locationManager.locationError != nil
            // Enable if we have location OR if there's an error
            return !hasLocation && !hasError
        }
        
        // For manual entry, need city name
        return newLocationCity.isEmpty
    }
}

// MARK: - Activities Step

struct ActivitiesStepView: View {
    @EnvironmentObject var store: DataStore
    @State private var newActivityName = ""
    @State private var selectedDefaultActivities: Set<String> = []
    
    let defaultActivities = ["Golfing", "Skiing", "Biking", "Yoga", "Exercise", "Pickleball", "Hiking", "Swimming", "Running", "Reading"]
    
    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Set Up Activities")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Choose activities you enjoy or create your own. These help you track what you do at each location.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Default activities selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select from common activities:")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                            ForEach(defaultActivities, id: \.self) { activity in
                                Button(action: { toggleDefaultActivity(activity) }) {
                                    HStack {
                                        Image(systemName: selectedDefaultActivities.contains(activity) ? "checkmark.circle.fill" : "circle")
                                        Text(activity)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedDefaultActivities.contains(activity) ? Color.blue.opacity(0.2) : Color(.systemBackground))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding()
                    
                    // Custom activity form
                    VStack(spacing: 16) {
                        Text("Or add a custom activity:")
                            .font(.headline)
                        
                        HStack {
                            TextField("Activity Name", text: $newActivityName)
                                .textFieldStyle(.roundedBorder)
                            
                            Button(action: addCustomActivity) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .disabled(newActivityName.isEmpty)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.horizontal)
                    
                    // List of added activities
                    if !store.activities.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Activities (\(store.activities.count))")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(store.activities) { activity in
                                HStack {
                                    Image(systemName: "figure.run")
                                        .foregroundColor(.blue)
                                    
                                    Text(activity.name)
                                        .font(.body)
                                    
                                    Spacer()
                                    
                                    Button(action: { deleteActivity(activity) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemBackground))
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Sync selectedDefaultActivities with what's already in the store
            for activity in store.activities {
                if defaultActivities.contains(activity.name) {
                    selectedDefaultActivities.insert(activity.name)
                }
            }
            
            // If store is empty, pre-select common activities
            if store.activities.isEmpty {
                let defaults = ["Golfing", "Skiing", "Biking", "Yoga", "Exercise", "Pickleball"]
                selectedDefaultActivities = Set(defaults)
                // Add them to store immediately
                for name in defaults {
                    let activity = Activity(name: name)
                    store.addActivity(activity)
                }
            }
        }
    }
    
    private func toggleDefaultActivity(_ activity: String) {
        if selectedDefaultActivities.contains(activity) {
            selectedDefaultActivities.remove(activity)
            // Remove from store
            if let existingActivity = store.activities.first(where: { $0.name == activity }) {
                store.deleteActivity(existingActivity)
            }
        } else {
            selectedDefaultActivities.insert(activity)
            // Add to store
            let newActivity = Activity(name: activity)
            store.addActivity(newActivity)
        }
    }
    
    private func addCustomActivity() {
        let activity = Activity(name: newActivityName)
        store.addActivity(activity)
        newActivityName = ""
    }
    
    private func deleteActivity(_ activity: Activity) {
        selectedDefaultActivities.remove(activity.name)
        store.deleteActivity(activity)
    }
}

// MARK: - Affirmations Step

struct AffirmationsStepView: View {
    @EnvironmentObject var store: DataStore
    @State private var newAffirmationText = ""
    @State private var selectedCategory: Affirmation.Category = .custom
    @State private var selectedPresetIDs: Set<String> = []
    
    // Group preset affirmations by category
    var groupedPresets: [(category: Affirmation.Category, affirmations: [Affirmation])] {
        let grouped = Dictionary(grouping: Affirmation.presets) { $0.category }
        return Affirmation.Category.allCases.compactMap { category in
            guard let affirmations = grouped[category], !affirmations.isEmpty else { return nil }
            return (category, affirmations)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Set Up Affirmations")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Choose positive affirmations to inspire your travels or create your own. These help you set intentions for your stays.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Preset affirmations grouped by category
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Select from preset affirmations:")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(groupedPresets, id: \.category) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                // Category header
                                HStack(spacing: 8) {
                                    Image(systemName: group.category.icon)
                                        .foregroundColor(categoryColor(group.category))
                                    Text(group.category.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(categoryColor(group.category))
                                }
                                .padding(.horizontal)
                                
                                // Affirmations in this category
                                VStack(spacing: 8) {
                                    ForEach(group.affirmations) { affirmation in
                                        Button(action: { togglePresetAffirmation(affirmation) }) {
                                            HStack(alignment: .top, spacing: 12) {
                                                Image(systemName: selectedPresetIDs.contains(affirmation.id) ? "checkmark.circle.fill" : "circle")
                                                    .font(.title3)
                                                    .foregroundColor(selectedPresetIDs.contains(affirmation.id) ? .blue : .gray)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(affirmation.text)
                                                        .font(.body)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.primary)
                                                        .multilineTextAlignment(.leading)
                                                    
                                                    if affirmation.isFavorite {
                                                        HStack(spacing: 4) {
                                                            Image(systemName: "star.fill")
                                                                .font(.caption2)
                                                                .foregroundColor(.yellow)
                                                            Text("Popular")
                                                                .font(.caption)
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                }
                                                
                                                Spacer()
                                            }
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(selectedPresetIDs.contains(affirmation.id) ? categoryColor(affirmation.category).opacity(0.1) : Color(.systemBackground))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(selectedPresetIDs.contains(affirmation.id) ? categoryColor(affirmation.category).opacity(0.3) : Color.clear, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Add custom affirmation section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Or create your own:")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            // Category picker
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(Affirmation.Category.allCases, id: \.self) { category in
                                    HStack {
                                        Image(systemName: category.icon)
                                        Text(category.rawValue)
                                    }
                                    .tag(category)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal)
                            
                            // Text input
                            HStack {
                                TextField("Enter your affirmation...", text: $newAffirmationText, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(2...4)
                                
                                Button(action: addCustomAffirmation) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                .disabled(newAffirmationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                    
                    // Current affirmations list
                    if !store.affirmations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your affirmations (\(store.affirmations.count)):")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(store.affirmations) { affirmation in
                                HStack(spacing: 12) {
                                    Image(systemName: affirmation.category.icon)
                                        .foregroundColor(categoryColor(affirmation.category))
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(affirmation.text)
                                            .font(.body)
                                        Text(affirmation.category.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: { deleteAffirmation(affirmation) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemBackground))
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top)
                    }
                    
                    Text("Tip: You can skip this and add affirmations later from Activities & Affirmations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .onAppear {
            // Sync selectedPresetIDs with what's already in the store
            for affirmation in store.affirmations {
                if let preset = Affirmation.presets.first(where: { $0.text == affirmation.text }) {
                    selectedPresetIDs.insert(preset.id)
                }
            }
            
            // If store is empty, pre-select popular (favorited) affirmations
            if store.affirmations.isEmpty {
                let popularAffirmations = Affirmation.presets.filter { $0.isFavorite }
                for affirmation in popularAffirmations {
                    selectedPresetIDs.insert(affirmation.id)
                    store.addAffirmation(affirmation)
                }
            }
        }
    }
    
    private func categoryColor(_ category: Affirmation.Category) -> Color {
        switch category.defaultColor {
        case "green": return .green
        case "yellow": return .yellow
        case "pink": return .pink
        case "orange": return .orange
        case "purple": return .purple
        case "blue": return .blue
        case "indigo": return .indigo
        case "gray": return .gray
        default: return .blue
        }
    }
    
    private func togglePresetAffirmation(_ affirmation: Affirmation) {
        if selectedPresetIDs.contains(affirmation.id) {
            selectedPresetIDs.remove(affirmation.id)
            // Remove from store
            if let existing = store.affirmations.first(where: { $0.text == affirmation.text }) {
                store.deleteAffirmation(existing)
            }
        } else {
            selectedPresetIDs.insert(affirmation.id)
            // Add to store
            store.addAffirmation(affirmation)
        }
    }
    
    private func addCustomAffirmation() {
        let trimmed = newAffirmationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let affirmation = Affirmation(
            text: trimmed,
            category: selectedCategory,
            color: selectedCategory.defaultColor
        )
        store.addAffirmation(affirmation)
        newAffirmationText = ""
    }
    
    private func deleteAffirmation(_ affirmation: Affirmation) {
        // Remove from selected presets if it's a preset
        if let preset = Affirmation.presets.first(where: { $0.text == affirmation.text }) {
            selectedPresetIDs.remove(preset.id)
        }
        store.deleteAffirmation(affirmation)
    }
}

// MARK: - Preview

struct FirstLaunchWizard_Previews: PreviewProvider {
    static var previews: some View {
        FirstLaunchWizard()
            .environmentObject(DataStore())
    }
}

