# Location Display Consistency: Travel History ↔ Event Form

## Overview
The event form now displays location information in the same style and format as Travel History's stay detail sheet, creating a consistent user experience throughout the app.

## Visual Consistency

### Travel History - Stay Detail Sheet
```
┌─────────────────────────────────────┐
│ Location Details                    │
├─────────────────────────────────────┤
│ 📍 Name          Home               │
│ 🏙️ City          San Francisco      │
│ 🗺️ State         California         │
│ 🌍 Country       United States      │
└─────────────────────────────────────┘
```

### Event Form - Location Section
```
┌─────────────────────────────────────┐
│ 🗺️ Location Details                 │
├─────────────────────────────────────┤
│ Location: [Home ▼]                  │
│ 🏙️ City          San Francisco      │
│ 🗺️ State         California         │
│ 🌍 Country       United States      │
└─────────────────────────────────────┘
Footer: Location details inherited from 
'Home'. You can override any field.
```

## Icon Mapping

| Field   | Icon                    | Color  | Used In                    |
|---------|-------------------------|--------|----------------------------|
| Name    | `mappin.circle.fill`    | Blue   | Travel History only        |
| City    | `building.2.fill`       | Orange | Both                       |
| State   | `map.fill`              | Green  | Both                       |
| Country | `globe`                 | Purple | Both                       |

## Field Behavior Comparison

### Travel History (Read-Only Display)
- Shows data from event with live lookup of parent location
- For "Other": Shows event-specific city/state/country
- For named locations: Shows current location data (master-detail)
- Displays "—" if state is not available

### Event Form (Editable)
- Shows data that can be edited
- For "Other": User enters or uses GPS to auto-populate
- For named locations: Inherits from location, allows override
- All fields always visible and editable

## Data Flow

### Display Flow (Travel History)
```
Event Data
    ↓
Is location "Other"?
    ├─ Yes → Use event.city, event.state, event.country
    └─ No  → Use location.city, location.state, location.country
         ↓
Display in detail sheet (read-only)
```

### Edit Flow (Event Form)
```
User selects location
    ↓
Is location "Other"?
    ├─ Yes → Clear fields (user enters or uses GPS)
    └─ No  → Populate from location data
         ↓
User can override any field
    ↓
Save: Use manual entry if present, else auto-detect country
```

## Unified Information Architecture

Both views now present location information in the same order and style:

1. **Location Name** (picker in form, label in history)
2. **City** 🏙️
3. **State** 🗺️
4. **Country** 🌍
5. **GPS Coordinates** (in separate section)

This creates a mental model where users see the same information flow when:
- Creating a new stay
- Editing an existing stay  
- Viewing a stay in history
- Viewing a stay detail sheet

## User Benefits

### For New Users
- Consistent layout reduces learning curve
- Icons help identify fields quickly
- Same information everywhere = less confusion

### For Power Users
- Faster data entry (fields are where expected)
- Override capability for edge cases
- Predictable behavior across the app

### For All Users
- Professional, polished appearance
- Reduced cognitive load
- Clear visual hierarchy

## Implementation Notes

### Color Coordination
The color choices are intentional and semantic:
- **Orange (City)**: Warm, represents urban/populated areas
- **Green (State)**: Natural, represents geographic regions
- **Purple (Country)**: Regal, represents nations/sovereignty
- **Blue (Name)**: Trustworthy, represents user-defined data

### Icon Selection
Icons chosen for universal recognition:
- Building = City (urban environment)
- Map = State/Province (geographic area)
- Globe = Country (world/international)
- Map pin = Named location (point on map)

### Typography
Both views use:
- System font for accessibility
- `.secondary` color for values (clear hierarchy)
- Consistent spacing and alignment

## Testing the Consistency

### Visual Test
1. Create or edit an event in the calendar
2. Fill in location details
3. Save the event
4. View the same event in Travel History
5. Compare the display → Should match!

### Data Flow Test
1. Start in Travel History
2. Note the city/state/country shown
3. Edit the event from calendar
4. Verify the form shows same data
5. Make changes and save
6. Return to Travel History
7. Verify changes are reflected

### Override Test
1. Select a named location (e.g., "Home")
2. Note the auto-populated city/state/country
3. Manually change the city
4. Save the event
5. View in Travel History
6. Verify your override is displayed

## Accessibility Considerations

Both views now:
- Use semantic labels with SF Symbols
- Provide sufficient color contrast
- Support Dynamic Type (system font)
- Include descriptive footer text
- Work with VoiceOver (system controls)

## Future Enhancements

Potential improvements to further enhance consistency:

1. **Visual Indicator for Overrides**
   - Show a small badge when a field has been manually overridden
   - Example: "San Francisco*" (asterisk = custom)

2. **Quick Actions**
   - "Reset to Location Default" button in form
   - "Edit Event" button in detail sheet

3. **Live Validation**
   - Warning if coordinates don't match entered country
   - Suggestion to "Refresh from GPS"

4. **Batch Operations**
   - Update multiple events when parent location changes
   - Option to preserve overrides

5. **History Tracking**
   - Show when/why a field was changed
   - "City was auto-populated from GPS on [date]"
