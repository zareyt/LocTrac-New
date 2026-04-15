# Quick Start: Adding a New "What's New" Version

**For Version**: 1.5+  
**Last Updated**: April 14, 2026

---

## 🎯 Quick Steps

### 1. Create Release Notes File

Create `VERSION_1.6_RELEASE_NOTES.md` (replace `1.6` with your version):

```markdown
# LocTrac v1.6 Release Notes

**Release Date**: TBD  
**Version**: 1.6.0  
**Build**: TBD

---

## 🎉 What's New in v1.6

### Feature One
icon: star.fill | color: yellow

Short description of feature one. Keep it to 1-2 sentences for best display.

### Feature Two
icon: heart.fill | color: red

Short description of feature two. This appears in the What's New sheet.

### Feature Three
icon: bolt.fill | color: orange

Short description of feature three.

---

## Detailed Documentation

(Everything below this line is ignored by the parser)
```

### 2. Add File to Xcode

1. Drag `VERSION_1.6_RELEASE_NOTES.md` into Xcode
2. ✅ Check "Add to targets: LocTrac"
3. ✅ Check "Copy items if needed"

### 3. Update Version Number

In `Info.plist` (or Xcode target settings):
- Set **CFBundleShortVersionString** to `1.6`

### 4. Test

1. Clear UserDefaults: `UserDefaults.standard.removeObject(forKey: "LocTrac_lastSeenVersion")`
2. Launch app
3. Verify "What's New" sheet appears
4. Check console for: `✅ Using dynamically parsed features for version 1.6`

---

## 📝 Markdown Format Reference

### Required Structure

```markdown
## 🎉 What's New in vX.X    ← Must include this heading

### Feature Title            ← Feature name
icon: symbol | color: name   ← Metadata (required!)

Feature description here.    ← Description text
```

### Supported Colors

`blue` | `purple` | `green` | `orange` | `red` | `pink` | `yellow` | `cyan` | `indigo` | `teal` | `mint` | `brown` | `gray`

### Popular SF Symbols

**General:**
- `star.fill`, `sparkles`, `heart.fill`
- `bolt.fill`, `flame.fill`, `wand.and.stars`

**Location/Travel:**
- `map.fill`, `globe`, `airplane.departure`
- `location.fill`, `mappin.and.ellipse`

**Time/Calendar:**
- `clock.fill`, `calendar.badge.clock`
- `clock.arrow.circlepath`

**Data/Documents:**
- `doc.text.fill`, `chart.bar.fill`
- `square.and.arrow.down.fill`

**UI Elements:**
- `paintpalette.fill`, `slider.horizontal.3`
- `checkmark.circle.fill`, `exclamationmark.triangle.fill`

Browse more in **SF Symbols app** (free from Apple).

---

## 🐛 Troubleshooting

### "What's New" doesn't appear

**Check:**
1. ✅ File is in Xcode target (blue checkmark in File Inspector)
2. ✅ Version in `Info.plist` matches filename (e.g., `1.6`)
3. ✅ UserDefaults cleared: `defaults delete com.yourcompany.LocTrac LocTrac_lastSeenVersion`
4. ✅ `## 🎉 What's New in vX.X` heading exists

### Features show but are wrong

**Check:**
1. ✅ `icon:` line immediately follows `### Title`
2. ✅ Format: `icon: symbol | color: name` (with pipe separator)
3. ✅ Color name is supported (see list above)
4. ✅ SF Symbol name is correct (check SF Symbols app)

### Falls back to hardcoded features

**Check console logs:**

```
⚠️ Could not find release notes file for version 1.6
   Tried: VERSION_1.6_RELEASE_NOTES.md, VERSION_v1.6_RELEASE_NOTES.md, V1.6_RELEASE_NOTES.md
```

**Solution:** File not in app bundle. Add to Xcode target.

```
⚠️ No release notes file found for version 1.6
⚠️ Falling back to hardcoded features for version 1.6
```

**Solution:** Create `VERSION_1.6_RELEASE_NOTES.md` with proper format.

---

## ✅ Checklist

Before releasing:

- [ ] Created `VERSION_x.x_RELEASE_NOTES.md`
- [ ] Added file to Xcode target
- [ ] Updated `CFBundleShortVersionString` in `Info.plist`
- [ ] Tested "What's New" sheet appears
- [ ] Verified all features show correctly
- [ ] Verified icons and colors match design
- [ ] Added optional hardcoded fallback to `WhatsNewFeature.swift`
- [ ] Updated `CHANGELOG.md` with version details

---

## 📚 More Information

See **WHATS_NEW_DYNAMIC_SYSTEM.md** for:
- Complete parser implementation details
- Advanced markdown features
- Debugging tips
- Architecture diagrams
- Future enhancement ideas

---

*WHATS_NEW_QUICK_START.md — LocTrac v1.5 — Tim Arey — 2026-04-14*
