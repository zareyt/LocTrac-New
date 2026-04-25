//
//  TripRefreshView.swift
//  LocTrac
//
//  Refresh trips from events with preview and selection
//

import SwiftUI

struct TripRefreshView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewState: ViewState = .initial
    @State private var refreshResults: RefreshResults?
    @State private var selectedChanges: Set<UUID> = []
    @State private var includeAdditions = true
    @State private var includeUpdates = true
    @State private var includeDeletions = true
    
    enum ViewState {
        case initial
        case analyzing
        case preview
        case applying
        case complete
    }
    
    struct RefreshResults {
        var updates: [TripUpdate] = []
        var additions: [Trip] = []
        var deletions: [Trip] = []
        var unchanged: [Trip] = []
        var problemTrips: [ProblemTrip] = []
    }
    
    struct TripUpdate: Identifiable {
        let id: UUID
        let existingTrip: Trip
        let suggestedTrip: Trip
        var changes: [String]
    }
    
    struct ProblemTrip: Identifiable {
        let id: UUID
        let trip: Trip
        let issue: String
        let fromEvent: Event?
        let toEvent: Event?
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch viewState {
                case .initial:
                    initialView
                case .analyzing:
                    analyzingView
                case .preview:
                    if let results = refreshResults {
                        previewView(results: results)
                    }
                case .applying:
                    applyingView
                case .complete:
                    completeView
                }
            }
            .navigationTitle("Refresh Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Initial View
    
    private var initialView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Refresh Trips")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This will regenerate trips from your events and show you what changed. You can review and select which updates to apply.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                infoRow(icon: "checkmark.circle", text: "Detect new trips from events", color: .green)
                infoRow(icon: "arrow.triangle.branch", text: "Find changed trip details", color: .blue)
                infoRow(icon: "exclamationmark.triangle", text: "Identify problem trips", color: .orange)
                infoRow(icon: "trash", text: "Remove invalid trips", color: .red)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            VStack(spacing: 8) {
                Text("Current Status")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    statBox(value: "\(store.events.count)", label: "Events")
                    statBox(value: "\(store.trips.count)", label: "Trips")
                }
            }
            
            Button {
                analyzeTrips()
            } label: {
                Label("Analyze Trips", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private func infoRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
    
    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
                .foregroundStyle(.blue)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Analyzing View
    
    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Analyzing trips...")
                .font(.headline)
            
            Text("Comparing existing trips with event data")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    // MARK: - Preview View
    
    private func previewView(results: RefreshResults) -> some View {
        VStack(spacing: 0) {
            // Filter toggles
            filterTogglesSection(results: results)
            
            // Summary cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if !results.additions.isEmpty && includeAdditions {
                        summaryCard(count: results.additions.count, label: "New", color: .green, icon: "plus.circle.fill")
                    }
                    if !results.updates.isEmpty && includeUpdates {
                        summaryCard(count: results.updates.count, label: "Updates", color: .blue, icon: "arrow.triangle.branch")
                    }
                    if !results.deletions.isEmpty && includeDeletions {
                        summaryCard(count: results.deletions.count, label: "Remove", color: .red, icon: "trash.fill")
                    }
                    if !results.problemTrips.isEmpty {
                        summaryCard(count: results.problemTrips.count, label: "Problems", color: .orange, icon: "exclamationmark.triangle.fill")
                    }
                    if !results.unchanged.isEmpty {
                        summaryCard(count: results.unchanged.count, label: "Unchanged", color: .gray, icon: "checkmark.circle.fill")
                    }
                }
                .padding()
            }
            
            // Changes list
            List {
                if !results.problemTrips.isEmpty {
                    Section("⚠️ Problem Trips") {
                        ForEach(results.problemTrips) { problem in
                            ProblemTripRow(problem: problem, store: store)
                        }
                    }
                }
                
                if !results.updates.isEmpty && includeUpdates {
                    Section("Updates") {
                        ForEach(results.updates) { update in
                            TripUpdateRow(
                                update: update,
                                store: store,
                                isSelected: selectedChanges.contains(update.id)
                            ) {
                                toggleSelection(update.id)
                            }
                        }
                    }
                }
                
                if !results.additions.isEmpty && includeAdditions {
                    Section("New Trips") {
                        ForEach(results.additions) { trip in
                            TripAdditionRow(
                                trip: trip,
                                store: store,
                                isSelected: selectedChanges.contains(trip.id)
                            ) {
                                toggleSelection(trip.id)
                            }
                        }
                    }
                }
                
                if !results.deletions.isEmpty && includeDeletions {
                    Section("Trips to Remove") {
                        ForEach(results.deletions) { trip in
                            TripDeletionRow(
                                trip: trip,
                                store: store,
                                isSelected: selectedChanges.contains(trip.id)
                            ) {
                                toggleSelection(trip.id)
                            }
                        }
                    }
                }
            }
            
            // Action buttons
            VStack(spacing: 12) {
                HStack {
                    Button("Select All Visible") {
                        selectAll()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Deselect All") {
                        selectedChanges.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button {
                    applySelectedChanges()
                } label: {
                    Label("Apply \(selectedChanges.count) Changes", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedChanges.isEmpty ? Color.gray : Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
                .disabled(selectedChanges.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private func filterTogglesSection(results: RefreshResults) -> some View {
        VStack(spacing: 12) {
            Text("Filter Changes")
                .font(.headline)
            
            HStack(spacing: 16) {
                if !results.additions.isEmpty {
                    Toggle(isOn: $includeAdditions) {
                        Label("New (\(results.additions.count))", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                    .toggleStyle(.button)
                    .tint(.green)
                }
                
                if !results.updates.isEmpty {
                    Toggle(isOn: $includeUpdates) {
                        Label("Updates (\(results.updates.count))", systemImage: "arrow.triangle.branch")
                            .font(.subheadline)
                    }
                    .toggleStyle(.button)
                    .tint(.blue)
                }
                
                if !results.deletions.isEmpty {
                    Toggle(isOn: $includeDeletions) {
                        Label("Remove (\(results.deletions.count))", systemImage: "trash")
                            .font(.subheadline)
                    }
                    .toggleStyle(.button)
                    .tint(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .onChange(of: includeAdditions) { _, _ in updateSelection(results: results) }
        .onChange(of: includeUpdates) { _, _ in updateSelection(results: results) }
        .onChange(of: includeDeletions) { _, _ in updateSelection(results: results) }
    }
    
    private func summaryCard(count: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.title.bold())
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Applying View
    
    private var applyingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Applying changes...")
                .font(.headline)
        }
        .padding()
    }
    
    // MARK: - Complete View
    
    private var completeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Refresh Complete")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let results = refreshResults {
                VStack(spacing: 8) {
                    if !results.additions.isEmpty {
                        resultRow(icon: "plus.circle.fill", text: "Added \(selectedChanges.filter { id in results.additions.contains(where: { $0.id == id }) }.count) trips", color: .green)
                    }
                    if !results.updates.isEmpty {
                        resultRow(icon: "arrow.triangle.branch", text: "Updated \(selectedChanges.filter { id in results.updates.contains(where: { $0.id == id }) }.count) trips", color: .blue)
                    }
                    if !results.deletions.isEmpty {
                        resultRow(icon: "trash.fill", text: "Removed \(selectedChanges.filter { id in results.deletions.contains(where: { $0.id == id }) }.count) trips", color: .red)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private func resultRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
    
    // MARK: - Helper Functions
    
    private func analyzeTrips() {
        viewState = .analyzing
        
        Task {
            let results = await performAnalysis()
            
            await MainActor.run {
                self.refreshResults = results
                
                // Auto-select all non-problem changes
                selectedChanges = Set(
                    results.updates.map { $0.id } +
                    results.additions.map { $0.id } +
                    results.deletions.map { $0.id }
                )
                
                viewState = .preview
            }
        }
    }
    
    private func performAnalysis() async -> RefreshResults {
        // Generate fresh trips from events
        let freshTrips = TripMigrationUtility.migrateEventsToTrips(events: store.events)

        var results = RefreshResults()

        // Phase 1: Find problem trips (trips with missing/invalid events)
        for trip in store.trips {
            let fromEvent = store.events.first(where: { $0.id == trip.fromEventID })
            let toEvent = store.events.first(where: { $0.id == trip.toEventID })

            if fromEvent == nil || toEvent == nil {
                let issue = fromEvent == nil && toEvent == nil ? "Both events missing" :
                           fromEvent == nil ? "Departure event missing" : "Arrival event missing"
                results.problemTrips.append(ProblemTrip(
                    id: trip.id,
                    trip: trip,
                    issue: issue,
                    fromEvent: fromEvent,
                    toEvent: toEvent
                ))
                results.deletions.append(trip)
            } else if let from = fromEvent, let to = toEvent {
                let fromCountry = from.effectiveCountry
                let toCountry = to.effectiveCountry

                if fromCountry == nil || fromCountry == "Unknown" || toCountry == nil || toCountry == "Unknown" {
                    results.problemTrips.append(ProblemTrip(
                        id: trip.id,
                        trip: trip,
                        issue: "Unknown destination or origin",
                        fromEvent: from,
                        toEvent: to
                    ))
                }
            }
        }

        // Phase 2: Compare existing trips with fresh trips
        for freshTrip in freshTrips {
            if let existingTrip = store.trips.first(where: {
                $0.fromEventID == freshTrip.fromEventID &&
                $0.toEventID == freshTrip.toEventID
            }) {
                var changes: [String] = []

                if abs(existingTrip.distance - freshTrip.distance) > 0.1 {
                    changes.append("Distance: \(existingTrip.formattedDistance) → \(freshTrip.formattedDistance) mi")
                }
                if existingTrip.departureDate != freshTrip.departureDate {
                    changes.append("Departure: \(existingTrip.departureDate.utcMediumDateString) → \(freshTrip.departureDate.utcMediumDateString)")
                }
                if existingTrip.arrivalDate != freshTrip.arrivalDate {
                    changes.append("Arrival: \(existingTrip.arrivalDate.utcMediumDateString) → \(freshTrip.arrivalDate.utcMediumDateString)")
                }

                if !changes.isEmpty {
                    results.updates.append(TripUpdate(
                        id: existingTrip.id,
                        existingTrip: existingTrip,
                        suggestedTrip: freshTrip,
                        changes: changes
                    ))
                } else {
                    results.unchanged.append(existingTrip)
                }
            } else {
                results.additions.append(freshTrip)
            }
        }

        // Phase 3: Find trips that no longer have matching events (deletions)
        for existingTrip in store.trips {
            let stillValid = freshTrips.contains(where: {
                $0.fromEventID == existingTrip.fromEventID &&
                $0.toEventID == existingTrip.toEventID
            })
            if !stillValid && !results.deletions.contains(where: { $0.id == existingTrip.id }) {
                results.deletions.append(existingTrip)
            }
        }

        return results
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedChanges.contains(id) {
            selectedChanges.remove(id)
        } else {
            selectedChanges.insert(id)
        }
    }
    
    private func selectAll() {
        guard let results = refreshResults else { return }
        var allChanges: [UUID] = []
        
        if includeUpdates {
            allChanges += results.updates.map { $0.id }
        }
        if includeAdditions {
            allChanges += results.additions.map { $0.id }
        }
        if includeDeletions {
            allChanges += results.deletions.map { $0.id }
        }
        
        selectedChanges = Set(allChanges)
    }
    
    private func updateSelection(results: RefreshResults) {
        // Remove selections that are now hidden by filters
        var validSelections: [UUID] = []
        
        if includeUpdates {
            validSelections += results.updates.map { $0.id }
        }
        if includeAdditions {
            validSelections += results.additions.map { $0.id }
        }
        if includeDeletions {
            validSelections += results.deletions.map { $0.id }
        }
        
        selectedChanges = selectedChanges.intersection(Set(validSelections))
    }
    
    private func applySelectedChanges() {
        guard let results = refreshResults else { return }
        
        viewState = .applying
        
        Task {
            // Apply updates
            for update in results.updates where selectedChanges.contains(update.id) {
                if let index = store.trips.firstIndex(where: { $0.id == update.existingTrip.id }) {
                    store.trips[index] = update.suggestedTrip
                }
            }
            
            // Add new trips
            for trip in results.additions where selectedChanges.contains(trip.id) {
                store.trips.append(trip)
            }
            
            // Delete invalid trips
            for trip in results.deletions where selectedChanges.contains(trip.id) {
                store.trips.removeAll(where: { $0.id == trip.id })
            }
            
            // Save changes
            store.storeData()
            
            await MainActor.run {
                viewState = .complete
            }
        }
    }
}

// MARK: - Shared Display Name Helper

/// Resolves "Other" location names to the event's city or country.
/// Used by all trip row views in TripRefreshView.
private func tripDisplayName(for event: Event?) -> String {
    guard let event = event else { return "Unknown" }
    if event.location.name == "Other" {
        return event.effectiveCity
            ?? event.effectiveCountry
            ?? "Unknown City"
    }
    return event.location.name
}

// MARK: - Row Views

struct ProblemTripRow: View {
    let problem: TripRefreshView.ProblemTrip
    let store: DataStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(problem.issue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            HStack(spacing: 8) {
                Text(tripRoute)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            // Show dates
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("\(formatDate(problem.trip.departureDate)) → \(formatDate(problem.trip.arrivalDate))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            // Show if it will be deleted
            if problem.issue != "Unknown destination or origin" {
                Text("This trip will be removed")
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else {
                Text("Trip exists but needs country updates")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var tripRoute: String {
        let from = tripDisplayName(for: problem.fromEvent)
        let to = tripDisplayName(for: problem.toEvent)
        return "\(from) → \(to)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct TripUpdateRow: View {
    let update: TripRefreshView.TripUpdate
    let store: DataStore
    let isSelected: Bool
    let onToggle: () -> Void

    private var fromEvent: Event? {
        store.events.first(where: { $0.id == update.existingTrip.fromEventID })
    }
    private var toEvent: Event? {
        store.events.first(where: { $0.id == update.existingTrip.toEventID })
    }

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 6) {
                    // Route
                    Text("\(tripDisplayName(for: fromEvent)) → \(tripDisplayName(for: toEvent))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    // Current trip details
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("\(update.existingTrip.departureDate.utcMediumDateString) → \(update.existingTrip.arrivalDate.utcMediumDateString)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label("\(update.existingTrip.formattedDistance) mi", systemImage: "arrow.left.and.right")
                        Label(update.existingTrip.mode.rawValue, systemImage: update.existingTrip.mode.icon)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // What changed
                    ForEach(update.changes, id: \.self) { change in
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                            Text(change)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

struct TripAdditionRow: View {
    let trip: Trip
    let store: DataStore
    let isSelected: Bool
    let onToggle: () -> Void

    private var fromEvent: Event? {
        store.events.first(where: { $0.id == trip.fromEventID })
    }
    private var toEvent: Event? {
        store.events.first(where: { $0.id == trip.toEventID })
    }

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .gray)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 6) {
                    // Route
                    Text("\(tripDisplayName(for: fromEvent)) → \(tripDisplayName(for: toEvent))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    // Dates
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("\(trip.departureDate.utcMediumDateString) → \(trip.arrivalDate.utcMediumDateString)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    // Distance and mode
                    HStack(spacing: 12) {
                        Label("\(trip.formattedDistance) mi", systemImage: "arrow.left.and.right")
                        Label(trip.mode.rawValue, systemImage: trip.mode.icon)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Reason: consecutive events at different locations
                    Text("New consecutive location change detected")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

struct TripDeletionRow: View {
    let trip: Trip
    let store: DataStore
    let isSelected: Bool
    let onToggle: () -> Void

    private var fromEvent: Event? {
        store.events.first(where: { $0.id == trip.fromEventID })
    }
    private var toEvent: Event? {
        store.events.first(where: { $0.id == trip.toEventID })
    }

    /// Explain why the trip is being removed
    private var deletionReason: String {
        guard let from = fromEvent, let to = toEvent else {
            if fromEvent == nil && toEvent == nil {
                return "Both departure and arrival events are missing"
            }
            return fromEvent == nil ? "Departure event is missing" : "Arrival event is missing"
        }
        // Events exist but trip no longer generated — a new event was inserted between them
        return "Events are no longer consecutive (new stay added between them)"
    }

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .red : .gray)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 6) {
                    // Route
                    Text("\(tripDisplayName(for: fromEvent)) → \(tripDisplayName(for: toEvent))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    // Dates
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("\(trip.departureDate.utcMediumDateString) → \(trip.arrivalDate.utcMediumDateString)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    // Distance and mode
                    HStack(spacing: 12) {
                        Label("\(trip.formattedDistance) mi", systemImage: "arrow.left.and.right")
                        Label(trip.mode.rawValue, systemImage: trip.mode.icon)
                        if trip.isAutoGenerated {
                            Text("Auto")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Reason for deletion
                    Text(deletionReason)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TripRefreshView()
        .environmentObject(DataStore())
}
