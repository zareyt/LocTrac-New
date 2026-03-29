import SwiftUI
import UniformTypeIdentifiers

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
                
                Button {
                    pickCSV()
                } label: {
                    Label("Choose CSV File", systemImage: "doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting)
                .padding(.horizontal)
                
                if let pickedURL {
                    Text("Selected: \(pickedURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button {
                        Task {
                            await runImport(from: pickedURL)
                        }
                    } label: {
                        if isImporting {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Label("Import Now", systemImage: "tray.and.arrow.down.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
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
        }
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
    
    @MainActor
    private func runImport(from url: URL) async {
        isImporting = true
        createdCount = 0
        updatedCount = 0
        errors = []
        showResults = false
        
        defer {
            isImporting = false
            showResults = true
        }
        
        guard let data = try? Data(contentsOf: url),
              var content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
            errors.append("Unable to read file or unsupported encoding.")
            return
        }
        
        // Normalize line endings
        content = content.replacingOccurrences(of: "\r\n", with: "\n")
                         .replacingOccurrences(of: "\r", with: "\n")
        
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.isEmpty {
            errors.append("The file is empty.")
            return
        }
        
        // Ensure "Golfing" activity exists
        let golfActivityID = ensureGolfingActivity()
        
        // Determine default/fallback location
        guard let importLocation = resolveImportLocation() else {
            errors.append("No locations available. Please create a location or set a Default Location first.")
            return
        }
        
        // Date formatter for UTC input like "9/19/2024 10:37:58 AM"
        let utcFormatter = DateFormatter()
        utcFormatter.locale = Locale(identifier: "en_US_POSIX")
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        utcFormatter.dateFormat = "M/d/yyyy h:mm:ss a"
        
        let calendar = Calendar(identifier: .gregorian)
        
        for (index, rawLine) in lines.enumerated() {
            // Data starts at row 1 (no header), but we’ll just process all non-empty lines
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            
            // Simple CSV split by comma; handle facility names with commas by a basic quoted field fallback
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
            
            // Find existing .stay event on that local day
            if var event = store.events.first(where: { ev in
                guard Event.EventType(rawValue: ev.eventType) == .stay else { return false }
                return ev.date.startOfDay == localStartOfDay
            }) {
                // Update existing event
                var changed = false
                if !event.activityIDs.contains(golfActivityID) {
                    event.activityIDs.append(golfActivityID)
                    changed = true
                }
                if !facility.isEmpty {
                    if event.note.isEmpty {
                        event.note = facility
                        changed = true
                    } else if !event.note.localizedCaseInsensitiveContains(facility) {
                        event.note = event.note + " • " + facility
                        changed = true
                    }
                }
                if changed {
                    store.update(event)
                    updatedCount += 1
                } else {
                    // No change needed; still count as updated? We’ll skip counting to keep stats meaningful.
                }
            } else {
                // Create new .stay event on that day using importLocation
                let newEvent = Event(
                    eventType: .stay,
                    date: localStartOfDay,
                    location: importLocation,
                    city: importLocation.city ?? "",
                    latitude: importLocation.latitude,
                    longitude: importLocation.longitude,
                    country: importLocation.country,
                    note: facility,
                    people: [],
                    activityIDs: [golfActivityID]
                )
                store.add(newEvent)
                createdCount += 1
            }
        }
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

