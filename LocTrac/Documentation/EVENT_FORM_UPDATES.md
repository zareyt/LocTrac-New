# Event Form Updates - Summary

## Changes Made ✅

### 1. **Stay Type Changed to Picker** 📝
- **Before**: Large visual cards with checkmarks
- **After**: Dropdown picker (menu style) like Trip's Transport Mode
- Shows emoji icon + capitalized name for each type
- Cleaner, more compact interface

### 2. **People Moved Above Activities** 👥 → 🚶
- **New Order**:
  1. Location Details
  2. Date Range
  3. Stay Type (picker)
  4. **People** ← Moved up
  5. **Activities** ← Moved down
  6. Coordinates (if "Other")
  7. Notes
  8. Save Button

### 3. **Default Location Support** 🏠
- Locations are now sorted with default location first
- Default location is automatically selected for new events
- Uses `UserDefaults.standard` key: `"defaultLocationID"`

---

## How Default Location Works

### Setting a Default Location

To set a default location, add this code to your location management:

```swift
// Set default location
UserDefaults.standard.set(locationID, forKey: "defaultLocationID")
```

### Where to Add "Set as Default" Feature

You can add a "Set as Default" option in several places:

#### Option 1: Location Form (Recommended)
Add a toggle when creating/editing locations:

```swift
// In your location form
Section {
    Toggle("Set as Default", isOn: $isDefault)
}

// On save:
if isDefault {
    UserDefaults.standard.set(location.id, forKey: "defaultLocationID")
}
```

#### Option 2: Location List (Quick Access)
Add a context menu to each location:

```swift
// In location list
.contextMenu {
    Button {
        UserDefaults.standard.set(location.id, forKey: "defaultLocationID")
    } label: {
        Label("Set as Default", systemImage: "star.fill")
    }
}
```

#### Option 3: Settings/About View
Add a picker in app settings:

```swift
Section("Default Location") {
    Picker("Default", selection: $defaultLocationID) {
        Text("None").tag(nil as String?)
        ForEach(store.locations) { location in
            Text(location.name).tag(location.id as String?)
        }
    }
    .onChange(of: defaultLocationID) { _, newValue in
        if let id = newValue {
            UserDefaults.standard.set(id, forKey: "defaultLocationID")
        } else {
            UserDefaults.standard.removeObject(forKey: "defaultLocationID")
        }
    }
}
```

### How It Works in the Form

**When creating a new event:**
1. Form checks for `defaultLocationID` in UserDefaults
2. If found, searches for that location in `store.locations`
3. Automatically selects it and populates coordinates
4. User can still change to any other location

**In the location picker:**
1. Default location is always shown first in the list
2. Other locations follow in their original order
3. Makes default easy to find and select

**When editing existing events:**
- Default location is NOT automatically applied
- Preserves the event's original location

---

## Quick Implementation Guide

### 1. Add "Set as Default" Button

**In your LocationFormView or similar:**

```swift
Section {
    Button {
        UserDefaults.standard.set(location.id, forKey: "defaultLocationID")
        // Optional: Show confirmation
    } label: {
        Label("Set as Default Location", systemImage: "star.fill")
    }
}
```

### 2. Show Current Default

**Display which location is default:**

```swift
Section("Default Location") {
    if let defaultID = UserDefaults.standard.string(forKey: "defaultLocationID"),
       let defaultLoc = store.locations.first(where: { $0.id == defaultID }) {
        HStack {
            Text(defaultLoc.name)
            Spacer()
            Text("Default")
                .foregroundColor(.orange)
                .font(.caption)
        }
    } else {
        Text("No default set")
            .foregroundColor(.secondary)
    }
}
```

### 3. Clear Default

**Allow removing default:**

```swift
Button(role: .destructive) {
    UserDefaults.standard.removeObject(forKey: "defaultLocationID")
} label: {
    Label("Clear Default Location", systemImage: "xmark.circle")
}
```

---

## Example: Complete Default Location Manager

Here's a complete view you could add to your app:

