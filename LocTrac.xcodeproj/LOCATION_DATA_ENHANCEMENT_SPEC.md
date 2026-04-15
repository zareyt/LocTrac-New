# Location Data Validation & Enhancement - Technical Specification

## Overview
This specification defines the priority-based algorithm for validating, cleaning, and enhancing location data (city, state, country, GPS coordinates) across all events and locations in LocTrac.

## Goals
1. Clean up legacy data with incorrect formats (e.g., "Denver, CO" should be "Denver" with state="CO")
2. Populate missing state and country data using GPS or intelligent parsing
3. Ensure data consistency across all events
4. Provide clear error reporting for unresolvable data
5. Minimize geocoding API calls through smart logic

## Priority Processing Algorithm

### Step 1: Complete Data - Format Check Only
**Condition:** City, State, Country, and GPS coordinates ALL exist

**Logic:**
```swift
if city != nil && state != nil && country != nil && 
   latitude != 0.0 && longitude != 0.0 {
    
    // Check for format "City Name, XX"
    if let commaIndex = city.firstIndex(of: ",") {
        // Extract city without suffix
        let cleanCity = String(city[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        
        // Update city to clean format
        city = cleanCity
    }
    
    // STOP - data is now complete and clean
    return .success
}
```

**Why this works:**
- All data exists, just need format cleanup
- No geocoding needed (saves API calls)
- Fast processing

**Example:**
- Input: city="Denver, CO", state="Colorado", country="United States", GPS=(39.7, -104.9)
- Output: city="Denver", state="Colorado", country="United States", GPS=(39.7, -104.9)

---

### Step 2: Valid GPS - Use Reverse Geocoding
**Condition:** GPS coordinates exist and are valid (not 0,0 or nil)

**Logic:**
```swift
if latitude != 0.0 && longitude != 0.0 &&
   latitude != nil && longitude != nil {
    
    // Use reverse geocoding to get state and country
    let location = CLLocation(latitude: latitude, longitude: longitude)
    let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
    
    if let placemark = placemarks.first {
        // Update state (administrativeArea)
        if let state = placemark.administrativeArea {
            event.state = state
        }
        
        // Update country
        if let country = placemark.country {
            event.country = country
        }
        
        // Check if city has format "City Name, XX" and clean it
        if let city = event.city,
           let commaIndex = city.firstIndex(of: ",") {
            let cleanCity = String(city[..<commaIndex]).trimmingCharacters(in: .whitespaces)
            event.city = cleanCity
        }
    }
    
    // STOP - data updated from GPS
    return .success
}
```

**Why this works:**
- GPS is most reliable source of truth
- Reverse geocoding provides accurate state/country
- Handles any city format issues

**Example:**
- Input: city="Denver, CO", state=nil, country=nil, GPS=(39.7, -104.9)
- Reverse geocode: Gets "Colorado" and "United States"
- Output: city="Denver", state="Colorado", country="United States", GPS=(39.7, -104.9)

---

### Step 3: No GPS - Parse City Format
**Condition:** GPS coordinates are 0,0 or nil

**Logic:**
```swift
if (latitude == 0.0 || latitude == nil) &&
   (longitude == 0.0 || longitude == nil) {
    
    guard let city = event.city else {
        return .error("Missing city name")
    }
    
    // Check for format "City Name, XX"
    guard let commaIndex = city.firstIndex(of: ",") else {
        return .error("City doesn't contain code and GPS is missing")
    }
    
    let cleanCity = String(city[..<commaIndex]).trimmingCharacters(in: .whitespaces)
    let code = String(city[city.index(after: commaIndex)...])
                .trimmingCharacters(in: .whitespaces)
                .uppercased()
    
    // Try as US state code
    if let stateName = USStateCodeMapper.stateName(for: code) {
        event.city = cleanCity
        event.state = stateName
        event.country = "United States"
        return .success
    }
    
    // Try as country code
    if let countryName = CountryCodeMapper.countryName(for: code) {
        event.city = cleanCity
        event.country = countryName
        
        // Use forward geocoding to get state
        let geocoder = CLGeocoder()
        let query = "\(cleanCity), \(countryName)"
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            if let placemark = placemarks.first {
                event.state = placemark.administrativeArea
                event.latitude = placemark.location?.coordinate.latitude ?? 0.0
                event.longitude = placemark.location?.coordinate.longitude ?? 0.0
                return .success
            }
        } catch {
            return .error("Could not geocode '\(query)'")
        }
    }
    
    // Code is neither state nor country
    return .error("Unknown code '\(code)' in '\(city)'")
}
```

