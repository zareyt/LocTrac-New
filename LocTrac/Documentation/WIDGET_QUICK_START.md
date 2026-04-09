# LocTrac Widget Quick Start Checklist

**Version**: 1.4  
**Author**: Tim Arey  
**Date**: 2026-04-08

---

## 🎯 Widget Setup Checklist

Follow these steps to add the Daily Affirmation Widget to your LocTrac app:

### ☐ Step 1: Create Widget Extension Target
1. Open Xcode → Select LocTrac project
2. **File** → **New** → **Target**
3. Select **Widget Extension**
4. Product Name: `LocTracWidgetExtension`
5. Bundle ID: `com.yourdomain.LocTrac.LocTracWidgetExtension`
6. Language: **Swift**
7. ❌ **Uncheck** "Include Configuration Intent"
8. Click **Finish** → **Activate** scheme

### ☐ Step 2: Add Widget Files
1. Delete auto-generated `LocTracWidgetExtension.swift`
2. Add `LocTracWidget.swift` to widget target
3. Add `LocTracWidgetBundle.swift` to widget target
4. Select `Affirmation.swift` → File Inspector → Check `LocTracWidgetExtension` target

### ☐ Step 3: Configure Deployment Target
1. Select `LocTracWidgetExtension` target
2. General tab → Deployment Info
3. Set **Minimum Deployment**: iOS 14.0 (WidgetKit requirement)

### ☐ Step 4: Build and Test
1. Select `LocTracWidgetExtension` scheme
2. Choose simulator or device
3. Click **Run** (⌘R)
4. Select **SpringBoard** when prompted
5. Long-press home screen → Tap **+** → Search "LocTrac"
6. Add widget to home screen

---

## ✅ Verification Checklist

After setup, verify these work:

- [ ] Widget appears in widget gallery with name "Daily Affirmation"
- [ ] Small widget displays affirmation text clearly
- [ ] Medium widget shows icon, day name, and affirmation
- [ ] Widget background color matches affirmation category
- [ ] No crashes when adding/removing widget
- [ ] Widget shows different affirmation after 24 hours (test by changing device date)

---

## 🐛 Common Issues

### Widget doesn't appear in gallery
**Fix**: Ensure the widget extension built successfully. Check scheme selection.

### "Module 'WidgetKit' not found"
**Fix**: Set widget extension deployment target to iOS 14.0+

### Widget shows placeholder only
**Fix**: Verify `Affirmation.swift` is added to widget target (File Inspector)

### Widget doesn't update at midnight
**Fix**: iOS may delay updates for battery optimization. Remove and re-add widget.

---

## 📚 Full Documentation

See `WIDGET_IMPLEMENTATION.md` for complete setup instructions, design details, troubleshooting, and future enhancements.

---

## 🎨 Widget Design Preview

### Small Widget
```
┌─────────────┐
│   ❤️        │
│  "I am      │
│   worthy    │
│   of love"  │
│             │
│   Monday    │
└─────────────┘
```

### Medium Widget
```
┌──────────────────────────────┐
│ ❤️         MONDAY             │
│            "I am worthy       │
│ LocTrac     of love and       │
│             respect"          │
│            Confidence         │
└──────────────────────────────┘
```

---

*LocTrac Widget — v1.4 — Tim Arey — 2026-04-08*
