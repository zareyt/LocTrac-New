# Affirmations in First Launch Wizard

## Feature Added ✨

### **New Affirmations Setup Step**

Added a new step to the First Launch Wizard that allows users to select preset affirmations during onboarding.

---

## What's New

### **Wizard Structure Updated**
- **Total Steps**: 4 → **5 steps**
  1. Welcome
  2. Permissions
  3. Locations
  4. Activities
  5. **Affirmations** ✨ (NEW!)

---

## Affirmations Step Features

### 📝 **Preset Affirmations Grouped by Category**

Displays all 10 preset affirmations from `Affirmation.presets`, organized by category:

#### 🫀 **Health & Wellness**
- "I am healthy, strong, and vibrant"

#### ⭐ **Success & Abundance**
- "I attract success and abundance"
- "Abundance flows to me effortlessly"

#### 👥 **Relationships**
- "My relationships are loving and supportive"

#### 🔥 **Confidence**
- "I am worthy of love and respect" ⭐ Popular
- "I am capable of achieving my goals"

#### ✨ **Gratitude**
- "I am grateful for this moment" ⭐ Popular

#### ☁️ **Peace & Calm**
- "I choose peace and calm"
- "I trust the journey of my life"

#### 🎨 **Creativity**
- "I am creative and inspired"

---

### ✅ **Smart Pre-Selection**

On first load:
- **Popular affirmations** (marked with ⭐) are **pre-selected**
- These are the ones with `isFavorite: true` in the presets:
  - "I am worthy of love and respect" (Confidence)
  - "I am grateful for this moment" (Gratitude)

Users can easily deselect these or add more!

---

### 🎨 **Beautiful Category-Based Design**

Each category section shows:
- **Category icon and name** in the category's color
- **Affirmations** as selectable cards
- **Checkmark circle** that fills when selected
- **Colored background** when selected (matches category color)
- **"Popular" badge** with yellow star for favorites

---

### ➕ **Create Custom Affirmations**

Users can also create their own:
1. **Select category** from dropdown menu
2. **Enter affirmation text** (multi-line support)
3. **Tap +** button to add
4. Automatically uses the category's default color

---

### 📊 **Live Affirmations List**

Shows all added affirmations:
- Count display: "Your affirmations (X):"
- Each row shows:
  - Category icon in color
  - Affirmation text
  - Category name
  - Delete button (X)

---

### 💡 **Helpful Tip**

Footer text reminds users:
> "Tip: You can skip this and add affirmations later from Activities & Affirmations"

---

## User Experience Flow

### 1. **Wizard Opens to Affirmations Step**
- Beautiful sparkles icon ✨
- Title: "Set Up Affirmations"
- Description explains what affirmations are for

### 2. **Browse Preset Affirmations**
- Grouped by category (Health, Success, Relationships, etc.)
- Popular ones pre-selected with ⭐ badge
- Tap to select/deselect
- Visual feedback: checkmark fills, background colors

### 3. **Add Custom (Optional)**
- Pick category
- Type affirmation
- Tap + to add
- Appears in list below

### 4. **Review Selection**
- See count: "Your affirmations (5):"
- All selected affirmations listed
- Delete any if desired

### 5. **Continue or Skip**
- Tap "Next" to continue (if not last step)
- Tap "Get Started" on final step
- All selections saved to DataStore

---

## Technical Implementation

### **State Management**
```swift
@State private var newAffirmationText = ""
@State private var selectedCategory: Affirmation.Category = .custom
@State private var selectedPresetIDs: Set<String> = []
```

### **Grouped Display**
```swift
var groupedPresets: [(category: Affirmation.Category, affirmations: [Affirmation])] {
    let grouped = Dictionary(grouping: Affirmation.presets) { $0.category }
    return Affirmation.Category.allCases.compactMap { category in
        guard let affirmations = grouped[category], !affirmations.isEmpty else { return nil }
        return (category, affirmations)
    }
}
```

### **Auto-Selection on First Load**
```swift
.onAppear {
    // If store is empty, pre-select popular (favorited) affirmations
    if store.affirmations.isEmpty {
        let popularAffirmations = Affirmation.presets.filter { $0.isFavorite }
        for affirmation in popularAffirmations {
            selectedPresetIDs.insert(affirmation.id)
            store.addAffirmation(affirmation)
        }
    }
}
```

### **Toggle Selection**
```swift
private func togglePresetAffirmation(_ affirmation: Affirmation) {
    if selectedPresetIDs.contains(affirmation.id) {
        selectedPresetIDs.remove(affirmation.id)
        // Remove from store
        if let existing = store.affirmations.first(where: { $0.text == affirmation.text }) {
            store.deleteAffirmation(existing)
        }
    } else {
        selectedPresetIDs.insert(affirmation.id)
        // Add to store
        store.addAffirmation(affirmation)
    }
}
```

---

## Benefits

### ✅ **Seamless Onboarding**
- Users discover affirmations feature during setup
- Don't have to manually create from scratch
- Popular ones pre-selected for quick start

### ✅ **Encourages Usage**
- Seeing preset affirmations inspires users
- Low barrier to entry (just tap to select)
- Can customize immediately or skip

### ✅ **Consistent with Activities Step**
- Same design pattern as Activities selection
- Familiar interaction model
- Grouped by category for easy browsing

### ✅ **Flexible**
- Can select all, some, or none
- Can add custom affirmations
- Can skip entirely and add later
- Can edit/delete selections

---

## Visual Design

### **Category Headers**
```
[Icon] Category Name
─────────────────────
```

### **Affirmation Card (Unselected)**
```
┌─────────────────────────────────┐
│ ○  I am healthy, strong, and    │
│    vibrant                       │
└─────────────────────────────────┘
```

### **Affirmation Card (Selected)**
```
┌─────────────────────────────────┐
│ ✓  I am worthy of love and      │  ← Colored background
│    respect                       │  ← Blue checkmark
│    ⭐ Popular                    │  ← Yellow star
└─────────────────────────────────┘
```

### **Custom Affirmation Creator**
```
┌─────────────────────────────────┐
│ Category: [Confidence ▾]        │
│                                  │
│ ┌─────────────────────────────┐ │
│ │ Enter your affirmation...   │+│
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

---

## Integration with Existing Features

### **DataStore**
- Uses existing `store.addAffirmation()`
- Uses existing `store.deleteAffirmation()`
- Uses existing `store.affirmations` array

### **Affirmation Model**
- Uses `Affirmation.presets` array
- Uses `Category` enum with icons and colors
- Respects `isFavorite` for popular badges

### **Wizard Flow**
- Integrates seamlessly with existing steps
- Follows same navigation pattern
- Uses same "Next" and "Get Started" buttons
- Progress bar updates correctly

---

## Summary

✅ **New Affirmations step added to wizard** (Step 5 of 5)  
✅ **10 preset affirmations** grouped by category  
✅ **2 popular affirmations** pre-selected (Confidence, Gratitude)  
✅ **Custom affirmation creation** available  
✅ **Beautiful category-based design** with icons and colors  
✅ **Skip option** for users who want to add later  
✅ **Seamless integration** with existing wizard and DataStore  

New users now get a warm introduction to affirmations with thoughtfully curated presets that inspire positive mindsets for their travels! ✨
