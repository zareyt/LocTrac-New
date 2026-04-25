//
//
//  LocationDataEnhancementView.swift
//  LocTrac
//
//  ✅ CORRECT FILE - KEEP THIS ONE
//  ⏰ Last Updated: 2026-04-13 (Process Locations + Events, track skipped)
//  ⚠️ DELETE: LocationDataEnhancementView 2.swift or any duplicates
//

import SwiftUI

struct LocationDataEnhancementView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var debugConfig: DebugConfig
    @Environment(\.dismiss) var dismiss

    @State private var isProcessing = false
    @State private var currentIndex = 0
    @State private var totalItems = 0
    @State private var locationResults: [LocationResult] = []
    @State private var eventResults: [EventResult] = []
    @State private var showResults = false
    @State private var retryQueue: [RetryItem] = []  // Items to retry after rate limiting
    @State private var isRetryingErrors = false  // Track if we're in error retry mode
    @State private var hasCompletedFirstPass = false  // Track if first pass completed
    
    // UserDefaults keys for persistence
    private let hasCompletedKey = "LocationEnhancement.hasCompleted"
    private let locationResultsKey = "LocationEnhancement.locationResults"
    private let eventResultsKey = "LocationEnhancement.eventResults"
    
    // On appear, check if we have saved results
    private func loadSavedResults() {
        if UserDefaults.standard.bool(forKey: hasCompletedKey) {
            // Load saved results
            if let locationData = UserDefaults.standard.data(forKey: locationResultsKey),
               let eventData = UserDefaults.standard.data(forKey: eventResultsKey) {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    locationResults = try decoder.decode([LocationResult].self, from: locationData)
                    eventResults = try decoder.decode([EventResult].self, from: eventData)
                    hasCompletedFirstPass = true
                    showResults = true
                    print("📥 Loaded \(locationResults.count) location results and \(eventResults.count) event results from previous session")
                } catch {
                    print("❌ Failed to load saved results: \(error)")
                }
            }
        }
    }
    
    // Save results after completion
    private func saveResults() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let locationData = try encoder.encode(locationResults)
            let eventData = try encoder.encode(eventResults)
            
            UserDefaults.standard.set(true, forKey: hasCompletedKey)
            UserDefaults.standard.set(locationData, forKey: locationResultsKey)
            UserDefaults.standard.set(eventData, forKey: eventResultsKey)
            print("💾 Saved \(locationResults.count) location results and \(eventResults.count) event results")
        } catch {
            print("❌ Failed to save results: \(error)")
        }
    }
    
    // Clear saved results when starting fresh
    private func clearSavedResults() {
        UserDefaults.standard.removeObject(forKey: hasCompletedKey)
        UserDefaults.standard.removeObject(forKey: locationResultsKey)
        UserDefaults.standard.removeObject(forKey: eventResultsKey)
        print("🗑️ Cleared saved results")
    }
    
    enum RetryItem: Identifiable {
        case location(Location)
        case event(Event)
        
        var id: String {
            switch self {
            case .location(let loc): return "loc-\(loc.id)"
            case .event(let evt): return "evt-\(evt.id)"
            }
        }
    }
    
    struct LocationResult: Identifiable, Codable {
        let id: UUID
        let locationID: String
        let locationName: String
        let originalCity: String?
        let originalState: String?
        let originalCountry: String?
        let newCity: String?
        let newState: String?
        let newCountry: String?
        var result: LocationDataProcessingResult  // ← Make mutable for retry updates
        
        init(id: UUID = UUID(), locationID: String, locationName: String, originalCity: String?, originalState: String?, originalCountry: String?, newCity: String?, newState: String?, newCountry: String?, result: LocationDataProcessingResult) {
            self.id = id
            self.locationID = locationID
            self.locationName = locationName
            self.originalCity = originalCity
            self.originalState = originalState
            self.originalCountry = originalCountry
            self.newCity = newCity
            self.newState = newState
            self.newCountry = newCountry
            self.result = result
        }
    }
    
    struct EventResult: Identifiable, Codable {
        let id: UUID
        let eventID: String
        let eventDate: Date
        let locationName: String
        let originalCity: String?
        let originalState: String?
        let originalCountry: String?
        let newCity: String?
        let newState: String?
        let newCountry: String?
        var result: LocationDataProcessingResult  // ← Make mutable for retry updates
        
        init(id: UUID = UUID(), eventID: String, eventDate: Date, locationName: String, originalCity: String?, originalState: String?, originalCountry: String?, newCity: String?, newState: String?, newCountry: String?, result: LocationDataProcessingResult) {
            self.id = id
            self.eventID = eventID
            self.eventDate = eventDate
            self.locationName = locationName
            self.originalCity = originalCity
            self.originalState = originalState
            self.originalCountry = originalCountry
            self.newCity = newCity
            self.newState = newState
            self.newCountry = newCountry
            self.result = result
        }
    }
    
    var successCount: Int {
        locationResults.filter { if case .success = $0.result { return true }; return false }.count +
        eventResults.filter { if case .success = $0.result { return true }; return false }.count
    }
    
    var errorCount: Int {
        locationResults.filter { if case .error = $0.result { return true }; return false }.count +
        eventResults.filter { if case .error = $0.result { return true }; return false }.count
    }
    
    var skippedCount: Int {
        locationResults.filter { if case .skipped = $0.result { return true }; return false }.count +
        eventResults.filter { if case .skipped = $0.result { return true }; return false }.count
    }
    
    var errorLocationResults: [LocationResult] {
        locationResults.filter {
            if case .error = $0.result { return true }
            return false
        }
    }
    
    var errorEventResults: [EventResult] {
        eventResults.filter {
            if case .error = $0.result { return true }
            return false
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isProcessing {
                    processingView
                } else if showResults {
                    resultsView
                } else {
                    startView
                }
            }
            .navigationTitle("Enhance Location Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
                
                // Add "Start Fresh" button when showing results
                if showResults && !isProcessing {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            clearSavedResults()
                            hasCompletedFirstPass = false
                            locationResults = []
                            eventResults = []
                            showResults = false
                        } label: {
                            Label("Start Fresh", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .onAppear {
                loadSavedResults()
            }
        }
        .debugViewName("LocationDataEnhancementView")
    }
    
    private var startView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "location.magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                Text("Enhance Location Data")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Show resume option if we have saved results
                if hasCompletedFirstPass {
                    VStack(spacing: 12) {
                        Text("Previous session found")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("You have \(errorCount) errors from your last run. You can resume and retry them, or start fresh.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            Button {
                                // Show previous results
                                showResults = true
                            } label: {
                                Label("Resume", systemImage: "arrow.clockwise")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            
                            Button {
                                // Clear and start fresh
                                clearSavedResults()
                                hasCompletedFirstPass = false
                                locationResults = []
                                eventResults = []
                            } label: {
                                Label("Start Fresh", systemImage: "trash")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else {
                    Text("This will process \(store.locations.count) locations and \(store.events.count) events to clean and enhance location data.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    featureItem(icon: "checkmark.circle.fill", text: "Clean city name formats")
                    featureItem(icon: "checkmark.circle.fill", text: "Populate missing states")
                    featureItem(icon: "checkmark.circle.fill", text: "Update countries from GPS")
                    featureItem(icon: "checkmark.circle.fill", text: "Process master locations first")
                    featureItem(icon: "checkmark.circle.fill", text: "Skip named-location events")
                    featureItem(icon: "checkmark.circle.fill", text: "Report unfixable data")
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Processing Steps:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        stepItem(number: "1", text: "If all data exists, clean format")
                        stepItem(number: "2", text: "If GPS exists, use reverse geocoding")
                        stepItem(number: "3", text: "If no GPS, parse city format")
                        stepItem(number: "4", text: "Report errors if unfixable")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                if !hasCompletedFirstPass {
                    Button {
                        Task {
                            await processAllData()
                        }
                    } label: {
                        Label("Start Enhancement", systemImage: "play.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
    }
    
    @ViewBuilder
    private func featureItem(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline)
        }
    }
    
    @ViewBuilder
    private func stepItem(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ProgressView(value: Double(currentIndex), total: Double(totalItems))
                .progressViewStyle(.linear)
                .padding(.horizontal, 40)
            
            VStack(spacing: 8) {
                Text("Processing item \(currentIndex) of \(totalItems)")
                    .font(.headline)
                
                Text("Please wait...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if currentIndex > 0 {
                    Text("\(successCount) successful • \(errorCount) errors • \(skippedCount) skipped")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var resultsView: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(successCount) Successful")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("\(errorCount) Errors")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "arrow.forward.circle.fill")
                        .foregroundColor(.gray)
                    Text("\(skippedCount) Skipped")
                    Spacer()
                }
                
                // Retry Errors Button
                if errorCount > 0 && !isRetryingErrors {
                    Button {
                        Task {
                            await retryErrorsOnly()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.orange)
                            Text("Retry \(errorCount) Errors")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if isRetryingErrors {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("Retrying errors...")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Summary")
            } footer: {
                if errorCount > 0 && !isRetryingErrors {
                    Text("Tap 'Retry Errors' to reprocess only the failed items. This is useful for network errors or rate limiting issues.")
                        .font(.caption)
                } else {
                    Text("Skipped items don't need processing (e.g., events with named locations inherit from their master location).")
                        .font(.caption)
                }
            }
            
            // Location Errors
            if !errorLocationResults.isEmpty {
                Section {
                    ForEach(errorLocationResults) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.purple)
                                Text(result.locationName)
                                    .font(.headline)
                            }
                            
                            if let city = result.originalCity {
                                HStack {
                                    Image(systemName: "building.2")
                                        .foregroundColor(.orange)
                                        .frame(width: 20)
                                    Text("City: \(city)")
                                        .font(.subheadline)
                                }
                            }
                            
                            if let state = result.originalState {
                                HStack {
                                    Image(systemName: "map")
                                        .foregroundColor(.green)
                                        .frame(width: 20)
                                    Text("State: \(state)")
                                        .font(.subheadline)
                                }
                            }
                            
                            if let country = result.originalCountry {
                                HStack {
                                    Image(systemName: "globe")
                                        .foregroundColor(.purple)
                                        .frame(width: 20)
                                    Text("Country: \(country)")
                                        .font(.subheadline)
                                }
                            }
                            
                            if case .error(let message) = result.result {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .frame(width: 20)
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Location Errors (\(errorLocationResults.count))")
                } footer: {
                    Text("These locations need manual review in Locations Management.")
                        .font(.caption)
                }
            }
            
            // Event Errors
            if !errorEventResults.isEmpty {
                Section {
                    ForEach(errorEventResults) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue)
                                Text(result.eventDate.utcMediumDateString)
                                    .font(.headline)
                                Spacer()
                                Text(eventDisplayName(for: result))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let city = result.originalCity {
                                HStack {
                                    Image(systemName: "building.2")
                                        .foregroundColor(.orange)
                                        .frame(width: 20)
                                    Text("City: \(city)")
                                        .font(.subheadline)
                                }
                            }
                            
                            if let state = result.originalState {
                                HStack {
                                    Image(systemName: "map")
                                        .foregroundColor(.green)
                                        .frame(width: 20)
                                    Text("State: \(state)")
                                        .font(.subheadline)
                                }
                            }
                            
                            if let country = result.originalCountry {
                                HStack {
                                    Image(systemName: "globe")
                                        .foregroundColor(.purple)
                                        .frame(width: 20)
                                    Text("Country: \(country)")
                                        .font(.subheadline)
                                }
                            }
                            
                            if case .error(let message) = result.result {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .frame(width: 20)
                                    Text(message)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Event Errors (\(errorEventResults.count))")
                } footer: {
                    Text("These events need manual review. You can edit them in the calendar or from Travel History.")
                        .font(.caption)
                }
            }
            
            // Success Samples
            if successCount > 0 {
                let successfulLocations = locationResults.filter {
                    if case .success = $0.result { return true }
                    return false
                }
                let successfulEvents = eventResults.filter {
                    if case .success = $0.result { return true }
                    return false
                }
                
                Section {
                    // Location samples
                    ForEach(successfulLocations) { result in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.purple)
                                Text(result.locationName)
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            
                            if let newCity = result.newCity {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(.orange)
                                        .frame(width: 20)
                                    Text(newCity)
                                        .font(.subheadline)
                                }
                            }
                            
                            HStack {
                                if let newState = result.newState {
                                    HStack {
                                        Image(systemName: "map.fill")
                                            .foregroundColor(.green)
                                            .frame(width: 20)
                                        Text(newState)
                                            .font(.caption)
                                    }
                                }
                                
                                if let newCountry = result.newCountry {
                                    HStack {
                                        Image(systemName: "globe")
                                            .foregroundColor(.purple)
                                            .frame(width: 20)
                                        Text(newCountry)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Event samples
                    ForEach(successfulEvents) { result in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue)
                                Text(result.eventDate.utcMediumDateString)
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            
                            if let newCity = result.newCity {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(.orange)
                                        .frame(width: 20)
                                    Text(newCity)
                                        .font(.subheadline)
                                }
                            }
                            
                            HStack {
                                if let newState = result.newState {
                                    HStack {
                                        Image(systemName: "map.fill")
                                            .foregroundColor(.green)
                                            .frame(width: 20)
                                        Text(newState)
                                            .font(.caption)
                                    }
                                }
                                
                                if let newCountry = result.newCountry {
                                    HStack {
                                        Image(systemName: "globe")
                                            .foregroundColor(.purple)
                                            .frame(width: 20)
                                        Text(newCountry)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if successCount > 10 {
                        Text("+ \(successCount - 10) more successful updates")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Sample Successful Updates (\(successCount) total)")
                }
            }
        }
    }
    
    /// Returns city name instead of "Other" for Other-location events
    private func eventDisplayName(for result: EventResult) -> String {
        if result.locationName == "Other" {
            return result.newCity ?? result.originalCity ?? result.newCountry ?? result.originalCountry ?? "Other"
        }
        return result.locationName
    }

    private func processAllData() async {
        isProcessing = true
        locationResults = []
        eventResults = []
        retryQueue = []
        currentIndex = 0
        
        // Calculate total items (locations + events)
        await MainActor.run {
            totalItems = store.locations.count + store.events.count
        }
        
        let enhancer = LocationDataEnhancer()
        
        print("🚀 Starting location data enhancement")
        print("   📍 Processing \(store.locations.count) locations")
        print("   📅 Processing \(store.events.count) events")
        print("   📊 Total: \(totalItems) items")
        
        // PHASE 1: Process Locations
        print("\n📍 PHASE 1: Processing Locations")
        let namedLocationsCount = store.locations.filter { $0.name != "Other" }.count
        let alreadyGeocodedLocationsCount = store.locations.filter { $0.name != "Other" && $0.isGeocoded }.count
        print("   📊 Found \(namedLocationsCount) named locations total")
        print("   ✅ Already geocoded: \(alreadyGeocodedLocationsCount)")
        print("   🔄 Need processing: \(namedLocationsCount - alreadyGeocodedLocationsCount)")
        for (index, location) in store.locations.enumerated() {
            await MainActor.run {
                currentIndex = index + 1
            }
            
            let originalCity = location.city
            let originalState = location.state
            let originalCountry = location.country
            
            var mutableLocation = location
            let result = await enhancer.processLocation(&mutableLocation)
            
            await MainActor.run {
                locationResults.append(LocationResult(
                    locationID: location.id,
                    locationName: location.name,
                    originalCity: originalCity,
                    originalState: originalState,
                    originalCountry: originalCountry,
                    newCity: mutableLocation.city,
                    newState: mutableLocation.state,
                    newCountry: mutableLocation.country,
                    result: result
                ))
                
                if case .success = result {
                    print("   ✅ Updated location '\(location.name)' — isGeocoded=\(mutableLocation.isGeocoded)")
                    store.update(mutableLocation)
                    // Verify the flag was persisted
                    if let saved = store.locations.first(where: { $0.id == mutableLocation.id }) {
                        print("   🔍 Verify after save: isGeocoded=\(saved.isGeocoded)")
                    }
                } else if case .retryLater = result {
                    print("   🔄 Rate limited - queuing '\(location.name)' for retry")
                    retryQueue.append(.location(mutableLocation))
                } else if case .skipped = result {
                    // Silent skip
                } else if case .error(let msg) = result {
                    print("   ❌ Location '\(location.name)' error: \(msg)")
                }
            }
            
            // Rate limit: 50ms between items
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        
        // PHASE 2: Process Events
        print("\n📅 PHASE 2: Processing Events")
        let locationCount = store.locations.count
        
        // Count "Other" events for diagnostics
        let otherEventsCount = store.events.filter { $0.location.name == "Other" }.count
        let alreadyGeocodedCount = store.events.filter { $0.location.name == "Other" && $0.isGeocoded }.count
        print("   📊 Found \(otherEventsCount) 'Other' events total")
        print("   ✅ Already geocoded: \(alreadyGeocodedCount)")
        print("   🔄 Need processing: \(otherEventsCount - alreadyGeocodedCount)")
        
        for (index, event) in store.events.enumerated() {
            await MainActor.run {
                currentIndex = locationCount + index + 1
            }
            
            let originalCity = event.city
            let originalState = event.state
            let originalCountry = event.country
            
            var mutableEvent = event
            let result = await enhancer.processEvent(&mutableEvent)
            
            await MainActor.run {
                eventResults.append(EventResult(
                    eventID: event.id,
                    eventDate: event.date,
                    locationName: event.location.name,
                    originalCity: originalCity,
                    originalState: originalState,
                    originalCountry: originalCountry,
                    newCity: mutableEvent.city,
                    newState: mutableEvent.state,
                    newCountry: mutableEvent.country,
                    result: result
                ))
                
                if case .success = result {
                    print("   ✅ Updated event on \(event.date.utcMediumDateString) — isGeocoded=\(mutableEvent.isGeocoded)")
                    store.update(mutableEvent)
                    // Verify the flag was persisted
                    if let saved = store.events.first(where: { $0.id == mutableEvent.id }) {
                        print("   🔍 Verify after save: isGeocoded=\(saved.isGeocoded)")
                    }
                } else if case .retryLater = result {
                    print("   🔄 Rate limited - queuing event on \(event.date.utcMediumDateString) for retry")
                    retryQueue.append(.event(mutableEvent))
                } else if case .skipped = result {
                    // Silent skip for named-location events (no spam)
                } else if case .error(let msg) = result {
                    print("   ❌ Event on \(event.date.utcMediumDateString) (location: '\(event.location.name)') error: \(msg)")
                }
            }
            
            // Rate limit: 50ms between items
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        
        // PHASE 3: Retry Queue
        if !retryQueue.isEmpty {
            print("\n🔄 PHASE 3: Processing Retry Queue (\(retryQueue.count) items)")
            var retryAttempt = 1
            let maxRetries = 3
            
            while !retryQueue.isEmpty && retryAttempt <= maxRetries {
                print("   🔄 Retry attempt \(retryAttempt)/\(maxRetries) - \(retryQueue.count) items remaining")
                let currentRetryQueue = retryQueue
                retryQueue = []
                
                for retryItem in currentRetryQueue {
                    switch retryItem {
                    case .location(var location):
                        let result = await enhancer.processLocation(&location)
                        if case .success = result {
                            print("   ✅ Retry success: location '\(location.name)'")
                            store.update(location)
                            // Update result in locationResults
                            if let index = locationResults.firstIndex(where: { $0.locationID == location.id }) {
                                locationResults[index] = LocationResult(
                                    locationID: location.id,
                                    locationName: location.name,
                                    originalCity: locationResults[index].originalCity,
                                    originalState: locationResults[index].originalState,
                                    originalCountry: locationResults[index].originalCountry,
                                    newCity: location.city,
                                    newState: location.state,
                                    newCountry: location.country,
                                    result: .success
                                )
                            }
                        } else if case .retryLater = result {
                            retryQueue.append(.location(location))
                        } else if case .error(let msg) = result {
                            print("   ❌ Retry failed: location '\(location.name)' - \(msg)")
                            // Update result in locationResults
                            if let index = locationResults.firstIndex(where: { $0.locationID == location.id }) {
                                var updated = locationResults[index]
                                updated.result = .error(msg)
                                locationResults[index] = updated
                            }
                        }
                        
                    case .event(var event):
                        let result = await enhancer.processEvent(&event)
                        if case .success = result {
                            print("   ✅ Retry success: event on \(event.date.utcMediumDateString)")
                            store.update(event)
                            // Update result in eventResults
                            if let index = eventResults.firstIndex(where: { $0.eventID == event.id }) {
                                eventResults[index] = EventResult(
                                    eventID: event.id,
                                    eventDate: event.date,
                                    locationName: event.location.name,
                                    originalCity: eventResults[index].originalCity,
                                    originalState: eventResults[index].originalState,
                                    originalCountry: eventResults[index].originalCountry,
                                    newCity: event.city,
                                    newState: event.state,
                                    newCountry: event.country,
                                    result: .success
                                )
                            }
                        } else if case .retryLater = result {
                            retryQueue.append(.event(event))
                        } else if case .error(let msg) = result {
                            print("   ❌ Retry failed: event on \(event.date.utcMediumDateString) - \(msg)")
                            // Update result in eventResults
                            if let index = eventResults.firstIndex(where: { $0.eventID == event.id }) {
                                var updated = eventResults[index]
                                updated.result = .error(msg)
                                eventResults[index] = updated
                            }
                        }
                    }
                    
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                
                retryAttempt += 1
            }
            
            if !retryQueue.isEmpty {
                print("   ⚠️ \(retryQueue.count) items still failed after \(maxRetries) retry attempts")
                // Mark remaining items as errors
                for retryItem in retryQueue {
                    switch retryItem {
                    case .location(let location):
                        if let index = locationResults.firstIndex(where: { $0.locationID == location.id }) {
                            var updated = locationResults[index]
                            updated.result = .error("Rate limited - max retries exceeded")
                            locationResults[index] = updated
                        }
                    case .event(let event):
                        if let index = eventResults.firstIndex(where: { $0.eventID == event.id }) {
                            var updated = eventResults[index]
                            updated.result = .error("Rate limited - max retries exceeded")
                            eventResults[index] = updated
                        }
                    }
                }
            }
        }
        
        print("\n✅ Enhancement Complete")
        print("   ✅ Success: \(successCount)")
        print("   ❌ Errors: \(errorCount)")
        print("   ⏭️ Skipped: \(skippedCount)")
        print("   📊 'Other' events found: \(otherEventsCount)")
        
        // Count processed "Other" events
        let processedOtherCount = eventResults.filter { result in
            guard result.locationName == "Other" else { return false }
            switch result.result {
            case .success, .error:
                return true
            case .skipped, .retryLater:
                return false
            }
        }.count
        print("   📊 'Other' events processed: \(processedOtherCount)")
        
        await MainActor.run {
            isProcessing = false
            hasCompletedFirstPass = true
            showResults = true
            saveResults()  // Save results for later resume
        }
    }
    
    /// Retry only the items that failed with errors (not skipped items)
    private func retryErrorsOnly() async {
        isRetryingErrors = true
        
        let enhancer = LocationDataEnhancer()
        
        // Collect error items
        let errorLocations = locationResults.enumerated().filter {
            if case .error = $0.element.result { return true }
            return false
        }
        
        let errorEvents = eventResults.enumerated().filter {
            if case .error = $0.element.result { return true }
            return false
        }
        
        let totalErrors = errorLocations.count + errorEvents.count
        print("\n🔄 RETRY ERRORS: Processing \(totalErrors) failed items")
        print("   📍 Locations: \(errorLocations.count)")
        print("   📅 Events: \(errorEvents.count)")
        
        var successCount = 0
        var stillErrorCount = 0
        
        // Retry error locations
        for (index, locationResult) in errorLocations {
            // Find the location in the store
            guard let location = store.locations.first(where: { $0.id == locationResult.locationID }) else {
                print("   ⚠️ Location not found: \(locationResult.locationName)")
                continue
            }
            
            var mutableLocation = location
            let result = await enhancer.processLocation(&mutableLocation)
            
            await MainActor.run {
                if case .success = result {
                    print("   ✅ Retry success: location '\(location.name)'")
                    store.update(mutableLocation)
                    // Update result
                    locationResults[index] = LocationResult(
                        locationID: location.id,
                        locationName: location.name,
                        originalCity: locationResult.originalCity,
                        originalState: locationResult.originalState,
                        originalCountry: locationResult.originalCountry,
                        newCity: mutableLocation.city,
                        newState: mutableLocation.state,
                        newCountry: mutableLocation.country,
                        result: .success
                    )
                    successCount += 1
                } else if case .error(let msg) = result {
                    print("   ❌ Still error: location '\(location.name)' - \(msg)")
                    // Update with new error message
                    var updated = locationResults[index]
                    updated.result = .error(msg)
                    locationResults[index] = updated
                    stillErrorCount += 1
                } else if case .retryLater = result {
                    print("   ⏸️ Rate limited: location '\(location.name)'")
                    var updated = locationResults[index]
                    updated.result = .error("Rate limited - try again")
                    locationResults[index] = updated
                    stillErrorCount += 1
                }
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms between items
        }
        
        // Retry error events
        for (index, eventResult) in errorEvents {
            // Find the event in the store
            guard let event = store.events.first(where: { $0.id == eventResult.eventID }) else {
                print("   ⚠️ Event not found: \(eventResult.eventDate)")
                continue
            }
            
            var mutableEvent = event
            let result = await enhancer.processEvent(&mutableEvent)
            
            await MainActor.run {
                if case .success = result {
                    print("   ✅ Retry success: event on \(event.date.utcMediumDateString)")
                    store.update(mutableEvent)
                    // Update result
                    eventResults[index] = EventResult(
                        eventID: event.id,
                        eventDate: event.date,
                        locationName: event.location.name,
                        originalCity: eventResult.originalCity,
                        originalState: eventResult.originalState,
                        originalCountry: eventResult.originalCountry,
                        newCity: mutableEvent.city,
                        newState: mutableEvent.state,
                        newCountry: mutableEvent.country,
                        result: .success
                    )
                    successCount += 1
                } else if case .error(let msg) = result {
                    print("   ❌ Still error: event on \(event.date.utcMediumDateString) - \(msg)")
                    // Update with new error message
                    var updated = eventResults[index]
                    updated.result = .error(msg)
                    eventResults[index] = updated
                    stillErrorCount += 1
                } else if case .retryLater = result {
                    print("   ⏸️ Rate limited: event on \(event.date.utcMediumDateString)")
                    var updated = eventResults[index]
                    updated.result = .error("Rate limited - try again")
                    eventResults[index] = updated
                    stillErrorCount += 1
                }
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms between items
        }
        
        print("\n✅ Retry Complete")
        print("   ✅ Now successful: \(successCount)")
        print("   ❌ Still errors: \(stillErrorCount)")
        
        await MainActor.run {
            isRetryingErrors = false
            saveResults()  // Save updated results
        }
    }
}
