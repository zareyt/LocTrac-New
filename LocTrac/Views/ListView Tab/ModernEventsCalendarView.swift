//
//  ModernEventsCalendarView.swift
//  LocTrac
//
//  Modern calendar view with enhanced filtering and information display
//

import SwiftUI
import Contacts

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
            .onChange(of: store.calendarRefreshToken) { _, _ in
                print("🔄 Calendar refresh token changed - forcing calendar update")
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
            print("🔄 [ModernCalendarView] Filter/trigger changed → reloading decorations window")
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
                let eventColor: UIColor = self.store.locations[singleEvent.getLocationIndex(locations: self.store.locations, location: singleEvent.location) ?? 0].theme.uiColor
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
            guard let view = calendarView else { return }
            let cal = view.calendar
            
            // Prefer the visible month from the calendar, fall back to selected or today
            let anchor: Date
            let visibleComponents = view.visibleDateComponents
            if let visibleDate = cal.date(from: visibleComponents) {
                anchor = visibleDate
                print("🔍 [Coordinator] Reloading based on visible month: \(visibleDate.formatted(date: .abbreviated, time: .omitted))")
            } else if let selectedDate = parent.dateSelected?.date {
                anchor = selectedDate
                print("🔍 [Coordinator] Reloading based on selected date: \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
            } else {
                anchor = Date()
                print("🔍 [Coordinator] Reloading based on today: \(Date().formatted(date: .abbreviated, time: .omitted))")
            }
            
            guard let currentMonth = cal.dateInterval(of: .month, for: anchor),
                  let prevMonthStart = cal.date(byAdding: .month, value: -1, to: currentMonth.start),
                  let prevMonth = cal.dateInterval(of: .month, for: prevMonthStart),
                  let nextMonthStart = cal.date(byAdding: .month, value: 1, to: currentMonth.start),
                  let nextMonth = cal.dateInterval(of: .month, for: nextMonthStart) else { return }
            
            let totalStart = prevMonth.start
            let totalEnd = nextMonth.end
            
            print("🔄 [Coordinator] Reloading decorations from \(totalStart.formatted(date: .abbreviated, time: .omitted)) to \(totalEnd.formatted(date: .abbreviated, time: .omitted))")
            
            var comps: [DateComponents] = []
            var cursor = totalStart
            while cursor <= totalEnd {
                comps.append(cal.dateComponents([.year, .month, .day], from: cursor))
                guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            view.reloadDecorations(forDateComponents: comps, animated: true)
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
            .navigationTitle(dateSelected?.date?.formatted(date: .long, time: .omitted) ?? "")
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
            // Header with time and location
            HStack {
                Text(event.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
    @State private var eventType: Event.EventType
    @State private var city: String
    @State private var country: String
    @State private var notes: String
    @State private var selectedPeople: [Person]
    @State private var selectedActivityIDs: Set<String>
    @State private var selectedAffirmationIDs: Set<String>
    @State private var showingContactsPicker = false
    @State private var showingAffirmationsSelector = false
    
    init(event: Event) {
        self.event = event
        _selectedLocation = State(initialValue: event.location)
        _eventDate = State(initialValue: event.date)
        _eventType = State(initialValue: Event.EventType(rawValue: event.eventType) ?? .unspecified)
        _city = State(initialValue: event.city ?? "")
        _country = State(initialValue: event.country ?? "")
        _notes = State(initialValue: event.note)
        _selectedPeople = State(initialValue: event.people)
        _selectedActivityIDs = State(initialValue: Set(event.activityIDs))
        _selectedAffirmationIDs = State(initialValue: Set(event.affirmationIDs))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Location Section
                Section("Location") {
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
                    
                    TextField("City", text: $city)
                    TextField("Country", text: $country)
                }
                
                // Date & Time
                Section("Date & Time") {
                    DatePicker("Event Date", selection: $eventDate)
                }
                
                // Stay Type Section
                Section {
                    Picker("Stay Type", selection: $eventType) {
                        ForEach(Event.EventType.allCases) { type in
                            Text("\(type.icon) \(type.rawValue.capitalized)")
                                .tag(type)
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
                    } else {
                        ForEach(store.activities, id: \.id) { activity in
                            Toggle(isOn: Binding(
                                get: { selectedActivityIDs.contains(activity.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedActivityIDs.insert(activity.id)
                                    } else {
                                        selectedActivityIDs.remove(activity.id)
                                    }
                                }
                            )) {
                                HStack {
                                    Image(systemName: "figure.walk")
                                        .foregroundColor(.green)
                                    Text(activity.name)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Activities")
                } footer: {
                    Text("\(selectedActivityIDs.count) selected")
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
            }
            .navigationTitle("Edit Event")
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
                }
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
        }
    }
    
    private func saveChanges() {
        // Update event properties
        var updatedEvent = event
        updatedEvent.location = selectedLocation
        updatedEvent.date = eventDate
        updatedEvent.eventType = eventType.rawValue  // Save the event type
        updatedEvent.city = city
        updatedEvent.country = country
        updatedEvent.note = notes
        updatedEvent.people = selectedPeople
        updatedEvent.activityIDs = Array(selectedActivityIDs)
        updatedEvent.affirmationIDs = Array(selectedAffirmationIDs)
        updatedEvent.latitude = selectedLocation.latitude
        updatedEvent.longitude = selectedLocation.longitude
        
        // Save via store
        if let index = store.events.firstIndex(where: { $0.id == event.id }) {
            store.events[index] = updatedEvent
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

