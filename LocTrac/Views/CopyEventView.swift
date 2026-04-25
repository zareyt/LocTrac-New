//
//  CopyEventView.swift
//  LocTrac
//
//  Copy an existing event's data to a range of dates with
//  per-field selection and per-date conflict resolution.
//

import SwiftUI

// MARK: - Supporting Types

enum CopyConflictResolution: String, CaseIterable, Identifiable {
    case skip = "Skip"
    case replace = "Replace"
    case merge = "Merge"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .skip: return "Keep existing event unchanged"
        case .replace: return "Replace with copied data"
        case .merge: return "Update only selected fields"
        }
    }

    var icon: String {
        switch self {
        case .skip: return "forward.fill"
        case .replace: return "arrow.triangle.2.circlepath"
        case .merge: return "arrow.triangle.merge"
        }
    }
}

struct CopyFieldOption: Identifiable {
    let id: String
    let label: String
    let icon: String
    var isSelected: Bool
}

struct DateConflict: Identifiable {
    let id: Date
    let existingEvent: Event
    let sameLocation: Bool
    var resolution: CopyConflictResolution = .skip
}

// MARK: - CopyEventView

struct CopyEventView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var debugConfig: DebugConfig
    @Environment(\.dismiss) private var dismiss

    let sourceEvent: Event
    let skipSourceDate: Bool

    // Date range
    @State private var startDate: Date
    @State private var endDate: Date

    // Field toggles
    @State private var fields: [CopyFieldOption]

    // Conflict state
    @State private var conflicts: [DateConflict] = []
    @State private var showResultAlert = false
    @State private var resultMessage = ""

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    /// - Parameters:
    ///   - sourceEvent: The event whose data will be copied.
    ///   - skipSourceDate: When true (edit mode), the source event's date is skipped. When false (add mode), all dates are created.
    ///   - overrideStartDate: Optional start date override (add mode passes the form's start date).
    ///   - overrideEndDate: Optional end date override (add mode passes the form's end date).
    init(sourceEvent: Event, skipSourceDate: Bool = true, overrideStartDate: Date? = nil, overrideEndDate: Date? = nil) {
        self.sourceEvent = sourceEvent
        self.skipSourceDate = skipSourceDate
        // Default: start the day after the source, end same day (user adjusts)
        let nextDay = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!
            return cal.date(byAdding: .day, value: 1, to: sourceEvent.date.startOfDay)!
        }()
        _startDate = State(initialValue: overrideStartDate?.startOfDay ?? nextDay)
        _endDate = State(initialValue: overrideEndDate?.startOfDay ?? nextDay)

        _fields = State(initialValue: [
            CopyFieldOption(id: "location", label: "Location", icon: "mappin.and.ellipse", isSelected: true),
            CopyFieldOption(id: "eventType", label: "Stay Type", icon: "tag.fill", isSelected: true),
            CopyFieldOption(id: "people", label: "People", icon: "person.2.fill", isSelected: true),
            CopyFieldOption(id: "activities", label: "Activities", icon: "figure.walk", isSelected: true),
            CopyFieldOption(id: "affirmations", label: "Affirmations", icon: "sparkles", isSelected: true),
            CopyFieldOption(id: "note", label: "Notes", icon: "note.text", isSelected: true),
            CopyFieldOption(id: "photos", label: "Photos", icon: "camera.fill", isSelected: false),
        ])
    }

    private var allSelected: Bool {
        fields.allSatisfy(\.isSelected)
    }

    private var noneSelected: Bool {
        !fields.contains(where: \.isSelected)
    }

    private var durationDays: Int {
        let days = utcCalendar.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay).day ?? 0
        return max(days, 0)
    }

    private var targetDates: [Date] {
        (0...durationDays).compactMap { n in
            utcCalendar.date(byAdding: .day, value: n, to: startDate.startOfDay)
        }
    }

    private var newDatesCount: Int {
        targetDates.count - conflicts.count - autoMergeCount
    }

    /// Count of target dates with same-location events that will be auto-merged
    private var autoMergeCount: Int {
        let existingByDate = Dictionary(
            grouping: store.events,
            by: { $0.date.startOfDay }
        ).mapValues(\.first!)
        return targetDates.filter { date in
            guard let existing = existingByDate[date], existing.id != sourceEvent.id else { return false }
            return existing.location.id == sourceEvent.location.id
        }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                sourceEventSection
                dateRangeSection
                fieldSelectionSection
                if !conflicts.isEmpty {
                    conflictResolutionSection
                }
                summarySection
                copyButtonSection
            }
            .navigationTitle("Copy Stay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: startDate) { _, _ in recalculateConflicts() }
            .onChange(of: endDate) { _, _ in recalculateConflicts() }
            .onAppear {
                DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] CopyEventView appeared — source: '\(sourceEvent.location.name)' on \(sourceEvent.date.utcMediumDateString)")
                recalculateConflicts()
            }
            .alert("Copy Complete", isPresented: $showResultAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(resultMessage)
            }
        }
        .debugViewName("CopyEventView")
    }

    // MARK: - Source Event Summary

    private var sourceEventSection: some View {
        Section {
            HStack(spacing: 12) {
                if let typeItem = store.eventTypes.first(where: { $0.name == sourceEvent.eventType }) {
                    Image(systemName: typeItem.sfSymbol)
                        .foregroundStyle(typeItem.color)
                        .font(.title2)
                } else {
                    Image(systemName: "bed.double.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceEvent.location.name)
                        .font(.headline)
                    Text(sourceEvent.date.utcMediumDateString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !sourceEvent.note.isEmpty {
                        Text(sourceEvent.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
        } header: {
            Label("Source Event", systemImage: "doc.on.doc")
        }
    }

    // MARK: - Date Range

    private var dateRangeSection: some View {
        Section {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.green)
                    .frame(width: 30)
                DatePicker(
                    "Start Date",
                    selection: $startDate,
                    displayedComponents: .date
                )
                .environment(\.calendar, utcCalendar)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            }
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundColor(.red)
                    .frame(width: 30)
                DatePicker(
                    "End Date",
                    selection: $endDate,
                    in: startDate...Date.distantFuture,
                    displayedComponents: .date
                )
                .environment(\.calendar, utcCalendar)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            }
            if durationDays >= 0 {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    Text("\(durationDays + 1) day\(durationDays == 0 ? "" : "s") selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Target Dates", systemImage: "calendar")
        } footer: {
            Text("Events will be copied to each day in this range")
                .font(.caption)
        }
    }

    // MARK: - Field Selection

    private var fieldSelectionSection: some View {
        Section {
            // Select All toggle
            Toggle(isOn: Binding(
                get: { allSelected },
                set: { newValue in
                    for i in fields.indices {
                        fields[i].isSelected = newValue
                    }
                }
            )) {
                Label("Select All", systemImage: "checkmark.circle.fill")
                    .fontWeight(.medium)
            }
            .tint(.blue)

            ForEach($fields) { $field in
                Toggle(isOn: $field.isSelected) {
                    Label(field.label, systemImage: field.icon)
                }
                .tint(.blue)
            }
        } header: {
            Label("Fields to Copy", systemImage: "list.bullet.clipboard")
        } footer: {
            Text("Unselected fields will use defaults for new events or remain unchanged for merged events")
                .font(.caption)
        }
    }

    // MARK: - Conflict Resolution

    private var conflictResolutionSection: some View {
        Section {
            ForEach($conflicts) { $conflict in
                VStack(alignment: .leading, spacing: 8) {
                    // Existing event info
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(conflict.id.utcMediumDateString)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(conflict.existingEvent.location.name) - \(conflict.existingEvent.eventType)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Resolution picker — only Skip/Replace for different-location conflicts
                    Picker("Action", selection: $conflict.resolution) {
                        ForEach([CopyConflictResolution.skip, .replace], id: \.self) { resolution in
                            Label(resolution.rawValue, systemImage: resolution.icon)
                                .tag(resolution)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Label("Conflicts (\(conflicts.count))", systemImage: "exclamationmark.triangle")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Skip: Keep existing event unchanged")
                Text("Replace: Overwrite with copied data")
                Text("Same-location dates are merged automatically")
            }
            .font(.caption)
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section {
            if newDatesCount > 0 {
                Label("\(newDatesCount) new event\(newDatesCount == 1 ? "" : "s") will be created", systemImage: "plus.circle.fill")
                    .foregroundStyle(.green)
            }
            let replaceCount = conflicts.filter { $0.resolution == .replace }.count
            if replaceCount > 0 {
                Label("\(replaceCount) event\(replaceCount == 1 ? "" : "s") will be replaced", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
            }
            if autoMergeCount > 0 {
                Label("\(autoMergeCount) same-location event\(autoMergeCount == 1 ? "" : "s") will be auto-merged", systemImage: "arrow.triangle.merge")
                    .foregroundStyle(.blue)
            }
            let skipCount = conflicts.filter { $0.resolution == .skip }.count
            if skipCount > 0 {
                Label("\(skipCount) event\(skipCount == 1 ? "" : "s") will be skipped", systemImage: "forward.fill")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Summary", systemImage: "info.circle")
        }
    }

    // MARK: - Copy Button

    private var copyButtonSection: some View {
        Section {
            Button {
                performCopy()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "doc.on.doc.fill")
                    Text("Copy Stay\(durationDays > 0 ? "s" : "")")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .foregroundColor(.white)
                .padding()
                .background(noneSelected ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .disabled(noneSelected)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Logic

    private func recalculateConflicts() {
        let existingByDate = Dictionary(
            grouping: store.events,
            by: { $0.date.startOfDay }
        ).mapValues(\.first!)

        // Preserve existing resolution choices where the date still conflicts
        let oldResolutions = Dictionary(uniqueKeysWithValues: conflicts.map { ($0.id, $0.resolution) })

        conflicts = targetDates.compactMap { date in
            guard let existing = existingByDate[date] else { return nil }
            // Don't flag the source event itself as a conflict
            guard existing.id != sourceEvent.id else { return nil }
            let isSameLocation = existing.location.id == sourceEvent.location.id
            // Same location = auto-merge (no user prompt needed)
            if isSameLocation {
                DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] \(date.utcMediumDateString): same location '\(existing.location.name)' — will auto-merge")
                return nil
            }
            return DateConflict(
                id: date,
                existingEvent: existing,
                sameLocation: false,
                resolution: oldResolutions[date] ?? .skip
            )
        }
        DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] recalculateConflicts: \(targetDates.count) target dates, \(conflicts.count) conflicts (different location)")
    }

    private func performCopy() {
        let selectedFieldNames = fields.filter(\.isSelected).map(\.label).joined(separator: ", ")
        DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] performCopy: \(targetDates.count) dates, fields=[\(selectedFieldNames)], conflicts=\(conflicts.count)")

        let existingByDate = Dictionary(
            grouping: store.events,
            by: { $0.date.startOfDay }
        ).mapValues(\.first!)

        var created = 0
        var replaced = 0
        var merged = 0
        var skipped = 0

        let selectedFieldIDs = Set(fields.filter(\.isSelected).map(\.id))

        for date in targetDates {
            // Skip the source event's own date (edit mode only)
            if skipSourceDate && date == sourceEvent.date.startOfDay {
                skipped += 1
                continue
            }

            if let existing = existingByDate[date], existing.id != sourceEvent.id {
                let isSameLocation = existing.location.id == sourceEvent.location.id

                if isSameLocation {
                    // Same location — auto-merge selected fields (no user prompt)
                    let mergedEvent = buildMergedEvent(existing: existing, selectedFields: selectedFieldIDs)
                    store.update(mergedEvent)
                    merged += 1
                    DebugConfig.shared.log(.dataStore, "📋 [CopyEvent] \(date.utcMediumDateString): auto-merged (same location)")
                } else if let conflict = conflicts.first(where: { $0.id == date }) {
                    // Different location — use user's conflict resolution
                    switch conflict.resolution {
                    case .skip:
                        skipped += 1
                    case .replace:
                        let newEvent = buildEvent(for: date, selectedFields: selectedFieldIDs, base: nil)
                        store.delete(existing)
                        store.add(newEvent)
                        replaced += 1
                    case .merge:
                        // Merge not offered in UI for different locations — treat as skip
                        skipped += 1
                    }
                } else {
                    skipped += 1
                }
            } else {
                // No conflict -- create new
                let newEvent = buildEvent(for: date, selectedFields: selectedFieldIDs, base: nil)
                store.add(newEvent)
                created += 1
            }
        }

        store.bumpCalendarRefresh()

        // Build result message
        var parts: [String] = []
        if created > 0 { parts.append("\(created) created") }
        if replaced > 0 { parts.append("\(replaced) replaced") }
        if merged > 0 { parts.append("\(merged) merged") }
        if skipped > 0 { parts.append("\(skipped) skipped") }
        resultMessage = parts.joined(separator: ", ") + "."

        #if DEBUG
        DebugConfig.shared.log(.dataStore, "CopyEvent: \(resultMessage)")
        #endif

        showResultAlert = true
    }

    /// Build a new event for the given date using selected fields from source.
    /// Unselected fields get defaults.
    private func buildEvent(for date: Date, selectedFields: Set<String>, base: Event?) -> Event {
        let location = selectedFields.contains("location") ? sourceEvent.location : (base?.location ?? sourceEvent.location)
        let eventType = selectedFields.contains("eventType") ? sourceEvent.eventType : (base?.eventType ?? "unspecified")
        let people = selectedFields.contains("people") ? sourceEvent.people : (base?.people ?? [])
        let activityIDs = selectedFields.contains("activities") ? sourceEvent.activityIDs : (base?.activityIDs ?? [])
        let affirmationIDs = selectedFields.contains("affirmations") ? sourceEvent.affirmationIDs : (base?.affirmationIDs ?? [])
        let note = selectedFields.contains("note") ? sourceEvent.note : (base?.note ?? "")
        let imageIDs = selectedFields.contains("photos") ? sourceEvent.imageIDs : (base?.imageIDs ?? [])

        return Event(
            eventTypeRaw: eventType,
            date: date.startOfDay,
            location: location,
            city: selectedFields.contains("location") ? sourceEvent.city : nil,
            latitude: selectedFields.contains("location") ? sourceEvent.latitude : location.latitude,
            longitude: selectedFields.contains("location") ? sourceEvent.longitude : location.longitude,
            country: selectedFields.contains("location") ? sourceEvent.country : location.country,
            state: selectedFields.contains("location") ? sourceEvent.state : location.state,
            note: note,
            people: people,
            activityIDs: activityIDs,
            affirmationIDs: affirmationIDs,
            isGeocoded: selectedFields.contains("location") ? sourceEvent.isGeocoded : false,
            imageIDs: imageIDs
        )
    }

    /// Merge selected fields from source into an existing event.
    private func buildMergedEvent(existing: Event, selectedFields: Set<String>) -> Event {
        var merged = existing

        if selectedFields.contains("location") {
            merged.location = sourceEvent.location
            merged.city = sourceEvent.city
            merged.latitude = sourceEvent.latitude
            merged.longitude = sourceEvent.longitude
            merged.country = sourceEvent.country
            merged.state = sourceEvent.state
            merged.isGeocoded = sourceEvent.isGeocoded
        }
        if selectedFields.contains("eventType") {
            merged.eventType = sourceEvent.eventType
        }
        if selectedFields.contains("people") {
            merged.people = sourceEvent.people
        }
        if selectedFields.contains("activities") {
            merged.activityIDs = sourceEvent.activityIDs
        }
        if selectedFields.contains("affirmations") {
            merged.affirmationIDs = sourceEvent.affirmationIDs
        }
        if selectedFields.contains("note") {
            merged.note = sourceEvent.note
        }
        if selectedFields.contains("photos") {
            merged.imageIDs = sourceEvent.imageIDs
        }

        return merged
    }
}

// MARK: - Preview

struct CopyEventView_Previews: PreviewProvider {
    static var previews: some View {
        CopyEventView(sourceEvent: Event.sampleData[0])
            .environmentObject(DataStore(preview: true))
    }
}
