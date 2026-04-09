# LocTrac Widget Implementation Guide

**Author**: Tim Arey  
**Date**: 2026-04-08  
**Version**: 1.4

---

## 📱 Widget Overview

The LocTrac Daily Affirmation Widget displays a single, calming affirmation on the user's home screen. The affirmation automatically updates at midnight (12:00 AM) each day and remains unchanged until the next midnight.

### Widget Features

✅ **One affirmation per day** — Updates at midnight, stays the same all day  
✅ **Passive display** — No user interaction required  
✅ **Automatic rotation** — Cycles through affirmations based on day of year  
✅ **Clean design** — Minimal, calming aesthetic  
✅ **Two sizes** — Small (square) and Medium (rectangular) widgets  
✅ **Color-coded** — Each affirmation category has a unique color theme  

---

## 🛠️ Xcode Setup Instructions

### Step 1: Add Widget Extension Target

1. **Open Xcode** → Select your LocTrac project in the navigator
2. **File** → **New** → **Target**
3. Select **Widget Extension**
4. Configure the widget:
   - **Product Name**: `LocTracWidgetExtension`
   - **Bundle Identifier**: `com.yourdomain.LocTrac.LocTracWidgetExtension`
   - **Language**: Swift
   - **Include Configuration Intent**: ❌ **Uncheck** (we don't need user configuration)
   - Click **Finish**
5. When asked "Activate 'LocTracWidgetExtension' scheme?", click **Activate**

### Step 2: Replace Generated Files

Xcode creates default widget files. Replace them with the LocTrac widget implementation:

1. **Delete** the auto-generated files:
   - `LocTracWidgetExtension.swift` (or similar name)
   - Keep only the `Assets.xcassets` folder inside the widget target

2. **Add** the LocTrac widget files to the **Widget Extension target**:
   - Drag `LocTracWidget.swift` into the widget target
   - Drag `LocTracWidgetBundle.swift` into the widget target
   - Ensure **both files** are checked for the `LocTracWidgetExtension` target

3. **Share the Affirmation model**:
   - Select `Affirmation.swift` in the Project Navigator
   - In the **File Inspector** (right sidebar), check the box for `LocTracWidgetExtension` target
   - This allows the widget to access the `Affirmation` model

### Step 3: Configure Info.plist

The widget extension has its own `Info.plist`. Xcode should configure it automatically, but verify:

1. Open `LocTracWidgetExtension` → `Info.plist`
2. Ensure these keys exist:
   - `NSExtension` → `NSExtensionPointIdentifier` = `com.apple.widgetkit-extension`

### Step 4: Build and Run

1. **Select the widget scheme**:
   - In Xcode's scheme dropdown (next to Run button), select `LocTracWidgetExtension`
2. **Select a simulator or device**
3. Click **Run** (⌘R)
4. Xcode will ask which app to run — select **SpringBoard** (the home screen)
5. The simulator/device will launch to the home screen

### Step 5: Add Widget to Home Screen

1. **Long-press** on the home screen (simulator or device)
2. Tap the **+ button** in the top-left corner
3. Search for **"LocTrac"**
4. Select the **Daily Affirmation** widget
5. Choose **Small** or **Medium** size
6. Tap **Add Widget**
7. Position the widget and tap **Done**

---

## 🎨 Widget Design

### Small Widget (Square)
```
┌─────────────────┐
│   ❤️ Icon       │
│                 │
│  "I am worthy   │
│   of love and   │
│    respect"     │
│                 │
│     Monday      │
└─────────────────┘
```

### Medium Widget (Rectangular)
```
┌───────────────────────────────────┐
│  ❤️              MONDAY            │
│  Icon            "I am worthy of   │
│                   love and         │
│  LocTrac          respect"         │
│                                    │
│                  Confidence        │
└───────────────────────────────────┘
```

### Design Principles

| Element | Purpose |
|---------|---------|
| **Soft gradient background** | Calming, non-distracting |
| **Category icon** | Visual interest, quick recognition |
| **Rounded font** | Friendly, approachable |
| **Minimal text** | Easy to read at a glance |
| **Day name** | Context for daily rotation |
| **Color-coded** | Category differentiation |

---

## 🔄 How the Widget Works

### Timeline Updates

The widget uses WidgetKit's **Timeline API** to schedule updates:

```swift
// Widget updates at midnight every day
let tomorrowMidnight = Calendar.current.date(byAdding: .day, value: 1, to: midnight)!
let timeline = Timeline(entries: [entry], policy: .after(tomorrowMidnight))
```

**Key behaviors**:
- Widget displays affirmation from **12:00 AM to 11:59 PM**
- At **12:00 AM**, iOS automatically refreshes the widget with the next day's affirmation
- Widget **does not** refresh during the day (no rotation)

### Affirmation Rotation

The widget uses a **deterministic rotation** based on day of year:

```swift
let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
let index = (dayOfYear - 1) % affirmations.count
```

**Benefits**:
- Same affirmation shows all day for all users with the same affirmation set
- Predictable rotation (Tuesday always shows the same affirmation)
- No random variation (calming consistency)

### Fallback Strategy

1. **Primary**: Load user's custom affirmations from app data (when implemented)
2. **Fallback**: Use `Affirmation.presets` (10 default affirmations)
3. **Day-of-week rotation**: If using presets, rotate based on weekday (Sunday-Saturday)

---

## 📊 Widget Sizes

| Family | Dimensions (approx) | Lines of Text | Best For |
|--------|---------------------|---------------|----------|
| **Small** | ~158×158 pts | 4-5 lines | Lock screen, compact spaces |
| **Medium** | ~338×158 pts | 3-4 lines | Home screen, more readable |

> **Note**: Large and Extra Large families are intentionally not supported. Affirmations should be concise and focused.

---

## 🔮 Future Enhancements

### Phase 1 (Current Implementation)
- ✅ Basic widget with preset affirmations
- ✅ Day-of-year rotation
- ✅ Small and Medium sizes
- ✅ Midnight auto-update

### Phase 2 (Planned)
- [ ] **App Group shared data** — Load user's custom affirmations from the main app
- [ ] **Favorite affirmations** — Prioritize user-favorited affirmations
- [ ] **Category filtering** — Widget shows only selected categories
- [ ] **Lock Screen widget** — iOS 16+ lock screen support

### Phase 3 (Long Term)
- [ ] **iCloud sync** — Share affirmations across devices
- [ ] **Interactive widget** — Tap to cycle through affirmations (requires Button API)
- [ ] **Custom backgrounds** — User-uploaded images or gradients
- [ ] **Accessibility** — VoiceOver support, dynamic type scaling

---

## 🐛 Troubleshooting

### Widget doesn't appear in widget gallery
- Ensure the widget extension target is **built successfully**
- Check that `Info.plist` has the correct `NSExtensionPointIdentifier`
- Try running the widget scheme directly (select `LocTracWidgetExtension` scheme)

### Widget shows placeholder content
- Check that `Affirmation.swift` is added to the widget extension target
- Verify the `Affirmation.presets` array is not empty
- Rebuild the widget extension

### Widget doesn't update at midnight
- iOS may delay widget updates to save battery
- Force a timeline refresh by removing and re-adding the widget
- Check device Date & Time settings (must be automatic)

### "Module 'WidgetKit' not found" error
- Ensure deployment target is **iOS 18.0+** for the widget extension (matches main app)
- WidgetKit is available since iOS 14, but LocTrac requires iOS 18+

### Widget crashes on launch
- Check for force-unwraps in widget code (avoid `!` operators)
- Ensure all data access is safe and handles missing data gracefully
- Review Xcode's crash logs in the Reports navigator

---

## 📝 Code Structure

### Files in Widget Extension Target

| File | Purpose |
|------|---------|
| `LocTracWidgetBundle.swift` | Widget bundle configuration (required for iOS 14+) |
| `LocTracWidget.swift` | Widget definition, timeline provider, and views |
| `Affirmation.swift` | Shared model (also used by main app) |

### Key Components

```swift
// Widget entry point
@main
struct LocTracWidgetBundle: WidgetBundle

// Widget configuration
struct LocTracWidget: Widget

// Timeline provider (updates at midnight)
struct DailyAffirmationProvider: TimelineProvider

// Widget UI
struct DailyAffirmationWidgetView: View
struct SmallWidgetView: View
struct MediumWidgetView: View
```

---

## ✅ Testing Checklist

Before releasing the widget:

- [ ] Widget appears in widget gallery with correct name and description
- [ ] Small widget displays affirmation clearly
- [ ] Medium widget displays affirmation with icon and category
- [ ] Affirmation updates at midnight (use "Simulate Location" → Custom Date in Xcode)
- [ ] Widget uses correct colors for each category
- [ ] Text is readable on both light and dark mode
- [ ] No crashes or errors in Console when adding/removing widget
- [ ] Widget respects device's Dynamic Type settings (accessibility)
- [ ] Screenshot for App Store shows widget in use

---

## 🎯 App Store Marketing

### Widget Feature Highlights

> **Daily Affirmation Widget**  
> Start each day with a calming affirmation directly on your home screen. The widget automatically updates at midnight with a new positive message, keeping you inspired and focused throughout your day.

### Screenshots

Include at least one screenshot showing:
1. Home screen with LocTrac widget visible
2. Both Small and Medium widget sizes
3. Light and dark mode variations
4. Widget in context with other apps

---

## 📚 References

- [Apple WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)
- [Human Interface Guidelines: Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets)
- [WWDC 2020: Meet WidgetKit](https://developer.apple.com/videos/play/wwdc2020/10028/)
- [WWDC 2021: Principles of Great Widgets](https://developer.apple.com/videos/play/wwdc2021/10048/)

---

*LocTrac Widget — v1.4 — Tim Arey — 2026-04-08*
