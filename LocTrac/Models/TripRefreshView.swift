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
        print("\n🔍 === TRIP REFRESH ANALYSIS START ===")
        print("📊 Current Data: \(store.events.count) events, \(store.trips.count) trips")
        
        // Generate fresh trips from events
        let freshTrips = TripMigrationUtility.migrateEventsToTrips(events: store.events)
        print("✅ Fresh Generation: \(freshTrips.count) trips")
        
        var results = RefreshResults()
        
        print("\n🔍 Phase 1: Scanning for Problem Trips...")
        // Find problem trips (trips with missing/invalid events)
        for (index, trip) in store.trips.enumerated() {
            let fromEvent = store.events.first(where: { $0.id == trip.fromEventID })
            let toEvent = store.events.first(where: { $0.id == trip.toEventID })
            
            print("[\(index + 1)/\(store.trips.count)] Trip \(trip.id)")
            print("   From Event ID: \(trip.fromEventID) - \(fromEvent != nil ? "✓ Found" : "❌ Missing")")
            print("   To Event ID: \(trip.toEventID) - \(toEvent != nil ? "✓ Found" : "❌ Missing")")
            print("   Departure: \(formatDate(trip.departureDate))")
            print("   Arrival: \(formatDate(trip.arrivalDate))")
            
            if fromEvent == nil || toEvent == nil {
                let issue = fromEvent == nil && toEvent == nil ? "Both events missing" :
                           fromEvent == nil ? "Departure event missing" : "Arrival event missing"
                print("   ⚠️ PROBLEM: \(issue)")
                
                results.problemTrips.append(ProblemTrip(
                    id: trip.id,
                    trip: trip,
                    issue: issue,
                    fromEvent: fromEvent,
                    toEvent: toEvent
                ))
                results.deletions.append(trip)
                print("   → Marked for DELETION")
            } else if let from = fromEvent, let to = toEvent {
                // Check for "Unknown" destinations
                let fromCountry = from.country ?? from.location.country
                let toCountry = to.country ?? to.location.country
                
                print("   From: \(from.location.name) (\(from.city ?? "no city")) - Country: '\(fromCountry ?? "nil")'")
                print("   To: \(to.location.name) (\(to.city ?? "no city")) - Country: '\(toCountry ?? "nil")'")
                
                if fromCountry == nil || fromCountry == "Unknown" || toCountry == nil || toCountry == "Unknown" {
                    print("   ⚠️ PROBLEM: Unknown destination or origin")
                    results.problemTrips.append(ProblemTrip(
                        id: trip.id,
                        trip: trip,
                        issue: "Unknown destination or origin",
                        fromEvent: from,
                        toEvent: to
                    ))
                    // NOTE: Do NOT add to deletions here - this is just a warning, not an invalid trip
                    print("   → Marked as PROBLEM (but not automatically for deletion)")
                } else {
                    print("   ✓ Valid countries")
                }
            }
        }
        
        print("\n📊 Problem Trips Summary:")
        print("   Total Problems: \(results.problemTrips.count)")
        print("   Marked for Deletion: \(results.deletions.count)")
        
        print("\n🔍 Phase 2: Comparing with Fresh Trips...")
        // Compare existing trips with fresh trips
        for freshTrip in freshTrips {
            if let existingTrip = store.trips.first(where: {
                $0.fromEventID == freshTrip.fromEventID &&
                $0.toEventID == freshTrip.toEventID
            }) {
                // Trip exists - check for changes
                // ONLY compare: distance, departure date, arrival date
                // EXCLUDE: transport mode (type) and notes
                var changes: [String] = []
                
                if abs(existingTrip.distance - freshTrip.distance) > 0.1 {
                    changes.append("Distance: \(existingTrip.formattedDistance) → \(freshTrip.formattedDistance) mi")
                }
                
                // REMOVED: Transport mode comparison (excluded per user request)
                // if existingTrip.mode != freshTrip.mode {
                //     changes.append("Transport: \(existingTrip.mode.rawValue) → \(freshTrip.mode.rawValue)")
                // }
                
                if existingTrip.departureDate != freshTrip.departureDate {
                    changes.append("Departure date changed")
                }
                
                if existingTrip.arrivalDate != freshTrip.arrivalDate {
                    changes.append("Arrival date changed")
                }
                
                // REMOVED: Notes comparison (excluded per user request)
                
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
                // New trip
                results.additions.append(freshTrip)
            }
        }
        
        // Find trips that no longer have matching events (deletions)
        print("\n🔍 Phase 3: Finding Invalid Trips...")
        for existingTrip in store.trips {
            let stillValid = freshTrips.contains(where: {
                $0.fromEventID == existingTrip.fromEventID &&
                $0.toEventID == existingTrip.toEventID
            })
            
            if !stillValid && !results.deletions.contains(where: { $0.id == existingTrip.id }) {
                print("   ❌ Trip no longer valid: \(existingTrip.id)")
                print("      From Event: \(existingTrip.fromEventID)")
                print("      To Event: \(existingTrip.toEventID)")
                print("      Dates: \(formatDate(existingTrip.departureDate)) → \(formatDate(existingTrip.arrivalDate))")
                results.deletions.append(existingTrip)
            }
        }
        
        print("\n📊 === ANALYSIS COMPLETE ===")
        print("   Problem Trips: \(results.problemTrips.count)")
        print("   Deletions: \(results.deletions.count)")
        print("   Updates: \(results.updates.count)")
        print("   Additions: \(results.additions.count)")
        print("   Unchanged: \(results.unchanged.count)")
        print("\n⚠️ MISMATCH CHECK:")
        print("   Problems Found: \(results.problemTrips.count)")
        print("   Fixes Available: \(results.deletions.count + results.updates.count + results.additions.count)")
        if results.problemTrips.count != results.deletions.count {
            print("   ⚠️ NOTE: Not all problems result in deletions!")
            print("   'Unknown destination' trips are flagged but may still be valid trips")
        }
        print("=========================\n")
        
        return results
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
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
        let from = problem.fromEvent?.location.name ?? "Unknown"
        let to = problem.toEvent?.location.name ?? "Unknown"
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
    
    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(tripRoute)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatDate(update.existingTrip.departureDate))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    ForEach(update.changes, id: \.self) { change in
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                            Text(change)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    
    private var tripRoute: String {
        let fromEvent = store.events.first(where: { $0.id == update.existingTrip.fromEventID })
        let toEvent = store.events.first(where: { $0.id == update.existingTrip.toEventID })
        let from = fromEvent?.location.name ?? "Unknown"
        let to = toEvent?.location.name ?? "Unknown"
        return "\(from) → \(to)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct TripAdditionRow: View {
    let trip: Trip
    let store: DataStore
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(tripRoute)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatDate(trip.departureDate))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    HStack(spacing: 12) {
                        Label("\(trip.formattedDistance) mi", systemImage: "arrow.left.and.right")
                        Label(trip.mode.rawValue, systemImage: trip.mode.icon)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    
    private var tripRoute: String {
        let fromEvent = store.events.first(where: { $0.id == trip.fromEventID })
        let toEvent = store.events.first(where: { $0.id == trip.toEventID })
        let from = fromEvent?.location.name ?? "Unknown"
        let to = toEvent?.location.name ?? "Unknown"
        return "\(from) → \(to)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct TripDeletionRow: View {
    let trip: Trip
    let store: DataStore
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .red : .gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(tripRoute)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(formatDate(trip.departureDate))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Text("No longer matches event data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    
    private var tripRoute: String {
        let fromEvent = store.events.first(where: { $0.id == trip.fromEventID })
        let toEvent = store.events.first(where: { $0.id == trip.toEventID })
        let from = fromEvent?.location.name ?? "Unknown"
        let to = toEvent?.location.name ?? "Unknown"
        return "\(from) → \(to)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    TripRefreshView()
        .environmentObject(DataStore())
}
