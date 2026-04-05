# Key Code Changes - Before & After

## TimelineRestoreView.swift

### 1. File Picker: UIKit → SwiftUI

#### BEFORE (UIKit - Causes Conflicts)
```swift
// Function that presents UIKit view controller
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

// Button that calls it
Button {
    pickBackupFile()
} label: {
    Label("Select Backup File", systemImage: "folder")
}
```

#### AFTER (SwiftUI - No Conflicts)
```swift
// State variable
@State private var showFileImporter = false

// Button triggers state change
Button {
    print("🔵 [TimelineRestoreView] 'Select Backup File' button tapped")
    showFileImporter = true
} label: {
    Label("Select Backup File", systemImage: "folder")
}

// SwiftUI modifier handles file picking
.fileImporter(
    isPresented: $showFileImporter,
    allowedContentTypes: [.json, .text, .data],
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
```

### 2. Removed UIKit Dependencies

#### BEFORE
```swift
// UIKit delegate class
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

// UIKit view controller finding logic
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
```

#### AFTER
```swift
// COMMENTED OUT - No longer needed with SwiftUI fileImporter
// (All UIKit code removed/commented)
```

### 3. Added Debug Logging

#### BEFORE
```swift
struct TimelineRestoreView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    var preselectedURL: URL?
    
    var body: some View {
        NavigationStack {
            // ... view code
        }
        .onAppear {
            if let preselectedURL {
                pickedURL = preselectedURL
                Task {
                    await loadBackupFile(from: preselectedURL)
                }
            }
        }
    }
}
```

#### AFTER
```swift
// File-level debug print
fileprivate let _ = print("📌 [TimelineRestoreView.swift] File loaded and compiled")

struct TimelineRestoreView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    // Explicit init with debug logging
    init(isPresented: Binding<Bool>, preselectedURL: URL?) {
        print("🟢 [TimelineRestoreView] init called with preselectedURL: \(preselectedURL?.lastPathComponent ?? "nil")")
        self._isPresented = isPresented
        self.preselectedURL = preselectedURL
    }
    
    var preselectedURL: URL?
    
    var body: some View {
        print("🔄 [TimelineRestoreView] body rendering - pickedURL: \(pickedURL?.lastPathComponent ?? "nil"), preselectedURL: \(preselectedURL?.lastPathComponent ?? "nil")")
        return NavigationStack {
            // ... view code
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
    }
}
```

---

## ViewsBackupExportView.swift

### Added Debug Logging

#### BEFORE
```swift
import SwiftUI
import UniformTypeIdentifiers

struct BackupExportView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    // ... state variables
    
    var body: some View {
        NavigationStack {
            // ... view code
        }
        .onAppear {
            loadFileInfo()
            loadBackupFiles()
        }
    }
}
```

#### AFTER
```swift
import SwiftUI
import UniformTypeIdentifiers

// File-level debug print
fileprivate let _ = print("📌 [ViewsBackupExportView.swift] File loaded and compiled")

struct BackupExportView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    
    init() {
        print("🟢 [BackupExportView] init called")
    }
    
    // ... state variables
    
    var body: some View {
        print("🔄 [BackupExportView] body rendering")
        return NavigationStack {
            // ... view code
        }
        .onAppear {
            print("🟢 [BackupExportView] onAppear called")
            loadFileInfo()
            loadBackupFiles()
        }
        .sheet(isPresented: $showTimelineRestoreWithPreselected) {
            print("🔷 [BackupExportView] Presenting TimelineRestoreView WITH preselected URL")
            // ... sheet content
        }
        .sheet(isPresented: $showTimelineRestoreWithoutPreselected) {
            print("🔷 [BackupExportView] Presenting TimelineRestoreView WITHOUT preselected URL")
            // ... sheet content
        }
    }
}
```

---

## StartTabView.swift

### Added Debug Logging

#### BEFORE
```swift
.sheet(isPresented: $showBackupExport) {
    BackupExportView()
        .environmentObject(store)
}
```

#### AFTER
```swift
.sheet(isPresented: $showBackupExport) {
    print("🔷 [StartTabView] Presenting BackupExportView sheet")
    return BackupExportView()
        .environmentObject(store)
}
```

---

## Why These Changes Fix the Issue

### The Core Problem
**UIKit's `UIDocumentPickerViewController`** was being presented **on top of** SwiftUI's sheet presentation system. When the UIKit picker dismissed, it left SwiftUI's presentation system in an inconsistent state.

### The Solution
**SwiftUI's `.fileImporter` modifier** stays within SwiftUI's presentation system, so there's no conflict. All presentations are managed by SwiftUI's coordinator.

### Benefits
1. ✅ No presentation conflicts
2. ✅ Cleaner, more SwiftUI-idiomatic code
3. ✅ No need for UIKit delegates or view controller introspection
4. ✅ Better error handling with Result type
5. ✅ Comprehensive debug logging to trace execution

---

## Verification

After clean build, you should see this flow in console:

```
📌 [ViewsBackupExportView.swift] File loaded and compiled
📌 [TimelineRestoreView.swift] File loaded and compiled
...
🔷 [StartTabView] Presenting BackupExportView sheet
🟢 [BackupExportView] init called
🔄 [BackupExportView] body rendering
🟢 [BackupExportView] onAppear called
...
🔵 [BackupExportView] 'Import from Backup File' button tapped
🔷 [BackupExportView] Presenting TimelineRestoreView WITHOUT preselected URL
🟢 [TimelineRestoreView] init called with preselectedURL: nil
🔄 [TimelineRestoreView] body rendering - pickedURL: nil, preselectedURL: nil
🟢 [TimelineRestoreView] onAppear - preselectedURL: nil
...
🔵 [TimelineRestoreView] 'Select Backup File' button tapped
📂 [TimelineRestoreView] fileImporter callback triggered
✅ [TimelineRestoreView] File selected: backup.json
...
🔵 [TimelineRestoreView] Start date button tapped
📆 [TimelineRestoreView] Date picker sheet appeared
✅ [TimelineRestoreView] Date picker Done button tapped
```

**No "Attempt to present while presentation is in progress" errors!**
