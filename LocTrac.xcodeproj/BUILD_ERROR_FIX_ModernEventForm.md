# ModernEventFormView.swift Build Error Fix

## Error
```
Return type of property 'locationSection' requires that 'EmptyTableRowContent<V>' conform to 'View'
Static method 'buildExpression' requires that 'some View' conform to 'TableRowContent'
```

## Cause
Line 91 in ModernEventFormView.swift - `locationSection` property is returning wrong type.

## Most Likely Issue
The `locationSection` computed property accidentally has `@TableContentBuilder` or is trying to return Table content instead of View content.

## Fix

### Change FROM (likely):
```swift
@TableContentBuilder  // ❌ WRONG
private var locationSection: some View {
    // or
    Section {  // Inside a Table context
        // ...
    }
}
```

### Change TO:
```swift
@ViewBuilder  // ✅ CORRECT
private var locationSection: some View {
    Section {  // Regular Form/List section
        // ...
    }
}
```

## Or if it's in a Form/List:

Make sure `locationSection` returns proper SwiftUI Views, not Table components:

```swift
private var locationSection: some View {
    Section {
        // Regular views here
        Picker("Location", selection: $selectedLocation) { ... }
        // etc.
    } header: {
        Label("Location", systemImage: "mappin.circle")
    }
}
```

## Quick Action
1. Open ModernEventFormView.swift
2. Go to line 91
3. Find `locationSection` property
4. Make sure it has `@ViewBuilder` (not `@TableContentBuilder`)
5. Make sure it returns Section/VStack/etc (not Table content)
