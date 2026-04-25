//
//  TimelineRestoreView.swift
//  LocTrac
//
//  Timeline-based selective restore from backup files
//

import SwiftUI
import UniformTypeIdentifiers

/// View for selectively restoring data from a backup using timeline filtering
struct TimelineRestoreView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var debugConfig: DebugConfig
    @Environment(\.dismiss) private var dismiss
    
    init(isPresented: Binding<Bool>, preselectedURL: URL?) {
        print("📌 [TimelineRestoreView.swift] File loaded - init called")
        print("🟢 [TimelineRestoreView] init called with preselectedURL: \(preselectedURL?.lastPathComponent ?? "nil")")
        self._isPresented = isPresented
        self.preselectedURL = preselectedURL
    }
    
    // If presented modally elsewhere, use this to dismiss
    @Binding var isPresented: Bool
    
    // Optional URL to pre-seed selection (from Exported Backups list or file picker)
    var preselectedURL: URL?
    
    @State private var pickedURL: URL?
    @State private var decodedBackup: DecodedBackupData?
    @State private var loadError: String?
    
    // Decoded backup data with real model types
    struct DecodedBackupData {
        let locations: [Location]
        let events: [Event]
        let activities: [Activity]
        let affirmations: [Affirmation]
        let trips: [Trip]
    }
    
    // Timeline filtering
    @State private var dateRange: ClosedRange<Date>?
    @State private var sliderStartDate: Date = Date()
    @State private var sliderEndDate: Date = Date()
    @State private var datePickerMode: DatePickerMode? = nil
    
    enum DatePickerMode: Identifiable {
        case start
        case end
        
        var id: String {
            switch self {
            case .start: return "start"
            case .end: return "end"
            }
        }
        
        var title: String {
            switch self {
            case .start: return "Select Start Date"
            case .end: return "Select End Date"
            }
        }
    }
    
    // Filtered counts
    @State private var filteredLocationsCount = 0
    @State private var filteredEventsCount = 0
    @State private var filteredEventsWithAffirmationsCount = 0 // NEW: Events that have affirmations
    @State private var filteredActivitiesCount = 0
    @State private var filteredAffirmationsCount = 0
    @State private var filteredTripsCount = 0
    @State private var filteredPeopleCount = 0
    
    // Import mode selection
    @State private var importMode: ImportMode = .merge
    
    // Selective import options
    @State private var importEvents = true
    @State private var importLocations = true
    @State private var importActivities = true
    @State private var importAffirmations = true
    @State private var importAffirmationEvents = true // NEW: Separate toggle for events with affirmations
    @State private var importTrips = true
    @State private var importPeople = true
    
    // Import state
    @State private var isImporting = false
    @State private var showResults = false
    @State private var resultMessage = ""
    @State private var isSuccess = false
    @State private var showConfirmation = false

    // v2.0: Image import from .zip archives
    @State private var archiveImageEntries: [String: Data] = [:]
    @State private var isZipBackup = false
    @State private var importImages = true
    @State private var imageConflictCount = 0
    @State private var imageConflictResolution: BackupArchiveService.ConflictResolution = .skip

    // NEW: SwiftUI file importer state
    @State private var showFileImporter = false
    
    enum ImportMode: String, CaseIterable {
        case merge = "Merge"
        case replace = "Replace All"
        
        var description: String {
            switch self {
            case .merge:
                return "Add selected data to your existing data"
            case .replace:
                return "Replace ALL data with selected backup data"
            }
        }
        
        var icon: String {
            switch self {
            case .merge:
                return "plus.circle.fill"
            case .replace:
                return "arrow.triangle.2.circlepath"
            }
        }
    }
    
    var body: some View {
        print("🔄 [TimelineRestoreView] body rendering - pickedURL: \(pickedURL?.lastPathComponent ?? "nil"), preselectedURL: \(preselectedURL?.lastPathComponent ?? "nil")")
        return NavigationStack {
            if pickedURL == nil && preselectedURL == nil {
                // File picker initial state
                filePickerInitialView
            } else {
                // Timeline restore interface
                if let _ = decodedBackup {
                    timelineRestoreView
                } else if let error = loadError {
                    errorView(error)
                } else {
                    loadingView
                }
            }
        }
        .onAppear {
            print("🟢 [TimelineRestoreView] onAppear - preselectedURL: \(preselectedURL?.lastPathComponent ?? "nil")")
            if let preselectedURL {
                pickedURL = preselectedURL
                Task {
                    await loadBackupFile(from: preselectedURL)
                }
            }
        }
        // NEW: Use SwiftUI's fileImporter instead of UIKit UIDocumentPickerViewController
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json, .text, .data, .zip, .archive],
            allowsMultipleSelection: false
        ) { result in
            print("📂 [TimelineRestoreView] fileImporter callback triggered")
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    print("✅ [TimelineRestoreView] File selected: \(url.lastPathComponent)")
                    pickedURL = url
                    Task {
                        await loadBackupFile(from: url)
                    }
                }
            case .failure(let error):
                print("❌ [TimelineRestoreView] File picker error: \(error.localizedDescription)")
                loadError = "Failed to pick file: \(error.localizedDescription)"
            }
        }
        .debugViewName("TimelineRestoreView")
    }
    
    // MARK: - File Picker Initial View
    
    private var filePickerInitialView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Import from Backup")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Select a backup file to preview and choose a date range to import.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                print("🔵 [TimelineRestoreView] 'Select Backup File' button tapped")
                showFileImporter = true
            } label: {
                Label("Select Backup File", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            
            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Timeline Restore View
    
    private var timelineRestoreView: some View {
        List {
            // File info section
            fileInfoSection
            
            // Timeline filter section
            timelineFilterSection
            
            // Import mode selection
            importModeSection
            
            // Selective import options
            selectiveImportSection

            // Image import options (only for .zip archives)
            if isZipBackup && !archiveImageEntries.isEmpty {
                imageImportSection
            }

            // Preview filtered data
            previewSection
            
            // Import button
            importButtonSection
            
            if showResults {
                resultsSection
            }
        }
        .navigationTitle("Import from Backup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                    dismiss()
                }
            }
        }
        .confirmationDialog(
            importMode == .replace ? "Replace All Data?" : "Merge Data?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button(importMode == .replace ? "Replace All Data" : "Merge Data", role: importMode == .replace ? .destructive : .none) {
                Task {
                    await performImport()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if importMode == .replace {
                Text("This will permanently replace all your current data with the selected backup data. This action cannot be undone. Are you sure?")
            } else {
                Text("This will add the selected data from the backup to your existing data. Duplicates may be created.")
            }
        }
        // Date picker sheet using item-based presentation for cleaner state management
        .sheet(item: $datePickerMode) { mode in
            NavigationStack {
                VStack {
                    Text("Currently editing: \(mode == .start ? "Start Date" : "End Date")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                    
                    Group {
                        switch mode {
                        case .start:
                            DatePicker(
                                "Start Date",
                                selection: $sliderStartDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            
                        case .end:
                            DatePicker(
                                "End Date",
                                selection: $sliderEndDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
                .navigationTitle(mode.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            print("✅ [TimelineRestoreView] Date picker Done - was editing: \(mode == .start ? "START" : "END")")
                            print("   Start: \(sliderStartDate.utcMediumDateString)")
                            print("   End: \(sliderEndDate.utcMediumDateString)")
                            validateAndUpdateDateRange()
                            datePickerMode = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    private var fileInfoSection: some View {
        Section("Selected Backup") {
            if let url = pickedURL {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(url.lastPathComponent)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let backup = decodedBackup {
                            HStack(spacing: 4) {
                                Text("\(backup.locations.count) locations, \(backup.events.count) events")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if isZipBackup && !archiveImageEntries.isEmpty {
                                    Text("+ \(archiveImageEntries.count) photos")
                                        .font(.caption)
                                        .foregroundColor(.cyan)
                                }
                            }
                        }
                    }
                }
            }
            
            Button {
                print("🔵 [TimelineRestoreView] 'Select Different File' button tapped (fileInfoSection)")
                showFileImporter = true
            } label: {
                Label("Select Different File", systemImage: "folder")
            }
        }
    }
    
    private var timelineFilterSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Date Range")
                        .font(.headline)
                    Spacer()
                    Button {
                        resetDateRange()
                    } label: {
                        Text("Reset")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // Start date
                HStack {
                    Text("From:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)
                    Spacer()
                    Button {
                        print("🔵 [TimelineRestoreView] Start date button tapped")
                        datePickerMode = .start
                    } label: {
                        Text(sliderStartDate.utcMediumDateString)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)  // Add spacing between buttons
                
                // End date
                HStack {
                    Text("To:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)
                    Spacer()
                    Button {
                        print("🔵 [TimelineRestoreView] End date button tapped")
                        datePickerMode = .end
                    } label: {
                        Text(sliderEndDate.utcMediumDateString)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                // Visual timeline indicator
                timelineVisualization
            }
            .padding(.vertical, 8)
        } header: {
            Text("Timeline Filter")
        } footer: {
            Text("Select the date range you want to import. Only events and trips within this range will be imported.")
        }
    }
    
    private var timelineVisualization: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timeline bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    // Selected range
                    if let backup = decodedBackup, !backup.events.isEmpty {
                        let minDate = backup.events.map { $0.date }.min() ?? Date()
                        let maxDate = backup.events.map { $0.date }.max() ?? Date()
                        let totalRange = maxDate.timeIntervalSince(minDate)
                        
                        if totalRange > 0 {
                            let startOffset = sliderStartDate.timeIntervalSince(minDate) / totalRange
                            let endOffset = sliderEndDate.timeIntervalSince(minDate) / totalRange
                            
                            let startX = CGFloat(max(0, min(1, startOffset))) * geometry.size.width
                            let endX = CGFloat(max(0, min(1, endOffset))) * geometry.size.width
                            let width = endX - startX
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: max(8, width), height: 8)
                                .offset(x: startX)
                        }
                    }
                }
            }
            .frame(height: 8)
            
            // Date labels
            if let backup = decodedBackup, !backup.events.isEmpty {
                let minDate = backup.events.map { $0.date }.min() ?? Date()
                let maxDate = backup.events.map { $0.date }.max() ?? Date()
                
                HStack {
                    Text(minDate.utcMediumDateString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(maxDate.utcMediumDateString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var importModeSection: some View {
        Section {
            ForEach(ImportMode.allCases, id: \.self) { mode in
                Button {
                    importMode = mode
                    updateFilteredCounts()
                } label: {
                    HStack {
                        Image(systemName: mode.icon)
                            .foregroundColor(mode == .replace ? .red : .blue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if importMode == mode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Import Mode")
        } footer: {
            if importMode == .replace {
                Label("Warning: Replace mode will delete all your current data", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var selectiveImportSection: some View {
        Section {
            Toggle(isOn: $importEvents) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Events")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(filteredEventsCount) events in date range")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if filteredEventsWithAffirmationsCount > 0 {
                            Text("(\(filteredEventsWithAffirmationsCount) with affirmations)")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            .onChange(of: importEvents) { _, _ in
                updateFilteredCounts()
            }
            
            Toggle(isOn: $importTrips) {
                HStack {
                    Image(systemName: "airplane")
                        .foregroundColor(.purple)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trips")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(filteredTripsCount) trips in date range")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onChange(of: importTrips) { _, _ in
                updateFilteredCounts()
            }
            
            Toggle(isOn: $importLocations) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Locations")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(importMode == .replace ? "All locations" : "Referenced locations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onChange(of: importLocations) { _, _ in
                updateFilteredCounts()
            }
            
            Toggle(isOn: $importActivities) {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.green)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Activities")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(filteredActivitiesCount) \(importMode == .replace ? "total activities" : "referenced activities")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onChange(of: importActivities) { _, _ in
                updateFilteredCounts()
            }
            
            Toggle(isOn: $importAffirmations) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Affirmations")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(filteredAffirmationsCount) \(importMode == .replace ? "total affirmations" : "unique affirmations")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if filteredEventsWithAffirmationsCount > 0 {
                            Text("(used in \(filteredEventsWithAffirmationsCount) event\(filteredEventsWithAffirmationsCount == 1 ? "" : "s"))")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            .onChange(of: importAffirmations) { _, newValue in
                // If affirmations are disabled, also disable affirmation events
                if !newValue {
                    importAffirmationEvents = false
                }
                updateFilteredCounts()
            }
            
            // NEW: Affirmation Events toggle (indented/sub-option)
            Toggle(isOn: $importAffirmationEvents) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.purple)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("  Affirmation Events")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("  Keep affirmations on imported events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(!importAffirmations) // Can't import affirmation events without affirmations
            .opacity(importAffirmations ? 1.0 : 0.5)
            .onChange(of: importAffirmationEvents) { _, _ in
                updateFilteredCounts()
            }
            
            Toggle(isOn: $importPeople) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("People")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(filteredPeopleCount) people in date range")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onChange(of: importPeople) { _, _ in
                updateFilteredCounts()
            }
            
            // Quick select buttons
            HStack {
                Button("Select All") {
                    importEvents = true
                    importTrips = true
                    importLocations = true
                    importActivities = true
                    importAffirmations = true
                    importAffirmationEvents = true
                    importPeople = true
                    updateFilteredCounts()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("Deselect All") {
                    importEvents = false
                    importTrips = false
                    importLocations = false
                    importActivities = false
                    importAffirmations = false
                    importAffirmationEvents = false
                    importPeople = false
                    updateFilteredCounts()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .listRowBackground(Color.clear)
        } header: {
            Text("Select Data to Import")
        } footer: {
            Text("Choose which types of data you want to import from the backup file.")
        }
    }
    
    private var imageImportSection: some View {
        Section {
            Toggle(isOn: $importImages) {
                HStack {
                    Image(systemName: "photo.fill")
                        .foregroundColor(.cyan)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Photos")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        let totalSize = BackupArchiveService.estimateImageSize(
                            imageFilenames: Array(archiveImageEntries.keys)
                        )
                        Text("\(archiveImageEntries.count) photos (\(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if importImages && imageConflictCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(imageConflictCount) photo\(imageConflictCount == 1 ? "" : "s") already exist\(imageConflictCount == 1 ? "s" : "") on this device")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    Picker("When a photo already exists:", selection: $imageConflictResolution) {
                        Text("Skip (keep existing)").tag(BackupArchiveService.ConflictResolution.skip)
                        Text("Replace (overwrite)").tag(BackupArchiveService.ConflictResolution.replace)
                        Text("Rename (import as copy)").tag(BackupArchiveService.ConflictResolution.rename)
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                }
            }
        } header: {
            Text("Photo Import")
        } footer: {
            if importImages {
                Text("Photos from the backup archive will be saved to the app's Documents folder.")
            } else {
                Text("Photos in the archive will not be imported. Only event data will be restored.")
            }
        }
    }

    private var previewSection: some View {
        Section("Data to Import") {
            HStack {
                Label("\(filteredEventsCount)", systemImage: "calendar")
                    .foregroundColor(.blue)
                Spacer()
                Text("Events in date range")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(filteredTripsCount)", systemImage: "airplane")
                    .foregroundColor(.purple)
                Spacer()
                Text("Trips in date range")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(filteredLocationsCount)", systemImage: "mappin.circle.fill")
                    .foregroundColor(.red)
                Spacer()
                Text("Locations" + (importMode == .replace ? " (all)" : " (referenced)"))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(filteredActivitiesCount)", systemImage: "figure.walk")
                    .foregroundColor(.green)
                Spacer()
                Text("Activities" + (importMode == .replace ? " (all)" : " (referenced)"))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(filteredAffirmationsCount)", systemImage: "sparkles")
                    .foregroundColor(.purple)
                Spacer()
                Text("Affirmations" + (importMode == .replace ? " (all)" : " (referenced)"))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(filteredEventsWithAffirmationsCount)", systemImage: "calendar.badge.checkmark")
                    .foregroundColor(.indigo)
                Spacer()
                Text("Events with affirmations")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(filteredPeopleCount)", systemImage: "person.2.fill")
                    .foregroundColor(.orange)
                Spacer()
                Text("People in events")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var importButtonSection: some View {
        Section {
            Button {
                showConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    if isImporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Label(
                            importMode == .replace ? "Replace All Data" : "Merge Data",
                            systemImage: importMode.icon
                        )
                        .fontWeight(.semibold)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .disabled(isImporting || (!importEvents && !importTrips && !importLocations && !importActivities && !importAffirmations && !importPeople))
            .buttonStyle(.borderedProminent)
            .tint(importMode == .replace ? .red : .blue)
            .listRowBackground(Color.clear)
        } footer: {
            if !importEvents && !importTrips && !importLocations && !importActivities && !importAffirmations && !importPeople {
                Text("Please select at least one data type to import")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var resultsSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(isSuccess ? .green : .orange)
                
                Text(isSuccess ? "Import Complete!" : "Import Status")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(resultMessage)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Done") {
                    isPresented = false
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Loading & Error Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading backup file...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error Loading Backup")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                print("🔵 [TimelineRestoreView] 'Select Different File' button tapped (errorView)")
                showFileImporter = true
            } label: {
                Label("Select Different File", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    
    // REMOVED: Old UIKit-based file picker that was causing sheet presentation conflicts
    // Now using SwiftUI's .fileImporter modifier instead
    /*
    private func pickBackupFile() {
        let supported = [UTType.json, UTType.text, UTType.data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supported, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = TimelineBackupPickerContext.shared
        TimelineBackupPickerContext.shared.onPick = { url in
            if let url {
                self.pickedURL = url
                Task {
                    await loadBackupFile(from: url)
                }
            }
        }
        UIApplication.shared.topMostViewController?.present(picker, animated: true)
    }
    */
    
    @MainActor
    private func loadBackupFile(from url: URL) async {
        decodedBackup = nil
        loadError = nil
        archiveImageEntries = [:]
        isZipBackup = false

        do {
            let data: Data

            // Detect .zip archive vs plain .json
            if BackupArchiveService.isZipArchive(at: url) {
                isZipBackup = true
                let extracted = try BackupArchiveService.extractArchive(at: url)
                data = extracted.jsonData
                archiveImageEntries = extracted.imageEntries

                // Detect conflicts
                imageConflictCount = BackupArchiveService.detectConflicts(
                    imageFilenames: Array(extracted.imageEntries.keys)
                ).count

                if DebugConfig.shared.isEnabled && DebugConfig.shared.logPhotos {
                    print("📷 [photos] [TimelineRestoreView] Loaded .zip archive: \(extracted.imageEntries.count) images, \(imageConflictCount) conflicts")
                }
            } else {
                data = try Data(contentsOf: url)
            }

            let decoder = JSONDecoder()

            // Decode as Import (the actual structure in backup.json)
            let importData = try decoder.decode(Import.self, from: data)
            
            // Convert Import.LocationData → Location
            let locations = importData.locations.map { locationData in
                Location(
                    id: locationData.id,
                    name: locationData.name,
                    city: locationData.city,
                    state: locationData.state,  // v1.5: State/province
                    latitude: locationData.latitude,
                    longitude: locationData.longitude,
                    country: locationData.country,
                    countryCode: locationData.countryCode,  // v1.5: ISO country code
                    theme: Theme(rawValue: locationData.theme) ?? .purple,
                    imageIDs: locationData.imageIDs,
                    customColorHex: locationData.customColorHex  // v1.5: Custom color
                )
            }
            
            // Convert Import.EventData → Event
            let events = importData.events.map { eventData in
                let location = locations.first(where: { $0.id == eventData.locationID }) 
                    ?? Location(name: "Unknown", city: nil, latitude: 0, longitude: 0, theme: .purple)
                
                return Event(
                    id: eventData.id,
                    eventType: Event.EventType(rawValue: eventData.eventType) ?? .unspecified,
                    date: eventData.date,
                    location: location,
                    city: eventData.city,  // v1.5: City for "Other" location events
                    latitude: eventData.latitude,
                    longitude: eventData.longitude,
                    country: eventData.country,
                    state: eventData.state,  // v1.5: Use state if available
                    note: eventData.note,
                    people: eventData.people ?? [],
                    activityIDs: eventData.activityIDs ?? [],
                    affirmationIDs: eventData.affirmationIDs ?? [],
                    imageIDs: eventData.imageIDs ?? []
                )
            }
            
            // Debug: Check affirmation IDs in loaded events
            let eventsWithAffirmations = events.filter { !$0.affirmationIDs.isEmpty }
            print("📂 [loadBackupFile] Events with affirmations: \(eventsWithAffirmations.count) out of \(events.count) total")
            if let firstWithAffirmations = eventsWithAffirmations.first {
                print("   Example: Event '\(firstWithAffirmations.location.name)' has \(firstWithAffirmations.affirmationIDs.count) affirmation IDs: \(firstWithAffirmations.affirmationIDs)")
            }
            
            // Convert Import.ActivityData → Activity
            let activities = importData.activities?.map { activityData in
                Activity(id: activityData.id, name: activityData.name)
            } ?? []
            
            // Convert Import.AffirmationData → Affirmation
            let affirmations = importData.affirmations?.map { affirmationData in
                Affirmation(
                    id: affirmationData.id,
                    text: affirmationData.text,
                    category: Affirmation.Category(rawValue: affirmationData.category) ?? .custom,
                    createdDate: affirmationData.createdDate,
                    color: affirmationData.color,
                    isFavorite: affirmationData.isFavorite
                )
            } ?? []
            
            print("📊 [loadBackupFile] Decoded affirmations:")
            print("   Total affirmations in backup: \(affirmations.count)")
            for (index, affirmation) in affirmations.enumerated() {
                print("   [\(index)] ID: \(affirmation.id), Text: '\(affirmation.text)', Category: \(affirmation.category.rawValue)")
            }
            
            // Convert Import.TripData → Trip
            let trips = importData.trips?.map { tripData in
                Trip(
                    id: tripData.id,
                    fromEventID: tripData.fromEventID,
                    toEventID: tripData.toEventID,
                    departureDate: tripData.departureDate,
                    arrivalDate: tripData.arrivalDate,
                    distance: tripData.distance,
                    transportMode: Trip.TransportMode(rawValue: tripData.transportMode) ?? .other,
                    co2Emissions: tripData.co2Emissions,
                    notes: tripData.notes,
                    isAutoGenerated: tripData.isAutoGenerated
                )
            } ?? []
            
            // Store converted data
            decodedBackup = DecodedBackupData(
                locations: locations,
                events: events,
                activities: activities,
                affirmations: affirmations,
                trips: trips
            )
            
            // Initialize date range to cover all events
            if !events.isEmpty {
                let dates = events.map { $0.date }
                let minDate = dates.min() ?? Date()
                let maxDate = dates.max() ?? Date()
                sliderStartDate = minDate
                sliderEndDate = maxDate
                dateRange = minDate...maxDate
            }
            
            updateFilteredCounts()
        } catch {
            loadError = "Failed to decode backup: \(error.localizedDescription)"
        }
    }
    
    private func validateAndUpdateDateRange() {
        // Ensure start is before end
        if sliderStartDate > sliderEndDate {
            let temp = sliderStartDate
            sliderStartDate = sliderEndDate
            sliderEndDate = temp
        }
        
        dateRange = sliderStartDate...sliderEndDate
        updateFilteredCounts()
    }
    
    private func resetDateRange() {
        guard let backup = decodedBackup, !backup.events.isEmpty else { return }
        let dates = backup.events.map { $0.date }
        sliderStartDate = dates.min() ?? Date()
        sliderEndDate = dates.max() ?? Date()
        dateRange = sliderStartDate...sliderEndDate
        updateFilteredCounts()
    }
    
    private func updateFilteredCounts() {
        guard let backup = decodedBackup else { return }
        
        let startDate = sliderStartDate
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: sliderEndDate) ?? sliderEndDate
        
        // Filter events by date range
        let filteredEvents = backup.events.filter { event in
            event.date >= startDate && event.date < endDate
        }
        filteredEventsCount = importEvents ? filteredEvents.count : 0
        
        // Count events that have affirmations (only if the toggle is on)
        filteredEventsWithAffirmationsCount = importAffirmationEvents ? filteredEvents.filter { !$0.affirmationIDs.isEmpty }.count : 0
        
        // Count unique people in filtered events (only if the toggle is on)
        let allPeople = Set(filteredEvents.flatMap { $0.people })
        filteredPeopleCount = importPeople ? allPeople.count : 0
        
        print("📊 [TimelineRestoreView] updateFilteredCounts:")
        print("   Events: \(filteredEventsCount)")
        print("   Events with affirmations: \(filteredEventsWithAffirmationsCount)")
        print("   People: \(filteredPeopleCount) unique people from \(filteredEvents.flatMap { $0.people }.count) total people entries")
        
        // Filter trips by date range (using associated event dates)
        let filteredTrips = backup.trips.filter { trip in
            // Check if any event in the trip's date range falls within our filter
            let fromEvent = backup.events.first { $0.id == trip.fromEventID }
            let toEvent = backup.events.first { $0.id == trip.toEventID }
            
            if let fromDate = fromEvent?.date, let toDate = toEvent?.date {
                return (fromDate >= startDate && fromDate < endDate) ||
                       (toDate >= startDate && toDate < endDate) ||
                       (fromDate < startDate && toDate >= endDate)
            }
            return false
        }
        filteredTripsCount = importTrips ? filteredTrips.count : 0
        
        if importMode == .replace {
            // Replace mode imports all locations, activities, and affirmations (but only if toggles are on)
            filteredLocationsCount = importLocations ? backup.locations.count : 0
            filteredActivitiesCount = importActivities ? backup.activities.count : 0
            filteredAffirmationsCount = importAffirmations ? backup.affirmations.count : 0
            print("   Mode: REPLACE - showing all locations (\(filteredLocationsCount)), activities (\(filteredActivitiesCount)), and affirmations (\(filteredAffirmationsCount))")
        } else {
            // Merge mode only imports referenced locations, activities, and affirmations (but only if toggles are on)
            let referencedLocationIDs = Set(filteredEvents.map { $0.location.id })
            filteredLocationsCount = importLocations ? backup.locations.filter { referencedLocationIDs.contains($0.id) }.count : 0
            
            let referencedActivityIDs = Set(filteredEvents.flatMap { $0.activityIDs })
            filteredActivitiesCount = importActivities ? backup.activities.filter { referencedActivityIDs.contains($0.id) }.count : 0
            
            let referencedAffirmationIDs = Set(filteredEvents.flatMap { $0.affirmationIDs })
            filteredAffirmationsCount = importAffirmations ? backup.affirmations.filter { referencedAffirmationIDs.contains($0.id) }.count : 0
            print("   Mode: MERGE - showing referenced locations (\(filteredLocationsCount)), activities (\(filteredActivitiesCount)), and affirmations (\(filteredAffirmationsCount))")
        }
    }
    
    @MainActor
    private func performImport() async {
        guard let backup = decodedBackup else { return }
        
        isImporting = true
        showResults = false
        
        var importedEventsCount = 0
        var importedTripsCount = 0
        var importedLocationsCount = 0
        var importedActivitiesCount = 0
        var importedAffirmationsCount = 0
        var importedPeopleCount = 0
        
        defer {
            isImporting = false
            showResults = true
        }
        
        print("📥 [TimelineRestoreView] performImport starting:")
        print("   Import toggles - Events: \(importEvents), Trips: \(importTrips), Locations: \(importLocations), Activities: \(importActivities), Affirmations: \(importAffirmations), AffirmationEvents: \(importAffirmationEvents), People: \(importPeople)")
        print("   Import mode: \(importMode.rawValue)")
        
        let startDate = sliderStartDate
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: sliderEndDate) ?? sliderEndDate
        
        if importMode == .replace {
            // Replace mode: clear selected data types first
            if importLocations {
                store.locations.removeAll()
            }
            if importEvents {
                store.events.removeAll()
            }
            if importActivities {
                store.activities.removeAll()
            }
            if importAffirmations {
                store.affirmations.removeAll()
            }
            if importTrips {
                store.trips.removeAll()
            }
            
            // Import ALL of selected types from backup (only if toggle is ON)
            if importLocations {
                store.locations = backup.locations
                importedLocationsCount = backup.locations.count
            }
            if importActivities {
                store.activities = backup.activities
                importedActivitiesCount = backup.activities.count
            }
            if importAffirmations {
                store.affirmations = backup.affirmations
                importedAffirmationsCount = backup.affirmations.count
                print("📝 [performImport] Replace mode - Imported all affirmations: \(importedAffirmationsCount)")
            }
        } else {
            // Merge mode: import only referenced data (only if toggles are ON)
            // Get filtered events
            let filteredEvents = backup.events.filter { $0.date >= startDate && $0.date < endDate }
            
            // Import locations if selected
            if importLocations {
                let referencedLocationIDs = Set(filteredEvents.map { $0.location.id })
                let locationsToImport = backup.locations.filter { referencedLocationIDs.contains($0.id) }
                
                print("📍 [performImport] Locations import (Merge mode):")
                print("   Locations to import: \(locationsToImport.count)")
                
                for location in locationsToImport {
                    // Skip "Other" location if one already exists (prevents duplicates)
                    let isOtherLocation = location.name.caseInsensitiveCompare("Other") == .orderedSame
                    let otherAlreadyExists = store.locations.contains { $0.name.caseInsensitiveCompare("Other") == .orderedSame }
                    
                    if isOtherLocation && otherAlreadyExists {
                        print("   ⏭️ Skipped 'Other' location (already exists)")
                        continue
                    }
                    
                    // Check for duplicate by ID
                    let alreadyExistsByID = store.locations.contains(where: { $0.id == location.id })
                    
                    if !alreadyExistsByID {
                        store.locations.append(location)
                        importedLocationsCount += 1
                        print("   ✅ Imported location: '\(location.name)'")
                    } else {
                        print("   ⏭️ Skipped '\(location.name)' (ID already exists)")
                    }
                }
                
                print("   Final imported count: \(importedLocationsCount)")
            }
            
            // Import activities if selected
            if importActivities {
                let referencedActivityIDs = Set(filteredEvents.flatMap { $0.activityIDs })
                let activitiesToImport = backup.activities.filter { referencedActivityIDs.contains($0.id) }
                
                for activity in activitiesToImport {
                    if !store.activities.contains(where: { $0.id == activity.id }) {
                        store.activities.append(activity)
                        importedActivitiesCount += 1
                    }
                }
            }
            
            // Import affirmations if selected
            if importAffirmations {
                let referencedAffirmationIDs = Set(filteredEvents.flatMap { $0.affirmationIDs })
                let affirmationsToImport = backup.affirmations.filter { referencedAffirmationIDs.contains($0.id) }
                
                print("📝 [performImport] Affirmations import (Merge mode):")
                print("   Filtered events count: \(filteredEvents.count)")
                print("   Referenced affirmation IDs: \(referencedAffirmationIDs.count)")
                print("   IDs: \(Array(referencedAffirmationIDs))")
                print("   Affirmations to import: \(affirmationsToImport.count)")
                print("   Current store.affirmations count: \(store.affirmations.count)")
                
                for affirmation in affirmationsToImport {
                    let alreadyExists = store.affirmations.contains(where: { $0.id == affirmation.id })
                    print("   Checking '\(affirmation.text)' (ID: \(affirmation.id)) - Already exists: \(alreadyExists)")
                    
                    if !alreadyExists {
                        store.affirmations.append(affirmation)
                        importedAffirmationsCount += 1
                        print("   ✅ Imported: '\(affirmation.text)'")
                    } else {
                        print("   ⏭️ Skipped (already exists): '\(affirmation.text)'")
                    }
                }
                
                print("   Final imported count: \(importedAffirmationsCount)")
            } else {
                print("📝 [performImport] Affirmations import DISABLED by toggle")
            }
        }
        
        // Import filtered events if selected
        if importEvents {
            let filteredEvents = backup.events.filter { $0.date >= startDate && $0.date < endDate }
            
            if importMode == .replace {
                // Replace mode: import all or clear people/activities/affirmations based on toggles
                var eventsToStore = filteredEvents
                
                // Clean up events based on what's NOT being imported
                if !importPeople || !importActivities || !importAffirmationEvents {
                    let originalActivityCount = filteredEvents.flatMap { $0.activityIDs }.count
                    let originalAffirmationCount = filteredEvents.flatMap { $0.affirmationIDs }.count
                    let originalPeopleCount = filteredEvents.flatMap { $0.people }.count
                    
                    eventsToStore = filteredEvents.map { event in
                        var modifiedEvent = event
                        if !importPeople {
                            modifiedEvent.people = []
                        }
                        if !importActivities {
                            modifiedEvent.activityIDs = []
                        }
                        if !importAffirmationEvents {
                            modifiedEvent.affirmationIDs = []
                        }
                        return modifiedEvent
                    }
                    
                    if !importActivities && originalActivityCount > 0 {
                        print("   🧹 Stripped \(originalActivityCount) activity references from events (Activities toggle OFF)")
                    }
                    if !importAffirmationEvents && originalAffirmationCount > 0 {
                        print("   🧹 Stripped \(originalAffirmationCount) affirmation references from events (Affirmation Events toggle OFF)")
                    }
                    if !importPeople && originalPeopleCount > 0 {
                        print("   🧹 Stripped \(originalPeopleCount) people from events (People toggle OFF)")
                    }
                }
                
                // Count unique people if importing them
                if importPeople {
                    let allPeople = Set(filteredEvents.flatMap { $0.people })
                    importedPeopleCount = allPeople.count
                }
                
                store.events = eventsToStore
                importedEventsCount = filteredEvents.count
            } else {
                // Merge mode
                // NEW: Build a mapping of old location IDs → new location IDs
                var locationIDMapping: [String: String] = [:]
                
                if importLocations {
                    let referencedLocationIDs = Set(filteredEvents.map { $0.location.id })
                    let locationsToImport = backup.locations.filter { referencedLocationIDs.contains($0.id) }
                    
                    for backupLocation in locationsToImport {
                        // Check if this location already exists in the store
                        if let existingLocation = store.locations.first(where: { $0.id == backupLocation.id }) {
                            // Already imported earlier in this session - use the same ID
                            locationIDMapping[backupLocation.id] = existingLocation.id
                        } else if backupLocation.name.caseInsensitiveCompare("Other") == .orderedSame {
                            // Special case: "Other" location - always map to current store's "Other"
                            if let storeOther = store.locations.first(where: { $0.name.caseInsensitiveCompare("Other") == .orderedSame }) {
                                locationIDMapping[backupLocation.id] = storeOther.id
                                print("   🔗 Mapping backup 'Other' (ID: \(backupLocation.id)) → store 'Other' (ID: \(storeOther.id))")
                            }
                        } else {
                            // Location was imported - map to itself
                            locationIDMapping[backupLocation.id] = backupLocation.id
                        }
                    }
                    
                    print("📍 [performImport] Location ID mapping created: \(locationIDMapping.count) mappings")
                }
                
                for event in filteredEvents {
                    if !store.events.contains(where: { $0.id == event.id }) {
                        var modifiedEvent = event
                        
                        // NEW: Remap location ID if needed
                        if let newLocationID = locationIDMapping[event.location.id],
                           let updatedLocation = store.locations.first(where: { $0.id == newLocationID }) {
                            // Update the event's embedded location to match the current store
                            modifiedEvent.location = updatedLocation
                            print("   🔗 Remapped event '\(event.id)' location from '\(event.location.id)' → '\(newLocationID)'")
                        } else if !store.locations.contains(where: { $0.id == event.location.id }) {
                            // Location doesn't exist - this would create an orphan!
                            // Try to find "Other" location as fallback
                            if let otherLocation = store.locations.first(where: { $0.name.caseInsensitiveCompare("Other") == .orderedSame }) {
                                print("   ⚠️ Event '\(event.id)' location ID '\(event.location.id)' not found - assigning to 'Other'")
                                modifiedEvent.location = otherLocation
                            } else {
                                print("   ❌ ERROR: Event '\(event.id)' location ID '\(event.location.id)' not found and no 'Other' location exists!")
                            }
                        }
                        
                        // Clean up based on toggles
                        if !importPeople {
                            modifiedEvent.people = []
                        }
                        if !importActivities {
                            if !modifiedEvent.activityIDs.isEmpty {
                                print("   🧹 Stripping \(modifiedEvent.activityIDs.count) activity IDs from event '\(modifiedEvent.location.name)' on \(modifiedEvent.date.utcMediumDateString)")
                            }
                            modifiedEvent.activityIDs = []
                        }
                        if !importAffirmationEvents {
                            if !modifiedEvent.affirmationIDs.isEmpty {
                                print("   🧹 Stripping \(modifiedEvent.affirmationIDs.count) affirmation IDs from event '\(modifiedEvent.location.name)' on \(modifiedEvent.date.utcMediumDateString)")
                            }
                            modifiedEvent.affirmationIDs = []
                        }
                        
                        store.events.append(modifiedEvent)
                        
                        // Count what was actually imported
                        if importPeople {
                            importedPeopleCount += event.people.count
                        }
                        
                        importedEventsCount += 1
                    }
                }
            }
        }
        
        // Import filtered trips if selected
        if importTrips {
            let filteredTrips = backup.trips.filter { trip in
                let fromEvent = backup.events.first { $0.id == trip.fromEventID }
                let toEvent = backup.events.first { $0.id == trip.toEventID }
                
                if let fromDate = fromEvent?.date, let toDate = toEvent?.date {
                    return (fromDate >= startDate && fromDate < endDate) ||
                           (toDate >= startDate && toDate < endDate) ||
                           (fromDate < startDate && toDate >= endDate)
                }
                return false
            }
            
            if importMode == .replace {
                store.trips = filteredTrips
                importedTripsCount = filteredTrips.count
            } else {
                for trip in filteredTrips {
                    if !store.trips.contains(where: { $0.id == trip.id }) {
                        store.trips.append(trip)
                        importedTripsCount += 1
                    }
                }
            }
        }
        
        // v2.0: Import images from .zip archive
        var importedImagesCount = 0
        if isZipBackup && importImages && !archiveImageEntries.isEmpty {
            // Filter images to only those referenced by imported events/locations
            let startDateForImages = sliderStartDate
            let endDateForImages = Calendar.current.date(byAdding: .day, value: 1, to: sliderEndDate) ?? sliderEndDate
            let filteredEventsForImages = backup.events.filter { $0.date >= startDateForImages && $0.date < endDateForImages }

            let relevantFilenames = Set(
                BackupArchiveService.imageFilenames(for: filteredEventsForImages, locations: backup.locations)
            )

            let imagesToImport = archiveImageEntries.filter { relevantFilenames.contains($0.key) }

            if !imagesToImport.isEmpty {
                let filenameMap = BackupArchiveService.importImages(imagesToImport, resolution: imageConflictResolution)
                importedImagesCount = filenameMap.count

                // If rename resolution was used, remap image references in imported events
                if imageConflictResolution == .rename {
                    let hasRenames = filenameMap.contains { $0.key != $0.value }
                    if hasRenames {
                        for i in store.events.indices {
                            let event = store.events[i]
                            let remapped = event.imageIDs.map { filenameMap[$0] ?? $0 }
                            if remapped != event.imageIDs {
                                store.events[i].imageIDs = remapped
                            }
                        }
                        for i in store.locations.indices {
                            if let ids = store.locations[i].imageIDs {
                                let remapped = ids.map { filenameMap[$0] ?? $0 }
                                if remapped != ids {
                                    store.locations[i].imageIDs = remapped
                                }
                            }
                        }
                        print("[TimelineRestoreView] Remapped image filenames in \(filenameMap.filter { $0.key != $0.value }.count) references")
                    }
                }

                print("[TimelineRestoreView] Imported \(importedImagesCount) images with resolution: \(imageConflictResolution)")
            }
        }

        // Ensure "Other" location exists
        store.ensureOtherLocationExists(saveIfAdded: false)

        // Save to backup.json
        store.storeData()
        
        // Force calendar to refresh after import
        store.bumpCalendarRefresh()
        print("🔄 [TimelineRestoreView] Bumped calendar refresh token after import")
        
        // Build detailed result message
        var parts: [String] = []
        
        if importEvents && importedEventsCount > 0 {
            parts.append("\(importedEventsCount) event\(importedEventsCount == 1 ? "" : "s")")
        }
        if importTrips && importedTripsCount > 0 {
            parts.append("\(importedTripsCount) trip\(importedTripsCount == 1 ? "" : "s")")
        }
        if importLocations && importedLocationsCount > 0 {
            parts.append("\(importedLocationsCount) location\(importedLocationsCount == 1 ? "" : "s")")
        }
        if importActivities && importedActivitiesCount > 0 {
            parts.append("\(importedActivitiesCount) activit\(importedActivitiesCount == 1 ? "y" : "ies")")
        }
        if importAffirmations && importedAffirmationsCount > 0 {
            parts.append("\(importedAffirmationsCount) affirmation\(importedAffirmationsCount == 1 ? "" : "s")")
        }
        if importPeople && importedPeopleCount > 0 {
            parts.append("\(importedPeopleCount) people")
        }
        if importedImagesCount > 0 {
            parts.append("\(importedImagesCount) photo\(importedImagesCount == 1 ? "" : "s")")
        }
        
        if parts.isEmpty {
            resultMessage = "⚠️ No new data was imported (all items may already exist)"
            isSuccess = false
        } else {
            let dataList = parts.joined(separator: ", ")
            resultMessage = "✓ Successfully imported:\n\(dataList)"
            isSuccess = true
        }
        
        print("📊 [TimelineRestoreView] Import completed: \(resultMessage)")
        
        // DON'T auto-close - let user dismiss manually or wait longer
        // User can tap Done/Cancel to close
    }
}

// MARK: - Document Picker Delegate (REMOVED - No longer needed with SwiftUI fileImporter)

/*
private final class TimelineBackupPickerContext: NSObject, UIDocumentPickerDelegate {
    static let shared = TimelineBackupPickerContext()
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
*/

// MARK: - UIApplication Extension (REMOVED - No longer needed with SwiftUI fileImporter)

/*
private extension UIApplication {
    var keyWindow: UIWindow? {
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
*/

// MARK: - Preview

struct TimelineRestoreView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineRestoreView(isPresented: .constant(true), preselectedURL: nil)
            .environmentObject(DataStore())
    }
}
