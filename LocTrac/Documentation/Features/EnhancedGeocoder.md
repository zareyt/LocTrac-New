# EnhancedGeocoder Quick Reference
## v1.5 - Geocoding & Parsing API

### 📍 Parse Manual Entry

```swift
// Parse user input into components
let parsed = EnhancedGeocoder.parseManualEntry("Denver, CO")
// Result: (city: "Denver", state: "CO", country: "United States")
```

**Supported Formats**:
| Input | Output |
|-------|--------|
| `"Denver"` | city: "Denver" |
| `"Denver, CO"` | city: "Denver", state: "CO", country: "United States" |
| `"Toronto, ON"` | city: "Toronto", state: "ON", country: "Canada" |
| `"Paris, France"` | city: "Paris", country: "France" |
| `"Berlin, DE"` | city: "Berlin", country: "Germany" |
| `"Denver, CO, United States"` | city: "Denver", state: "CO", country: "United States" |

---

### 🌐 Forward Geocode

```swift
// Convert address to coordinates
do {
    let result = try await EnhancedGeocoder.forwardGeocode(address: "Denver, CO")
    print(result?.latitude)   // 39.7392
    print(result?.longitude)  // -104.9903
} catch {
    print("Failed: \(error)")
}
```

---

### 📍 Reverse Geocode

```swift
// Convert coordinates to address
do {
    let result = try await EnhancedGeocoder.reverseGeocode(
        latitude: 39.7392,
        longitude: -104.9903
    )
    print(result?.city)     // "Denver"
    print(result?.state)    // "CO"
    print(result?.country)  // "United States"
} catch {
    print("Failed: \(error)")
}
```

---

### 🔄 Parse + Geocode (Combined)

```swift
// Parse AND geocode in one call
let result = await EnhancedGeocoder.parseAndGeocode("Paris, France")
// Returns:
// - city: "Paris" (from parsing, ALWAYS preserved)
// - country: "France" (from parsing)
// - latitude/longitude (from geocoding)
// - countryCode: "FR" (from geocoding)
```

**Key Behavior**: City name is ALWAYS from parsing, never from geocoding. This prevents losing user's original city name if geocoding fails or returns incorrect data.

---

### 🚦 Rate Limit Handling

```swift
// Automatic retry (default behavior)
let result = try await EnhancedGeocoder.reverseGeocode(
    latitude: 39.7392,
    longitude: -104.9903,
    retryOnRateLimit: true  // Will wait and retry automatically
)

// Manual handling
do {
    let result = try await EnhancedGeocoder.reverseGeocode(
        latitude: 39.7392,
        longitude: -104.9903,
        retryOnRateLimit: false  // Throw error instead
    )
} catch EnhancedGeocoder.GeocodingError.rateLimitExceeded(let retryAfter) {
    print("Wait \(retryAfter) seconds before retrying")
}
```

**Apple's Rate Limit**: 50 requests per 60 seconds

---

### 📊 GeocodeResult Structure

```swift
struct GeocodeResult {
    let city: String?        // "Denver"
    let state: String?       // "CO"
    let country: String?     // "United States"
    let countryCode: String? // "US"
    let latitude: Double     // 39.7392
    let longitude: Double    // -104.9903
}
```

---

### 🔄 Data Migration

```swift
// Migrate all existing data
let stats = await LocationDataMigrator.performFullMigration(
    dataStore: dataStore
)

print("Locations updated: \(stats.locationsGeocoded)")
print("Events updated: \(stats.eventsGeocoded)")
print("Errors: \(stats.errors)")
```

**What It Does**:
1. Parses "City, State" entries → separate fields
2. Geocodes coordinates → fill missing state/country
3. Preserves original city names
4. Handles rate limits (300ms delays + auto-retry)
5. Tracks statistics and errors

---

### ⚠️ Error Handling

```swift
enum GeocodingError: Error {
    case rateLimitExceeded(retryAfter: TimeInterval)
    case invalidCoordinates
    case noResults
    case networkError(Error)
    case unknownError(Error)
}
```

**Example**:
```swift
do {
    let result = try await EnhancedGeocoder.forwardGeocode(address: "...")
} catch EnhancedGeocoder.GeocodingError.rateLimitExceeded(let seconds) {
    // Wait and retry
} catch EnhancedGeocoder.GeocodingError.noResults {
    // Address not found
} catch {
    // Other error
}
```

---

### 🗺️ Supported Regions

