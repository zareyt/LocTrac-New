import SwiftUI
import UniformTypeIdentifiers

/// UPDATED VERSION - Replace your ImportGolfshotView.swift with this content
/// This version shows detailed preview of duplicates before deletion

struct ImportGolfshotView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @Binding var isPresented: Bool
    
    @State private var pickedURL: URL?
    @State private var isImporting = false
    @State private var createdCount = 0
    @State private var updatedCount = 0
    @State private var errors: [String] = []
    @State private var showResults = false
    @State private var showCleanupConfirmation = false
    @State private var duplicatesFound = 0
    @State private var previewChanges: [ImportPreviewItem] = []
    @State private var showPreview = false
    @State private var previewURL: URL?
    @State private var duplicatePreview: [DuplicateGroup] = []
    @State private var showDuplicatePreview = false
    @State private var selectionStateForDeletion: [String: Bool] = [:]
    
    struct DuplicateGroup: Identifiable {
        let id = UUID()
        let date: Date
        let allEvents: [Event] // All events for this date
        var keepIndex: Int // Index of event to keep (toggleable)
        
        var eventsToKeep: [Event] {
            [allEvents[keepIndex]]
        }
        
        var eventsToDelete: [Event] {
            allEvents.enumerated().filter { $0.offset != keepIndex }.map { $0.element }
        }
    }
    
    struct ImportPreviewItem: Identifiable {
        let id = UUID()
        let date: Date
        let facility: String
        let action: Action
        let events: [Event]
        
        enum Action {
            case update(Event)  // Will update this existing event
            case removeDuplicates([Event])  // Will remove these duplicate events
            case skip  // No existing event found - will skip
        }
        
        var actionDescription: String {
            switch action {
            case .update:
                return "Update existing"
            case .removeDuplicates(let duplicates):
                return "Remove \(duplicates.count) duplicate(s)"
            case .skip:
                return "⚠️ Skip (no event)"
            }
        }
        
        var actionColor: Color {
            switch action {
            case .update: return .blue
            case .removeDuplicates: return .orange
            case .skip: return .secondary
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Import Golfshot CSV")
                    .font(.title2).bold()
                
                Text("Select a .csv file exported from Golfshot. The file should have two columns per row starting at row 1: Round DateTime (UTC) and Facility name.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Cleanup duplicates section
                VStack(spacing: 8) {
                    Text("Step 1: Find & Remove Duplicates")
                        .font(.headline)
                    
                    Button {
                        findDuplicatesByDate()
                    } label: {
                        Label("Scan for Duplicate Events by Date", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isImporting)
                    
                    if duplicatesFound > 0 {
                        Text("Found \(duplicatesFound) duplicate entries on the same dates")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Button {
                            showDuplicatePreview = true
                        } label: {
                            Label("Preview Duplicates", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(role: .destructive) {
                            showCleanupConfirmation = true
                        } label: {
                            Label("Remove All Duplicates", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if duplicatesFound == 0 && duplicatePreview.isEmpty && showResults {
                        Text("✓ Scan complete - No duplicates found")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemBackground)))
                .padding(.horizontal)
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(spacing: 8) {
                    Text("Step 2: Preview & Import")
                        .font(.headline)
                    
                    Button {
                        pickCSV()
                    } label: {
                        Label("Choose CSV File", systemImage: "doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isImporting)
                    .padding(.horizontal)
                }
                
                if let pickedURL {
                    Text("Selected: \(pickedURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button {
                        Task {
                            await generatePreview(from: pickedURL)
                        }
                    } label: {
                        if isImporting {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Label("Preview Changes", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isImporting)
                    .padding(.horizontal)
                }
                
                if showResults {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Results")
                            .font(.headline)
                        Text("Created: \(createdCount)")
                        Text("Updated: \(updatedCount)")
                        if !errors.isEmpty {
                            Text("Errors: \(errors.count)")
                                .foregroundColor(.orange)
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(errors.indices, id: \.self) { idx in
                                        Text("• \(errors[idx])")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(maxHeight: 150)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Remove Duplicates", isPresented: $showCleanupConfirmation) {
                Button("Remove \(duplicatesFound) Duplicates", role: .destructive) {
                    removeDuplicates()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove duplicate .stay events that have the same date. The event with the most data (notes, activities) will be kept. This action cannot be undone.")
            }
            .sheet(isPresented: $showPreview) {
                PreviewChangesView(
                    previewItems: previewChanges,
                    onConfirm: {
                        if let url = previewURL {
                            Task {
                                await executeImport(from: url)
                            }
                        }
                    },
                    onCancel: {
                        showPreview = false
                    }
                )
            }
            .sheet(isPresented: $showDuplicatePreview) {
                DuplicatePreviewView(
                    duplicateGroups: duplicatePreview,
                    onConfirm: { groups in
                        showDuplicatePreview = false
                        removeDuplicatesWithGroups(groups)
                    },
                    onCancel: {
                        showDuplicatePreview = false
                    }
                )
            }
        }
    }
    
    // MARK: - Duplicate Preview View
    
    struct DuplicatePreviewView: View {
        let duplicateGroups: [DuplicateGroup]
        let onConfirm: ([DuplicateGroup]) -> Void
        let onCancel: () -> Void
        
        @State private var mutableGroups: [DuplicateGroup] = []
        
        var totalToDelete: Int {
            mutableGroups.reduce(0) { $0 + $1.eventsToDelete.count }
        }
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    // Summary header
                    VStack(spacing: 8) {
                        Text("Duplicate Events Preview")
                            .font(.title2).bold()
                        
                        HStack(spacing: 20) {
                            VStack {
                                Text("\(duplicateGroups.count)")
                                    .font(.title3).bold()
                                    .foregroundColor(.orange)
                                Text("Dates")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(totalToDelete)")
                                    .font(.title3).bold()
                                    .foregroundColor(.red)
                                Text("To Delete")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("Review the duplicates below. Tap 'Swap' to reverse which event is kept vs deleted.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    
                    // List of duplicate groups
                    List {
                        ForEach(mutableGroups.indices, id: \.self) { index in
                            let group = mutableGroups[index]
                            VStack(alignment: .leading, spacing: 8) {
                                // Date header with swap button
                                HStack {
                                    Text(group.date, style: .date)
                                        .font(.headline)
                                    Spacer()
                                    
                                    Button {
                                        swapSelection(for: index)
                                    } label: {
                                        Label("Swap", systemImage: "arrow.up.arrow.down")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Text("\(group.eventsToDelete.count) duplicate(s)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.orange.opacity(0.2)))
                                }
                                
                                // Events for this date
                                ForEach(Array(group.allEvents.enumerated()), id: \.element.id) { eventIndex, event in
                                    let isKeeping = eventIndex == group.keepIndex
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: isKeeping ? "checkmark.circle.fill" : "trash")
                                                .font(.caption)
                                                .foregroundColor(isKeeping ? .green : .red)
                                            Text(isKeeping ? "KEEP" : "DELETE")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(isKeeping ? .green : .red)
                                        }
                                        
                                        Text("📍 \(event.location.name)")
                                            .font(.subheadline)
                                            .fontWeight(isKeeping ? .semibold : .regular)
                                        
                                        if !event.note.isEmpty {
                                            Text("Note: \(event.note)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                        
                                        HStack(spacing: 12) {
                                            if !event.activityIDs.isEmpty {
                                                Label("\(event.activityIDs.count)", systemImage: "figure.run")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            if !event.people.isEmpty {
                                                Label("\(event.people.count)", systemImage: "person.2")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background((isKeeping ? Color.green : Color.red).opacity(0.1))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isKeeping ? Color.green : Color.red, lineWidth: isKeeping ? 2 : 1)
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(role: .destructive) {
                            onConfirm(mutableGroups)
                        } label: {
                            Label("Delete \(totalToDelete) Duplicates", systemImage: "trash.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        
                        Button(role: .cancel) {
                            onCancel()
                        } label: {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                }
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    mutableGroups = duplicateGroups
                }
            }
        }
        
        private func swapSelection(for groupIndex: Int) {
            guard groupIndex < mutableGroups.count else { return }
            let group = mutableGroups[groupIndex]
            
            // If only 2 events, simple swap
            if group.allEvents.count == 2 {
                mutableGroups[groupIndex].keepIndex = group.keepIndex == 0 ? 1 : 0
            } else {
                // For more than 2, cycle through them
                mutableGroups[groupIndex].keepIndex = (group.keepIndex + 1) % group.allEvents.count
            }
        }
    }
    
    // MARK: - Preview Changes View
    
    struct PreviewChangesView: View {
        let previewItems: [ImportPreviewItem]
        let onConfirm: () -> Void
        let onCancel: () -> Void
        
        var updateCount: Int {
            previewItems.filter { if case .update = $0.action { return true }; return false }.count
        }
        
        var removeCount: Int {
            previewItems.compactMap { item -> Int? in
                if case .removeDuplicates(let dups) = item.action {
                    return dups.count
                }
                return nil
            }.reduce(0, +)
        }
        
        var skipCount: Int {
            previewItems.filter { if case .skip = $0.action { return true }; return false }.count
        }
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    // Summary header
                    VStack(spacing: 8) {
                        Text("Preview Changes")
                            .font(.title2).bold()
                        
                        HStack(spacing: 20) {
                            VStack {
                                Text("\(updateCount)")
                                    .font(.title3).bold()
                                    .foregroundColor(.blue)
                                Text("Updates")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(removeCount)")
                                    .font(.title3).bold()
                                    .foregroundColor(.orange)
                                Text("Removals")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if skipCount > 0 {
                                VStack {
                                    Text("\(skipCount)")
                                        .font(.title3).bold()
                                        .foregroundColor(.secondary)
                                    Text("Skipped")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    
                    // List of changes
                    List {
                        ForEach(previewItems) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.date, style: .date)
                                        .font(.headline)
                                    Spacer()
                                    Text(item.actionDescription)
                                        .font(.caption)
                                        .foregroundColor(item.actionColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(item.actionColor.opacity(0.2)))
                                }
                                
                                if !item.facility.isEmpty {
                                    Text("Facility: \(item.facility)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                switch item.action {
                                case .update(let event):
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("📍 \(event.location.name)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if !event.note.isEmpty {
                                            Text("Current note: \(event.note)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                        if !event.activityIDs.isEmpty {
                                            Text("Has \(event.activityIDs.count) activities")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                case .removeDuplicates(let duplicates):
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Will keep the best event and remove \(duplicates.count) duplicate(s):")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        
                                        ForEach(duplicates) { dup in
                                            HStack(spacing: 4) {
                                                Image(systemName: "trash")
                                                    .font(.caption2)
                                                    .foregroundColor(.red)
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("📍 \(dup.location.name)")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    
                                                    if !dup.note.isEmpty {
                                                        Text("Note: \(dup.note)")
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                            .lineLimit(1)
                                                    }
                                                    
                                                    HStack(spacing: 8) {
                                                        if !dup.activityIDs.isEmpty {
                                                            Text("\(dup.activityIDs.count) activities")
                                                                .font(.caption2)
                                                                .foregroundColor(.secondary)
                                                        }
                                                        if !dup.people.isEmpty {
                                                            Text("\(dup.people.count) people")
                                                                .font(.caption2)
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                }
                                            }
                                            .padding(.leading, 8)
                                            .padding(.vertical, 4)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.red.opacity(0.05))
                                            .cornerRadius(6)
                                        }
                                    }
                                    
                                case .skip:
                                    Text("No existing event found for this date - will be skipped")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            onConfirm()
                        } label: {
                            Label("Confirm & Import", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(updateCount == 0 && removeCount == 0)
                        
                        Button(role: .cancel) {
                            onCancel()
                        } label: {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                }
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    // MARK: - Duplicate Detection & Removal
    
    /// Find duplicate events by scanning for multiple .stay events on the same date
    private func findDuplicatesByDate() {
        // Group .stay events by their date (start of day)
        var eventsByDate: [Date: [Event]] = [:]
        
        for event in store.events {
            guard Event.EventType(rawValue: event.eventType) == .stay else {
                continue
            }
            
            let startOfDay = event.date.startOfDay(in: .current)
            eventsByDate[startOfDay, default: []].append(event)
        }
        
        // Build preview data and count duplicates
        var duplicateCount = 0
        var previewGroups: [DuplicateGroup] = []
        
        for (date, events) in eventsByDate {
            if events.count > 1 {
                // Sort: Keep ORIGINAL events (most data) and DELETE imported ones
                // Imported events typically have:
                // - Location = "Loft" or "Other"
                // - Only golf course name in notes
                // - No activities (or only Golfing)
                // - No people
                let sorted = events.sorted { e1, e2 in
                    // Deprioritize "Loft" and "Other" locations (likely imports)
                    let e1IsImport = e1.location.name.caseInsensitiveCompare("Loft") == .orderedSame ||
                                     e1.location.name.caseInsensitiveCompare("Other") == .orderedSame
                    let e2IsImport = e2.location.name.caseInsensitiveCompare("Loft") == .orderedSame ||
                                     e2.location.name.caseInsensitiveCompare("Other") == .orderedSame
                    
                    if !e1IsImport && e2IsImport { return true }
                    if e1IsImport && !e2IsImport { return false }
                    
                    // Keep events with people over those without
                    if !e1.people.isEmpty && e2.people.isEmpty { return true }
                    if e1.people.isEmpty && !e2.people.isEmpty { return false }
                    
                    // Keep events with more activities
                    if e1.activityIDs.count > e2.activityIDs.count { return true }
                    if e1.activityIDs.count < e2.activityIDs.count { return false }
                    
                    // Keep events with longer notes (original likely has more info)
                    if e1.note.count > e2.note.count { return true }
                    if e1.note.count < e2.note.count { return false }
                    
                    // Finally, keep older one (by ID - earlier UUID)
                    return e1.id < e2.id
                }
                
                _ = [sorted.first!] // Keep reference for clarity
                let toDelete = Array(sorted.dropFirst())
                
                previewGroups.append(DuplicateGroup(
                    date: date,
                    allEvents: sorted,
                    keepIndex: 0 // Keep first (best) by default
                ))
                
                duplicateCount += toDelete.count
            }
        }
        
        // Sort by date
        duplicatePreview = previewGroups.sorted { $0.date < $1.date }
        duplicatesFound = duplicateCount
        
        // Show feedback even if no duplicates
        if duplicateCount == 0 {
            errors.append("No duplicate events found on the same dates.")
            showResults = true
        }
    }
    
    private func removeDuplicates() {
        // Group .stay events by their date (start of day)
        var eventsByDate: [Date: [Event]] = [:]
        
        for event in store.events {
            guard Event.EventType(rawValue: event.eventType) == .stay else {
                continue
            }
            
            let startOfDay = event.date.startOfDay(in: .current)
            eventsByDate[startOfDay, default: []].append(event)
        }
        
        var removedCount = 0
        
        // For each day with duplicates, keep ORIGINAL and delete imports
        for (_, events) in eventsByDate {
            if events.count > 1 {
                // Sort: Keep ORIGINAL events (most data) and DELETE imported ones
                let sorted = events.sorted { e1, e2 in
                    // Deprioritize "Loft" and "Other" locations (likely imports)
                    let e1IsImport = e1.location.name.caseInsensitiveCompare("Loft") == .orderedSame ||
                                     e1.location.name.caseInsensitiveCompare("Other") == .orderedSame
                    let e2IsImport = e2.location.name.caseInsensitiveCompare("Loft") == .orderedSame ||
                                     e2.location.name.caseInsensitiveCompare("Other") == .orderedSame
                    
                    if !e1IsImport && e2IsImport { return true }
                    if e1IsImport && !e2IsImport { return false }
                    
                    // Keep events with people over those without
                    if !e1.people.isEmpty && e2.people.isEmpty { return true }
                    if e1.people.isEmpty && !e2.people.isEmpty { return false }
                    
                    // Keep events with more activities
                    if e1.activityIDs.count > e2.activityIDs.count { return true }
                    if e1.activityIDs.count < e2.activityIDs.count { return false }
                    
                    // Keep events with longer notes (original likely has more info)
                    if e1.note.count > e2.note.count { return true }
                    if e1.note.count < e2.note.count { return false }
                    
                    // Finally, keep older one (by ID)
                    return e1.id < e2.id
                }
                
                // Keep first (best/original), delete rest (imports)
                for eventToRemove in sorted.dropFirst() {
                    store.delete(eventToRemove)
                    removedCount += 1
                }
            }
        }
        
        // Update the UI
        duplicatesFound = 0
        errors.append("Successfully removed \(removedCount) duplicate entries.")
        showResults = true
    }
    
    private func removeDuplicatesWithSelection() {
        var removedCount = 0
        
        // Delete only the events that are selected
        for group in duplicatePreview {
            for event in group.eventsToDelete {
                if selectionStateForDeletion[event.id] == true {
                    store.delete(event)
                    removedCount += 1
                }
            }
        }
        
        // Update the UI
        duplicatesFound = 0
        selectionStateForDeletion = [:]
        errors.append("Successfully removed \(removedCount) selected duplicate entries.")
        showResults = true
    }
    
    private func removeDuplicatesWithGroups(_ groups: [DuplicateGroup]) {
        var removedCount = 0
        
        // Delete the events marked for deletion in each group
        for group in groups {
            for event in group.eventsToDelete {
                store.delete(event)
                removedCount += 1
            }
        }
        
        // Update the UI
        duplicatesFound = 0
        errors.append("Successfully removed \(removedCount) duplicate entries.")
        showResults = true
    }
    
    private func pickCSV() {
        let supported = [UTType.commaSeparatedText, UTType.text, UTType.data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supported, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = Context.shared
        Context.shared.onPick = { url in
            self.pickedURL = url
        }
        UIApplication.shared.topMostViewController?.present(picker, animated: true)
    }
    
    // MARK: - Import Preview & Execution
    
    @MainActor
    private func generatePreview(from url: URL) async {
        isImporting = true
        previewChanges = []
        errors = []
        
        defer {
            isImporting = false
        }
        
        guard let data = try? Data(contentsOf: url),
              var content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
            errors.append("Unable to read file or unsupported encoding.")
            showResults = true
            return
        }
        
        // Normalize line endings
        content = content.replacingOccurrences(of: "\r\n", with: "\n")
                         .replacingOccurrences(of: "\r", with: "\n")
        
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.isEmpty {
            errors.append("The file is empty.")
            showResults = true
            return
        }
        
        // Date formatter for UTC input like "9/19/2024 10:37:58 AM"
        let utcFormatter = DateFormatter()
        utcFormatter.locale = Locale(identifier: "en_US_POSIX")
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        utcFormatter.dateFormat = "M/d/yyyy h:mm:ss a"
        
        var previews: [ImportPreviewItem] = []
        
        for (index, rawLine) in lines.enumerated() {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            
            let fields = splitCSVLine(line)
            guard fields.count >= 2 else {
                errors.append("Row \(index + 1): Expected 2 fields, found \(fields.count).")
                continue
            }
            
            let dateString = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let facility = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let utcDate = utcFormatter.date(from: dateString) else {
                errors.append("Row \(index + 1): Invalid date format '\(dateString)'.")
                continue
            }
            
            // Convert to local day (start of day)
            let localStartOfDay = utcDate.startOfDay(in: .current)
            
            // Find ALL .stay events on that day
            let eventsOnDay = store.events.filter { ev in
                guard Event.EventType(rawValue: ev.eventType) == .stay else { return false }
                return ev.date.startOfDay(in: .current) == localStartOfDay
            }
            
            if eventsOnDay.isEmpty {
                // No existing event - will skip
                previews.append(ImportPreviewItem(
                    date: localStartOfDay,
                    facility: facility,
                    action: .skip,
                    events: []
                ))
            } else if eventsOnDay.count == 1 {
                // Single event - will update
                previews.append(ImportPreviewItem(
                    date: localStartOfDay,
                    facility: facility,
                    action: .update(eventsOnDay[0]),
                    events: eventsOnDay
                ))
            } else {
                // Multiple events - will remove duplicates and update the kept one
                // Sort to determine which to keep (same logic as removeDuplicates)
                let sorted = eventsOnDay.sorted { e1, e2 in
                    if !e1.note.isEmpty && e2.note.isEmpty { return true }
                    if e1.note.isEmpty && !e2.note.isEmpty { return false }
                    if !e1.activityIDs.isEmpty && e2.activityIDs.isEmpty { return true }
                    if e1.activityIDs.isEmpty && !e2.activityIDs.isEmpty { return false }
                    return e1.id < e2.id
                }
                
                previews.append(ImportPreviewItem(
                    date: localStartOfDay,
                    facility: facility,
                    action: .removeDuplicates(Array(sorted.dropFirst())),
                    events: eventsOnDay
                ))
            }
        }
        
        previewChanges = previews.sorted { $0.date < $1.date }
        previewURL = url
        
        if errors.isEmpty {
            showPreview = true
        } else {
            showResults = true
        }
    }
    
    @MainActor
    private func executeImport(from url: URL) async {
        showPreview = false
        isImporting = true
        createdCount = 0
        updatedCount = 0
        var removedCount = 0
        errors = []
        showResults = false
        
        defer {
            isImporting = false
            showResults = true
        }
        
        // Ensure "Golfing" activity exists
        let golfActivityID = ensureGolfingActivity()
        
        // Execute the changes from the preview
        for item in previewChanges {
            switch item.action {
            case .update(var event):
                // Update existing event
                var changed = false
                if !event.activityIDs.contains(golfActivityID) {
                    event.activityIDs.append(golfActivityID)
                    changed = true
                }
                if !item.facility.isEmpty {
                    if event.note.isEmpty {
                        event.note = item.facility
                        changed = true
                    } else if !event.note.localizedCaseInsensitiveContains(item.facility) {
                        event.note = event.note + " • " + item.facility
                        changed = true
                    }
                }
                if changed {
                    store.update(event)
                    updatedCount += 1
                }
                
            case .removeDuplicates(let duplicates):
                // First, update the kept event (first in sorted list that was kept)
                let keptEvent = item.events.first { event in
                    !duplicates.contains(where: { $0.id == event.id })
                }
                
                if var kept = keptEvent {
                    var changed = false
                    if !kept.activityIDs.contains(golfActivityID) {
                        kept.activityIDs.append(golfActivityID)
                        changed = true
                    }
                    if !item.facility.isEmpty {
                        if kept.note.isEmpty {
                            kept.note = item.facility
                            changed = true
                        } else if !kept.note.localizedCaseInsensitiveContains(item.facility) {
                            kept.note = kept.note + " • " + item.facility
                            changed = true
                        }
                    }
                    if changed {
                        store.update(kept)
                        updatedCount += 1
                    }
                }
                
                // Then remove duplicates
                for duplicate in duplicates {
                    store.delete(duplicate)
                    removedCount += 1
                }
                
            case .skip:
                // Do nothing - no event to update
                break
            }
        }
        
        if removedCount > 0 {
            errors.append("Removed \(removedCount) duplicate event(s).")
        }
        
        // Clear preview data
        previewChanges = []
        previewURL = nil
    }
    
    private func ensureGolfingActivity() -> String {
        if let existing = store.activities.first(where: { $0.name.caseInsensitiveCompare("Golfing") == .orderedSame }) {
            return existing.id
        }
        let new = Activity(name: "Golfing")
        store.addActivity(new)
        return new.id
    }
    
    private func resolveImportLocation() -> Location? {
        if let def = store.defaultLocation {
            return def
        }
        if let other = store.locations.first(where: { $0.name == "Other" }) {
            return other
        }
        return store.locations.first
    }
}

// MARK: - Helpers

private extension Date {
    func startOfDay(in timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.startOfDay(for: self)
    }
}

// Basic CSV splitter that supports quoted second field (facility) with commas
private func splitCSVLine(_ line: String) -> [String] {
    var result: [String] = []
    var current = ""
    var inQuotes = false
    
    for char in line {
        if char == "\"" {
            inQuotes.toggle()
        } else if char == "," && !inQuotes {
            result.append(current)
            current = ""
        } else {
            current.append(char)
        }
    }
    result.append(current)
    return result
}

// MARK: - Document Picker plumbing

private final class Context: NSObject, UIDocumentPickerDelegate {
    static let shared = Context()
    var onPick: ((URL?) -> Void)?
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onPick?(urls.first)
        onPick = nil
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onPick?(nil)
        onPick = nil
    }
}

private extension UIApplication {
    var keyWindow: UIWindow? {
        // For iOS 15+
        return connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
    
    var topMostViewController: UIViewController? {
        guard var top = keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
