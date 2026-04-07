# Affirmations Backup & Import Implementation

## Feature Complete ✅

Affirmations are now fully integrated into the backup and import/restore system, working exactly like People and Activities.

---

## What's Been Added

### 1. **Backup System** ✅ (Already Working)

Affirmations are automatically backed up in `backup.json`:

**Export Struct** (`ImportExport.swift`)
```swift
struct Export: Codable {
    let locations: [LocationData]
    let events: [EventData]
    let activities: [ActivityData]
    let affirmations: [AffirmationData] // ✅ Already included
    let trips: [TripData]
}
```

**Affirmation Data Structure**:
```swift
struct AffirmationData: Codable {
    let id: String
    let text: String
    let category: String
    let createdDate: Date
    let color: String
    let isFavorite: Bool
}
```

**What Gets Backed Up**:
- Affirmation ID
- Full text
- Category (Health, Success, Relationships, etc.)
- Creation date
- Color
- Favorite status

**Events Include Affirmation References**:
```swift
struct EventData: Codable {
    // ...
    let affirmationIDs: [String] // ✅ References to affirmations
}
```

---

### 2. **Import/Restore System** ✨ (NEW!)

**Timeline Restore View** (`TimelineRestoreView.swift`)

#### **A. Affirmations Toggle**

Added toggle control alongside Activities and People:

```
┌─────────────────────────────────┐
│ Select Data to Import           │
├─────────────────────────────────┤
│ ✓ Events                        │
│ ✓ Trips                         │
│ ✓ Locations                     │
│ ✓ Activities (X referenced)     │
│ ✓ Affirmations (Y referenced)   │  ← NEW!
│ ✓ People                        │
└─────────────────────────────────┘
```

**Visual Design**:
- ✨ Purple sparkles icon
- Purple color (matches affirmations theme)
- Shows count of referenced affirmations in date range

#### **B. Filtered Counts**

**Replace Mode**:
- Shows total affirmations count from backup file
- Example: "5 total affirmations"

**Merge Mode**:
- Shows only affirmations referenced in selected events
- Example: "3 referenced affirmations"
- Calculates which affirmations are actually used in the date range

#### **C. Import Logic**

**Replace Mode**:
1. If "Affirmations" toggled ON:
   - Clears all existing affirmations
   - Imports all affirmations from backup
   
2. If "Affirmations" toggled OFF:
   - Keeps existing affirmations
   - Strips affirmation IDs from imported events

**Merge Mode**:
1. If "Affirmations" toggled ON:
   - Imports only affirmations referenced in selected events
   - Skips affirmations that already exist (by ID)
   - Preserves affirmation IDs on imported events
   
2. If "Affirmations" toggled OFF:
   - Doesn't import any affirmations
   - Strips affirmation IDs from imported events

#### **D. Smart Deduplication**

```swift
for affirmation in affirmationsToImport {
    if !store.affirmations.contains(where: { $0.id == affirmation.id }) {
        store.affirmations.append(affirmation)
        importedAffirmationsCount += 1
    }
}
```

- Only imports affirmations that don't already exist
- Uses ID matching to prevent duplicates
- Counts what was actually imported

---

## User Experience Flow

### **Importing a Backup with Affirmations**

1. **Select Backup File**
   - Choose a backup.json file
   - System decodes affirmations automatically

2. **Set Date Range**
   - Slide timeline to select date range
   - Filtered affirmation count updates automatically

3. **Choose Import Mode**
   - **Replace**: Import all affirmations from backup
   - **Merge**: Import only referenced affirmations

4. **Toggle Data Types**
   - ✓ Affirmations = Include affirmations
   - ✗ Affirmations = Exclude affirmations (strip from events)

5. **Import**
   - System imports selected affirmations
   - Event-affirmation relationships preserved
   - Shows count in result: "✓ Successfully imported: X affirmations"

---

## Technical Implementation

### **Data Structures Updated**

**DecodedBackupData**:
```swift
struct DecodedBackupData {
    let locations: [Location]
    let events: [Event]
    let activities: [Activity]
    let affirmations: [Affirmation] // ✅ NEW
    let trips: [Trip]
}
```

**State Variables Added**:
```swift
@State private var filteredAffirmationsCount = 0
@State private var importAffirmations = true
```

### **Functions Updated**

#### **1. loadBackupFile()**
```swift
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
```

#### **2. updateFilteredCounts()**
```swift
if importMode == .replace {
    filteredAffirmationsCount = backup.affirmations.count
} else {
    let referencedAffirmationIDs = Set(filteredEvents.flatMap { $0.affirmationIDs })
    filteredAffirmationsCount = backup.affirmations.filter { 
        referencedAffirmationIDs.contains($0.id) 
    }.count
}
```

#### **3. performImport()**

**Replace Mode**:
```swift
if importAffirmations {
    store.affirmations.removeAll()
}
```

**Merge Mode**:
```swift
if importAffirmations {
    let referencedAffirmationIDs = Set(filteredEvents.flatMap { $0.affirmationIDs })
    let affirmationsToImport = backup.affirmations.filter { 
        referencedAffirmationIDs.contains($0.id) 
    }
    
    for affirmation in affirmationsToImport {
        if !store.affirmations.contains(where: { $0.id == affirmation.id }) {
            store.affirmations.append(affirmation)
            importedAffirmationsCount += 1
        }
    }
}
```

