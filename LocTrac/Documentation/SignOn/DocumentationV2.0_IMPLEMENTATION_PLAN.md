# V2.0 IMPLEMENTATION PLAN — Authentication & Profile for LocTrac

**Status**: Planning
**Target**: v2.0
**Based on**: WineClub v1.2 Implementation Plan (adapted for LocTrac)
**Author**: Tim Arey / Claude

---

## Architecture Decisions

- **Fully local / iCloud-ready** — no Firebase or external backend (cloud option planned for future)
- **Optional login** — users can use the app without an account (existing data is never blocked)
- **Two sign-in methods**: Apple Sign-In + Email/Password
- **Credentials in Keychain** — not in backup.json or UserDefaults
- **UserProfile in separate `profile.json`** — keeps auth/profile data out of shared exports
- **backup.json remains untouched** — no user IDs in export data, enables clean sharing between users
- **All async/await** — no Combine, no GCD (per LocTrac convention)
- **iOS 18+** target
- **@EnvironmentObject pattern** — AuthState injected alongside DataStore

### Data Storage Strategy

| Data Type | Storage | Reason |
|---|---|---|
| Password hash + salt | Keychain | Security-sensitive credentials |
| Apple Sign-In tokens | Keychain | Security-sensitive credentials |
| Session token | Keychain | Persists login across launches |
| Biometric enrollment flag | Keychain | Tied to auth |
| TOTP secret + backup codes | Keychain | Security-sensitive |
| User profile (name, email, photo) | `profile.json` | Non-sensitive, separate from exports |
| User preferences (units, defaults) | `profile.json` | Non-sensitive, separate from exports |
| Locations, events, trips, etc. | `backup.json` | Existing system — unchanged |

### Why Not backup.json?

1. **Exports are shared between users** — profile/credentials must not leak
2. **Existing import/export pipeline stays untouched** — zero risk of breaking 1,500+ event datasets
3. **Clean separation of concerns** — auth is orthogonal to travel data
4. **Future iCloud sync** — profile syncs separately from travel data

---

## Implementation Order

**Phase A** → **Phase B** → **Phase C** → **Phase E** → **Phase D**

Phase D (2FA/Biometrics) is implemented last since it depends on the auth infrastructure from A-C and the migration flow from E.

---

## Phase A: Auth Service & Models

### Files to Create

| File | Purpose |
|---|---|
| `Services/KeychainHelper.swift` | Keychain read/write/delete wrapper |
| `Services/AuthenticationService.swift` | Auth logic actor (Apple Sign-In, email/password, session) |
| `Models/AuthState.swift` | Observable auth state injected via `.environmentObject()` |
| `Models/UserProfile.swift` | Profile model with Codable persistence to `profile.json` |

### KeychainHelper

- Generic Keychain wrapper using `Security` framework
- Methods: `save(data:forKey:)`, `read(forKey:)`, `delete(forKey:)`
- String convenience methods for passwords/tokens
- Service identifier: `com.loctrac.auth`
- Error handling with descriptive error types (no force unwraps)

### AuthenticationService (actor)

- Apple Sign-In: handle `ASAuthorization` credential
- Email/Password: hash password, store in Keychain, validate on login
- Session persistence: store session token in Keychain, check on launch
- Sign out: clear session, optionally clear Keychain credentials
- `CryptoKit` for password hashing (SHA256 + salt)
- All methods are async — no Combine, no GCD

### AuthState (@Observable or ObservableObject)

- `isAuthenticated: Bool`
- `currentUser: UserProfile?`
- `isLoading: Bool`
- `authError: String?`
- Injected into environment at app root alongside DataStore
- Checks session on launch via `AuthenticationService`

**Decision**: Use `ObservableObject` with `@Published` to match LocTrac's existing pattern (DataStore uses `@EnvironmentObject`). This keeps injection consistent:

```swift
// In AppEntry.swift
@StateObject private var store = DataStore()
@StateObject private var authState = AuthState()

var body: some Scene {
    WindowGroup {
        RootView()
            .environmentObject(store)
            .environmentObject(authState)
    }
}
```

### UserProfile Model