**Why this works:**
- Extracts useful information from legacy format
- Attempts US state first (most common case)
- Falls back to country code
- Uses forward geocoding as last resort
- Provides specific error messages

**Examples:**

**Valid US State:**
- Input: city="Denver, CO", state=nil, country=nil, GPS=(0,0)
- Parse: "Denver" + "CO"
- Lookup: CO → "Colorado"
- Output: city="Denver", state="Colorado", country="United States", GPS=(0,0)

**Valid Country Code:**
- Input: city="London, GB", state=nil, country=nil, GPS=(0,0)
- Parse: "London" + "GB"
- Lookup: Not a US state, check GB → "United Kingdom"
- Forward geocode: "London, United Kingdom"
- Output: city="London", state="England", country="United Kingdom", GPS=(51.5, -0.1)

**Invalid Code:**
- Input: city="Paris, XY", state=nil, country=nil, GPS=(0,0)
- Parse: "Paris" + "XY"
- Lookup: XY is neither state nor country
- Error: "Unknown code 'XY' in 'Paris, XY'"

---

### Step 4: None of the Above
**Condition:** Doesn't match any previous condition

**Logic:**
```swift
// If we reach here, data is incomplete and can't be resolved
return .error("Insufficient data to validate location")
```

**Example:**
- Input: city=nil, state=nil, country=nil, GPS=(0,0)
- Error: "Insufficient data to validate location"

---

## Implementation Components

### 1. State Code Mapper

```swift
struct USStateCodeMapper {
    private static let codes: [String: String] = [
        "AL": "Alabama",
        "AK": "Alaska",
        "AZ": "Arizona",
        "AR": "Arkansas",
        "CA": "California",
        "CO": "Colorado",
        "CT": "Connecticut",
        "DE": "Delaware",
        "FL": "Florida",
        "GA": "Georgia",
        "HI": "Hawaii",
        "ID": "Idaho",
        "IL": "Illinois",
        "IN": "Indiana",
        "IA": "Iowa",
        "KS": "Kansas",
        "KY": "Kentucky",
        "LA": "Louisiana",
        "ME": "Maine",
        "MD": "Maryland",
        "MA": "Massachusetts",
        "MI": "Michigan",
        "MN": "Minnesota",
        "MS": "Mississippi",
        "MO": "Missouri",
        "MT": "Montana",
        "NE": "Nebraska",
        "NV": "Nevada",
        "NH": "New Hampshire",
        "NJ": "New Jersey",
        "NM": "New Mexico",
        "NY": "New York",
        "NC": "North Carolina",
        "ND": "North Dakota",
        "OH": "Ohio",
        "OK": "Oklahoma",
        "OR": "Oregon",
        "PA": "Pennsylvania",
        "RI": "Rhode Island",
        "SC": "South Carolina",
        "SD": "South Dakota",
        "TN": "Tennessee",
        "TX": "Texas",
        "UT": "Utah",
        "VT": "Vermont",
        "VA": "Virginia",
        "WA": "Washington",
        "WV": "West Virginia",
        "WI": "Wisconsin",
        "WY": "Wyoming",
        "DC": "District of Columbia"
    ]
    
    static func stateName(for code: String) -> String? {
        codes[code.uppercased()]
    }
    
    static func isValidCode(_ code: String) -> Bool {
        codes[code.uppercased()] != nil
    }
}
```

### 2. Country Code Mapper