**Event Cleanup**:
```swift
if !importAffirmations {
    if !modifiedEvent.affirmationIDs.isEmpty {
        print("   🧹 Stripping \(modifiedEvent.affirmationIDs.count) affirmation IDs...")
    }
    modifiedEvent.affirmationIDs = []
}
```

#### **4. Result Message**
```swift
if importAffirmations && importedAffirmationsCount > 0 {
    parts.append("\(importedAffirmationsCount) affirmation\(importedAffirmationsCount == 1 ? "" : "s")")
}
```

---

## Example Scenarios

### **Scenario 1: Full Backup Restore**

**Setup**:
- Old phone with 50 affirmations
- New phone (empty)

**Actions**:
1. Import backup in **Replace** mode
2. Select all date range
3. Keep all toggles ON

**Result**:
- ✅ All 50 affirmations imported
- ✅ All event-affirmation relationships preserved
- Message: "✓ Successfully imported: 200 events, 50 affirmations, ..."

### **Scenario 2: Selective Date Range**

**Setup**:
- Backup from 2020-2025
- Want only 2024 trips

**Actions**:
1. Import backup in **Merge** mode
2. Select date range: Jan 2024 - Dec 2024
3. Keep "Affirmations" toggle ON

**Result**:
- ✅ Only affirmations used in 2024 events imported
- ✅ Example: 50 events → 10 unique affirmations
- Message: "✓ Successfully imported: 50 events, 10 affirmations"

### **Scenario 3: Import Events Without Affirmations**

**Setup**:
- Backup has events with affirmations
- Don't want affirmations on new device

**Actions**:
1. Import backup in **Merge** mode
2. Turn OFF "Affirmations" toggle
3. Import

**Result**:
- ✅ Events imported successfully
- ✅ Affirmation IDs stripped from events
- ✅ No affirmations added to library
- Message: "✓ Successfully imported: 50 events" (no affirmations mentioned)

### **Scenario 4: Merge Without Duplicates**

**Setup**:
- Device already has 20 affirmations
- Importing backup with 30 affirmations (10 duplicates)

**Actions**:
1. Import backup in **Merge** mode
2. "Affirmations" toggle ON

**Result**:
- ✅ Only 20 new affirmations imported
- ✅ 10 existing affirmations skipped (ID match)
- ✅ Final count: 40 total affirmations
- Message: "✓ Successfully imported: 20 affirmations"

---

## UI Elements

### **Toggle Section**
```
📍 Locations
👥 Activities (5 referenced activities)
✨ Affirmations (3 referenced affirmations)  ← NEW!
👤 People (8 people in date range)
```

### **Quick Actions**
- **Select All** → Includes affirmations
- **Deselect All** → Excludes affirmations

### **Import Button**
- Disabled if NO toggles selected
- Enabled if at least one toggle ON (including affirmations)

### **Result Message**
```
✓ Successfully imported:
- 25 events
- 5 trips
- 3 locations
- 4 activities
- 6 affirmations  ← NEW!
- 15 people
```

---

## Benefits

### ✅ **Consistent with Existing Features**
- Works exactly like Activities and People
- Same toggle pattern
- Same counting logic
- Same import behavior

### ✅ **Flexible Import Options**
- Can import all or referenced only
- Can exclude affirmations if desired
- Preserves event relationships

### ✅ **Smart Deduplication**
- Prevents duplicate affirmations
- Uses ID matching
- Accurate count reporting

### ✅ **Data Integrity**
- Event-affirmation relationships preserved
- Affirmation properties intact (category, color, favorite)
- No data loss

### ✅ **User-Friendly**
- Clear visual indication (✨ purple icon)
- Live count updates
- Helpful result messages

---

## Testing Checklist

- [ ] **Backup Creation**
  - Create affirmations
  - Add to events
  - Verify backup.json includes affirmations array
  - Verify events include affirmationIDs

- [ ] **Replace Mode Import**
  - Toggle affirmations ON: All affirmations imported
  - Toggle affirmations OFF: No affirmations imported, IDs stripped

- [ ] **Merge Mode Import**
  - Toggle affirmations ON: Referenced affirmations imported
  - Toggle affirmations OFF: No affirmations, IDs stripped
  - Existing affirmations preserved

- [ ] **Date Range Filtering**
  - Change date range: Affirmation count updates
  - Only shows affirmations used in selected events

- [ ] **Deduplication**
  - Import same backup twice
  - Affirmations not duplicated
  - Count shows 0 on second import

- [ ] **Result Messages**
  - Affirmation count shown when imported
  - Affirmation count omitted when not imported

---

## Summary

✅ **Affirmations fully integrated into backup system**  
✅ **Import/restore UI includes affirmations toggle**  
✅ **Smart filtering by date range and references**  
✅ **Deduplication prevents duplicates**  
✅ **Event relationships preserved**  
✅ **Works in both Replace and Merge modes**  
✅ **Consistent with Activities and People implementation**  

Affirmations can now be backed up and selectively imported just like any other data type in LocTrac! ✨
