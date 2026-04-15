# What's New Dynamic System

**Created**: April 14, 2026  
**Version**: 1.5+  
**Author**: Tim Arey

---

## 📖 Overview

The **Dynamic What's New System** automatically generates "What's New" feature pages from markdown files instead of hardcoded Swift code. This makes it easier to maintain release notes and ensures consistency between documentation and the in-app experience.

---

## 🎯 Goals

1. **Single Source of Truth** — `VERSION_x.x_RELEASE_NOTES.md` drives both documentation and UI
2. **No Code Changes** — Add new release features without touching Swift files
3. **Flexible Fallback** — Hardcoded features remain as safety net
4. **Easy Maintenance** — Update markdown, not switch statements

---

## 🗂️ File Structure

```
LocTrac/
├── ReleaseNotesParser.swift         ← 🆕 Markdown parser
├── WhatsNewFeature.swift            ← 🔄 Updated with dynamic loading
├── WhatsNewView.swift               ← Unchanged (consumes features)
├── AppVersionManager.swift          ← Unchanged (version logic)
└── VERSION_1.5_RELEASE_NOTES.md     ← 🔄 Updated format
```

---

## 📝 Markdown Format

### Structure

The parser expects a specific markdown structure in `VERSION_x.x_RELEASE_NOTES.md` files:

```markdown
## 🎉 What's New in vX.X

### Feature Title
icon: symbol.name | color: colorname

Feature description goes here. Can be multiple sentences.
This will all be combined into the description.

### Another Feature
icon: sparkles | color: purple

Another feature description here.

---

## Other Sections

Content after the "What's New" section is ignored by the parser.
```

### Metadata Line Format

The line immediately following the `### Feature Title` must contain:

```
icon: sf.symbol.name | color: colorname
```

**Components:**
- `icon:` — Required prefix
- `sf.symbol.name` — Any valid SF Symbol name (e.g., `sparkles`, `globe`, `bolt.fill`)
- `|` — Separator
- `color:` — Required prefix
- `colorname` — Color name (see supported colors below)

### Supported Colors

| Color Name | SwiftUI Color |
|------------|---------------|
| blue | `.blue` |
| purple | `.purple` |
| green | `.green` |
| orange | `.orange` |
| red | `.red` |
| pink | `.pink` |
| yellow | `.yellow` |
| cyan | `.cyan` |
| indigo | `.indigo` |
| teal | `.teal` |
| mint | `.mint` |
| brown | `.brown` |
| gray/grey | `.gray` |

**Default:** If color is not recognized, defaults to `.blue`.

---

## 🔄 How It Works

### Flow Diagram

```
App Launch
    ↓
AppVersionManager.shouldShowWhatsNew
    ↓
WhatsNewView(features: WhatsNewFeature.features(for: "1.5"))
    ↓
WhatsNewFeature.features(for:)
    ↓
ReleaseNotesParser.parseFeatures(forVersion:)
    ↓
    ├─── ✅ Parse Success → Return [WhatsNewFeature]
    │
    └─── ❌ Parse Fail → Fall back to hardcodedFeatures(for:)
```

### Parser Logic

1. **File Search** — Tries these patterns:
   - `VERSION_1.5_RELEASE_NOTES.md`
   - `VERSION_v1.5_RELEASE_NOTES.md`
   - `V1.5_RELEASE_NOTES.md`

2. **Content Extraction**:
   - Finds `## 🎉 What's New in vX.X` section
   - Extracts each `### Feature Title`
   - Parses `icon:` and `color:` metadata
   - Collects description text (non-heading, non-metadata lines)
   - Stops at next `##` heading or end of section

3. **Feature Creation**:
   - Maps color names → SwiftUI `Color` values
   - Cleans markdown formatting from descriptions
   - Creates `WhatsNewFeature` objects

4. **Fallback**:
   - If file not found → uses hardcoded features
   - If parsing fails → uses hardcoded features
   - Console logs indicate which path was taken

---

## 🎨 Example: VERSION_1.5_RELEASE_NOTES.md

```markdown
# LocTrac v1.5 Release Notes

**Release Date**: April 13, 2026  
**Version**: 1.5.0  
**Build**: TBD

---

## 🎉 What's New in v1.5

### Location Data Enhancement Tool
icon: sparkles | color: purple

A powerful new tool to clean, validate, and enrich your location data automatically. Automatically cleans "City, ST" formats, populates missing state/province information, and standardizes country names for 50+ countries worldwide.

### International Support
icon: globe | color: green

Full support for international locations with state/province detection. Recognizes long country names like "Canada", "Scotland", and "United Kingdom".

### Smart Processing & Rate Limiting
icon: bolt.fill | color: orange

Efficient geocoding that skips already-processed events (saves up to 66% of processing time). Rate limiting respects Apple's geocoding limits with automatic retry for network errors.

### Session Persistence
icon: clock.arrow.circlepath | color: blue

Resume anytime with session persistence. Clear progress tracking, "Retry Errors" button to fix only failed items, and human-readable error messages guide you through the process.

---

## 📍 Detailed Documentation

(Everything after this is ignored by the parser)
```

**Result:** 4 feature pages with:
- Purple sparkles icon
- Green globe icon
- Orange bolt icon
- Blue clock icon

---

## 🚀 Adding a New Version

### Step 1: Create Release Notes File

Create `VERSION_1.6_RELEASE_NOTES.md`:

```markdown
# LocTrac v1.6 Release Notes

**Release Date**: TBD  
**Version**: 1.6.0  
**Build**: TBD

---

## 🎉 What's New in v1.6

### New Feature Name
icon: star.fill | color: yellow

Description of the new feature. Explain what it does and why it's great.

### Another Feature
icon: heart.fill | color: red

Another feature description here.

---

## Additional Documentation

More detailed docs here...
```