```swift
struct CountryCodeMapper {
    // ISO 3166-1 alpha-2 codes
    private static let codes: [String: String] = [
        "US": "United States",
        "CA": "Canada",
        "GB": "United Kingdom",
        "FR": "France",
        "DE": "Germany",
        "IT": "Italy",
        "ES": "Spain",
        "MX": "Mexico",
        "JP": "Japan",
        "CN": "China",
        "AU": "Australia",
        "NZ": "New Zealand",
        "BR": "Brazil",
        "AR": "Argentina",
        "IN": "India",
        "ZA": "South Africa",
        "KR": "South Korea",
        "TH": "Thailand",
        "SG": "Singapore",
        "NL": "Netherlands",
        "BE": "Belgium",
        "CH": "Switzerland",
        "AT": "Austria",
        "SE": "Sweden",
        "NO": "Norway",
        "DK": "Denmark",
        "FI": "Finland",
        "IE": "Ireland",
        "PT": "Portugal",
        "GR": "Greece",
        "PL": "Poland",
        "CZ": "Czech Republic",
        "HU": "Hungary",
        "RO": "Romania",
        "RU": "Russia",
        "TR": "Turkey",
        "EG": "Egypt",
        "IL": "Israel",
        "AE": "United Arab Emirates",
        "SA": "Saudi Arabia",
        // Add more as needed
    ]
    
    static func countryName(for code: String) -> String? {
        codes[code.uppercased()]
    }
    
    static func isValidCode(_ code: String) -> Bool {
        codes[code.uppercased()] != nil
    }
}
```

### 3. Main Processor

```swift
enum LocationDataProcessingResult {
    case success
    case error(String)
}

class LocationDataEnhancer {
    
    func processEvent(_ event: inout Event) async -> LocationDataProcessingResult {
        
        // Step 1: All data exists - just clean format
        if hasCompleteData(event) {
            cleanCityFormat(&event)
            return .success
        }
        
        // Step 2: Valid GPS - use reverse geocoding
        if hasValidGPS(event) {
            return await processWithGPS(&event)
        }
        
        // Step 3: No GPS - parse city format
        if !hasValidGPS(event) {
            return await processWithoutGPS(&event)
        }
        
        // Step 4: Insufficient data
        return .error("Insufficient data to validate location")
    }
    
    private func hasCompleteData(_ event: Event) -> Bool {
        event.city != nil &&
        event.state != nil &&
        event.country != nil &&
        event.latitude != 0.0 &&
        event.longitude != 0.0
    }
    
    private func hasValidGPS(_ event: Event) -> Bool {
        event.latitude != 0.0 && event.longitude != 0.0
    }
    
    private func cleanCityFormat(_ event: inout Event) {
        guard var city = event.city,
              let commaIndex = city.firstIndex(of: ",") else { return }
        
        let cleanCity = String(city[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        event.city = cleanCity
    }
    
    private func processWithGPS(_ event: inout Event) async -> LocationDataProcessingResult {
        let location = CLLocation(latitude: event.latitude, longitude: event.longitude)
        
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                return .error("Reverse geocoding returned no results")
            }
            
            // Update state and country
            if let state = placemark.administrativeArea {
                event.state = state
            }
            if let country = placemark.country {
                event.country = country
            }
            
            // Clean city format if needed
            cleanCityFormat(&event)
            
            return .success
            
        } catch {
            return .error("Geocoding failed: \(error.localizedDescription)")
        }
    }
    
    private func processWithoutGPS(_ event: inout Event) async -> LocationDataProcessingResult {
        guard let city = event.city else {
            return .error("Missing city name")
        }
        
        // Must have format "City, XX"
        guard let commaIndex = city.firstIndex(of: ",") else {
            return .error("City doesn't contain code and GPS is missing")
        }
        
        let cleanCity = String(city[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        let code = String(city[city.index(after: commaIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                    .uppercased()
        
        // Try US state code
        if let stateName = USStateCodeMapper.stateName(for: code) {
            event.city = cleanCity
            event.state = stateName
            event.country = "United States"
            return .success
        }
        
        // Try country code
        if let countryName = CountryCodeMapper.countryName(for: code) {
            event.city = cleanCity
            event.country = countryName
            
            // Forward geocode to get state and GPS
            return await forwardGeocode(city: cleanCity, country: countryName, event: &event)
        }
        
        return .error("Unknown code '\(code)' in '\(city)'")
    }
    
    private func forwardGeocode(city: String, country: String, event: inout Event) async -> LocationDataProcessingResult {
        let query = "\(city), \(country)"
        
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(query)
            guard let placemark = placemarks.first else {
                return .error("Could not find location for '\(query)'")
            }
            
            event.state = placemark.administrativeArea
            event.latitude = placemark.location?.coordinate.latitude ?? 0.0
            event.longitude = placemark.location?.coordinate.longitude ?? 0.0
            
            return .success
            
        } catch {
            return .error("Forward geocoding failed for '\(query)': \(error.localizedDescription)")
        }
    }
}
```

### 4. UI View for Batch Processing

