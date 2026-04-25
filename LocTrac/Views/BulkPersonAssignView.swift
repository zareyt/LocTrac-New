//
//  BulkPersonAssignView.swift
//  LocTrac
//
//  Utility to bulk-assign a contact to all events within a date range.
//  Matches by contactIdentifier first, then displayName as fallback.
//

import SwiftUI
import Contacts

struct BulkPersonAssignView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: DataStore

    // MARK: - State

    @State private var selectedPerson: Person?
    @State private var startDate: Date = Date().startOfDay
    @State private var endDate: Date = Date().startOfDay
    @State private var showContactsPicker = false

    // Preview / results
    @State private var previewCalculated = false
    @State private var eventsToUpdate: [Event] = []
    @State private var eventsSkipped: [Event] = []
    @State private var applied = false
    @State private var updatedCount = 0

    // Snapshot of dates at preview time — prevents drift between preview and apply
    @State private var previewStartDate: Date = .distantPast
    @State private var previewEndDate: Date = .distantFuture

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                contactSection
                dateRangeSection

                if let person = selectedPerson {
                    previewButton(person: person)
                }

                if previewCalculated {
                    previewSection
                }

                if previewCalculated && !eventsToUpdate.isEmpty && !applied {
                    applySection
                }

                if applied {
                    resultSection
                }
            }
            .navigationTitle("Bulk Assign Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showContactsPicker) {
                SingleContactPicker { contact in
                    let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "Unknown"
                    selectedPerson = Person(
                        displayName: name,
                        contactIdentifier: contact.identifier
                    )
                    resetPreview()
                    DebugConfig.shared.log(.dataStore, "\u{1F464} [BulkAssign] Selected contact: \(name) (id: \(contact.identifier))")
                }
            }
        }
    }

    // MARK: - Sections

    private var contactSection: some View {
        Section {
            if let person = selectedPerson {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(.blue)
                    Text(person.displayName)
                    Spacer()
                    Button("Change") {
                        showContactsPicker = true
                    }
                    .font(.subheadline)
                }
            } else {
                Button {
                    showContactsPicker = true
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundStyle(.blue)
                        Text("Select Contact")
                    }
                }
            }
        } header: {
            Label("Person", systemImage: "person.fill")
        } footer: {
            Text("Choose a contact to add to events in the date range")
                .font(.caption)
        }
    }

    private var dateRangeSection: some View {
        Section {
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                .environment(\.calendar, utcCalendar)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                .onChange(of: startDate) { _, _ in
                    if endDate < startDate { endDate = startDate }
                    resetPreview()
                }

            DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                .environment(\.calendar, utcCalendar)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                .onChange(of: endDate) { _, _ in
                    resetPreview()
                }
        } header: {
            Label("Date Range", systemImage: "calendar")
        } footer: {
            let count = eventsInRange.count
            Text("\(count) event\(count == 1 ? "" : "s") in this range")
                .font(.caption)
        }
    }

    private func previewButton(person: Person) -> some View {
        Section {
            Button {
                calculatePreview(person: person)
            } label: {
                HStack {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(.blue)
                    Text("Preview Changes")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(previewCalculated)
        }
    }

    private var previewSection: some View {
        Section {
            if eventsToUpdate.isEmpty && eventsSkipped.isEmpty {
                Label("No events found in this date range", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            } else {
                if !eventsToUpdate.isEmpty {
                    Label("\(eventsToUpdate.count) event\(eventsToUpdate.count == 1 ? "" : "s") will be updated", systemImage: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
                if !eventsSkipped.isEmpty {
                    Label("\(eventsSkipped.count) event\(eventsSkipped.count == 1 ? "" : "s") already have this person", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.orange)
                }

                // Show details
                DisclosureGroup("Event Details") {
                    ForEach(eventsToUpdate) { event in
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.green)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.date.utcMediumDateString)
                                    .font(.subheadline)
                                Text(event.location.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    ForEach(eventsSkipped) { event in
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.date.utcMediumDateString)
                                    .font(.subheadline)
                                Text("\(event.location.name) -- already has person")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } header: {
            Label("Preview", systemImage: "eye")
        }
    }

    private var applySection: some View {
        Section {
            Button {
                applyChanges()
            } label: {
                HStack {
                    Spacer()
                    Label("Apply to \(eventsToUpdate.count) Event\(eventsToUpdate.count == 1 ? "" : "s")", systemImage: "checkmark.circle.fill")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .foregroundStyle(.white)
            .listRowBackground(Color.blue)
        }
    }

    private var resultSection: some View {
        Section {
            Label("\(updatedCount) event\(updatedCount == 1 ? "" : "s") updated successfully", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        } header: {
            Label("Result", systemImage: "checkmark.circle")
        }
    }

    // MARK: - Logic

    private var eventsInRange: [Event] {
        let normalizedStart = startDate.startOfDay
        let normalizedEnd = endDate.startOfDay
        return store.events.filter { event in
            let d = event.date.startOfDay
            return d >= normalizedStart && d <= normalizedEnd
        }.sorted { $0.date < $1.date }
    }

    private func personAlreadyExists(in event: Event, person: Person) -> Bool {
        // Match by contactIdentifier first (handles name changes)
        if let newContactID = person.contactIdentifier, !newContactID.isEmpty {
            if event.people.contains(where: { $0.contactIdentifier == newContactID }) {
                return true
            }
        }
        // Fallback: match by displayName (case-insensitive)
        return event.people.contains(where: {
            $0.displayName.lowercased() == person.displayName.lowercased()
        })
    }

    private func calculatePreview(person: Person) {
        // Snapshot the date range so it can't drift between preview and apply
        previewStartDate = startDate.startOfDay
        previewEndDate = endDate.startOfDay

        DebugConfig.shared.log(.dataStore, "\u{1F464} [BulkAssign] Date range: \(previewStartDate.utcMediumDateString) to \(previewEndDate.utcMediumDateString)")
        DebugConfig.shared.log(.dataStore, "\u{1F464} [BulkAssign] Raw startDate=\(startDate), endDate=\(endDate)")

        let events = store.events.filter { event in
            let d = event.date.startOfDay
            return d >= previewStartDate && d <= previewEndDate
        }.sorted { $0.date < $1.date }

        var toUpdate: [Event] = []
        var skipped: [Event] = []

        for event in events {
            if personAlreadyExists(in: event, person: person) {
                skipped.append(event)
                DebugConfig.shared.log(.dataStore, "\u{1F464} [BulkAssign] Skip \(event.date.utcMediumDateString) -- person already exists")
            } else {
                toUpdate.append(event)
                DebugConfig.shared.log(.dataStore, "\u{1F464} [BulkAssign] Will update \(event.date.utcMediumDateString) at \(event.location.name)")
            }
        }

        eventsToUpdate = toUpdate
        eventsSkipped = skipped
        previewCalculated = true

        DebugConfig.shared.log(.dataStore, "\u{1F464} [BulkAssign] Preview: \(toUpdate.count) to update, \(skipped.count) skipped (range: \(previewStartDate.utcMediumDateString) - \(previewEndDate.utcMediumDateString))")
    }

    private func applyChanges() {
        guard let person = selectedPerson else { return }
        var count = 0

        // Build a set of event IDs to update for O(1) lookup
        let idsToUpdate = Set(eventsToUpdate.map { $0.id })

        // Batch-mutate the store's events array directly, then save once
        for i in store.events.indices {
            if idsToUpdate.contains(store.events[i].id) {
                store.events[i].people.append(person)
                count += 1
            }
        }

        // Single save + refresh instead of N individual saves
        store.storeData()
        store.bumpCalendarRefresh()

        updatedCount = count
        applied = true

        DebugConfig.shared.log(.dataStore, "\u{1F464} [BulkAssign] Applied: \(count) events updated with \(person.displayName) (single batch save)")
    }

    private func resetPreview() {
        previewCalculated = false
        eventsToUpdate = []
        eventsSkipped = []
        applied = false
        updatedCount = 0
        previewStartDate = .distantPast
        previewEndDate = .distantFuture
    }
}

// MARK: - Single Contact Picker

/// A single-select contact picker that returns one CNContact.
private struct SingleContactPicker: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (CNContact) -> Void

    @State private var allContacts: [CNContact] = []
    @State private var filtered: [CNContact] = []
    @State private var query: String = ""
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Select Contact")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search contacts")
                .onChange(of: query) { _, newQuery in
                    applyFilter(query: newQuery)
                }
                .task {
                    await loadContacts()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            VStack {
                Spacer()
                ProgressView("Loading contacts...")
                Spacer()
            }
            .padding()
        } else if let errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .imageScale(.large)
                Text(errorMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
        } else if filtered.isEmpty {
            VStack {
                Spacer()
                Text(query.isEmpty ? "No contacts found." : "No matches for \"\(query)\".")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
        } else {
            List(filtered, id: \.identifier) { contact in
                Button {
                    onSelect(contact)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.accentColor)
                        Text(displayName(for: contact))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private func displayName(for contact: CNContact) -> String {
        CNContactFormatter.string(from: contact, style: .fullName) ?? "Unknown"
    }

    private func applyFilter(query: String) {
        guard !query.isEmpty else {
            filtered = allContacts
            return
        }
        let lower = query.lowercased()
        filtered = allContacts.filter { c in
            let name = displayName(for: c).lowercased()
            if name.contains(lower) { return true }
            if c.organizationName.lowercased().contains(lower) { return true }
            return false
        }
    }

    private func loadContacts() async {
        loading = true
        defer { loading = false }
        do {
            _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                let store = CNContactStore()
                store.requestAccess(for: .contacts) { granted, err in
                    if let err { cont.resume(throwing: err); return }
                    if !granted {
                        cont.resume(throwing: NSError(domain: "Contacts", code: 1, userInfo: [
                            NSLocalizedDescriptionKey: "Access to Contacts was denied. You can enable it in Settings."
                        ]))
                        return
                    }
                    cont.resume()
                }
            }

            let contacts: [CNContact] = try await Task.detached(priority: .userInitiated) { () -> [CNContact] in
                let store = CNContactStore()
                let keys: [CNKeyDescriptor] = [
                    CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                    CNContactIdentifierKey as CNKeyDescriptor,
                    CNContactGivenNameKey as CNKeyDescriptor,
                    CNContactFamilyNameKey as CNKeyDescriptor,
                    CNContactOrganizationNameKey as CNKeyDescriptor
                ]
                let req = CNContactFetchRequest(keysToFetch: keys)
                var results: [CNContact] = []
                try store.enumerateContacts(with: req) { contact, _ in
                    results.append(contact)
                }
                let nameStrings = results.map { CNContactFormatter.string(from: $0, style: .fullName) ?? "" }
                let sortedIndices = nameStrings.indices.sorted { nameStrings[$0] < nameStrings[$1] }
                return sortedIndices.map { results[$0] }
            }.value

            await MainActor.run {
                self.allContacts = contacts
                self.filtered = contacts
            }
        } catch {
            await MainActor.run {
                self.errorMessage = (error as NSError).localizedDescription
            }
        }
    }
}