**US States** (50 + DC):
AL, AK, AZ, AR, CA, CO, CT, DE, FL, GA, HI, ID, IL, IN, IA, KS, KY, LA, ME, MD, MA, MI, MN, MS, MO, MT, NE, NV, NH, NJ, NM, NY, NC, ND, OH, OK, OR, PA, RI, SC, SD, TN, TX, UT, VT, VA, WA, WV, WI, WY, DC

**Canadian Provinces** (13):
AB, BC, MB, NB, NL, NS, NT, NU, ON, PE, QC, SK, YT

**Country Codes** (50+):
MX (Mexico), UK (United Kingdom), FR (France), DE (Germany), IT (Italy), ES (Spain), JP (Japan), CN (China), BR (Brazil), AR (Argentina), AU (Australia), NZ (New Zealand), IN (India), IE (Ireland), PT (Portugal), NL (Netherlands), BE (Belgium), CH (Switzerland), AT (Austria), SE (Sweden), NO (Norway), DK (Denmark), FI (Finland), PL (Poland), CZ (Czech Republic), GR (Greece), TR (Turkey), EG (Egypt), ZA (South Africa), KR (South Korea), SG (Singapore), TH (Thailand), MY (Malaysia), PH (Philippines), VN (Vietnam), ID (Indonesia), CL (Chile), PE (Peru), VE (Venezuela), EC (Ecuador), UY (Uruguay), CR (Costa Rica), PA (Panama), GT (Guatemala), HN (Honduras), NI (Nicaragua), SV (El Salvador), DO (Dominican Republic), JM (Jamaica), TT (Trinidad and Tobago), BB (Barbados), BS (Bahamas), BZ (Belize), PR (Puerto Rico), VI (US Virgin Islands), KY (Cayman Islands), BM (Bermuda), TC (Turks and Caicos), VG (British Virgin Islands)

---

### 💡 Best Practices

1. **Always Preserve City Names**
   ```swift
   // ✅ GOOD: Use parseAndGeocode() - preserves city name
   let result = await EnhancedGeocoder.parseAndGeocode(userInput)
   
   // ❌ BAD: Don't let geocoding overwrite user's city
   let geocoded = await forwardGeocode(userInput)
   location.city = geocoded?.city  // Might be wrong!
   ```

2. **Handle Rate Limits**
   ```swift
   // ✅ GOOD: Use retryOnRateLimit for migration
   try await reverseGeocode(..., retryOnRateLimit: true)
   
   // ✅ GOOD: Add delays between requests
   for event in events {
       let result = try await reverseGeocode(...)
       try await Task.sleep(nanoseconds: 300_000_000)  // 300ms
   }
   ```

3. **Validate Input**
   ```swift
   // ✅ GOOD: Check for valid input
   let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
   guard !trimmed.isEmpty else { return nil }
   ```

4. **Use Proper Error Types**
   ```swift
   // ✅ GOOD: Catch specific errors
   catch GeocodingError.rateLimitExceeded(let seconds) {
       // Handle specifically
   }
   
   // ❌ BAD: Catch all and ignore
   catch {
       // Lost error information
   }
   ```

---

### 📚 Related Documentation

- **GEOCODING_RATE_LIMIT_FIX.md** - Detailed rate limit handling
- **CITY_NAME_PRESERVATION_FIX.md** - City preservation logic
- **WEEK_2_GEOCODING_ENHANCEMENTS.md** - Complete Week 2 summary
- **README.md** - Project overview and setup

---

### 🎯 Common Use Cases

**Use Case 1: User enters "Denver, CO"**
```swift
let parsed = EnhancedGeocoder.parseManualEntry("Denver, CO")
// city: "Denver", state: "CO", country: "United States"
```

**Use Case 2: Get coordinates for an address**
```swift
let result = try await EnhancedGeocoder.forwardGeocode(address: "1600 Amphitheatre Parkway, Mountain View, CA")
// latitude: 37.4220, longitude: -122.0841
```

**Use Case 3: Reverse geocode GPS coordinates**
```swift
let result = try await EnhancedGeocoder.reverseGeocode(
    latitude: 48.8566,
    longitude: 2.3522
)
// city: "Paris", state: "Île-de-France", country: "France"
```

**Use Case 4: Migrate existing data**
```swift
// Run once after upgrading to v1.5
let stats = await LocationDataMigrator.performFullMigration(dataStore: dataStore)
```

---

**Version**: 1.5  
**Created**: April 10, 2026  
**Author**: Tim Arey
