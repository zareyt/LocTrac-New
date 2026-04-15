# Geocoding Rate Limit Fix

## Problem

During migration, the app was hitting Apple's geocoding rate limit of **50 requests per 60 seconds**. When the rate limit was exceeded, the geocoding requests would fail with:

```
Error Domain=GEOErrorDomain Code=-3 "(null)"
kCLErrorDomain error 2 (CLError.network)
```

However, the migration code was **not detecting or handling this error properly**. Instead of pausing and waiting for the rate limit to reset, it continued processing with failed geocoding results, leading to:

1. ❌ Missing city/state/country data
2. ❌ Wasted API calls  
3. ❌ Bad user experience with incomplete migration

## Solution

### 1. Enhanced Error Detection in `EnhancedGeocoder`

Added a new `GeocodingError` enum and rate limit detection:

```swift
enum GeocodingError: Error {
    case rateLimitExceeded(retryAfter: TimeInterval)
    case invalidCoordinates
    case noResults
    case networkError(Error)
    case unknownError(Error)
}
```

Created a helper method `extractRateLimitRetryTime()` that:
- Detects `GEOErrorDomain` error code `-3` (throttling)
- Extracts the `timeUntilReset` value from error's `userInfo`
- Falls back to 60 seconds if the exact time can't be extracted
- Also detects `kCLErrorDomain` error 2 (network) which often wraps GEO errors

### 2. Automatic Retry with Rate Limit Handling

Both `reverseGeocode()` and `forwardGeocode()` now:
- **Throw errors instead of returning nil** for better error handling
- Accept a `retryOnRateLimit` parameter (default: `true`)
- When rate limit is detected:
  - ⏳ Print the wait time
  - 🛌 Sleep for the required duration (`timeUntilReset`)
  - 🔄 Automatically retry the request once
  - 🚦 Throw `GeocodingError.rateLimitExceeded` if retry is disabled

### 3. Migration Code Updates

**LocationDataMigrator** now:
- Wraps geocoding calls in `do-catch` blocks
- Specifically catches `GeocodingError.rateLimitExceeded`
- Logs detailed error information
- Increased delay between requests: **200ms → 300ms** for extra safety

### 4. Better Error Reporting

Migration statistics now include:
- Specific error messages for rate limit issues
- Details about which location/event failed
- Coordinates for debugging

## Migration Flow

### Before Fix:
```
Request 1-50: ✅ Success
Request 51: ❌ Rate limit → Continue anyway
Request 52: ❌ Rate limit → Continue anyway
Request 53: ❌ Rate limit → Continue anyway
...
Result: Incomplete data, wasted effort
```

### After Fix:
```
Request 1-50: ✅ Success
Request 51: 🚦 Rate limit detected!
           ⏳ Waiting 42 seconds...
           🔄 Retrying...
           ✅ Success!
Request 52: ✅ Success (with 300ms delay)
Request 53: ✅ Success (with 300ms delay)
...
Result: Complete data, proper handling
```

## Testing Recommendations

1. **Small Dataset Test**: Run migration on 10-20 locations to verify basic functionality
2. **Large Dataset Test**: Run migration on 100+ locations to verify rate limit handling
3. **Monitor Console**: Watch for:
   - 🚦 Rate limit messages
   - ⏳ Wait time logs
   - 🔄 Retry messages
   - ✅ Successful completions

## Rate Limit Math

- **Apple's Limit**: 50 requests / 60 seconds
- **With 300ms delay**: ~3.3 requests/second = ~200 requests/minute
- **Safe threshold**: 50 requests/60s = 0.83 requests/second
- **Our delay ensures**: 1 request/300ms = 3.3 requests/second ✅

The 300ms delay is conservative and should prevent rate limiting in most cases, but the automatic retry ensures we handle it gracefully if it does occur.

## Future Improvements

1. **Batch Processing**: Group locations by proximity and geocode in batches
2. **Cache Results**: Store geocoding results to avoid repeat requests
3. **Progressive Saving**: Save progress periodically during migration
4. **Resume Capability**: Allow resuming from where migration left off
5. **Manual Rate Limiting**: Implement request counting to proactively throttle before hitting limit