```swift
import SwiftUI

struct DefaultLocationPicker: View {
    @EnvironmentObject var store: DataStore
    @AppStorage("defaultLocationID") private var defaultLocationID: String = ""
    
    var body: some View {
        Form {
            Section {
                Picker("Default Location", selection: $defaultLocationID) {
                    Text("None").tag("")
                    ForEach(store.locations) { location in
                        HStack {
                            Circle()
                                .fill(Color(location.theme.uiColor))
                                .frame(width: 12, height: 12)
                            Text(location.name)
                        }
                        .tag(location.id)
                    }
                }
            } header: {
                Text("Default Location")
            } footer: {
                Text("This location will be automatically selected when creating new events.")
            }
            
            if !defaultLocationID.isEmpty,
               let defaultLocation = store.locations.first(where: { $0.id == defaultLocationID }) {
                Section("Current Default") {
                    HStack {
                        Circle()
                            .fill(Color(defaultLocation.theme.uiColor))
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading) {
                            Text(defaultLocation.name)
                                .font(.headline)
                            if let city = defaultLocation.city {
                                Text(city)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Default Location")
    }
}
```

---

## User Benefits

### For New Events
- ✅ Faster event creation
- ✅ One less field to fill
- ✅ Consistency in data entry
- ✅ Reduces errors (selecting wrong location)

### For Power Users
- ✅ Home location always selected by default
- ✅ Quick override if traveling
- ✅ Sorted list makes finding default easy

### For Data Quality
- ✅ Encourages consistent location selection
- ✅ Reduces "Other" location usage
- ✅ Better analytics and reporting

---

## Form Changes Summary

### Stay Type Picker
```
Old:
┌──────────────────┐
│ 🟥 Stay      ✓  │
│ 🟦 Host         │
│ 🟩 Vacation     │
└──────────────────┘

New:
Stay Type: 🟥 Stay ▼
```

### Section Reordering
```
Old Order:
1. Location
2. Date Range
3. Stay Type
4. Activities
5. People
...

New Order:
1. Location
2. Date Range
3. Stay Type (now picker)
4. People (moved up)
5. Activities (moved down)
...
```

### Location Selection
```
Picker shows:
┌──────────────────────┐
│ Select Location      │
│ ● Home (DEFAULT)     │  ← Always first
│ ● Arrowhead         │
│ ● Cabo              │
│ ● Other             │
└──────────────────────┘
```

---

## Testing Checklist

- [ ] Stay type picker shows all types with icons
- [ ] People section appears before activities
- [ ] Activities section appears after people
- [ ] Setting default location via UserDefaults works
- [ ] Default location shows first in picker
- [ ] Default location auto-selects for new events
- [ ] Default location NOT applied when editing
- [ ] Can still select any location (not locked to default)
- [ ] Coordinates update when default location selected
- [ ] Form validates properly with all changes

---

## Technical Details

### UserDefaults Key
```swift
"defaultLocationID"  // String value: location.id
```

### Location Sorting Logic
```swift
private var sortedLocations: [Location] {
    if let defaultLocationID = UserDefaults.standard.string(forKey: "defaultLocationID") {
        var sorted = store.locations
        if let defaultIndex = sorted.firstIndex(where: { $0.id == defaultLocationID }) {
            let defaultLocation = sorted.remove(at: defaultIndex)
            sorted.insert(defaultLocation, at: 0)
        }
        return sorted
    }
    return store.locations
}
```

### Auto-Selection Logic
```swift
// In setupInitialValues()
if !viewModel.updating && viewModel.location == nil {
    if let defaultLocationID = UserDefaults.standard.string(forKey: "defaultLocationID"),
       let defaultLocation = store.locations.first(where: { $0.id == defaultLocationID }) {
        viewModel.location = defaultLocation
        viewModel.latitude = defaultLocation.latitude
        viewModel.longitude = defaultLocation.longitude
    }
}
```

---

## Backward Compatibility

✅ **No Breaking Changes**
- If no default location is set, form works exactly as before
- Existing events are not affected
- All existing functionality preserved

✅ **Progressive Enhancement**
- Default location is optional
- Users can continue without setting one
- Can be added/removed at any time

---

## Next Steps

1. **Test the updated form** - Create and edit events
2. **Add default location UI** - Choose your preferred method
3. **Set your home location as default** - Try it out
4. **Enjoy faster event creation!** 🎉

---

## Files Modified

- ✅ `ModernEventFormView.swift` - All three changes implemented
  - Stay type now uses picker
  - People/Activities reordered
  - Default location support added

---

## Summary

Your event form now:
- 🔄 Uses dropdown picker for Stay Type (like Trip Management)
- 👥 Shows People before Activities
- 🏠 Supports default location (auto-selects + sorts first)
- ✨ More streamlined and consistent

**All changes maintain backward compatibility!**
