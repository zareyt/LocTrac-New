import SwiftUI
import UniformTypeIdentifiers

/// View for restoring from a backup.json file
/// This will replace the current backup.json with the selected file
struct RestoreBackupView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    // If presented modally elsewhere, use this to dismiss
    @Binding var isPresented: Bool
    
    // Optional URL to pre-seed selection (used when launched from Exported Backups list)
    var preselectedURL: URL? = nil
    
    @State private var pickedURL: URL?
    @State private var isRestoring = false
    @State private var showResults = false
    @State private var resultMessage = ""
    @State private var isSuccess = false
    @State private var showConfirmation = false
    
    // Preview state
    @State private var decodedPreview: Export?
    @State private var previewFileSize: String = "Unknown"
    @State private var previewFileDate: Date?
    @State private var showPreviewSheet = false
    @State private var previewError: String?
    
    // Share support for previewed file
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Warning header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Restore from Backup")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("⚠️ This will replace ALL your current data with the selected backup file. Make sure you have a backup of your current data before proceeding!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(0.1))
                )
                .padding(.horizontal)
                
                Divider()
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Label("How it works:", systemImage: "info.circle.fill")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text("1.").fontWeight(.bold)
                            Text("Select a backup.json file from your device")
                        }
                        HStack(alignment: .top) {
                            Text("2.").fontWeight(.bold)
                            Text("Preview the backup details")
                        }
                        HStack(alignment: .top) {
                            Text("3.").fontWeight(.bold)
                            Text("Confirm to replace your current data")
                        }
                        HStack(alignment: .top) {
                            Text("4.").fontWeight(.bold)
                            Text("App will reload with restored data")
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)
                
                // File picker button
                Button {
                    pickBackupFile()
                } label: {
                    Label("Select Backup File", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRestoring)
                .padding(.horizontal)
                
                if let pickedURL {
                    VStack(spacing: 12) {
                        Text("Selected: \(pickedURL.lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    await generatePreview()
                                }
                            } label: {
                                Label("Preview", systemImage: "eye")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isRestoring)
                            
                            Button(role: .destructive) {
                                showConfirmation = true
                            } label: {
                                if isRestoring {
                                    ProgressView().progressViewStyle(.circular)
                                } else {
                                    Label("Restore from This Backup", systemImage: "arrow.clockwise")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .disabled(isRestoring)
                        }
                    }
                    .padding(.horizontal)
                }
                
                if showResults {
                    VStack(spacing: 8) {
                        Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(isSuccess ? .green : .red)
                        
                        Text(resultMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.vertical)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Restore Backup?",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Restore and Replace All Data", role: .destructive) {
                    Task {
                        await restoreBackup()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently replace all your current data with the selected backup. This action cannot be undone. Are you sure?")
            }
            .sheet(isPresented: $showPreviewSheet) {
                NavigationStack {
                    VStack(spacing: 0) {
                        VStack(spacing: 8) {
                            Text("Backup Preview")
                                .font(.title2).bold()
                            
                            if let decodedPreview {
                                let locCount = decodedPreview.locations.count
                                let eventCount = decodedPreview.events.count
                                let actCount = decodedPreview.activities.count
                                let tripCount = decodedPreview.trips.count
                                
                                HStack(spacing: 20) {
                                    countBlock(value: locCount, label: "Locations", color: .red)
                                    countBlock(value: eventCount, label: "Events", color: .blue)
                                    countBlock(value: actCount, label: "Activities", color: .green)
                                    countBlock(value: tripCount, label: "Trips", color: .purple)
                                }
                                .padding(.top, 4)
                                
                                if let previewFileDate {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock")
                                        Text("Modified")
                                        Spacer()
                                        Text(previewFileDate, style: .relative)
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.caption)
                                }
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "doc")
                                    Text("File Size")
                                    Spacer()
                                    Text(previewFileSize)
                                        .foregroundColor(.secondary)
                                }
                                .font(.caption)
                            } else if let previewError {
                                Text(previewError)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            } else {
                                ProgressView()
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        
                        List {
                            if let decodedPreview {
                                Section("Summary") {
                                    HStack {
                                        Text("Filename")
                                        Spacer()
                                        Text(pickedURL?.lastPathComponent ?? "Unknown")
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    if let previewFileDate {
                                        HStack {
                                            Text("Last Modified")
                                            Spacer()
                                            Text(previewFileDate.formatted(date: .abbreviated, time: .shortened))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    HStack {
                                        Text("File Size")
                                        Spacer()
                                        Text(previewFileSize)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Section("Counts") {
                                    HStack {
                                        Label("Locations", systemImage: "mappin.circle.fill")
                                        Spacer()
                                        Text("\(decodedPreview.locations.count)")
                                    }
                                    HStack {
                                        Label("Events", systemImage: "calendar")
                                        Spacer()
                                        Text("\(decodedPreview.events.count)")
                                    }
                                    HStack {
                                        Label("Activities", systemImage: "figure.walk")
                                        Spacer()
                                        Text("\(decodedPreview.activities.count)")
                                    }
                                    HStack {
                                        Label("Trips", systemImage: "airplane")
                                        Spacer()
                                        Text("\(decodedPreview.trips.count)")
                                    }
                                }
                            }
                        }
                        
                        VStack(spacing: 12) {
                            // Optional: Share the picked file directly from preview
                            if pickedURL != nil {
                                Button {
                                    showShareSheet = true
                                } label: {
                                    Label("Share This Backup", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Button {
                                showPreviewSheet = false
                                showConfirmation = true
                            } label: {
                                Label("Restore from This Backup", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .disabled(decodedPreview == nil)
                            
                            Button(role: .cancel) {
                                showPreviewSheet = false
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
                    .sheet(isPresented: $showShareSheet) {
                        if let url = pickedURL {
                            ShareSheet(activityItems: [url])
                        }
                    }
                }
            }
            .onAppear {
                // If a preselected URL was provided, seed it and generate preview immediately
                if let preselectedURL {
                    self.pickedURL = preselectedURL
                    Task { await generatePreview() }
                }
            }
        }
    }
    
    private func countBlock(value: Int, label: String, color: Color) -> some View {
        VStack {
            Text("\(value)")
                .font(.title3).bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func pickBackupFile() {
        let supported = [UTType.json, UTType.text, UTType.data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supported, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = BackupPickerContext.shared
        BackupPickerContext.shared.onPick = { url in
            self.pickedURL = url
            // Clear previous preview state
            self.decodedPreview = nil
            self.previewError = nil
        }
        UIApplication.shared.topMostViewController?.present(picker, animated: true)
    }
    
    @MainActor
    private func generatePreview() async {
        guard let pickedURL else { return }
        decodedPreview = nil
        previewError = nil
        showResults = false
        
        do {
            let data = try Data(contentsOf: pickedURL)
            let decoder = JSONDecoder()
            let export = try decoder.decode(Export.self, from: data)
            decodedPreview = export
            
            // File attributes
            if let attributes = try? FileManager.default.attributesOfItem(atPath: pickedURL.path) {
                if let size = attributes[.size] as? Int64 {
                    previewFileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                } else {
                    previewFileSize = "Unknown"
                }
                previewFileDate = attributes[.modificationDate] as? Date
            } else {
                previewFileSize = "Unknown"
                previewFileDate = nil
            }
            
            showPreviewSheet = true
        } catch {
            previewError = "Failed to decode backup: \(error.localizedDescription)"
            showPreviewSheet = true
        }
    }
    
    @MainActor
    private func restoreBackup() async {
        guard let pickedURL else { return }
        
        isRestoring = true
        showResults = false
        
        defer {
            isRestoring = false
            showResults = true
        }
        
        // Read the selected backup file
        guard let backupData = try? Data(contentsOf: pickedURL) else {
            resultMessage = "Failed to read the selected backup file."
            isSuccess = false
            return
        }
        
        // Validate it's a proper backup by trying to decode it
        let decoder = JSONDecoder()
        guard let _ = try? decoder.decode(Export.self, from: backupData) else {
            resultMessage = "The selected file is not a valid backup file."
            isSuccess = false
            return
        }
        
        // Get the path to the current backup.json
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            resultMessage = "Unable to access app documents directory."
            isSuccess = false
            return
        }
        
        let destinationURL = documentsURL.appendingPathComponent("backup.json")
        
        // Create a backup of the current backup.json before replacing
        let backupOfCurrentURL = documentsURL.appendingPathComponent("backup_before_restore_\(Date().timeIntervalSince1970).json")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.copyItem(at: destinationURL, to: backupOfCurrentURL)
        }
        
        // Replace the backup.json file
        do {
            // Remove existing if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy selected backup to backup.json
            try backupData.write(to: destinationURL)
            
            // Reload data from the new backup
            store.loadData()
            
            resultMessage = "✓ Backup restored successfully!\n\nYour data has been restored. A backup of your previous data was saved as:\n\(backupOfCurrentURL.lastPathComponent)"
            isSuccess = true
            
            // Close the sheet after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isPresented = false
                dismiss()
            }
        } catch {
            resultMessage = "Failed to restore backup: \(error.localizedDescription)"
            isSuccess = false
        }
    }
}

// MARK: - Document Picker Delegate

private final class BackupPickerContext: NSObject, UIDocumentPickerDelegate {
    static let shared = BackupPickerContext()
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

// MARK: - UIApplication Extension

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

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
