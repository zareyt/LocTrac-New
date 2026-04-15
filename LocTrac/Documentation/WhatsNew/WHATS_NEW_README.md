# Dynamic "What's New" System — README

**LocTrac v1.5+**  
**Created**: April 14, 2026  
**Author**: Tim Arey

---

## 📋 Quick Overview

The **Dynamic "What's New" System** automatically generates the in-app "What's New" feature pages from markdown files instead of hardcoded Swift code.

**Key Benefits:**
- ✅ Single source of truth (markdown drives both docs and UI)
- ✅ No code changes needed for new releases
- ✅ Guaranteed consistency between documentation and user experience
- ✅ Non-developers can update content
- ✅ Hardcoded fallback ensures reliability

---

## 📚 Documentation Files

This system includes comprehensive documentation:

### Quick Start
📄 **[WHATS_NEW_QUICK_START.md](WHATS_NEW_QUICK_START.md)**
- Fast guide for adding new versions
- Markdown format reference
- Troubleshooting checklist
- **Start here** if you just want to add a new version!

### Complete Guide
📘 **[WHATS_NEW_DYNAMIC_SYSTEM.md](WHATS_NEW_DYNAMIC_SYSTEM.md)**
- Complete technical documentation
- Architecture and parser implementation details
- Debugging guide with console log examples
- Best practices and future enhancements

### Implementation Summary
📊 **[DYNAMIC_WHATS_NEW_SUMMARY.md](DYNAMIC_WHATS_NEW_SUMMARY.md)**
- What was built and why
- Before/after comparison
- Technical details and API reference
- Testing scenarios

### Template
📝 **[VERSION_TEMPLATE.md](VERSION_TEMPLATE.md)**
- Copy-paste template for new releases
- Instructions and customization guide
- SF Symbols suggestions
- Quality checklist

---

## 🚀 Quick Start: Adding a New Version

### 1. Copy the Template

```bash
cp VERSION_TEMPLATE.md VERSION_1.6_RELEASE_NOTES.md
```

### 2. Edit the Markdown

Replace placeholders with your version's features:

```markdown
## 🎉 What's New in v1.6

### Your Feature Title
icon: star.fill | color: yellow

Short 1-2 sentence description of your feature.

### Another Feature
icon: heart.fill | color: red

Another short description here.
```

### 3. Add to Xcode

1. Drag file into Xcode
2. ✅ Check "Add to targets: LocTrac"
3. ✅ Check "Copy items if needed"

### 4. Update Version

Set `CFBundleShortVersionString` in `Info.plist` to `1.6`

### 5. Test

Launch app — "What's New" sheet should appear!

---

## 📝 Markdown Format

### Required Structure

```markdown
## 🎉 What's New in vX.X    ← Section header (required)

### Feature Name            ← Feature title
icon: symbol | color: name  ← Metadata line (required)

Description text here.      ← Description (1-2 sentences)
Can span multiple lines.
```

### Supported Colors

```
blue, purple, green, orange, red, pink, yellow
cyan, indigo, teal, mint, brown, gray
```

### Popular SF Symbols

**Travel:** `map.fill`, `globe`, `airplane.departure`  
**Time:** `clock.fill`, `calendar.badge.clock`  
**Data:** `doc.text.fill`, `chart.bar.fill`  
**UI:** `sparkles`, `star.fill`, `heart.fill`  
**Actions:** `bolt.fill`, `checkmark.circle.fill`

---

## 🏗️ How It Works

### Architecture

```
App Launch
    ↓
WhatsNewView requests features for current version
    ↓
WhatsNewFeature.features(for: "1.6")
    ↓
ReleaseNotesParser.parseFeatures(forVersion: "1.6")
    ↓
    ├─── ✅ Parse SUCCESS → Return [WhatsNewFeature]
    │
    └─── ❌ Parse FAIL → Fall back to hardcoded features
```

### Files Involved

| File | Purpose |
|------|---------|
| `ReleaseNotesParser.swift` | Markdown parsing engine |
| `WhatsNewFeature.swift` | Feature model + dynamic loading |
| `WhatsNewView.swift` | UI presentation |
| `AppVersionManager.swift` | Version tracking |
| `VERSION_*.md` | Markdown source files |

---

## 🐛 Troubleshooting

### "What's New" doesn't appear

**Check:**
- ✅ File added to Xcode target (blue checkmark in File Inspector)
- ✅ Version in `Info.plist` matches filename (e.g., `1.6`)
- ✅ UserDefaults cleared for testing
- ✅ `## 🎉 What's New in vX.X` heading exists

