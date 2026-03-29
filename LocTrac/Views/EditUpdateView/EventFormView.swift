import SwiftUI
import CoreLocation
import CoreLocationUI
import ContactsUI

struct EventFormView: View {
    @EnvironmentObject var store: DataStore
    @StateObject var viewModel: EventFormViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var focus: Bool?
    @State var toDate = Date().diff(numDays: 1)
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @StateObject var locationManager = LocationManager()
    @State private var showContactsSearch = false
    @State private var geocodeError: String?
    
    // Robust check: selected location matches the store's "Other" by id
    private var isOtherSelected: Bool {
        guard let selected = viewModel.location,
              let other = store.locations.first(where: { $0.name == "Other" }) else { return false }
        return selected.id == other.id
    }

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    getDates
                    getLocation
                    getEventType
                    activitiesSection
                    peopleSection
                    getNotes
                    Section(
                        footer:
                            HStack {
                                Spacer()
                                Button {
                                    performSave()
                                } label: {
                                    Text(viewModel.updating ? "Update Event" : "Add Event")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.incomplete)
                                Spacer()
                            }
                    ) {
                        EmptyView()
                    }
                }
            }
            .navigationTitle(viewModel.updating ? "Update" : "New Stay")
            .onAppear {
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
            }
            .sheet(isPresented: $showContactsSearch) {
                ContactsSearchPicker { contacts in
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
            }
        }
    }
}

struct EventFormView_Previews: PreviewProvider {
    static var previews: some View {
        EventFormView(viewModel: EventFormViewModel())
            .environmentObject(DataStore())
    }
}

extension EventFormView {
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

    private var getDates: some View {
        VStack {
            let startBinding = Binding<Date>(
                get: { localStartOfDay(fromUTCStartOfDay: viewModel.date.startOfDay) },
                set: { newLocalDay in
                    let newUTC = utcStartOfDay(fromLocalStartOfDay: newLocalDay)
                    viewModel.date = newUTC
                    if toDate < viewModel.date {
                        toDate = newUTC
                    }
                }
            )
            DatePicker(selection: startBinding, displayedComponents: .date) {
                Text("Start Date")
            }
            
            let localStart = localStartOfDay(fromUTCStartOfDay: viewModel.date.startOfDay)
            let localRange: ClosedRange<Date> = localStart...Date.distantFuture
            
            let endBinding = Binding<Date>(
                get: { localStartOfDay(fromUTCStartOfDay: toDate.startOfDay) },
                set: { newLocalDay in
                    toDate = utcStartOfDay(fromLocalStartOfDay: newLocalDay)
                }
            )
            DatePicker(selection: endBinding, in: localRange, displayedComponents: .date) {
                Text("End Date")
            }
            .tag(localStartOfDay(fromUTCStartOfDay: toDate.startOfDay))
        }
    }
    
    private var getLocation: some View {
        VStack {
            Picker("Location", selection: $viewModel.location) {
                Text("Select Location").tag(nil as Location?)
                ForEach(store.locations) { location in
                    Text(location.name)
                        .tag(location as Location?)
                }
            }
            
            if isOtherSelected {
                TextField("Enter City", text: Binding(
                    get: { viewModel.city ?? "" },
                    set: { viewModel.city = $0.isEmpty ? nil : $0 }
                ))
                
                // Show coordinates only when location is "Other"
                getCoordinates
            }
        }
    }
        
    private var getEventType: some View {
        Picker("Stay Type", selection: $viewModel.eventType) {
            ForEach(Event.EventType.allCases) { eventType in
                Text("\(eventType.icon) \(eventType.rawValue.capitalized)")
                    .tag(eventType)
            }
        }
    }
    
    private var activitiesSection: some View {
        Section(header: Text("Activities")) {
            if store.activities.isEmpty {
                Text("No activities defined. Use the menu to Manage Activities.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(store.activities) { activity in
                    HStack {
                        Text(activity.name)
                        Spacer()
                        let selected = viewModel.activityIDs.contains(activity.id)
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selected ? .accentColor : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleActivity(activity.id)
                    }
                }
                if !viewModel.activityIDs.isEmpty {
                    Button(role: .destructive) {
                        viewModel.activityIDs.removeAll()
                    } label: {
                        Label("Clear Activities", systemImage: "xmark.circle")
                    }
                }
            }
        }
    }
    
    private func toggleActivity(_ id: String) {
        if let idx = viewModel.activityIDs.firstIndex(of: id) {
            viewModel.activityIDs.remove(at: idx)
        } else {
            viewModel.activityIDs.append(id)
        }
    }
    
    private var peopleSection: some View {
        Section(header: Text("People")) {
            if viewModel.people.isEmpty {
                Text("No people added")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.people) { person in
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.accentColor)
                        Text(person.displayName)
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    viewModel.people.remove(atOffsets: indexSet)
                }
            }
            HStack {
                Button {
                    focus = nil
                    showContactsSearch = true
                } label: {
                    Label("From Contacts", systemImage: "person.crop.circle.badge.plus")
                }
                Spacer()
            }
        }
    }
    
    private var getCoordinates: some View {
        Section(header: Text("Coordinates")) {
            // Get current location button + status
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
            
            let latitudeBinding = Binding<String>(
                get: { latitudeText },
                set: { newValue in
                    latitudeText = newValue
                    if let doubleValue = Double(newValue) {
                        viewModel.latitude = doubleValue
                    }
                }
            )
            
            let longitudeBinding = Binding<String>(
                get: { longitudeText },
                set: { newValue in
                    longitudeText = newValue
                    if let doubleValue = Double(newValue) {
                        viewModel.longitude = doubleValue
                    }
                }
            )

            HStack {
                Text("Latitude")
                    .frame(width: 80, alignment: .leading)
                TextField("0.0", text: latitudeBinding)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Longitude")
                    .frame(width: 80, alignment: .leading)
                TextField("0.0", text: longitudeBinding)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
            }
            
            // Show warning if coordinates are (0.0, 0.0)
            if viewModel.latitude == 0.0 && viewModel.longitude == 0.0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Missing coordinates - country data may not be available")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
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
    
    private var getNotes: some View {
        VStack {
            TextField("Note", text: $viewModel.note, axis: .vertical)
                .focused($focus, equals: true)
        }
    }
    
    // MARK: - Save logic
    private func performSave() {
        Task { @MainActor in
            if viewModel.updating {
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
                
                let event = Event(id: id,
                                  eventType: viewModel.eventType,
                                  date: viewModel.date.startOfDay,
                                  location: selectedLocation,
                                  city: viewModel.city ?? "",
                                  latitude: viewModel.latitude,
                                  longitude: viewModel.longitude,
                                  country: country,
                                  note: viewModel.note,
                                  people: viewModel.people,
                                  activityIDs: viewModel.activityIDs)
                
                store.update(event)
            } else {
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
                    let newEvent = Event(eventType: viewModel.eventType,
                                         date: nextDate,
                                         location: selectedLocation,
                                         city: viewModel.city ?? "",
                                         latitude: viewModel.latitude,
                                         longitude: viewModel.longitude,
                                         country: country,
                                         note: viewModel.note,
                                         people: viewModel.people,
                                         activityIDs: viewModel.activityIDs)
                    store.add(newEvent)
                }
                store.bumpCalendarRefresh()
            }
            dismiss()
        }
    }
}

