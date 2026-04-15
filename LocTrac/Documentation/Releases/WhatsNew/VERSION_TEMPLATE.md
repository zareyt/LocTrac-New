# LocTrac vX.X Release Notes

**Release Date**: TBD  
**Version**: X.X.0  
**Build**: TBD

---

## 🎉 What's New in vX.X

### Feature One Title
icon: star.fill | color: yellow

Write a concise 1-2 sentence description of feature one here. Focus on what it does and why it matters to users.

### Feature Two Title
icon: heart.fill | color: red

Write a concise 1-2 sentence description of feature two here. Highlight the benefit or improvement.

### Feature Three Title
icon: bolt.fill | color: orange

Write a concise 1-2 sentence description of feature three here. Keep it clear and engaging.

### Feature Four Title
icon: sparkles | color: purple

Write a concise 1-2 sentence description of feature four here. Make users excited to try it!

---

## 📝 Instructions

### Customization Steps

1. **Replace placeholders:**
   - `X.X` → Your version number (e.g., `1.6`)
   - `TBD` → Actual dates and build numbers
   - Feature titles → Your actual feature names
   - Descriptions → Your actual feature descriptions

2. **Choose appropriate icons:**
   - Browse SF Symbols app (free from Apple)
   - Pick symbols that represent your features
   - Use `.fill` variants for bolder appearance
   - Examples: `map.fill`, `globe`, `airplane.departure`, `doc.text.fill`

3. **Choose colors:**
   - Supported: `blue`, `purple`, `green`, `orange`, `red`, `pink`, `yellow`, `cyan`, `indigo`, `teal`, `mint`, `brown`, `gray`
   - Pick colors that match your app's design
   - Use different colors for different features (variety is good!)

4. **Write descriptions:**
   - Keep to 1-2 sentences maximum
   - Focus on user benefits, not technical details
   - Use active voice ("Track your travels" not "Travels can be tracked")
   - Be specific ("Supports 50+ countries" not "Better international support")

### Adding to Project

1. **Rename this file:**
   - `VERSION_TEMPLATE.md` → `VERSION_X.X_RELEASE_NOTES.md`
   - Example: `VERSION_1.6_RELEASE_NOTES.md`

2. **Add to Xcode:**
   - Drag file into Xcode project
   - ✅ Check "Add to targets: LocTrac"
   - ✅ Check "Copy items if needed"

3. **Update Info.plist:**
   - Set `CFBundleShortVersionString` to match (e.g., `1.6`)

4. **Test:**
   - Clear UserDefaults: `UserDefaults.standard.removeObject(forKey: "LocTrac_lastSeenVersion")`
   - Launch app
   - Verify "What's New" sheet appears
   - Check console for: `✅ Using dynamically parsed features for version X.X`

---

## 🎨 Popular Icon Ideas

### Travel & Location
- `map.fill`, `globe`, `mappin.and.ellipse`
- `airplane.departure`, `car.fill`, `ferry.fill`
- `location.fill`, `location.fill.viewfinder`

### Time & Calendar
- `clock.fill`, `calendar.badge.clock`
- `clock.arrow.circlepath`, `timer`

### Data & Documents
- `doc.text.fill`, `doc.badge.plus`
- `chart.bar.fill`, `chart.line.uptrend.xyaxis`
- `arrow.down.doc.fill`, `square.and.arrow.up.fill`

### UI & Design
- `paintpalette.fill`, `wand.and.stars`
- `sparkles`, `star.fill`, `heart.fill`

### Actions & Tools
- `bolt.fill`, `hammer.fill`, `wrench.fill`
- `checkmark.circle.fill`, `arrow.triangle.2.circlepath`

### Communication
- `bell.badge.fill`, `message.fill`
- `quote.bubble.fill`, `text.bubble.fill`

---

## ✅ Quality Checklist

Before finalizing:

- [ ] All placeholders replaced (no `X.X` or `TBD`)
- [ ] SF Symbol names verified in SF Symbols app
- [ ] Color names are from supported list
- [ ] Descriptions are 1-2 sentences each
- [ ] Descriptions focus on user benefits
- [ ] Icons match feature themes
- [ ] Colors provide good variety
- [ ] File renamed to match version
- [ ] File added to Xcode target
- [ ] `Info.plist` version updated
- [ ] Tested "What's New" sheet appears
- [ ] All features display correctly

---

## 📚 Additional Resources

- **WHATS_NEW_QUICK_START.md** — Quick reference guide
- **WHATS_NEW_DYNAMIC_SYSTEM.md** — Complete technical documentation
- **SF Symbols app** — Browse all available icons (free download from Apple)

---

*VERSION_TEMPLATE.md — LocTrac v1.5 — Tim Arey — 2026-04-14*
