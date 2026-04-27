//
//  ModernEventsCalendarView.swift
//  LocTrac
//
//  Modern calendar view with enhanced filtering and information display
//

import SwiftUI
import Contacts
import CoreLocation
import PhotosUI

enum CalendarFilterMode: String, CaseIterable {
    case location = "Location"
    case activities = "Activities"
    case people = "People"
    
    var icon: String {
        switch self {
        case .location: return "mappin.circle.fill"
        case .activities: return "figure.walk"
        case .people: return "person.2.fill"
        }
    }
}

struct ModernEventsCalendarView: View {
    @EnvironmentObject var store: DataStore
    @State private var dateSelected: DateComponents?
    @State private var displayEvents = false
    @State private var formType: EventFormType?
    @State private var filterMode: CalendarFilterMode = .location
    @State private var calendarRefreshTrigger: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter selector
                filterSection
                
                // Calendar
                ScrollView {
                    ModernCalendarView(
                        interval: DateInterval(start: .distantPast, end: .distantFuture),
                        store: store,
                        dateSelected: $dateSelected,
                        displayEvents: $displayEvents,
                        filterMode: filterMode,
                        refreshTrigger: calendarRefreshTrigger
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        displayEvents = false
                        if let ds = dateSelected {
                            formType = .new(ds)
                        } else {
                            var cal = Calendar(identifier: .gregorian)
                            cal.timeZone = TimeZone(secondsFromGMT: 0)!
                            let comps = cal.dateComponents([.year, .month, .day], from: Date())
                            formType = .new(comps)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                }
            }
            .navigationDestination(item: $formType) { formType in
                formType.body
            }
            .sheet(isPresented: $displayEvents) {
                ModernDaysEventsListView(
                    dateSelected: $dateSelected,
                    filterMode: filterMode
                )
                .presentationDetents([.medium, .large])
            }
            .navigationTitle("Stays Calendar")
            .onChange(of: dateSelected) { oldValue, newValue in
                guard let date = newValue?.date else { return }
                let eventsForDate = store.events.filter { $0.date.startOfDay == date.startOfDay }
                
                #if DEBUG
                print("\n📅 [Calendar] Date selected: \(date.formatted(date: .abbreviated, time: .omitted))")
                print("   Events found: \(eventsForDate.count)")
                store.debugPrintEventsForDate(date)
                #endif
                
                if !eventsForDate.isEmpty {
                    formType = nil
                    displayEvents = true
                } else {
                    displayEvents = false
                    if let ds = newValue {
                        formType = .new(ds)
                    }
                }
            }
            // NEW: Listen for calendar refresh token changes
            .onChange(of: store.calendarRefreshToken) { oldValue, newValue in
                #if DEBUG
                print("🔄 [ModernEventsCalendarView] Calendar refresh token changed!")
                print("   Old token: \(oldValue)")
                print("   New token: \(newValue)")
                print("   Incrementing calendarRefreshTrigger from \(calendarRefreshTrigger) to \(calendarRefreshTrigger + 1)")
                #endif
                calendarRefreshTrigger += 1
            }
        }
    }
    
    private var filterSection: some View {
        VStack(spacing: 8) {
            Text("Filter by")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                ForEach(CalendarFilterMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            filterMode = mode
                            // Trigger calendar refresh when filter changes
                            calendarRefreshTrigger += 1
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                            Text(mode.rawValue)
                        }
                        .font(.subheadline)
                        .fontWeight(filterMode == mode ? .semibold : .regular)
                        .foregroundColor(filterMode == mode ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(filterMode == mode ? Color.blue : Color(.tertiarySystemBackground))
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Modern Calendar View (UIKit Wrapper)
struct ModernCalendarView: UIViewRepresentable {
    let interval: DateInterval
    @ObservedObject var store: DataStore
    @Binding var dateSelected: DateComponents?
    @Binding var displayEvents: Bool
    let filterMode: CalendarFilterMode
    let refreshTrigger: Int  // Trigger to force refresh when filter changes
    
    func makeUIView(context: Context) -> some UICalendarView {
        let view = UICalendarView()
        view.delegate = context.coordinator
        view.calendar = Calendar(identifier: .gregorian)
        view.availableDateRange = interval
        let dateSelection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        view.selectionBehavior = dateSelection
        context.coordinator.calendarView = view
        return view
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, store: _store)
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        // Detect changes that require a broader decoration reload
        let filterModeChanged = context.coordinator.filterMode != filterMode
        let refreshTriggerChanged = context.coordinator.lastRefreshTrigger != refreshTrigger
        
        context.coordinator.filterMode = filterMode
        context.coordinator.lastRefreshTrigger = refreshTrigger
        
        // Targeted refreshes for single-day changes
        if let changedEvent = store.changedEvent {
            uiView.reloadDecorations(forDateComponents: [changedEvent.dateComponents], animated: true)
        }
        if let movedEvent = store.movedEvent {
            uiView.reloadDecorations(forDateComponents: [movedEvent.dateComponents], animated: true)
        }
        
        // Read the token to participate in SwiftUI update cycles,
        // but avoid triggering a 3-month reload unless we really need to.
        _ = store.calendarRefreshToken
        
        // Only reload the visible 3-month window when the filter mode or explicit refresh trigger changes
        if filterModeChanged || refreshTriggerChanged {
            if DebugConfig.shared.isEnabled && DebugConfig.shared.logCalendar {
                print("📅 [calendar] Filter/trigger changed → reloading decorations window")
            }
            context.coordinator.reloadThreeMonthWindow()
        }
    }
    
    class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: ModernCalendarView
        @ObservedObject var store: DataStore
        weak var calendarView: UICalendarView?
        var filterMode: CalendarFilterMode = .location
        var lastRefreshTrigger: Int = 0
        
        init(parent: ModernCalendarView, store: ObservedObject<DataStore>) {
            self.parent = parent
            self._store = store
            self.filterMode = parent.filterMode
            self.lastRefreshTrigger = parent.refreshTrigger
        }
        
        @MainActor
        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            
            guard let date = calendar.date(from: dateComponents) else {
                return nil
            }
            
            let GMT = TimeZone(secondsFromGMT: 0)!
            var GMTDateComponents = calendar.dateComponents(in: GMT, from: date)
            GMTDateComponents.hour = 0
            GMTDateComponents.minute = 0
            GMTDateComponents.second = 0
            
            guard let GMTDate = calendar.date(from: GMTDateComponents) else {
                return nil
            }
            
            let foundEvents = store.events.filter {
                let eventGMTDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: $0.date, matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)!
                return calendar.isDate(eventGMTDate, inSameDayAs: GMTDate)
            }
            
            if foundEvents.isEmpty { return nil }
            
            // Multiple events indicator
            if foundEvents.count > 1 {
                switch filterMode {
                case .location:
                    return .image(UIImage(systemName: "circle.grid.2x2.fill"),
                                  color: .systemBlue,
                                  size: .large)
                case .activities:
                    return .image(UIImage(systemName: "list.bullet.circle.fill"),
                                  color: .systemOrange,
                                  size: .large)
                case .people:
                    return .image(UIImage(systemName: "person.2.circle.fill"),
                                  color: .systemPurple,
                                  size: .large)
                }
            }
            
            // Single event decoration based on filter mode
            let singleEvent = foundEvents.first!
            
            switch filterMode {
            case .location:
                // Try to get the location from the store first
                let locationIndex = singleEvent.getLocationIndex(locations: self.store.locations, location: singleEvent.location) ?? 0
                let locationFromStore = self.store.locations[locationIndex]
                
                // Use the event's embedded location color (which should be updated when location changes)
                let eventColor = UIColor(singleEvent.location.effectiveColor)
                
                #if DEBUG
                if DebugConfig.shared.isEnabled && DebugConfig.shared.logCalendar {
                    print("📅 [calendar] Decoration for \(dateComponents): \(singleEvent.location.name) theme=\(singleEvent.location.theme.rawValue) customHex=\(singleEvent.location.customColorHex ?? "nil")")
                }
                #endif
                
                return UICalendarView.Decoration.default(color: eventColor, size: .large)
                
            case .activities:
                if !singleEvent.activityIDs.isEmpty {
                    return .image(UIImage(systemName: "figure.walk.circle.fill"),
                                  color: .systemGreen,
                                  size: .large)
                } else {
                    return .default(color: .systemGray, size: .small)
                }
                
            case .people:
                if !singleEvent.people.isEmpty {
                    return .image(UIImage(systemName: "person.circle.fill"),
                                  color: .systemPink,
                                  size: .large)
                } else {
                    return .default(color: .systemGray, size: .small)
                }
            }
        }
        
        func dateSelection(_ selection: UICalendarSelectionSingleDate,
                           didSelectDate dateComponents: DateComponents?) {
            parent.dateSelected = dateComponents
            guard let dateComponents else { return }
            let foundEvents = store.events
                .filter { $0.date.startOfDay == dateComponents.date?.startOfDay }
            if !foundEvents.isEmpty {
                parent.displayEvents.toggle()
            }
        }
        
        func dateSelection(_ selection: UICalendarSelectionSingleDate,
                           canSelectDate dateComponents: DateComponents?) -> Bool {
            true
        }
        
        @MainActor
        func reloadThreeMonthWindow() {
            #if DEBUG
            print("\n🔄 ========== CALENDAR RELOAD START ==========")
            #endif
            
            guard let view = calendarView else {
                #if DEBUG
                print("❌ [Coordinator] Calendar view is nil!")
                #endif
                return
            }
            let cal = view.calendar
            
            // Prefer the visible month from the calendar, fall back to selected or today
            let anchor: Date
            let visibleComponents = view.visibleDateComponents
            if let visibleDate = cal.date(from: visibleComponents) {
                anchor = visibleDate
                #if DEBUG
                print("🔍 [Coordinator] Reloading based on visible month: \(visibleDate.formatted(date: .abbreviated, time: .omitted))")
                #endif
            } else if let selectedDate = parent.dateSelected?.date {
                anchor = selectedDate
                #if DEBUG
                print("🔍 [Coordinator] Reloading based on selected date: \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                #endif
            } else {
                anchor = Date()
                #if DEBUG
                print("🔍 [Coordinator] Reloading based on today: \(Date().formatted(date: .abbreviated, time: .omitted))")
                #endif
            }
            
            guard let currentMonth = cal.dateInterval(of: .month, for: anchor),
                  let prevMonthStart = cal.date(byAdding: .month, value: -1, to: currentMonth.start),
                  let prevMonth = cal.dateInterval(of: .month, for: prevMonthStart),
                  let nextMonthStart = cal.date(byAdding: .month, value: 1, to: currentMonth.start),
                  let nextMonth = cal.dateInterval(of: .month, for: nextMonthStart) else {
                #if DEBUG
                print("❌ [Coordinator] Failed to calculate month intervals!")
                #endif
                return
            }
            
            let totalStart = prevMonth.start
            let totalEnd = nextMonth.end
            
            #if DEBUG
            if DebugConfig.shared.isEnabled && DebugConfig.shared.logCalendar {
                print("📅 [calendar] Reloading decorations from \(totalStart.formatted(date: .abbreviated, time: .omitted)) to \(totalEnd.formatted(date: .abbreviated, time: .omitted))")
            }
            #endif
            
            var comps: [DateComponents] = []
            var cursor = totalStart
            while cursor <= totalEnd {
                comps.append(cal.dateComponents([.year, .month, .day], from: cursor))
                guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            
            #if DEBUG
            if DebugConfig.shared.isEnabled && DebugConfig.shared.logCalendar {
                print("📅 [calendar] Reloading \(comps.count) days of decorations")
            }
            #endif
            view.reloadDecorations(forDateComponents: comps, animated: true)
            #if DEBUG
            if DebugConfig.shared.isEnabled && DebugConfig.shared.logCalendar {
                print("📅 [calendar] Reload complete!")
            }
            #endif
        }
    }
}

// MARK: - Modern Days Events List
struct ModernDaysEventsListView: View {
    @EnvironmentObject var store: DataStore
    @Binding var dateSelected: DateComponents?
    let filterMode: CalendarFilterMode
    @State private var selectedEvent: Event?
    
    var body: some View {
        NavigationStack {
            Group {
                if let dateSelected {
                    let foundEvents = store.events
                        .filter { $0.date.startOfDay == dateSelected.date!.startOfDay }
                        .sorted { $0.date < $1.date }
                    
                    if foundEvents.isEmpty {
                        emptyState
                    } else {
                        eventsList(foundEvents)
                    }
                } else {
                    Text("No date selected")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(dateSelected?.date?.utcLongDateString ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedEvent) { event in
                ModernEventEditorSheet(event: event)
                    .environmentObject(store)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("No Events")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func eventsList(_ events: [Event]) -> some View {
        List {
            // Stats section
            Section {
                statsRow(for: events)
            }
            
            // Events
            Section("Events (\(events.count))") {
                ForEach(events) { event in
                    ModernEventRow(event: event, filterMode: filterMode)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEvent = event
                        }
                }
                .onDelete { offsets in
                    for index in offsets {
                        store.delete(events[index])
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func statsRow(for events: [Event]) -> some View {
        HStack(spacing: 16) {
            StatPill(
                icon: "mappin.circle.fill",
                value: "\(Set(events.map(\.location.id)).count)",
                label: "Locations",
                color: .blue
            )
            
            StatPill(
                icon: "figure.walk",
                value: "\(events.flatMap(\.activityIDs).count)",
                label: "Activities",
                color: .green
            )
            
            StatPill(
                icon: "person.2.fill",
                value: "\(events.flatMap(\.people).count)",
                label: "People",
                color: .purple
            )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Modern Event Row
struct ModernEventRow: View {
    @EnvironmentObject var store: DataStore
    let event: Event
    let filterMode: CalendarFilterMode
    
    private var locationColor: Color {
        Color(store.locations[event.getLocationIndex(locations: store.locations, location: event.location) ?? 0].theme.uiColor)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with location badge only (no time display)
            HStack {
                Spacer()
                
                // Location badge
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                    Text(event.location.name)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(locationColor.opacity(0.2))
                .foregroundColor(locationColor)
                .cornerRadius(8)
            }
            
            // Location details
            VStack(alignment: .leading, spacing: 4) {
                if let city = event.city {
                    HStack(spacing: 6) {
                        Image(systemName: "building.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(city)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let country = event.country {
                            Text("• \(country)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Activities (if any)
            if !event.activityIDs.isEmpty {
                let activities = event.activityIDs.compactMap { id in
                    store.activities.first(where: { $0.id == id })
                }
                
                if !activities.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(.caption2)
                            Text("Activities")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.secondary)
                        
                        FlowLayout(spacing: 6) {
                            ForEach(activities, id: \.id) { activity in
                                Text(activity.name)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundColor(.green)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            
            // People (if any)
            if !event.people.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("People")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.secondary)
                    
                    FlowLayout(spacing: 6) {
                        ForEach(event.people, id: \.id) { person in
                            Text(person.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.15))
                                .foregroundColor(.purple)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            // Notes
            if !event.note.isEmpty {
                Text(event.note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Photos thumbnail strip
            if !event.imageIDs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(event.imageIDs, id: \.self) { imageID in
                            if let uiImage = ImageStore.load(filename: imageID) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Modern Event Editor Sheet
struct ModernEventEditorSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    let event: Event
    
    @State private var selectedLocation: Location
    @State private var eventDate: Date
    @State private var eventType: String
    @State private var city: String
    @State private var state: String  // v1.5: State/province
    @State private var country: String
    @State private var notes: String
    @State private var selectedPeople: [Person]
    @State private var selectedActivityIDs: [String]
    @State private var selectedAffirmationIDs: Set<String>
    @State private var showingContactsPicker = false
    @State private var showingAffirmationsSelector = false
    @State private var showingActivitiesPicker = false
    @State private var latitude: Double
    @State private var longitude: Double
    @State private var latitudeText: String
    @State private var longitudeText: String
    @StateObject private var locationManager = LocationManager()
    @State private var geocodeError: String?
    @State private var showCopyEvent = false
    @State private var imageIDs: [String]
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var imageToDelete: String?
    @State private var showDeleteImageConfirm = false

    // UTC calendar for consistent date handling (no timezone issues)
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    // Check if "Other" location is selected
    private var isOtherSelected: Bool {
        guard let other = store.locations.first(where: { $0.name == "Other" }) else { return false }
        return selectedLocation.id == other.id
    }
    
    init(event: Event) {
        #if DEBUG
        print("📅 [ModernEventEditorSheet INIT] Initializing for event:")
        print("📅   - Event ID: \(event.id)")
        print("📅   - Event date (raw): \(event.date)")
        print("📅   - Event date (startOfDay): \(event.date.startOfDay)")
        #endif
        
        self.event = event
        _selectedLocation = State(initialValue: event.location)
        _eventDate = State(initialValue: event.date.startOfDay)  // Normalize to start of day
        _eventType = State(initialValue: event.eventType)
        _city = State(initialValue: event.city ?? "")
        _state = State(initialValue: event.state ?? "")  // v1.5: Initialize state
        _country = State(initialValue: event.country ?? "")
        _notes = State(initialValue: event.note)
        _selectedPeople = State(initialValue: event.people)
        _selectedActivityIDs = State(initialValue: event.activityIDs)
        _selectedAffirmationIDs = State(initialValue: Set(event.affirmationIDs))
        _latitude = State(initialValue: event.latitude)
        _longitude = State(initialValue: event.longitude)
        _latitudeText = State(initialValue: String(event.latitude))
        _longitudeText = State(initialValue: String(event.longitude))
        _imageIDs = State(initialValue: event.imageIDs)

        #if DEBUG
        print("📅   - Initialized eventDate: \(event.date.startOfDay)")
        #endif
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Location Section - matching Travel History style
                Section {
                    Picker("Location", selection: $selectedLocation) {
                        ForEach(store.locations, id: \.id) { location in
                            HStack {
                                Circle()
                                    .fill(Color(location.theme.uiColor))
                                    .frame(width: 12, height: 12)
                                Text(location.name)
                            }
                            .tag(location)
                        }
                    }
                    .onChange(of: selectedLocation) { oldValue, newValue in
                        // Auto-populate fields from location
                        populateFieldsFromLocation(newValue)
                    }
                    
                    // City field with icon
                    HStack {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        if isOtherSelected {
                            TextField("City", text: $city)
                        } else {
                            Text(city.isEmpty ? "" : city)
                                .foregroundColor(.secondary)
                        }
                    }

                    // State field with icon
                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundColor(.green)
                            .frame(width: 30)
                        if isOtherSelected {
                            TextField("State/Province", text: $state)
                        } else {
                            Text(state.isEmpty ? "" : state)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Country field with icon
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.purple)
                            .frame(width: 30)
                        if isOtherSelected {
                            TextField("Country", text: $country)
                        } else {
                            Text(country.isEmpty ? "" : country)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Location Details", systemImage: "map")
                } footer: {
                    if isOtherSelected {
                        Text("For 'Other' locations, enter city/state manually. Country will auto-populate from coordinates but can be overridden.")
                            .font(.caption)
                    } else {
                        Text("Location details inherited from '\(selectedLocation.name)'. Edit in Manage Locations.")
                            .font(.caption)
                    }
                }
                
                // Coordinates Section (only for "Other" location)
                if isOtherSelected {
                    coordinatesSection
                }
                
                // Date & Time
                Section("Date & Time") {
                    DatePicker(
                        "Event Date",
                        selection: $eventDate,
                        displayedComponents: .date
                    )
                    .environment(\.calendar, utcCalendar)
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                    #if DEBUG
                    .onChange(of: eventDate) { oldValue, newValue in
                        print("📅 [ModernEventEditorSheet] DatePicker changed:")
                        print("📅   - Old: \(oldValue)")
                        print("📅   - New: \(newValue)")
                        print("📅   - New (startOfDay): \(newValue.startOfDay)")
                    }
                    #endif
                }
                
                // Stay Type Section
                Section {
                    Picker("Stay Type", selection: $eventType) {
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
                }
                
                // Activities Section
                Section {
                    if store.activities.isEmpty {
                        Text("No activities available")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else if selectedActivityIDs.isEmpty {
                        Button {
                            showingActivitiesPicker = true
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
                        ActivityChipsView(
                            activityIDs: $selectedActivityIDs,
                            activities: store.activities
                        )

                        Button {
                            showingActivitiesPicker = true
                        } label: {
                            Label("Add, Modify, Delete Activities", systemImage: "pencil.circle")
                        }

                        Button(role: .destructive) {
                            selectedActivityIDs.removeAll()
                        } label: {
                            Label("Clear All", systemImage: "xmark.circle")
                        }
                    }
                } header: {
                    HStack {
                        Label("Activities", systemImage: "figure.walk")
                        Spacer()
                        Text("\(selectedActivityIDs.count) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Affirmations Section
                Section {
                    if store.affirmations.isEmpty {
                        Text("No affirmations available")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else if selectedAffirmationIDs.isEmpty {
                        Button {
                            showingAffirmationsSelector = true
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.blue)
                                Text("Add Affirmations")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        ForEach(Array(selectedAffirmationIDs), id: \.self) { affirmationID in
                            if let affirmation = store.affirmations.first(where: { $0.id == affirmationID }) {
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
                                    
                                    Button {
                                        selectedAffirmationIDs.remove(affirmationID)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        Button {
                            showingAffirmationsSelector = true
                        } label: {
                            Label("Manage Affirmations", systemImage: "pencil.circle")
                        }
                    }
                } header: {
                    Text("Affirmations")
                } footer: {
                    Text("\(selectedAffirmationIDs.count) selected")
                }
                
                // People Section
                Section("People") {
                    ForEach(selectedPeople) { person in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            Text(person.displayName)
                            Spacer()
                            Button {
                                selectedPeople.removeAll { $0.id == person.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Add person button - opens contacts picker
                    Button {
                        showingContactsPicker = true
                    } label: {
                        Label("Add from Contacts", systemImage: "person.crop.circle.badge.plus")
                    }
                }
                
                // Notes Section
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                // Photos Section (editable)
                Section {
                    if !imageIDs.isEmpty {
                        TabView {
                            ForEach(imageIDs, id: \.self) { imageID in
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

                    let remaining = 6 - imageIDs.count
                    if remaining > 0 {
                        PhotosPicker(
                            selection: $photoItems,
                            maxSelectionCount: remaining,
                            matching: .images
                        ) {
                            Label(
                                imageIDs.isEmpty ? "Add Photos" : "Add More (\(remaining) remaining)",
                                systemImage: "photo.badge.plus"
                            )
                        }
                        .onChange(of: photoItems) { _, items in
                            guard !items.isEmpty else { return }
                            Task {
                                await saveEditorPhotos(items)
                            }
                        }
                    }
                } header: {
                    Label("Photos (\(imageIDs.count)/6)", systemImage: "camera.fill")
                } footer: {
                    Text("Swipe to browse photos. Add up to 6 per stay.")
                        .font(.caption)
                }
                .confirmationDialog("Delete Photo?", isPresented: $showDeleteImageConfirm, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        if let id = imageToDelete {
                            imageIDs.removeAll { $0 == id }
                            ImageStore.delete(filename: id)
                            imageToDelete = nil
                        }
                    }
                }

                // Copy to Other Dates Section
                Section {
                    Button {
                        DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] 'Copy to Other Dates' tapped from ModernEventEditorSheet, event=\(event.id)")
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
                } header: {
                    Label("Copy", systemImage: "doc.on.doc")
                } footer: {
                    Text("Copy this stay's data to a range of other dates with conflict resolution")
                        .font(.caption)
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Refresh city/state/country from the current store location
                // The event's embedded snapshot may be stale (missing fields added later)
                if selectedLocation.name != "Other",
                   let currentLocation = store.locations.first(where: { $0.id == selectedLocation.id }) {
                    if city == (event.city ?? "") && state == (event.state ?? "") && country == (event.country ?? "") {
                        populateFieldsFromLocation(currentLocation)
                        selectedLocation = currentLocation
                    }
                }
            }
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
                }
            }
            .sheet(isPresented: $showingActivitiesPicker) {
                ActivityPickerSheet(
                    selectedIDs: $selectedActivityIDs,
                    activities: store.activities
                )
            }
            .sheet(isPresented: $showingContactsPicker) {
                ContactsSearchPicker { contacts in
                    let newPeople = contacts.map { cn in
                        Person(
                            displayName: CNContactFormatter.string(from: cn, style: .fullName) ?? "Unknown",
                            contactIdentifier: cn.identifier
                        )
                    }
                    // Add only unique people
                    var peopleSet = Set(selectedPeople)
                    for person in newPeople {
                        peopleSet.insert(person)
                    }
                    selectedPeople = Array(peopleSet)
                }
            }
            .sheet(isPresented: $showingAffirmationsSelector) {
                AffirmationSelectorView(selectedAffirmationIDs: Binding(
                    get: { Array(selectedAffirmationIDs) },
                    set: { selectedAffirmationIDs = Set($0) }
                ))
                .environmentObject(store)
            }
            .sheet(isPresented: $showCopyEvent) {
                CopyEventView(sourceEvent: buildCurrentEventForCopy())
                    .environmentObject(store)
            }
        }
    }

    /// Build an Event from the current editor state for use as CopyEventView source.
    private func buildCurrentEventForCopy() -> Event {
        return Event(
            id: event.id,
            eventTypeRaw: eventType,
            date: eventDate.startOfDay,
            location: selectedLocation,
            city: city,
            latitude: latitude,
            longitude: longitude,
            country: country,
            state: state,
            note: notes,
            people: selectedPeople,
            activityIDs: selectedActivityIDs,
            affirmationIDs: Array(selectedAffirmationIDs),
            isGeocoded: event.isGeocoded,
            imageIDs: imageIDs
        )
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
                    latitude = loc.coordinate.latitude
                    longitude = loc.coordinate.longitude
                    latitudeText = String(latitude)
                    longitudeText = String(longitude)
                    
                    print("🔍 [LocationManager] Got location - Latitude: \(latitude), Longitude: \(longitude)")
                    
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
                                latitude = doubleValue
                                print("🔍 [Latitude TextField] Updated to: \(latitude)")
                            } else {
                                print("⚠️ [Latitude TextField] Failed to parse: \(newValue)")
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
                                longitude = doubleValue
                                print("🔍 [Longitude TextField] Updated to: \(longitude)")
                            } else {
                                print("⚠️ [Longitude TextField] Failed to parse: \(newValue)")
                            }
                        }
                    ))
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                }
                
                // Warning if coordinates are missing
                if latitude == 0.0 && longitude == 0.0 {
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
                // Auto-populate city
                let cityName = placemark.locality ?? placemark.administrativeArea ?? ""
                if !cityName.isEmpty {
                    city = cityName
                }
                
                // Auto-populate state/province
                if let stateName = placemark.administrativeArea {
                    state = stateName
                }
                
                // Auto-populate country
                if let countryName = placemark.country {
                    country = countryName
                }
            }
        } catch {
            geocodeError = "Could not determine location details"
        }
    }
    
    // Helper: Populate fields from location
    private func populateFieldsFromLocation(_ location: Location) {
        if location.name == "Other" {
            // For "Other", keep existing event values or clear if needed
            // (User will use GPS or manual entry)
        } else {
            // For named locations, populate from location data
            city = location.city ?? ""
            state = location.state ?? ""
            country = location.country ?? ""
            latitude = location.latitude
            longitude = location.longitude
            latitudeText = String(location.latitude)
            longitudeText = String(location.longitude)
        }
    }
    
    private func saveEditorPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { continue }
            if let filename = try? ImageStore.save(image: uiImage) {
                await MainActor.run {
                    imageIDs.append(filename)
                }
            }
        }
        await MainActor.run {
            photoItems = []
        }
    }

    private func saveChanges() {
        #if DEBUG
        print("🔍 [ModernEventEditorSheet] Saving event:")
        print("   Event ID: \(event.id)")
        print("   Original event.date: \(event.date)")
        print("   Current eventDate: \(eventDate)")
        print("   Current eventDate.startOfDay: \(eventDate.startOfDay)")
        print("   Latitude: \(latitude)")
        print("   Longitude: \(longitude)")
        print("   Location: \(selectedLocation.name)")
        #endif
        
        // Update event properties
        var updatedEvent = event
        updatedEvent.location = selectedLocation
        updatedEvent.date = eventDate.startOfDay  // Normalize to start of day in UTC
        updatedEvent.eventType = eventType  // Save the event type
        updatedEvent.city = city
        updatedEvent.state = state  // v1.5: Save state
        updatedEvent.country = country
        updatedEvent.note = notes
        updatedEvent.people = selectedPeople
        updatedEvent.activityIDs = selectedActivityIDs
        updatedEvent.affirmationIDs = Array(selectedAffirmationIDs)
        updatedEvent.latitude = latitude
        updatedEvent.longitude = longitude
        updatedEvent.imageIDs = imageIDs
        
        #if DEBUG
        print("   Updated Event - Date: \(updatedEvent.date)")
        print("   Updated Event - Latitude: \(updatedEvent.latitude), Longitude: \(updatedEvent.longitude)")
        #endif
        
        // Save via store
        if let index = store.events.firstIndex(where: { $0.id == event.id }) {
            store.events[index] = updatedEvent
            
            #if DEBUG
            print("   After assignment to store - Date: \(store.events[index].date)")
            print("   After assignment to store - Latitude: \(store.events[index].latitude), Longitude: \(store.events[index].longitude)")
            #endif
            
            store.save()
        }
        
        dismiss()
    }
}

// MARK: - Helper Views

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Note: FlowLayout is defined in InfographicsView.swift and shared across the project

// MARK: - Preview
struct ModernEventsCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        ModernEventsCalendarView()
            .environmentObject(DataStore(preview: true))
    }
}

