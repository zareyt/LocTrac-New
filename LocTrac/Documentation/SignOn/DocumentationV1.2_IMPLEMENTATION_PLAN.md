read# V1.2 IMPLEMENTATION PLAN — Authentication & Profile

**Status**: Complete
**Target**: v1.2

---

## Architecture Decisions

- **Fully local / iCloud-only** — no Firebase or external backend
- **Optional login** — users can use the app without an account
- **Two sign-in methods**: Apple Sign-In + Email/Password
- **Credentials in Keychain** — not in SwiftData
- **UserProfile in SwiftData** — stores profile data and preferences (already exists)
- **No user IDs in export data** — enables clean sharing between users
- **All async/await** — no Combine, no GCD
- **iOS 18+** target

---

## Phase A: Auth Service & Models

### Files to Create
| File | Purpose |
|---|---|
| `Services/KeychainHelper.swift` | Keychain read/write/delete wrapper |
| `Services/AuthenticationService.swift` | Auth logic actor (Apple Sign-In, email/password, session) |
| `Views/Auth/AuthState.swift` | Observable auth state injected via `.environment()` |

### KeychainHelper
- Generic Keychain wrapper using `Security` framework
- Methods: `save(data:forKey:)`, `read(forKey:)`, `delete(forKey:)`
- String convenience methods for passwords/tokens
- Service identifier: `com.wineclub.auth`

### AuthenticationService (actor)
- Apple Sign-In: handle `ASAuthorization` credential
- Email/Password: hash password, store in Keychain, validate on login
- Session persistence: store session token in Keychain, check on launch
- Sign out: clear session, optionally clear Keychain credentials
- `CryptoKit` for password hashing (SHA256 + salt)

### AuthState (@Observable)
- `isAuthenticated: Bool`
- `currentUser: UserProfile?`
- `isLoading: Bool`
- `authError: String?`
- Injected into environment at app root
- Checks session on launch via `AuthenticationService`

### WineClubApp.swift Changes
- Create `AuthState` instance
- Inject into environment
- Check auth state on launch
- Conditional root view:
  - Authenticated -> `StartTabView`
  - Not authenticated + no data -> optional `WelcomeView`
  - Not authenticated + existing data -> `StartTabView` with prompt

---

## Phase B: Sign-In Views

### Files to Create
| File | Purpose |
|---|---|
| `Views/Auth/WelcomeView.swift` | First launch / optional sign-in prompt |
| `Views/Auth/SignInView.swift` | Email + password login |
| `Views/Auth/SignUpView.swift` | Email + password registration |
| `Views/Auth/EmailVerificationView.swift` | Verification code entry |

### Flow
1. App launches -> check for existing session
2. No session + no data -> `WelcomeView` (Skip or Sign In)
3. No session + existing data -> `StartTabView` + banner prompt
4. Sign In -> `SignInView` (Apple or Email)
5. New account -> `SignUpView` -> `EmailVerificationView`
6. Success -> create/update `UserProfile` in SwiftData

---

## Phase C: Profile Management

### Files to Create/Modify
| File | Purpose |
|---|---|
| `Views/Profile/ProfileView.swift` | Redesigned account hub (replaces placeholder) |
| `Views/Profile/EditProfileView.swift` | Edit name, photo, email |
| `Views/Profile/PreferencesView.swift` | App preferences |
| `Views/Profile/SecuritySettingsView.swift` | Password, 2FA, biometrics |

### Profile Tab Sections
- **Account**: display name, email, photo, edit, sign out, delete
- **Preferences**: temperature unit, default wine type, rating scale, notifications, favorite regions
- **Privacy**: share data toggle, analytics opt-in
- **Data Management**: placeholder for v1.3 export/import

---

## Phase D: 2FA & Biometrics

### Files to Create
| File | Purpose |
|---|---|
| `Services/BiometricService.swift` | Face ID / Touch ID via LAContext |
| `Services/TOTPService.swift` | TOTP generation and verification |
| `Views/Auth/TwoFactorSetupView.swift` | TOTP QR code and backup codes |
| `Views/Auth/TwoFactorVerifyView.swift` | TOTP code entry on login |

### Biometrics
- `LocalAuthentication` framework — `LAContext`
- Optional convenience unlock after initial login
- User enables in Security Settings

### 2FA (TOTP)
- Local TOTP using `CryptoKit`
- QR code for authenticator app setup
- Backup codes generated on setup
- Stored in Keychain

---

## Phase E: Existing User Migration

### Logic
- App detects existing `WineEntry` records with no linked `UserProfile`
- Non-intrusive prompt: "Create an account to secure your data"
- Account links to existing data — no data loss, no migration
- "Skip for now" — never block the user

---

## Files Summary

### New Files (14)
- `Services/KeychainHelper.swift`
- `Services/AuthenticationService.swift`
- `Services/BiometricService.swift`
- `Services/TOTPService.swift`
- `Views/Auth/AuthState.swift`
- `Views/Auth/WelcomeView.swift`
- `Views/Auth/SignInView.swift`
- `Views/Auth/SignUpView.swift`
- `Views/Auth/EmailVerificationView.swift`
- `Views/Auth/TwoFactorSetupView.swift`
- `Views/Auth/TwoFactorVerifyView.swift`
- `Views/Profile/EditProfileView.swift`
- `Views/Profile/PreferencesView.swift`
- `Views/Profile/SecuritySettingsView.swift`

### Modified Files (4)
- `WineClubApp.swift` — auth state check, conditional root view
- `StartTabView.swift` — use new ProfileView
- `ModelsUserProfile.swift` — add fields if needed
- `Info.plist` — Sign in with Apple capability

---

## Out of Scope for v1.2

- Google Sign-In (requires external SDK)
- JSON export/import (planned for v1.3)
- Cloud-based data sharing between accounts
- Server-side email verification (local flow only)
- Push notifications for auth events
