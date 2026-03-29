# How to Fix the Build Errors

## The Problem

Xcode is seeing a different version of `ImportGolfshotView.swift` than what I can edit. This is likely because:
1. There are multiple copies of the file in your project
2. Xcode has cached an old version
3. There's a file system sync issue

## The Solution

**Manually replace the file content:**

### Step 1: Delete ALL Copies
In Xcode Project Navigator, search for "ImportGolfshotView" and delete ALL files:
- ImportGolfshotView.swift
- ImportGolfshotView 2.swift
- ImportGolfshotView_NEW.swift
- Any other variations

**Important**: Choose "Move to Trash" not just "Remove Reference"

### Step 2: Clean Everything
```
1. Product → Clean Build Folder (⇧⌘K)
2. Close Xcode completely
3. Delete Derived Data:
   - Open Finder
   - Go to ~/Library/Developer/Xcode/DerivedData
   - Delete the LocTrac folder (or all folders to be safe)
4. Reopen Xcode
```

### Step 3: Create New File
1. In Xcode, right-click on "ListView Tab" folder (or wherever the file should be)
2. New File → Swift File
3. Name it exactly: `ImportGolfshotView`
4. Copy the ENTIRE content from `ImportGolfshotView_NEW.swift` into this new file
   - Or I can provide the content again if needed

### Step 4: Verify
After pasting the content, you should see at the top:
```swift
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
    @State private var showCleanupConfirmation = false
    @State private var duplicatesFound = 0
    @State private var previewChanges: [ImportPreviewItem] = []  // ← This line should exist!
    @State private var showPreview = false
    @State private var previewURL: URL?
```

Notice line 17-19 have the new preview-related state variables.

## Alternative: Use ImportGolfshotView_NEW.swift Directly

If the above doesn't work:
1. Delete `ImportGolfshotView.swift` completely
2. Rename `ImportGolfshotView_NEW.swift` to `ImportGolfshotView.swift` in Finder
3. In Xcode, right-click the "ListView Tab" folder → "Add Files to LocTrac"
4. Select the renamed file
5. Clean and rebuild

Let me know which approach you'd like to try, or if you need me to provide the complete file content again!
