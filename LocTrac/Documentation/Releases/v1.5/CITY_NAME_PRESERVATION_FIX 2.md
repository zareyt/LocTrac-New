# City Name Preservation Fix

## Problem

During migration and geocoding, the app was **overwriting user's original city names** with geocoded results, causing issues like:

| User Input | Expected Result | Actual (Before Fix) |
|------------|----------------|---------------------|
| `Blackcomb, Canada` | City: "Blackcomb", Country: "Canada" | City: "Unknown", Country: "Canada" |
| `Banff, Canada` | City: "Banff", Country: "Canada" | City: "Unknown", Country: "Canada" |
| `Diamante, MX` | City: "Diamante", Country: "Mexico" | City: "Unknown", Country: "Mexico" |
| `St. Andrews, Scotland` | City: "St. Andrews", Country: "Scotland" | City: "Unknown", Country: "United Kingdom" |
| `Columbia` | City: "Columbia" | City: "Columbia", State: "MO", Country: "United States" |

## Root Cause

The `parseAndGeocode()` method was using this logic:

```swift
// ❌ BAD: Prefers geocoded city even if it's wrong
city: geocoded.city ?? parsed.city
```

This meant:
- If geocoding returned ANY city (even "Unknown"), it would use that
- User's carefully entered city name was lost
- Geocoding can be inaccurate for small towns or international locations

## Solution

### 1. Always Preserve Parsed City Name

Changed `parseAndGeocode()` to **ALWAYS** use the parsed city name:

```swift
// ✅ GOOD: Always preserve user's city name
city: parsed.city  // First component before comma
```

Geocoding is now only used for:
- 📍 Getting coordinates (latitude/longitude)
- 🗺️ Filling in state/country if missing
- 🏷️ Getting country codes

### 2. Smart Country Preference

Added logic to prefer user's parsed country when it's more specific:

```swift
// Example: "Scotland" is more specific than "United Kingdom"
if parsed.country != geocoded.country {
    // Keep user's more specific entry
    finalCountry = parsed.country
}
```

This ensures:
- ✅ "St. Andrews, Scotland" keeps "Scotland" (not "United Kingdom")
- ✅ User's regional specificity is preserved
- ✅ Geocoding still provides accurate coordinates

### 3. Migration Already Safe

The migration code was already correct:

```swift
// Only update fields that are currently nil
if updated.city == nil {
    updated.city = geocoded.city  // Only fills if empty
}
```

This means migration never overwrites existing city names.

## Testing

Created comprehensive test suite: `EnhancedGeocoderTests.swift`

Tests cover:
- ✅ City name preservation (all your examples)
- ✅ US state parsing (Denver, CO)
- ✅ Canadian province parsing (Toronto, ON)
- ✅ Country code expansion (MX → Mexico, UK → United Kingdom)
- ✅ Edge cases (empty strings, extra spaces)

Run tests with: **⌘U** in Xcode

## How It Works Now

### Example: "Blackcomb, Canada"

**Step 1: Parse**
```swift
parsed = parseManualEntry("Blackcomb, Canada")
// Result: (city: "Blackcomb", state: nil, country: "Canada")
```

**Step 2: Geocode (for coordinates)**
```swift
geocoded = forwardGeocode("Blackcomb, Canada")
// Might return: (city: "Whistler", state: "BC", country: "Canada", lat: 50.1, lon: -122.9)
// (Geocoder might recognize Blackcomb as part of Whistler)
```

**Step 3: Merge (Smart Preference)**
```swift
finalResult = GeocodeResult(
    city: parsed.city,              // ✅ "Blackcomb" (user's input)
    state: geocoded.state,          // "BC" (from geocoding)
    country: parsed.country,        // ✅ "Canada" (user's input, kept over geocoded)
    countryCode: geocoded.countryCode,  // "CA"
    latitude: geocoded.latitude,    // 50.1
    longitude: geocoded.longitude   // -122.9
)
```

### Example: "Columbia"

**Step 1: Parse**
```swift
parsed = parseManualEntry("Columbia")
// Result: (city: "Columbia", state: nil, country: nil)
```

**Step 2: Geocode**
```swift
geocoded = forwardGeocode("Columbia")
// Might return: (city: "Columbia", state: "MO", country: "United States")
// (Geocoder assumes Columbia, Missouri)
```

**Step 3: Merge**
```swift
finalResult = GeocodeResult(
    city: parsed.city,              // ✅ "Columbia" (preserved)
    state: geocoded.state,          // "MO" (added from geocoding)
    country: parsed.country ?? geocoded.country,  // "United States" (filled in)
    countryCode: geocoded.countryCode,  // "US"
    latitude: geocoded.latitude,    // Coordinates for Columbia, MO
    longitude: geocoded.longitude
)
```

**Note**: In this case, geocoding DID fill in state/country. This is intentional - we assume if the user only typed a city name, they want us to look up the details. If they had typed "Columbia, South Carolina" or "Columbia, SC", we would preserve "South Carolina" instead of changing it to "Missouri".

## Key Principle

**User's explicit input always wins over geocoder's guesses.**

- User typed "Blackcomb" → We keep "Blackcomb" (not "Whistler")
- User typed "Scotland" → We keep "Scotland" (not "United Kingdom")
- User typed "Diamante" → We keep "Diamante" (not "Unknown")

Geocoding is a **helper** to fill in coordinates and missing data, not a replacement for user's knowledge.

## Future Improvements

1. **Geocoding Confidence**: Only use geocoded data if confidence is high
2. **User Confirmation**: Ask user "Did you mean Columbia, MO?" before assuming
3. **Custom Geocoding**: Build our own city database for better international support
4. **Learn from Corrections**: Remember when users correct geocoding mistakes