```swift
struct LocationDataEnhancementView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var isProcessing = false
    @State private var currentIndex = 0
    @State private var results: [EventResult] = []
    @State private var showResults = false
    
    struct EventResult: Identifiable {
        let id = UUID()
        let eventID: String
        let eventDate: Date
        let originalCity: String?
        let result: LocationDataProcessingResult
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isProcessing {
                    processingView
                } else if showResults {
                    resultsView
                } else {
                    startView
                }
            }
            .navigationTitle("Enhance Location Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }
    
    private var startView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Enhance Location Data")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This will process \(store.events.count) events to clean and enhance location data.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                Label("Clean city name formats", systemImage: "checkmark.circle.fill")
                Label("Populate missing states", systemImage: "checkmark.circle.fill")
                Label("Update countries from GPS", systemImage: "checkmark.circle.fill")
                Label("Report unfixable data", systemImage: "checkmark.circle.fill")
            }
            .foregroundColor(.green)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            Button {
                Task {
                    await processAllEvents()
                }
            } label: {
                Label("Start Enhancement", systemImage: "play.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: Double(currentIndex), total: Double(store.events.count))
                .progressViewStyle(.linear)
            
            Text("Processing event \(currentIndex) of \(store.events.count)")
                .foregroundColor(.secondary)
            
            Text("Please wait...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var resultsView: some View {
        List {
            Section {
                let successCount = results.filter { 
                    if case .success = $0.result { return true }
                    return false
                }.count
                let errorCount = results.count - successCount
                
                HStack {
                    Label("\(successCount) Successful", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Spacer()
                }
                
                HStack {
                    Label("\(errorCount) Errors", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Spacer()
                }
            } header: {
                Text("Summary")
            }
            
            if !results.filter({ 
                if case .error = $0.result { return true }
                return false
            }).isEmpty {
                Section {
                    ForEach(results.filter { 
                        if case .error = $0.result { return true }
                        return false
                    }) { result in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.eventDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.headline)
                            if let city = result.originalCity {
                                Text("City: \(city)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if case .error(let message) = result.result {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Errors (\(results.filter { if case .error = $0.result { return true }; return false }.count))")
                }
            }
        }
    }
    
    private func processAllEvents() async {
        isProcessing = true
        results = []
        
        let enhancer = LocationDataEnhancer()
        
        for (index, event) in store.events.enumerated() {
            await MainActor.run {
                currentIndex = index + 1
            }
            
            var mutableEvent = event
            let result = await enhancer.processEvent(&mutableEvent)
            
            await MainActor.run {
                results.append(EventResult(
                    eventID: event.id,
                    eventDate: event.date,
                    originalCity: event.city,
                    result: result
                ))
                
                // Update event in store if successful
                if case .success = result {
                    store.update(mutableEvent)
                }
            }
            
            // Rate limiting - 50ms delay between requests
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        
        await MainActor.run {
            isProcessing = false
            showResults = true
        }
    }
}
```

## Rate Limiting

Apple's CLGeocoder has limits:
- ~50 requests per minute
- Errors if exceeded

Our implementation:
- 50ms delay between requests = ~20 per second = ~1,200 per minute
- Actually under limit when accounting for async processing time
- Can adjust if needed

## Testing Checklist

- [ ] Test Step 1: Complete data with "City, XX" format
- [ ] Test Step 1: Complete data without comma format
- [ ] Test Step 2: Valid GPS with clean city
- [ ] Test Step 2: Valid GPS with "City, XX" format
- [ ] Test Step 3: No GPS with US state code
- [ ] Test Step 3: No GPS with country code
- [ ] Test Step 3: No GPS with invalid code
- [ ] Test Step 4: Completely missing data
- [ ] Test batch processing with 100+ events
- [ ] Test rate limiting doesn't hit API limits
- [ ] Test error reporting UI
- [ ] Test results display

## Future Enhancements

1. **Progress persistence** - Save progress to resume if interrupted
2. **Undo capability** - Allow reverting changes
3. **Preview mode** - Show what would change without applying
4. **Custom rules** - Allow user to define custom state/country codes
5. **Conflict resolution** - Ask user when multiple interpretations possible
6. **Export errors** - Save error report as CSV
7. **Timezone detection** - Also populate timezone from GPS (v1.6+)

---

*Location Data Enhancement Specification v1.0 - 2026-04-11*
