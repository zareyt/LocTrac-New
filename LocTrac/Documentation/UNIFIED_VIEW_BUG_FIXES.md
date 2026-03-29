# LocationsUnifiedView Bug Fixes

## Issues Fixed

### 1. ✅ Map Not Displaying
**Problem:** The map was blank/not rendering locations

**Root Cause:** 
- `LocationsMapViewModel` was creating its own `DataStore()` instance
- The unified view wasn't properly syncing the store with the view model
- `LocationsView` wasn't receiving the `DataStore` environment object

**Fix:**
- Updated `LocationsMapViewModel.init()` to not create its own DataStore
- Added `setStore(_ store:)` method to properly initialize with shared store
- Added `refreshLocations()` method to keep map in sync with data changes
- Pass `store` as environment object to `LocationsView` and its children
- Call `mapVM.setStore(store)` in `onAppear`
- Watch for location changes with `onChange(of: store.locations)`

### 2. ✅ Pictures Missing When Info Button Pressed
**Problem:** Location photos disappeared when viewing location details

**Root Causes:**
- `LocationDetailView` wasn't receiving the `DataStore` environment object
- Missing `onChange` handler for `PhotosPicker` items
- No `savePhotos()` function to persist selected photos

**Fix:**
- Pass `.environmentObject(store)` to `LocationDetailView` in `LocationsView`
- Added `onChange(of: photoItems)` handler to trigger photo saving
- Implemented `savePhotos()` function to:
  - Load photo data from picker items
  - Save to `ImageStore`
  - Update location's `imageIDs` array
  - Persist changes to DataStore
  - Clear picker selection

### 3. ✅ List View Button Blocking Info Button
**Problem:** Floating "List View" button was positioned over the location preview card's "Info" button

**Fix:**
- Moved button from bottom-right to bottom-left
- Changed from `.padding(.trailing, 20)` to `.padding(.leading, 20)`
- Adjusted bottom padding from 100 to 240 to position above preview card
- Changed alignment from `HStack { Spacer(); button }` to `HStack { button; Spacer() }`

## Code Changes Summary

### LocationsUnifiedView.swift
```swift
// Changed button position
VStack {
    Spacer()
    HStack {
        Button { ... }  // Now on LEFT side
        .padding(.leading, 20)
        .padding(.bottom, 240)  // Higher up
        Spacer()
    }
}

// Added store to map layer
private var mapLayer: some View {
    LocationsView()
        .environmentObject(mapVM)
        .environmentObject(store)  // NEW
}

// Removed NavigationStack wrapper (handled by StartTabView)
```

### LocationsMapViewModel.swift
```swift
// NEW: Store reference
private var store: DataStore?

init() {
    self.locations = []
    self.mapLocation = Location(name: "Loading", ...)
}

// NEW: Sync with DataStore
func setStore(_ store: DataStore) {
    self.store = store
    self.locations = store.locations
    if let firstLocation = locations.first {
        self.mapLocation = firstLocation
        self.updateMapRegion(location: firstLocation)
    }
}

// NEW: Refresh when data changes
func refreshLocations() {
    guard let store = store else { return }
    self.locations = store.locations
    // Update current location if deleted
    if !locations.contains(where: { $0.id == mapLocation.id }),
       let firstLocation = locations.first {
        self.mapLocation = firstLocation
    }
}
```

### LocationsView.swift
```swift
struct LocationsView: View {
    @EnvironmentObject private var vm: LocationsMapViewModel
    @EnvironmentObject var store: DataStore  // NEW

    var body: some View {
        // ...
        .sheet(item: $vm.sheetLocation) { location in
            LocationDetailView(lformType: $lformType, locationID: location.id)
                .environmentObject(vm)
                .environmentObject(store)  // NEW: Pass store for images
        }
    }
}
```

### LocationDetailView.swift
```swift
var body: some View {
    // ...
    .onChange(of: photoItems) { oldItems, newItems in
        Task {
            await savePhotos(newItems, to: location)
        }
    }
}

// NEW: Photo saving function
private func savePhotos(_ items: [PhotosPickerItem], to location: Location) async {
    var updated = location
    var currentIDs = updated.imageIDs ?? []
    
    for item in items {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { continue }
        
        let filename = ImageStore.save(uiImage)
        currentIDs.append(filename)
    }
    
    updated.imageIDs = currentIDs.isEmpty ? nil : currentIDs
    store.update(updated)
    photoItems = []
}
```

## Testing Checklist

After these fixes, verify:
- [x] Map displays with all location pins
- [x] Tapping pins shows correct location
- [x] "List View" button is visible and doesn't block Info button
- [x] Tapping "Info" button shows location details with photos
- [x] Can add new photos via PhotosPicker
- [x] Photos persist after closing and reopening detail view
- [x] Can delete photos
- [x] "Show on Map" button in list works correctly
- [x] Adding/editing/deleting locations updates both map and list

## Architecture Improvements

The fixes improved the architecture by:
1. **Single Source of Truth** - All views now share the same DataStore instance
2. **Proper State Management** - ViewModel syncs with store instead of creating its own data
3. **Environment Object Flow** - Store properly cascaded through view hierarchy
4. **Async/Await** - Modern Swift concurrency for photo loading
5. **Better Separation** - UI concerns separated from data management

## Performance Notes

- Photos are loaded asynchronously to avoid blocking UI
- Map only refreshes when location data actually changes
- Store is only synced once on appear, then kept in sync via onChange
- PhotosPicker automatically clears after saving to prevent re-processing
