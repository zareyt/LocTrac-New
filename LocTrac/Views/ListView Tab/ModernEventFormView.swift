//
//  ModernEventFormView.swift
//  LocTrac
//
//  Modern event form with enhanced UI matching Trip Management style
//

import SwiftUI
import CoreLocation
import ContactsUI
import PhotosUI

struct ModernEventFormView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var debugConfig: DebugConfig
    @StateObject var viewModel: EventFormViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var focus: Bool?
    
    @State private var toDate = Date().diff(numDays: 1)
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var showContactsSearch = false
    @State private var showAffirmationsSelector = false
    @State private var showActivitiesPicker = false
    @StateObject var locationManager = LocationManager()
    @State private var geocodeError: String?
    @State private var skippedDays: Int = 0
    @State private var showDuplicateAlert = false
    @State private var showCopyEvent = false
    @State private var dismissAfterCopy = false
    @State private var hasSetupInitialValues = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var imageToDelete: String?
    @State private var showDeleteImageConfirm = false
    
    // UTC calendar for consistent date handling (no timezone issues)
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    // Robust check: selected location matches the store's "Other" by id
    private var isOtherSelected: Bool {
        guard let selected = viewModel.location,
              let other = store.locations.first(where: { $0.name == "Other" }) else { return false }
        return selected.id == other.id
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Location Section - with visual improvements
                locationSection
                
                // Date Range Section
                dateRangeSection
                
                // Event Type Section - now a picker like Trip's transport mode
                eventTypeSection
                
                // People Section (moved above activities)
                peopleSection
                
                // Activities Section (moved below people)
                activitiesSection
                
                // Affirmations Section (NEW)
                affirmationsSection
                
                // Coordinates Section (only for "Other" location)
                if isOtherSelected {
                    coordinatesSection
                }
                
                // Notes Section
                notesSection

                // Photos Section
                photosSection

                // Copy to Dates — edit mode only (add mode auto-popups via performSave)
                if viewModel.updating {
                    copyToDatesSection
                }

                // Save Button Section
                saveButtonSection
            }
            .navigationTitle(viewModel.updating ? "Edit Stay" : "New Stay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialValues()
            }
            .sheet(isPresented: $showContactsSearch) {
                ContactsSearchPicker { contacts in
                    addPeopleFromContacts(contacts)
                }
            }
            .sheet(isPresented: $showActivitiesPicker) {
                ActivityPickerSheet(
                    selectedIDs: $viewModel.activityIDs,
                    activities: store.activities
                )
            }
            .sheet(isPresented: $showAffirmationsSelector) {
                AffirmationSelectorView(selectedAffirmationIDs: $viewModel.affirmationIDs)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showCopyEvent, onDismiss: {
                if dismissAfterCopy {
                    DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] CopyEventView dismissed in add mode — dismissing form")
                    dismissAfterCopy = false
                    dismiss()
                }
            }) {
                if let sourceEvent = buildCurrentEvent() {
                    if dismissAfterCopy {
                        // Add mode: cover full date range, create ALL dates including start
                        CopyEventView(
                            sourceEvent: sourceEvent,
                            skipSourceDate: false,
                            overrideStartDate: viewModel.date.startOfDay,
                            overrideEndDate: toDate.startOfDay
                        )
                        .environmentObject(store)
                    } else {
                        // Edit mode: default behavior (skip source date, user picks range)
                        CopyEventView(sourceEvent: sourceEvent)
                            .environmentObject(store)
                    }
                }
            }
            .alert("Days Skipped", isPresented: $showDuplicateAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                let created = calculateDurationDays() + 1 - skippedDays
                Text("\(skippedDays) day\(skippedDays == 1 ? " was" : "s were") skipped because a stay already exists on \(skippedDays == 1 ? "that date" : "those dates"). \(created) stay\(created == 1 ? " was" : "s were") created.")
            }
        }
        .debugViewName("ModernEventFormView")
    }
    
    // MARK: - Location Section
    @ViewBuilder
    private var locationSection: some View {
        Section {
            // Location Picker with color indicators
            Picker("Location", selection: $viewModel.location) {
                Text("Select Location").tag(nil as Location?)
                ForEach(sortedLocations) { location in
                    HStack {
                        Circle()
                            .fill(Color(location.theme.uiColor))
                            .frame(width: 12, height: 12)
                        Text(location.name)
                    }
                    .tag(location as Location?)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.location) { oldValue, newValue in
                // When location changes, auto-populate fields
                if let location = newValue {
                    populateFieldsFromLocation(location)
                }
            }
            
            // City field
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.orange)
                    .frame(width: 30)
                if isOtherSelected {
                    TextField("City", text: Binding(
                        get: { viewModel.city ?? "" },
                        set: { viewModel.city = $0.isEmpty ? nil : $0 }
                    ))
                } else {
                    Text(viewModel.city ?? "")
                        .foregroundColor(.secondary)
                }
            }

            // State field
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.green)
                    .frame(width: 30)
                if isOtherSelected {
                    TextField("State/Province", text: Binding(
                        get: { viewModel.state ?? "" },
                        set: { viewModel.state = $0.isEmpty ? nil : $0 }
                    ))
                } else {
                    Text(viewModel.state ?? "")
                        .foregroundColor(.secondary)
                }
            }

            // Country field
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.purple)
                    .frame(width: 30)
                if isOtherSelected {
                    TextField("Country", text: Binding(
                        get: { viewModel.country ?? "" },
                        set: { viewModel.country = $0.isEmpty ? nil : $0 }
                    ))
                } else {
                    Text(viewModel.country ?? "")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Label("Location Details", systemImage: "map")
        } footer: {
            if isOtherSelected {
                Text("For 'Other' locations, enter city/state manually. Country will auto-populate from coordinates but can be overridden.")
                    .font(.caption)
            } else if viewModel.location != nil {
                Text("Location details inherited from '\(viewModel.location?.name ?? "")'. Edit in Manage Locations.")
                    .font(.caption)
            } else {
                Text("Select a location to auto-populate location details")
                    .font(.caption)
            }
        }
    }
    
    // Computed property for sorted locations with default first
    private var sortedLocations: [Location] {
        if let defaultLocationID = UserDefaults.standard.string(forKey: "defaultLocationID") {
            var sorted = store.locations
            if let defaultIndex = sorted.firstIndex(where: { $0.id == defaultLocationID }) {
                let defaultLocation = sorted.remove(at: defaultIndex)
                sorted.insert(defaultLocation, at: 0)
            }
            return sorted
        }
        return store.locations
    }
    
    // MARK: - Date Range Section
    private var dateRangeSection: some View {
        Section {
            // Start Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.green)
                    .frame(width: 30)
                
                DatePicker(
                    "Start Date",
                    selection: $viewModel.date,
                    displayedComponents: .date
                )
                .environment(\.calendar, utcCalendar)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            }
            
            // End Date
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundColor(.red)
                    .frame(width: 30)
                
                DatePicker(
                    "End Date",
                    selection: $toDate,
                    in: viewModel.date...Date.distantFuture,
                    displayedComponents: .date
                )
                .environment(\.calendar, utcCalendar)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            }
            
            // Duration indicator
            let days = calculateDurationDays()
            if days > 0 {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    Text("Duration: \(days + 1) day\(days == 0 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Label("Date Range", systemImage: "calendar")
        } footer: {
            if !viewModel.updating && calculateDurationDays() > 0 {
                Text("Multiple events will be created for each day in the range")
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Event Type Section
    private var eventTypeSection: some View {
        Section {
            Picker("Stay Type", selection: $viewModel.eventType) {
                ForEach(store.eventTypes) { item in
                    Label(item.displayName, systemImage: item.sfSymbol)
                        .foregroundStyle(item.color)
                        .tag(item.name)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Label("Stay Type", systemImage: "tag")
        } footer: {
            Text("Select the type of stay for this event")
                .font(.caption)
        }
    }
    
    // MARK: - Activities Section
    private var activitiesSection: some View {
        Section {
            if store.activities.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("No activities available")
                        .foregroundColor(.secondary)
                }
            } else if viewModel.activityIDs.isEmpty {
                Button {
                    showActivitiesPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.green)
                        Text("Add Activities")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Selected activities as compact chips
                ActivityChipsView(
                    activityIDs: $viewModel.activityIDs,
                    activities: store.activities
                )

                Button {
                    showActivitiesPicker = true
                } label: {
                    Label("Add, Modify, Delete Activities", systemImage: "pencil.circle")
                }

                Button(role: .destructive) {
                    viewModel.activityIDs.removeAll()
                } label: {
                    Label("Clear All", systemImage: "xmark.circle")
                }
            }
        } header: {
            HStack {
                Label("Activities", systemImage: "figure.walk")
                Spacer()
                Text("\(viewModel.activityIDs.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Affirmations Section
    private var affirmationsSection: some View {
        Section {
            if viewModel.affirmationIDs.isEmpty {
                // Empty state - show button to add affirmations
                Button {
                    showAffirmationsSelector = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        Text("Add Affirmations")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Display selected affirmations
                ForEach(selectedAffirmations) { affirmation in
                    HStack(spacing: 12) {
                        Image(systemName: affirmation.category.icon)
                            .foregroundStyle(Color(affirmation.color).gradient)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(affirmation.text)
                                .font(.subheadline)
                                .lineLimit(2)
                            Text(affirmation.category.rawValue)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if affirmation.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let affirmation = selectedAffirmations[index]
                        viewModel.affirmationIDs.removeAll { $0 == affirmation.id }
                    }
                }
                
                // Add more button
                Button {
                    showAffirmationsSelector = true
                } label: {
                    Label("Manage Affirmations", systemImage: "pencil.circle")
                }
                
                if !viewModel.affirmationIDs.isEmpty {
                    Button(role: .destructive) {
                        viewModel.affirmationIDs.removeAll()
                    } label: {
                        Label("Clear All Affirmations", systemImage: "xmark.circle")
                    }
                }
            }
        } header: {
            HStack {
                Label("Affirmations", systemImage: "sparkles")
                Spacer()
                Text("\(viewModel.affirmationIDs.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } footer: {
            Text("Add positive affirmations to set your intentions for this stay")
                .font(.caption)
        }
    }
    
    private var selectedAffirmations: [Affirmation] {
        viewModel.affirmationIDs.compactMap { id in
            store.affirmations.first(where: { $0.id == id })
        }
    }
    
    // MARK: - People Section
    private var peopleSection: some View {
        Section {
            if viewModel.people.isEmpty {
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.purple)
                    Text("No people added")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(viewModel.people) { person in
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.purple)
                            .font(.title2)
                        Text(person.displayName)
                        Spacer()
                        Button {
                            if let index = viewModel.people.firstIndex(where: { $0.id == person.id }) {
                                viewModel.people.remove(at: index)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Button {
                focus = nil
                showContactsSearch = true
            } label: {
                Label("Add from Contacts", systemImage: "person.crop.circle.badge.plus")
                    .foregroundColor(.blue)
            }
        } header: {
            HStack {
                Label("People", systemImage: "person.2.fill")
                Spacer()
                Text("\(viewModel.people.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Coordinates Section
    private var coordinatesSection: some View {
        Section {
            VStack(spacing: 12) {
                // Fetch current location button and status
                HStack {
                    Button {
                        geocodeError = nil
                        locationManager.requestCurrentLocation()
                    } label: {
                        if locationManager.isRequestInFlight {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.8)
                                Text("Getting Current Location…")
                            }
                        } else {
                            Label("Get Current Location", systemImage: "location.circle.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer(minLength: 8)
                    
                    // Show quick status/error
                    if let msg = locationManager.errorMessage ?? geocodeError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    } else if locationManager.location != nil && !locationManager.isRequestInFlight {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Location updated")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // When we get a fix, update fields and reverse geocode city
                .onChange(of: locationManager.location) { _, newValue in
                    guard let loc = newValue else { return }
                    viewModel.latitude = loc.coordinate.latitude
                    viewModel.longitude = loc.coordinate.longitude
                    latitudeText = String(viewModel.latitude)
                    longitudeText = String(viewModel.longitude)
                    
                    Task {
                        await reverseGeocodeAndSetCity(for: loc)
                    }
                }
                
                // Latitude
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text("Latitude")
                        .frame(width: 80, alignment: .leading)
                    Spacer()
                    TextField("0.0", text: Binding<String>(
                        get: { latitudeText },
                        set: { newValue in
                            latitudeText = newValue
                            if let doubleValue = Double(newValue) {
                                viewModel.latitude = doubleValue
                            }
                        }
                    ))
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                }
                
                Divider()
                
                // Longitude
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text("Longitude")
                        .frame(width: 80, alignment: .leading)
                    Spacer()
                    TextField("0.0", text: Binding<String>(
                        get: { longitudeText },
                        set: { newValue in
                            longitudeText = newValue
                            if let doubleValue = Double(newValue) {
                                viewModel.longitude = doubleValue
                            }
                        }
                    ))
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                }
                
                // Warning if coordinates are missing
                if viewModel.latitude == 0.0 && viewModel.longitude == 0.0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Coordinates needed for accurate country data")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        } header: {
            Label("Coordinates", systemImage: "location.circle")
        } footer: {
            Text("GPS coordinates used to auto-populate city, state, and country information")
                .font(.caption)
        }
    }
    
    // MARK: - Helper: Populate fields from location
    private func populateFieldsFromLocation(_ location: Location) {
        if location.name == "Other" {
            // For "Other", clear fields but keep coordinates at 0,0
            // User will need to enter manually or use "Get Current Location"
            viewModel.city = nil
            viewModel.state = nil
            viewModel.country = nil
            viewModel.latitude = 0
            viewModel.longitude = 0
            latitudeText = "0.0"
            longitudeText = "0.0"
        } else {
            // For named locations, populate from location data
            viewModel.city = location.city
            viewModel.state = location.state
            viewModel.country = location.country
            viewModel.latitude = location.latitude
            viewModel.longitude = location.longitude
            latitudeText = String(location.latitude)
            longitudeText = String(location.longitude)
        }
    }
    
    @MainActor
    private func reverseGeocodeAndSetCity(for location: CLLocation) async {
        geocodeError = nil
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                // Auto-populate city
                let city = placemark.locality ?? placemark.administrativeArea ?? ""
                if !city.isEmpty {
                    viewModel.city = city
                }
                
                // Auto-populate state/province
                if let state = placemark.administrativeArea {
                    viewModel.state = state
                }
                
                // Auto-populate country
                if let country = placemark.country {
                    viewModel.country = country
                }
            }
        } catch {
            geocodeError = "Could not determine location details"
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        Section {
            TextEditor(text: $viewModel.note)
                .frame(minHeight: 80)
                .focused($focus, equals: true)
        } header: {
            Label("Notes", systemImage: "note.text")
        }
    }

    // MARK: - Photos Section
    private var photosSection: some View {
        Section {
            if !viewModel.imageIDs.isEmpty {
                TabView {
                    ForEach(viewModel.imageIDs, id: \.self) { imageID in
                        ZStack(alignment: .topTrailing) {
                            if let uiImage = ImageStore.load(filename: imageID) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 260)
                                    .clipped()
                                    .cornerRadius(12)
                            } else {
                                Color.gray.opacity(0.2)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .imageScale(.large)
                                            .foregroundColor(.secondary)
                                    )
                                    .frame(height: 260)
                                    .cornerRadius(12)
                            }
                            Button {
                                imageToDelete = imageID
                                showDeleteImageConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.red.opacity(0.8))
                                    .clipShape(Capsule())
                                    .padding()
                            }
                            .accessibilityLabel("Delete Photo")
                        }
                    }
                }
                .frame(height: 260)
                .tabViewStyle(PageTabViewStyle())
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            let remaining = 6 - viewModel.imageIDs.count
            if remaining > 0 {
                PhotosPicker(
                    selection: $photoItems,
                    maxSelectionCount: remaining,
                    matching: .images
                ) {
                    Label(
                        viewModel.imageIDs.isEmpty ? "Add Photos" : "Add More (\(remaining) remaining)",
                        systemImage: "photo.badge.plus"
                    )
                }
                .onChange(of: photoItems) { _, items in
                    guard !items.isEmpty else { return }
                    Task {
                        await saveEventPhotos(items)
                    }
                }
            }
        } header: {
            Label("Photos (\(viewModel.imageIDs.count)/6)", systemImage: "camera.fill")
        } footer: {
            Text("Swipe to browse photos. Add up to 6 per stay.")
                .font(.caption)
        }
        .confirmationDialog("Delete Photo?", isPresented: $showDeleteImageConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let imageID = imageToDelete {
                    deleteEventImage(imageID)
                }
            }
        }
    }

    private func saveEventPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { continue }
            if let filename = try? ImageStore.save(image: uiImage) {
                await MainActor.run {
                    viewModel.imageIDs.append(filename)
                }
                DebugConfig.shared.log(.dataStore, "📸 [EventForm] Saved photo: \(filename)")
            }
        }
        await MainActor.run {
            photoItems = []
        }
    }

    private func deleteEventImage(_ imageID: String) {
        viewModel.imageIDs.removeAll { $0 == imageID }
        ImageStore.delete(filename: imageID)
        imageToDelete = nil
        DebugConfig.shared.log(.dataStore, "📸 [EventForm] Deleted photo: \(imageID)")
    }

    // MARK: - Copy to Dates Section
    private var copyToDatesSection: some View {
        Section {
            Button {
                DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] 'Copy to Other Dates' tapped, updating=\(viewModel.updating), duration=\(calculateDurationDays()) days")
                showCopyEvent = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                    Text("Copy to Other Dates...")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(viewModel.location == nil)
        } header: {
            Label("Copy", systemImage: "doc.on.doc")
        } footer: {
            Text("Copy this stay's data to a range of other dates with conflict resolution")
                .font(.caption)
        }
    }

    /// Build an Event from the current form state (for copy source).
    private func buildCurrentEvent() -> Event? {
        guard let location = viewModel.location else {
            DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] buildCurrentEvent: no location selected, returning nil")
            return nil
        }
        let eventID = viewModel.id ?? UUID().uuidString
        DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] buildCurrentEvent: id=\(eventID), location='\(location.name)', date=\(viewModel.date.utcMediumDateString)")
        return Event(
            id: eventID,
            eventTypeRaw: viewModel.eventType,
            date: viewModel.date.startOfDay,
            location: location,
            city: viewModel.city,
            latitude: viewModel.latitude,
            longitude: viewModel.longitude,
            country: viewModel.country,
            state: viewModel.state,
            note: viewModel.note,
            people: viewModel.people,
            activityIDs: viewModel.activityIDs,
            affirmationIDs: viewModel.affirmationIDs,
            isGeocoded: viewModel.id.flatMap { id in store.events.first(where: { $0.id == id })?.isGeocoded } ?? false,
            imageIDs: viewModel.imageIDs
        )
    }

    // MARK: - Save Button Section
    private var saveButtonSection: some View {
        Section {
            Button {
                performSave()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: viewModel.updating ? "checkmark.circle.fill" : "plus.circle.fill")
                    Text(viewModel.updating ? "Update Stay" : "Create Stay")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .foregroundColor(.white)
                .padding()
                .background(viewModel.incomplete ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .disabled(viewModel.incomplete)
            .listRowBackground(Color.clear)
        }
    }
    
    // MARK: - Helper Functions
    
    private func setupInitialValues() {
        guard !hasSetupInitialValues else { return }
        hasSetupInitialValues = true
        focus = true
        if viewModel.updating {
            print("📅 [DATE DEBUG] === EDITING EXISTING EVENT ===")
            print("📅 [DATE DEBUG] Original viewModel.date: \(viewModel.date)")
            print("📅 [DATE DEBUG] Original viewModel.date.startOfDay: \(viewModel.date.startOfDay)")
            
            // ⚠️ DO NOT convert the date here!
            // The DatePicker's binding will handle UTC→Local conversion
            // If we convert here, then the binding converts AGAIN, causing double-conversion
            
            // Just ensure the date is normalized to start of day
            viewModel.date = viewModel.date.startOfDay
            toDate = viewModel.date.startOfDay
            
            print("📅 [DATE DEBUG] Normalized viewModel.date (UTC): \(viewModel.date)")
            print("📅 [DATE DEBUG] This will be converted by DatePicker binding")
            print("📅 [DATE DEBUG] === END EDITING SETUP ===\n")
            
            // When editing, ensure text fields are synced with viewModel
            latitudeText = String(viewModel.latitude)
            longitudeText = String(viewModel.longitude)
            
            // For named locations (not "Other"), refresh from current store location data
            // The event's embedded location snapshot may be stale (e.g., missing city/state
            // added after the event was created). Look up the live location from the store.
            if let embeddedLocation = viewModel.location, embeddedLocation.name != "Other",
               let currentLocation = store.locations.first(where: { $0.id == embeddedLocation.id }) {
                // Check if user had manually overridden values vs the embedded snapshot
                // If values match the stale snapshot (or are nil), refresh from current store data
                if viewModel.city == embeddedLocation.city &&
                   viewModel.state == embeddedLocation.state &&
                   viewModel.country == embeddedLocation.country {
                    populateFieldsFromLocation(currentLocation)
                    viewModel.location = currentLocation
                }
                // Otherwise keep the user's overridden values
            }
        } else if let selected = viewModel.dateSelected {
            // When creating from a selected date, use UTC start of day
            // DatePicker binding will convert to local for display
            viewModel.date = selected.startOfDay
            toDate = viewModel.toDateSelected?.startOfDay ?? selected.startOfDay
            latitudeText = String(viewModel.latitude)
            longitudeText = String(viewModel.longitude)
        } else {
            // Default to today (UTC start of day)
            // DatePicker binding will convert to local for display
            viewModel.date = Date().startOfDay
            toDate = Date().startOfDay
            latitudeText = String(viewModel.latitude)
            longitudeText = String(viewModel.longitude)
        }
        
        // Set default location if none is selected (only for new events)
        if !viewModel.updating && viewModel.location == nil {
            if let defaultLocationID = UserDefaults.standard.string(forKey: "defaultLocationID"),
               let defaultLocation = store.locations.first(where: { $0.id == defaultLocationID }) {
                viewModel.location = defaultLocation
                // Populate fields from default location
                populateFieldsFromLocation(defaultLocation)
            }
        }
    }
    
    private func localStartOfDay(fromUTCStartOfDay utc: Date) -> Date {
        // Extract Y/M/D from UTC midnight
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let ymd = utcCal.dateComponents([.year, .month, .day], from: utc)
        print("📅 [CONVERT UTC→Local] Input UTC: \(utc)")
        print("📅 [CONVERT UTC→Local] Extracted Y/M/D: \(ymd.year ?? 0)/\(ymd.month ?? 0)/\(ymd.day ?? 0)")
        
        // Create local midnight for the SAME CALENDAR DATE
        // This creates a Date that represents midnight in the user's timezone
        // Example: Apr 15 midnight MT = Apr 15 06:00 UTC
        let localCal = Calendar.current
        print("📅 [CONVERT DEBUG] Calendar.current.timeZone = \(localCal.timeZone.identifier)")
        print("📅 [CONVERT DEBUG] Calendar.current.timeZone.secondsFromGMT = \(localCal.timeZone.secondsFromGMT())")
        print("📅 [CONVERT DEBUG] TimeZone.current.identifier = \(TimeZone.current.identifier)")
        print("📅 [CONVERT DEBUG] TimeZone.current.secondsFromGMT = \(TimeZone.current.secondsFromGMT())")
        
        var components = DateComponents()
        components.year = ymd.year
        components.month = ymd.month
        components.day = ymd.day
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        print("📅 [CONVERT DEBUG] Components before date creation: year=\(components.year ?? 0), month=\(components.month ?? 0), day=\(components.day ?? 0), hour=\(components.hour ?? 99)")
        print("📅 [CONVERT DEBUG] Creating date from components in local calendar...")
        // Create the date - this will be midnight local time
        guard let result = localCal.date(from: components) else {
            print("📅 [CONVERT ERROR] Failed to create date from components!")
            return utc
        }
        
        print("📅 [CONVERT DEBUG] Raw result from localCal.date(from:): \(result)")
        print("📅 [CONVERT DEBUG] Result displayed in UTC: \(result)")
        
        // Try to extract components BACK from the result to see what we actually got
        let verifyComponents = localCal.dateComponents([.year, .month, .day, .hour, .minute, .timeZone], from: result)
        print("📅 [CONVERT DEBUG] Verification - extracted back: year=\(verifyComponents.year ?? 0), month=\(verifyComponents.month ?? 0), day=\(verifyComponents.day ?? 0), hour=\(verifyComponents.hour ?? 99), tz=\(verifyComponents.timeZone?.identifier ?? "nil")")
        
        print("📅 [CONVERT UTC→Local] Result local date: \(result)")
        print("📅 [CONVERT UTC→Local] Local timezone: \(TimeZone.current.identifier)")
        
        // Debug: Show what DatePicker will actually display
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        print("📅 [CONVERT UTC→Local] DatePicker will show: \(formatter.string(from: result))\n")
        return result
    }
    
    private func utcStartOfDay(fromLocalStartOfDay local: Date) -> Date {
        // Extract Y/M/D from local date
        let localCal = Calendar.current
        let ymd = localCal.dateComponents([.year, .month, .day], from: local)
        print("📅 [CONVERT Local→UTC] Input local: \(local)")
        print("📅 [CONVERT Local→UTC] Extracted Y/M/D: \(ymd.year ?? 0)/\(ymd.month ?? 0)/\(ymd.day ?? 0)")
        
        // Create UTC midnight for the same calendar date
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.year = ymd.year
        components.month = ymd.month
        components.day = ymd.day
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        // Use the UTC calendar to create the date
        guard let result = utcCal.date(from: components) else { return local.startOfDay }
        
        print("📅 [CONVERT Local→UTC] Result UTC date: \(result)")
        print("📅 [CONVERT Local→UTC] UTC start of day: \(result.startOfDay)\n")
        return result
    }
    
    private func calculateDurationDays() -> Int {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = viewModel.date.startOfDay
        let end = toDate.startOfDay
        return utcCalendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
    
    private func toggleActivity(_ id: String) {
        if let idx = viewModel.activityIDs.firstIndex(of: id) {
            viewModel.activityIDs.remove(at: idx)
        } else {
            viewModel.activityIDs.append(id)
        }
    }
    
    private func addPeopleFromContacts(_ contacts: [CNContact]) {
        let newPeople = contacts.map { cn in
            Person(
                displayName: CNContactFormatter.string(from: cn, style: .fullName) ?? "Unknown",
                contactIdentifier: cn.identifier
            )
        }
        var set = Set(viewModel.people)
        for p in newPeople { set.insert(p) }
        viewModel.people = Array(set)
        focus = nil
    }
    
    // MARK: - Save Logic
    private func performSave() {
        Task { @MainActor in
            if viewModel.updating {
                DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] performSave: updating existing event \(viewModel.id ?? "nil")")
                await updateExistingEvent()
                dismiss()
            } else {
                let duration = calculateDurationDays()
                DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] performSave: new event, duration=\(duration) days")

                // For multi-day ranges, redirect to CopyEventView so user can
                // choose which fields to copy and resolve any conflicts per-date
                if duration > 0 {
                    DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] Redirecting to CopyEventView for field selection (add mode, \(duration + 1) days)")
                    dismissAfterCopy = true
                    showCopyEvent = true
                    return
                }
                await createNewEvents()
                // If days were skipped, show alert before dismissing
                if skippedDays == 0 {
                    dismiss()
                }
                // Otherwise the duplicate alert's OK button will dismiss
            }
        }
    }

    /// Check if any dates in the multi-day range already have events.
    private func hasConflictsInRange() -> Bool {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = viewModel.date.startOfDay
        let days = utcCal.dateComponents([.day], from: start, to: toDate.startOfDay).day ?? 0
        let existingDates = Set(store.events.map { $0.date.startOfDay })

        for n in 0...days {
            guard let date = utcCal.date(byAdding: .day, value: n, to: start) else { continue }
            if existingDates.contains(date) {
                DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] Conflict found on \(date.utcMediumDateString)")
                return true
            }
        }
        DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] No conflicts in date range")
        return false
    }
    
    private func updateExistingEvent() async {
        guard let id = viewModel.id else { return }
        guard let selectedLocation = viewModel.location else { return }

        // Detect if location changed — reset isGeocoded so Enhance Location Data re-processes
        let originalEvent = store.events.first(where: { $0.id == id })
        let locationChanged = originalEvent?.location.id != selectedLocation.id
        if locationChanged {
            DebugConfig.shared.log(.dataStore, "🔄 [EventForm] Location changed from '\(originalEvent?.location.name ?? "nil")' to '\(selectedLocation.name)' — resetting isGeocoded")
        }

        // Use manually entered country if available, otherwise auto-detect
        let country: String?
        if let manualCountry = viewModel.country, !manualCountry.isEmpty {
            country = manualCountry
        } else {
            country = await store.updateEventCountry(Event(
                id: id,
                eventTypeRaw: viewModel.eventType,
                date: viewModel.date.startOfDay,
                location: selectedLocation,
                city: viewModel.city ?? "",
                latitude: viewModel.latitude,
                longitude: viewModel.longitude,
                note: viewModel.note
            ))
        }

        // Preserve isGeocoded unless location changed
        let shouldKeepGeocoded = !locationChanged && (originalEvent?.isGeocoded ?? false)
        DebugConfig.shared.log(.dataStore, "📍 [EventForm] Updating event \(id): isGeocoded=\(shouldKeepGeocoded) (locationChanged=\(locationChanged), original=\(originalEvent?.isGeocoded ?? false))")

        let event = Event(
            id: id,
            eventTypeRaw: viewModel.eventType,
            date: viewModel.date.startOfDay,
            location: selectedLocation,
            city: viewModel.city ?? "",
            latitude: viewModel.latitude,
            longitude: viewModel.longitude,
            country: country,
            state: viewModel.state,  // v1.5: Save state
            note: viewModel.note,
            people: viewModel.people,
            activityIDs: viewModel.activityIDs,
            affirmationIDs: viewModel.affirmationIDs,
            isGeocoded: shouldKeepGeocoded,
            imageIDs: viewModel.imageIDs
        )

        store.update(event)
    }
    
    private func createNewEvents() async {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = viewModel.date.startOfDay
        let end = toDate.startOfDay
        let days = utcCalendar.dateComponents([.day], from: start, to: end).day ?? 0
        guard let selectedLocation = viewModel.location else { return }

        // Use manually entered country if available, otherwise auto-detect
        let country: String?
        if let manualCountry = viewModel.country, !manualCountry.isEmpty {
            country = manualCountry
        } else {
            country = await store.updateEventCountry(Event(
                eventTypeRaw: viewModel.eventType,
                date: start,
                location: selectedLocation,
                city: viewModel.city ?? "",
                latitude: viewModel.latitude,
                longitude: viewModel.longitude,
                note: viewModel.note
            ))
        }

        // Build set of dates that already have events for quick lookup
        let existingEventDates = Set(store.events.map { $0.date.startOfDay })
        var skipped = 0

        for n in 0...days {
            guard let nextDate = utcCalendar.date(byAdding: .day, value: n, to: start) else { continue }

            // Skip days that already have an event (one stay per day rule)
            if existingEventDates.contains(nextDate) {
                skipped += 1
                #if DEBUG
                print("⚠️ [EventForm] Skipped \(nextDate) — event already exists on this date")
                #endif
                continue
            }

            let newEvent = Event(
                eventTypeRaw: viewModel.eventType,
                date: nextDate,
                location: selectedLocation,
                city: viewModel.city ?? "",
                latitude: viewModel.latitude,
                longitude: viewModel.longitude,
                country: country,
                state: viewModel.state,  // v1.5: Save state
                note: viewModel.note,
                people: viewModel.people,
                activityIDs: viewModel.activityIDs,
                affirmationIDs: viewModel.affirmationIDs,
                imageIDs: n == 0 ? viewModel.imageIDs : []  // Photos on first day only
            )
            store.add(newEvent)
        }

        skippedDays = skipped
        if skipped > 0 {
            showDuplicateAlert = true
        }

        store.bumpCalendarRefresh()
    }
}

// MARK: - Activity Chips (inline display)
struct ActivityChipsView: View {
    @Binding var activityIDs: [String]
    let activities: [Activity]

    var body: some View {
        FlowLayoutActivities(spacing: 6) {
            ForEach(selectedActivities) { activity in
                HStack(spacing: 4) {
                    Text(activity.name)
                        .font(.system(size: 13, weight: .medium))
                    Button {
                        activityIDs.removeAll { $0 == activity.id }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(Capsule())
            }
        }
    }

    private var selectedActivities: [Activity] {
        activityIDs.compactMap { id in activities.first { $0.id == id } }
    }
}

// MARK: - Activity Picker Sheet
struct ActivityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIDs: [String]
    let activities: [Activity]

    var body: some View {
        NavigationStack {
            List {
                ForEach(activities) { activity in
                    let isSelected = selectedIDs.contains(activity.id)
                    Button {
                        toggleActivity(activity.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? .green : .secondary)
                            Text(activity.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .listRowBackground(isSelected ? Color.green.opacity(0.08) : Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Select Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear All", role: .destructive) {
                        selectedIDs.removeAll()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }

    private func toggleActivity(_ id: String) {
        if let idx = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: idx)
        } else {
            selectedIDs.append(id)
        }
    }
}

// MARK: - Flow Layout for Activity Chips
struct FlowLayoutActivities: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxWidth = max(maxWidth, x)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Preview
struct ModernEventFormView_Previews: PreviewProvider {
    static var previews: some View {
        ModernEventFormView(viewModel: EventFormViewModel())
            .environmentObject(DataStore(preview: true))
    }
}