```swift
struct UserProfile: Codable, Identifiable {
    var id: String              // UUID string (matches LocTrac ID convention)
    var displayName: String
    var email: String?
    var photoData: Data?        // Local photo, not synced
    var signInMethod: SignInMethod  // .apple, .email, .none
    var createdDate: Date
    var lastLoginDate: Date

    // Preferences (LocTrac-specific)
    var defaultLocationID: String?      // ID of preferred default location
    var distanceUnit: DistanceUnit      // .miles, .kilometers
    var defaultTransportMode: TransportMode?  // Reuses existing TransportMode enum

    enum SignInMethod: String, Codable {
        case apple
        case email
        case none   // Guest / skipped sign-in
    }

    enum DistanceUnit: String, Codable {
        case miles
        case kilometers
    }
}
```

**Persistence**: Saved to `Documents/profile.json` via a `ProfileStore` helper (similar pattern to DataStore's `storeData()`). Loaded on launch, saved on changes.

### AppEntry.swift Changes

- Create `AuthState` instance as `@StateObject`
- Inject into environment alongside DataStore
- Check auth state on launch
- Conditional root view logic:
  - Authenticated → `StartTabView`
  - Not authenticated + no data → optional `WelcomeView`
  - Not authenticated + existing data → `StartTabView` with non-intrusive prompt

---

## Phase B: Sign-In Views

### Files to Create

| File | Purpose |
|---|---|
| `Views/Auth/WelcomeView.swift` | First launch / optional sign-in prompt |
| `Views/Auth/SignInView.swift` | Email + password login + Apple Sign-In button |
| `Views/Auth/SignUpView.swift` | Email + password registration |

### Flow

1. App launches → check for existing session in Keychain
2. No session + no data → `WelcomeView` (Skip or Sign In)
3. No session + existing data → `StartTabView` + subtle banner prompt
4. Sign In → `SignInView` (Apple or Email options)
5. New account → `SignUpView` → create UserProfile → save to `profile.json`
6. Success → update `AuthState`, proceed to `StartTabView`

### WelcomeView Design

- App logo and tagline
- "Sign in with Apple" button (prominent)
- "Sign in with Email" button (secondary)
- "Continue without account" link (always available, never blocked)
- Brief explanation: "Create an account to secure your data and enable future sync"

### SignInView Design

- Email field + password field
- "Sign in with Apple" button
- "Create Account" link → SignUpView
- "Forgot Password" → local password reset (Keychain-based, no server)
- Form validation with inline error messages

### Key Principle: Never Block the User

- No sign-in is ever required to use the app
- Existing data is always accessible regardless of auth state
- Sign-in is a value-add (security, future sync), not a gate

---

## Phase C: Profile Management

### Files to Create/Modify

| File | Action | Purpose |
|---|---|---|
| `Views/Profile/ProfileView.swift` | Create | Account hub — profile, preferences, security |
| `Views/Profile/EditProfileView.swift` | Create | Edit name, photo, email |
| `Views/Profile/PreferencesView.swift` | Create | App preferences (LocTrac-specific) |
| `StartTabView.swift` | Modify | Add profile access (toolbar or menu item) |

### ProfileView Sections

**Account**
- Display name, email, photo
- Edit profile button → `EditProfileView`
- Sign out button
- Delete account (clears Keychain + profile.json, does NOT delete travel data)

**Preferences (LocTrac-specific)**
- Default location picker (from existing locations list)
- Distance unit: Miles / Kilometers
- Default transport mode: Car, Plane, Train, etc. (reuses existing `TransportMode`)

**Privacy & Data**
- Export data (links to existing `BackupExportView`)
- "Your data stays on your device" — privacy reassurance
- Future: iCloud sync toggle (placeholder, disabled for v2.0)

### Integration with StartTabView

- Profile accessible via the existing Settings/Options menu in toolbar
- New menu item: "Profile & Settings" → presents `ProfileView` as sheet
- Add `@State private var showProfile: Bool` to `StartTabView`
- Wire `.sheet(isPresented: $showProfile) { ProfileView() }`

---

## Phase E: Existing User Migration (before Phase D)

### Logic

- App detects existing events/locations with no linked `UserProfile`
- Non-intrusive prompt on first launch after update: "Create an account to secure your data"
- Account creation links to existing data — no data loss, no migration needed
- "Skip for now" — prominently available, never pressures the user
- Prompt shown once, with option to access sign-up later from Profile

### Implementation

- `AppEntry.swift` checks: has data + no profile → show migration prompt
- Migration prompt is a one-time sheet, not a blocking view
- User can dismiss and access the same flow later via Settings → Profile
- Travel data (`backup.json`) is completely unaffected — no schema changes

### Data Safety Guarantees

1. **Zero data loss** — existing backup.json is never modified by auth system
2. **No schema migration** — backup.json format stays identical
3. **Rollback safe** — deleting profile.json returns to guest mode, all data intact
4. **Export compatibility** — v2.0 exports are identical to v1.5 exports (no auth data included)

---

## Phase D: Biometrics & 2FA (Last)

### Files to Create

| File | Purpose |
|---|---|
| `Services/BiometricService.swift` | Face ID / Touch ID via LAContext |
| `Services/TOTPService.swift` | TOTP generation and verification |
| `Views/Auth/TwoFactorSetupView.swift` | TOTP QR code and backup codes |
| `Views/Auth/TwoFactorVerifyView.swift` | TOTP code entry on login |
| `Views/Profile/SecuritySettingsView.swift` | Password change, 2FA toggle, biometrics toggle |

### Biometrics

- `LocalAuthentication` framework — `LAContext`
- Optional convenience unlock after initial login
- User enables in Security Settings within ProfileView
- Graceful fallback if biometrics unavailable (older devices, settings disabled)

### 2FA (TOTP)

- Local TOTP using `CryptoKit`
- QR code for authenticator app setup
- Backup codes generated on setup (stored in Keychain)
- Verification required on login when enabled
- Can be disabled from Security Settings

### SecuritySettingsView

- Change password (email accounts only)
- Enable/disable Face ID / Touch ID
- Enable/disable 2FA (TOTP)
- View/regenerate backup codes
- Accessible from ProfileView → Security section

---

## Files Summary

### New Files (14)

| # | File | Phase |
|---|---|---|
| 1 | `Services/KeychainHelper.swift` | A |
| 2 | `Services/AuthenticationService.swift` | A |
| 3 | `Models/AuthState.swift` | A |
| 4 | `Models/UserProfile.swift` | A |
| 5 | `Views/Auth/WelcomeView.swift` | B |
| 6 | `Views/Auth/SignInView.swift` | B |
| 7 | `Views/Auth/SignUpView.swift` | B |
| 8 | `Views/Profile/ProfileView.swift` | C |
| 9 | `Views/Profile/EditProfileView.swift` | C |
| 10 | `Views/Profile/PreferencesView.swift` | C |
| 11 | `Services/BiometricService.swift` | D |
| 12 | `Services/TOTPService.swift` | D |
| 13 | `Views/Auth/TwoFactorSetupView.swift` | D |
| 14 | `Views/Auth/TwoFactorVerifyView.swift` | D |
| 15 | `Views/Profile/SecuritySettingsView.swift` | D |

### Modified Files (3)

| File | Phase | Changes |
|---|---|---|
| `AppEntry.swift` | A | AuthState creation, environment injection, conditional root view |
| `StartTabView.swift` | C | Add showProfile state, menu item, sheet |
| `Info.plist` | A | Sign in with Apple capability |

### Unchanged Files

| File | Reason |
|---|---|
| `DataStore.swift` | No changes — auth is separate from travel data |
| `backup.json` format | No changes — exports remain user-agnostic |
| All existing views | No changes — auth is additive, not intrusive |

---

## Out of Scope for v2.0

- Google Sign-In (requires external SDK — violates no-dependency rule)
- Server-side email verification (no backend)
- Cloud-based data sharing between accounts (planned for future)
- Push notifications for auth events (no server)
- iCloud sync (planned for future, toggle placeholder only)
- Modifying backup.json schema for auth data

---

## Future Considerations (Post v2.0)

- **iCloud Sync**: Profile + travel data sync via CloudKit
- **Multi-device**: Same account on iPhone + iPad with synced data
- **Shared trips**: Export trips with recipient user ID for targeted import
- **Account recovery**: iCloud Keychain-based recovery flow