**Console logs:**
```
✅ Loaded release notes from: VERSION_1.6_RELEASE_NOTES.md
📄 Parsed 4 features from release notes
✅ Using dynamically parsed features for version 1.6
```

### Falls back to hardcoded features

**Console logs:**
```
⚠️ Could not find release notes file for version 1.6
   Tried: VERSION_1.6_RELEASE_NOTES.md, ...
⚠️ Falling back to hardcoded features for version 1.6
```

**Solution:** File not in app bundle → Add to Xcode target

### Features show but icons/colors wrong

**Check:**
- ✅ `icon:` line immediately follows `### Title`
- ✅ Format: `icon: symbol | color: name` (pipe separator!)
- ✅ Color name is supported (see list above)
- ✅ SF Symbol name is correct (check SF Symbols app)

---

## ✅ Pre-Release Checklist

Before each release:

- [ ] Created `VERSION_x.x_RELEASE_NOTES.md`
- [ ] Added file to Xcode target
- [ ] Updated `CFBundleShortVersionString` in `Info.plist`
- [ ] Tested "What's New" sheet appears
- [ ] Verified all features display correctly
- [ ] Verified icons and colors match design
- [ ] (Optional) Added hardcoded fallback to `WhatsNewFeature.swift`
- [ ] Updated `CHANGELOG.md` with version details

---

## 🎓 Learning Resources

### For Quick Tasks
👉 Start with **WHATS_NEW_QUICK_START.md**

### For Understanding the System
👉 Read **WHATS_NEW_DYNAMIC_SYSTEM.md**

### For Implementation Details
👉 Check **DYNAMIC_WHATS_NEW_SUMMARY.md**

### For Creating New Versions
👉 Copy **VERSION_TEMPLATE.md**

---

## 🔧 Advanced Usage

### Multiple Languages (Future)

The system could support localization:
```
VERSION_1.6_RELEASE_NOTES_en.md
VERSION_1.6_RELEASE_NOTES_es.md
VERSION_1.6_RELEASE_NOTES_fr.md
```

### Remote Loading (Future)

Parse markdown from URL instead of bundle:
```swift
ReleaseNotesParser.parseFeatures(fromURL: url)
```

### Custom Colors (Future)

Support hex colors in metadata:
```markdown
icon: star.fill | color: #FF6B35
```

---

## 📞 Support

### Common Questions

**Q: Can I skip versions?**  
A: Yes! If version 1.7 has no "What's New" content, just don't create the file.

**Q: What if parsing fails?**  
A: The system automatically falls back to hardcoded features in `WhatsNewFeature.swift`.

**Q: Can I test without changing the app version?**  
A: Yes! Clear UserDefaults: `defaults delete com.yourcompany.LocTrac LocTrac_lastSeenVersion`

**Q: How many features can I show?**  
A: No limit, but 3-5 is recommended for best user experience.

**Q: Can I update features after release?**  
A: Not in the current version (files are bundled). Future enhancement could load from remote URL.

---

## 🎯 Best Practices

### DO ✅

- Keep descriptions concise (1-2 sentences)
- Use standard SF Symbol names
- Use supported color names
- Test both dynamic and fallback modes
- Include the file in Xcode target
- Follow the template structure

### DON'T ❌

- Don't use custom/private SF Symbols
- Don't exceed 5 features per release
- Don't include markdown formatting in descriptions
- Don't forget to update `Info.plist` version
- Don't rely solely on dynamic parsing for critical releases

---

## 🚧 Future Enhancements

Potential improvements:

- [ ] Support for embedded images/screenshots
- [ ] Support for feature videos
- [ ] Localization (multiple languages)
- [ ] Remote markdown loading
- [ ] A/B testing different descriptions
- [ ] Analytics (track which features users view)
- [ ] Custom hex color support
- [ ] Dark/light mode specific colors

---

## 📄 License & Credits

Part of the LocTrac project by Tim Arey.

**Markdown Parsing**: Custom implementation  
**SF Symbols**: Apple Inc.  
**SwiftUI**: Apple Inc.

---

## 🎉 Summary

The Dynamic "What's New" System makes releasing new versions easier:

1. Create markdown file
2. Add to Xcode
3. Update version
4. Done!

No more duplicating content between code and docs. No more forgetting to update one or the other. Just write markdown and ship!

**Questions?** Check the guides:
- Quick tasks → `WHATS_NEW_QUICK_START.md`
- Technical details → `WHATS_NEW_DYNAMIC_SYSTEM.md`
- Implementation → `DYNAMIC_WHATS_NEW_SUMMARY.md`

---

*WHATS_NEW_README.md — LocTrac v1.5 — Tim Arey — 2026-04-14*
