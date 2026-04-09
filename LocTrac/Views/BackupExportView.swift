//
//  BackupExportView.swift
//  LocTrac
//
//  Backup and import data functionality
//

import SwiftUI
import UniformTypeIdentifiers

struct BackupExportView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    init() {
        print("📌 [ViewsBackupExportView.swift] File loaded - init called")
        print("🟢 [BackupExportView] init called")
    }
    
    @State private var showShareSheet = false
    @State private var showBackupSelectionForShare = false // NEW: Show selection dialog
    @State private var fileURL: URL?
    @State private var showExportSuccess = false
    @State private var showExportError = false
    @State private var errorMessage = ""
    @State private var lastBackupDate: Date?
    @State private var fileSize: String = "Unknown"
    @State private var backupFiles: [BackupFileInfo] = []
    @State private var fileToDelete: BackupFileInfo?
    @State private var showDeleteConfirmation = false
    
    // Present Timeline Restore flow with preselected URL (from list)
    @State private var showTimelineRestoreWithPreselected = false
    @State private var preselectedTimelineRestoreURL: URL?
    
    // Present Timeline Restore flow without preselected URL (Files picker path)
    @State private var showTimelineRestoreWithoutPreselected = false
    
    var body: some View {
        print("🔄 [BackupExportView] body rendering")
        return NavigationStack {
            List {
                infoSection
                statisticsSection
                exportOptionsSection
                fileDetailsSection
                
                if !backupFiles.isEmpty {
                    exportedBackupsSection
                }
            }
            .navigationTitle("Backup & Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = fileURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Backup Created", isPresented: $showExportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your backup has been created successfully!")
            }
            .alert("Error", isPresented: $showExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("Delete Backup?", isPresented: $showDeleteConfirmation, presenting: fileToDelete) { file in
                Button("Delete", role: .destructive) {
                    deleteBackupFile(file)
                }
                Button("Cancel", role: .cancel) { }
            } message: { file in
                Text("Are you sure you want to delete \(file.name)? This cannot be undone.")
            }
            .confirmationDialog("Select Backup to Share", isPresented: $showBackupSelectionForShare) {
                // Current backup.json
                Button("Current Backup (backup.json)") {
                    exportAndShare()
                }
                
                // Exported backups
                ForEach(backupFiles) { file in
                    Button(file.name) {
                        shareBackupFile(file)
                    }
                }
                
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Choose which backup file to share")
            }
            .onAppear {
                print("🟢 [BackupExportView] onAppear called")
                loadFileInfo()
                loadBackupFiles()
            }
            // Present TimelineRestoreView with preselected URL (from list)
            .sheet(isPresented: $showTimelineRestoreWithPreselected) {
                print("🔷 [BackupExportView] Presenting TimelineRestoreView WITH preselected URL")
                if let url = preselectedTimelineRestoreURL {
                    return AnyView(TimelineRestoreView(isPresented: $showTimelineRestoreWithPreselected, preselectedURL: url)
                        .environmentObject(store))
                } else {
                    print("⚠️ [BackupExportView] ERROR: No preselected URL despite sheet trigger!")
                    return AnyView(Text("Error: No URL selected"))
                }
            }
            // Present TimelineRestoreView without preselected URL (Files picker path)
            .sheet(isPresented: $showTimelineRestoreWithoutPreselected) {
                print("🔷 [BackupExportView] Presenting TimelineRestoreView WITHOUT preselected URL")
                return TimelineRestoreView(isPresented: $showTimelineRestoreWithoutPreselected, preselectedURL: nil)
                    .environmentObject(store)
            }
        }
    }
    
    // MARK: - View Components
    
    private var infoSection: some View {
        Section("About") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Backup your Data and Import Data")
                            .font(.headline)
                        Text("Export all locations, events, and activities. Import data from your backup, all or selected timeframe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var statisticsSection: some View {
        Section("Data Summary") {
            HStack {
                Label("\(store.locations.count)", systemImage: "mappin.circle.fill")
                    .foregroundColor(.red)
                Spacer()
                Text("Locations")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(store.events.count)", systemImage: "calendar")
                    .foregroundColor(.blue)
                Spacer()
                Text("Events")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("\(store.activities.count)", systemImage: "figure.walk")
                    .foregroundColor(.green)
                Spacer()
                Text("Activities")
                    .foregroundColor(.secondary)
            }
            
            if let lastBackup = lastBackupDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    Text(lastBackup, style: .relative)
                    Spacer()
                    Text("Last Backup")
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label(fileSize, systemImage: "doc.fill")
                    .foregroundColor(.purple)
                Spacer()
                Text("File Size")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var exportOptionsSection: some View {
        Section {
            // Share button - now shows selection dialog
            Button(action: { showBackupSelectionForShare = true }) {
                BackupOptionRow(
                    icon: "square.and.arrow.up",
                    color: .blue,
                    title: "Share Backup File",
                    subtitle: backupFiles.isEmpty ? "Select which backup to share" : "\(backupFiles.count + 1) backup\(backupFiles.count == 0 ? "" : "s") available"
                )
            }
            
            // Create backup button
            Button(action: createBackup) {
                BackupOptionRow(
                    icon: "arrow.clockwise.circle.fill",
                    color: .green,
                    title: "Create Fresh Backup",
                    subtitle: "Update backup file with current data"
                )
            }
            
            // Import button
            Button {
                print("🔵 [BackupExportView] 'Import from Backup File' button tapped")
                showTimelineRestoreWithoutPreselected = true
            } label: {
                BackupOptionRow(
                    icon: "clock.arrow.circlepath",
                    color: .orange,
                    title: "Import from Backup File",
                    subtitle: "Select backup file to import"
                )
            }
        } header: {
            Text("Backup & Import")
        } footer: {
            Text("Your backup file (backup.json) contains all your locations, events, and activities. Keep it safe to restore your data if needed.")
        }
    }
    
    private var fileDetailsSection: some View {
        Section("File Details") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Filename:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("backup.json")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
                
                HStack {
                    Text("Format:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("JSON")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Location:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("App Documents")
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
        }
    }
    
    private var exportedBackupsSection: some View {
        Section {
            ForEach(backupFiles) { backupFile in
                backupFileRow(backupFile)
            }
        } header: {
            HStack {
                Text("Exported Backups")
                Spacer()
                Text("\(backupFiles.count)")
                    .foregroundColor(.secondary)
            }
        } footer: {
            Text("These are backup files you've exported from this device. Tap the menu button to import with timeline filtering, share, or delete.")
        }
    }
    
    private func backupFileRow(_ backupFile: BackupFileInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(backupFile.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(backupFile.date, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text(backupFile.sizeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Menu {
                Button {
                    // Open timeline-based import with this file
                    print("🔵 [BackupExportView] 'Import from This Backup' menu item tapped for: \(backupFile.name)")
                    preselectedTimelineRestoreURL = backupFile.url
                    showTimelineRestoreWithPreselected = true
                } label: {
                    Label("Import from This Backup", systemImage: "clock.arrow.circlepath")
                }
                
                Button {
                    shareBackupFile(backupFile)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Button(role: .destructive) {
                    fileToDelete = backupFile
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Functions
    
    private func loadFileInfo() {
        guard let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("backup.json") else {
            return
        }
        
        // Get file attributes
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
            // Last modified date
            if let modDate = attributes[.modificationDate] as? Date {
                lastBackupDate = modDate
            }
            
            // File size
            if let size = attributes[.size] as? Int64 {
                fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        }
    }
    
    private func createBackup() {
        // 1) Save current data to Documents/backup.json
        store.storeData()
        
        // 2) Also create a timestamped copy in temporary directory so it appears in Exported Backups
        guard let sourceURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("backup.json") else {
            errorMessage = "Could not locate backup file after saving."
            showExportError = true
            return
        }
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            errorMessage = "Backup file not found after saving."
            showExportError = true
            return
        }
        let tempDir = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let exportFileName = "LocTrac_Backup_\(dateString).json"
        let tempURL = tempDir.appendingPathComponent(exportFileName)
        
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: tempURL)
        } catch {
            errorMessage = "Error creating exported copy: \(error.localizedDescription)"
            showExportError = true
        }
        
        // 3) Refresh file info and exported backups list
        loadFileInfo()
        loadBackupFiles()
        
        // 4) Show success alert
        showExportSuccess = true
    }
    
    // Load list of backup files
    private func loadBackupFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            // Filter for LocTrac backup files
            let backupURLs = fileURLs.filter { url in
                url.lastPathComponent.hasPrefix("LocTrac_Backup_") &&
                url.pathExtension == "json"
            }
            
            // Map to BackupFileInfo
            backupFiles = backupURLs.compactMap { url in
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
                    return nil
                }
                
                let date = attributes[.modificationDate] as? Date ?? Date()
                let size = attributes[.size] as? Int64 ?? 0
                let sizeString = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                
                return BackupFileInfo(
                    id: url.lastPathComponent,
                    name: url.lastPathComponent,
                    url: url,
                    date: date,
                    size: size,
                    sizeString: sizeString
                )
            }
            .sorted { $0.date > $1.date } // Most recent first
            
        } catch {
            print("Error loading backup files: \(error.localizedDescription)")
        }
    }
    
    // Share a specific backup file
    private func shareBackupFile(_ backupFile: BackupFileInfo) {
        fileURL = backupFile.url
        showShareSheet = true
    }
    
    // Delete a specific backup file
    private func deleteBackupFile(_ backupFile: BackupFileInfo) {
        do {
            try FileManager.default.removeItem(at: backupFile.url)
            loadBackupFiles() // Refresh list
        } catch {
            errorMessage = "Error deleting file: \(error.localizedDescription)"
            showExportError = true
        }
    }
    
    private func exportAndShare() {
        guard let sourceURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("backup.json") else {
            errorMessage = "Could not locate backup file"
            showExportError = true
            return
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            errorMessage = "Backup file not found. Please create a backup first."
            showExportError = true
            return
        }
        
        // Create a temporary copy with a better name
        let tempDir = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let exportFileName = "LocTrac_Backup_\(dateString).json"
        let tempURL = tempDir.appendingPathComponent(exportFileName)
        
        do {
            // Remove old temp file if it exists
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            
            // Copy to temp location with better name
            try FileManager.default.copyItem(at: sourceURL, to: tempURL)
            
            // Refresh backup files list
            loadBackupFiles()
            
            // Set URL and show share sheet
            fileURL = tempURL
            showShareSheet = true
            
        } catch {
            errorMessage = "Error preparing file: \(error.localizedDescription)"
            showExportError = true
        }
    }
}

// MARK: - Backup File Info Model

struct BackupFileInfo: Identifiable {
    let id: String
    let name: String
    let url: URL
    let date: Date
    let size: Int64
    let sizeString: String
}

// MARK: - Backup Option Row

struct BackupOptionRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct BackupExportView_Previews: PreviewProvider {
    static var previews: some View {
        BackupExportView()
            .environmentObject(DataStore())
    }
}