### Step 2: Update Info.plist

Set `CFBundleShortVersionString` to `1.6`.

### Step 3: Test

Launch the app — the "What's New" sheet should appear with your new features!

### Step 4: Add Hardcoded Fallback (Optional)

For safety, add a hardcoded version in `WhatsNewFeature.swift`:

```swift
case "1.6":
    return [
        WhatsNewFeature(
            symbolName: "star.fill",
            symbolColor: .yellow,
            title: "New Feature Name",
            description: "Description of the new feature."
        ),
        // ... more features
    ]
```

This ensures features show even if the markdown file is missing or fails to parse.

---

## 🐛 Debugging

### Console Logs

The system prints helpful debug logs:

**Success:**
```
✅ Loaded release notes from: VERSION_1.5_RELEASE_NOTES.md
📄 Parsed 4 features from release notes
✅ Using dynamically parsed features for version 1.5
```

**Fallback:**
```
⚠️ Could not find release notes file for version 1.5
   Tried: VERSION_1.5_RELEASE_NOTES.md, VERSION_v1.5_RELEASE_NOTES.md, V1.5_RELEASE_NOTES.md
⚠️ No release notes file found for version 1.5
⚠️ Falling back to hardcoded features for version 1.5
```

**Unknown Color:**
```
⚠️ Unknown color 'chartreuse', defaulting to blue
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Fallback used | File not in bundle | Add file to Xcode target |
| No features shown | Missing `##` section | Add "What's New in vX.X" heading |
| Wrong symbol | Typo in icon name | Check SF Symbols app |
| Wrong color | Unsupported color name | Use supported color (see table) |
| Missing description | Empty lines only | Add text content |

---

## 📊 Benefits

### Before (Hardcoded)

**To add a new version:**
1. Edit `WhatsNewFeature.swift`
2. Add new `case "1.6":`
3. Duplicate feature structs
4. Recompile app
5. Maintain separate release notes doc

**Problems:**
- Duplicate content (code + docs)
- Easy to forget updating one
- Requires developer to edit Swift
- Can't update features post-release

### After (Dynamic)

**To add a new version:**
1. Create `VERSION_1.6_RELEASE_NOTES.md`
2. Write features in markdown
3. Done!

**Benefits:**
- ✅ Single source of truth
- ✅ Non-developers can update
- ✅ Consistency guaranteed
- ✅ Hardcoded fallback for safety
- ✅ Easy to maintain

---

## 🔒 Safety Features

1. **Graceful Fallback** — Always falls back to hardcoded features
2. **Default Colors** — Unknown colors default to `.blue`
3. **Nil Safety** — Missing files return `nil`, triggering fallback
4. **Empty Check** — `AppVersionManager` checks for empty feature arrays
5. **Debug Logging** — Console logs explain what happened

---

## 🎯 Best Practices

### DO ✅

- Keep feature descriptions concise (1-2 sentences)
- Use standard SF Symbol names
- Use supported color names
- Test both dynamic and fallback modes
- Add hardcoded fallback for important releases
- Include the file in the Xcode target

### DON'T ❌

- Don't use custom/private SF Symbols
- Don't use unsupported color names without checking logs
- Don't rely solely on dynamic parsing for critical releases
- Don't forget to update `Info.plist` version
- Don't include markdown formatting in descriptions (it's stripped)

---

## 🧪 Testing

### Manual Test Checklist

- [ ] Create test `VERSION_TEST_RELEASE_NOTES.md`
- [ ] Add valid "What's New" section with 2-3 features
- [ ] Set `CFBundleShortVersionString` to `TEST`
- [ ] Clear UserDefaults: `UserDefaults.standard.removeObject(forKey: "LocTrac_lastSeenVersion")`
- [ ] Launch app → verify "What's New" sheet appears
- [ ] Verify features match markdown content
- [ ] Verify icons and colors are correct
- [ ] Delete markdown file
- [ ] Launch app → verify fallback features appear
- [ ] Check console logs for success/fallback messages

---

## 🚧 Future Enhancements

### Potential Improvements

- [ ] Support custom colors with hex codes
- [ ] Parse feature screenshots from markdown
- [ ] Support multiple languages (i18n)
- [ ] Remote feature flags (enable/disable specific features)
- [ ] Analytics integration (track which features users view)
- [ ] A/B testing different feature descriptions

### Advanced Markdown Features

- [ ] Support for code blocks in descriptions
- [ ] Support for bullet points in descriptions
- [ ] Support for links (open in Safari)
- [ ] Support for embedded images/videos

---

## 📚 Related Files

| File | Purpose |
|------|---------|
| `ReleaseNotesParser.swift` | Markdown parsing logic |
| `WhatsNewFeature.swift` | Feature model + loading logic |
| `WhatsNewView.swift` | UI for "What's New" sheet |
| `AppVersionManager.swift` | Version tracking + show logic |
| `VERSION_*.md` | Release notes markdown files |
| `CLAUDE.md` | Project documentation (context for AI) |
| `CHANGELOG.md` | Version history |

---

## ✅ Summary

The **Dynamic What's New System** provides:

1. **Easier Maintenance** — Edit markdown, not code
2. **Consistency** — One source for docs and UI
3. **Flexibility** — Update without recompiling
4. **Safety** — Hardcoded fallback always available
5. **Debugging** — Clear console logs
6. **Future-Proof** — Easy to extend with new features

**Next time you release**, just create a markdown file and let the system handle the rest!

---

*WHATS_NEW_DYNAMIC_SYSTEM.md — LocTrac v1.5 — Tim Arey — 2026-04-14*
