# Fix: InfoRow Build Error

## 🐛 Problem

You're getting:
```
error: Invalid redeclaration of 'InfoRow'
/LocTrac/Views/NotificationManager.swift:477:16
```

## 🔍 Root Cause

There are likely **TWO NotificationManager files** in your project:
1. `NotificationManager.swift` (in Services or root)
2. `NotificationManager-Views.swift` or another copy (in Views folder)

OR you have an existing `InfoRow` struct elsewhere in your project.

## ✅ Solution: Delete or Rename InfoRow

### **Option 1: Find and Delete Duplicate File (Recommended)**

1. **In Xcode Project Navigator**:
   - Search for "NotificationManager" (⌘⇧O)
   - Look for multiple files with similar names
   - Delete any duplicates
   - Keep ONLY ONE NotificationManager.swift

2. **Search for existing InfoRow**:
   - Press ⌘⇧F (Find in Project)
   - Search: `struct InfoRow`
   - Find all occurrences
   - If there's an InfoRow in another file, that's the conflict

### **Option 2: Make InfoRow Name More Specific (Quick Fix)**

If you found an existing `InfoRow` elsewhere, change the one in `NotificationManager.swift` line 477:

**Find this code** (around line 477):
```swift
// Helper view for info rows
private struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
```

**Replace with**:
```swift
// Helper view for notification info rows
private struct NotificationInfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
```

**Then find all 4 uses** (around line 455-458):
```swift
// Before
InfoRow(icon: "moon.fill", text: "Calm, supportive tone", color: .indigo)
InfoRow(icon: "checkmark.circle.fill", text: "Sent once per day", color: .green)
InfoRow(icon: "clock.fill", text: "Morning delivery (12 AM - 12 PM)", color: .orange)
InfoRow(icon: "lock.fill", text: "Respects Do Not Disturb", color: .gray)

// After
NotificationInfoRow(icon: "moon.fill", text: "Calm, supportive tone", color: .indigo)
NotificationInfoRow(icon: "checkmark.circle.fill", text: "Sent once per day", color: .green)
NotificationInfoRow(icon: "clock.fill", text: "Morning delivery (12 AM - 12 PM)", color: .orange)
NotificationInfoRow(icon: "lock.fill", text: "Respects Do Not Disturb", color: .gray)
```

### **Option 3: Clean Build & Restart Xcode**

Sometimes Xcode caches old file contents:

1. **Close Xcode**
2. **Delete Derived Data**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. **Reopen Xcode**
4. **Clean Build Folder** (⌘⇧K)
5. **Build** (⌘B)

## 🔍 How to Find the Conflict

### **Step 1: Search for InfoRow**

Press **⌘⇧F** in Xcode, search for:
```
struct InfoRow
```

You'll see all declarations. Look for duplicates like:
```
NotificationManager.swift:477  - private struct InfoRow: View
DefaultLocationSettingsView.swift:125  - private struct InfoRow: View  ← CONFLICT!
```

### **Step 2: Rename One of Them**

Pick one file to rename:
- If in `DefaultLocationSettingsView.swift` → rename to `LocationInfoRow`
- If in `NotificationManager.swift` → rename to `NotificationInfoRow`

## ✅ Verification

After fixing:

1. ⌘⇧K (Clean Build)
2. ⌘B (Build)
3. Should succeed with no errors!

## 📝 If Still Failing

If you still get the error after trying these steps:

1. **Copy the entire error message** from Xcode
2. **Show me which files have InfoRow** (search results)
3. **I'll provide exact fix**

The issue is definitely a **name collision** — two structs named `InfoRow` exist somewhere in your project.

---

*Quick Fix Guide — LocTrac v1.4 — 2026-04-08*
