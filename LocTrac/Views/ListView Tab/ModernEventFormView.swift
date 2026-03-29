//
//  ModernEventFormView.swift
//  LocTrac
//
//  Modern event form with enhanced UI matching Trip Management style
//

import SwiftUI
import CoreLocation
import ContactsUI

struct ModernEventFormView: View {
    @EnvironmentObject var store: DataStore
    @StateObject var viewModel: EventFormViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var focus: Bool?
    
    @State private var toDate = Date().diff(numDays: 1)
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var showContactsSearch = false
    @StateObject var locationManager = LocationManager()
    @State private var geocodeError: String?
    
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
                
                // Coordinates Section (only for "Other" location)
                if isOtherSelected {
                    coordinatesSection
                }
                
                // Notes Section
                notesSection
                
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
        }
    }
    
    // MARK: - Location Section
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
            
            // City field (for "Other" location)
            if isOtherSelected {
                HStack {
                    Image(systemName: "building.2")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    TextField("City Name", text: Binding(
                        get: { viewModel.city ?? "" },
                        set: { viewModel.city = $0.isEmpty ? nil : $0 }
                    ))
                }
            }
        } header: {
            Label("Location Details", systemImage: "map")
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
                    selection: Binding<Date>(
                        get: { localStartOfDay(fromUTCStartOfDay: viewModel.date.startOfDay) },
                        set: { newLocalDay in
                            let newUTC = utcStartOfDay(fromLocalStartOfDay: newLocalDay)
                            viewModel.date = newUTC
                            if toDate < viewModel.date {
                                toDate = newUTC
                            }
                        }
                    ),
                    displayedComponents: .date
                )
            }
            
            // End Date
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundColor(.red)
                    .frame(width: 30)
                
                let localStart = localStartOfDay(fromUTCStartOfDay: viewModel.date.startOfDay)
                let localRange: ClosedRange<Date> = localStart...Date.distantFuture
                
                DatePicker(
                    "End Date",
                    selection: Binding<Date>(
                        get: { localStartOfDay(fromUTCStartOfDay: toDate.startOfDay) },
                        set: { newLocalDay in
                            toDate = utcStartOfDay(fromLocalStartOfDay: newLocalDay)
                        }
                    ),
                    in: localRange,
                    displayedComponents: .date
                )
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
                ForEach(Event.EventType.allCases) { eventType in
                    Text("\(eventType.icon) \(eventType.rawValue.capitalized)")
                        .tag(eventType)
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
                    Spacer()
                    Button("Manage") {
                        // Optional: open activities management
                    }
                    .font(.subheadline)
                }
            } else {
                ForEach(store.activities) { activity in
                    Toggle(isOn: Binding(
                        get: { viewModel.activityIDs.contains(activity.id) },
                        set: { _ in toggleActivity(activity.id) }
                    )) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.green)
                            Text(activity.name)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                
                if !viewModel.activityIDs.isEmpty {
                    Button(role: .destructive) {
                        viewModel.activityIDs.removeAll()
                    } label: {
                        Label("Clear All Activities", systemImage: "xmark.circle")
                    }
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
            Text("Coordinates are required for 'Other' locations to determine country information")
                .font(.caption)
        }
    }
    
    @MainActor
    private func reverseGeocodeAndSetCity(for location: CLLocation) async {
        geocodeError = nil
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let city = placemark.locality ?? placemark.administrativeArea ?? ""
                if !city.isEmpty {
                    viewModel.city = city
                }
            }
        } catch {
            geocodeError = "Could not determine city"
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
        focus = true
        if viewModel.updating {
            let localExisting = localStartOfDay(fromUTCStartOfDay: viewModel.date.startOfDay)
            viewModel.date = localExisting
            toDate = localExisting
        } else if let selected = viewModel.dateSelected {
            let localSelected = localStartOfDay(fromUTCStartOfDay: selected.startOfDay)
            viewModel.date = localSelected
            toDate = localSelected
        } else {
            let todayLocal = localStartOfDay(fromUTCStartOfDay: Date().startOfDay)
            viewModel.date = todayLocal
            toDate = todayLocal
        }
        latitudeText = String(viewModel.latitude)
        longitudeText = String(viewModel.longitude)
        
        // Set default location if none is selected (only for new events)
        if !viewModel.updating && viewModel.location == nil {
            if let defaultLocationID = UserDefaults.standard.string(forKey: "defaultLocationID"),
               let defaultLocation = store.locations.first(where: { $0.id == defaultLocationID }) {
                viewModel.location = defaultLocation
                viewModel.latitude = defaultLocation.latitude
                viewModel.longitude = defaultLocation.longitude
                latitudeText = String(viewModel.latitude)
                longitudeText = String(viewModel.longitude)
            }
        }
    }
    
    private func localStartOfDay(fromUTCStartOfDay utc: Date) -> Date {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let ymd = utcCal.dateComponents([.year, .month, .day], from: utc)
        var localCal = Calendar.current
        localCal.timeZone = TimeZone.current
        return localCal.date(from: ymd) ?? utc
    }
    
    private func utcStartOfDay(fromLocalStartOfDay local: Date) -> Date {
        var localCal = Calendar.current
        localCal.timeZone = TimeZone.current
        let ymd = localCal.dateComponents([.year, .month, .day], from: local)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        return utcCal.date(from: ymd) ?? local.startOfDay
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
                await updateExistingEvent()
            } else {
                await createNewEvents()
            }
            dismiss()
        }
    }
    
    private func updateExistingEvent() async {
        guard let id = viewModel.id else { return }
        guard let selectedLocation = viewModel.location else { return }
        
        let country = await store.updateEventCountry(Event(
            id: id,
            eventType: viewModel.eventType,
            date: viewModel.date.startOfDay,
            location: selectedLocation,
            city: viewModel.city ?? "",
            latitude: viewModel.latitude,
            longitude: viewModel.longitude,
            note: viewModel.note
        ))
        
        let event = Event(
            id: id,
            eventType: viewModel.eventType,
            date: viewModel.date.startOfDay,
            location: selectedLocation,
            city: viewModel.city ?? "",
            latitude: viewModel.latitude,
            longitude: viewModel.longitude,
            country: country,
            note: viewModel.note,
            people: viewModel.people,
            activityIDs: viewModel.activityIDs
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
        
        let country = await store.updateEventCountry(Event(
            eventType: viewModel.eventType,
            date: start,
            location: selectedLocation,
            city: viewModel.city ?? "",
            latitude: viewModel.latitude,
            longitude: viewModel.longitude,
            note: viewModel.note
        ))
        
        for n in 0...days {
            guard let nextDate = utcCalendar.date(byAdding: .day, value: n, to: start) else { continue }
            let newEvent = Event(
                eventType: viewModel.eventType,
                date: nextDate,
                location: selectedLocation,
                city: viewModel.city ?? "",
                latitude: viewModel.latitude,
                longitude: viewModel.longitude,
                country: country,
                note: viewModel.note,
                people: viewModel.people,
                activityIDs: viewModel.activityIDs
            )
            store.add(newEvent)
        }
        store.bumpCalendarRefresh()
    }
}

// MARK: - Preview
struct ModernEventFormView_Previews: PreviewProvider {
    static var previews: some View {
        ModernEventFormView(viewModel: EventFormViewModel())
            .environmentObject(DataStore(preview: true))
    }
}

