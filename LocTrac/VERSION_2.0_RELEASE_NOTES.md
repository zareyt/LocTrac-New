# LocTrac v2.0 Release Notes

**Release Date**: 2026-04-25
**Version**: 2.0.0
**Build**: TBD

---

## What's New in v2.0

### Sign In with Apple
icon: person.badge.key.fill | color: blue

Securely sign in with your Apple ID. Your credentials are stored safely in the Keychain — no passwords to remember. Sign-in is completely optional and never blocks access to your travel data.

### Email & Password Accounts
icon: envelope.badge.shield.half.filled.fill | color: green

Create a local account with email and password. All authentication stays on your device — no servers, no cloud, fully private. Passwords are securely hashed with CryptoKit.

### Profile & Preferences
icon: person.crop.circle.fill | color: purple

New profile hub with customizable preferences. Set your default location, choose between miles and kilometers, and pick a default transport mode. Access your profile from the Settings menu.

### Face ID & Touch ID
icon: faceid | color: orange

Enable biometric unlock for quick, secure access to your travel data. When enabled, the app automatically locks when you leave and unlocks with Face ID or Touch ID when you return. Optional convenience feature you can enable in Security Settings after signing in.

### Two-Factor Authentication
icon: lock.shield.fill | color: red

Add an extra layer of security with real TOTP-based two-factor authentication (RFC 6238). Works with any authenticator app (Google Authenticator, Authy, etc.) and includes backup codes for account recovery. When enabled, you'll need to verify a code after signing in with email.

### Event Type Visual Revamp
icon: paintbrush.fill | color: red

Event types now use SF Symbol icons and a consistent color palette across the entire app. The Infographic donut chart, event forms, calendar, map detail views, and location rows all share the same colors: Stay (red), Host (blue), Vacation (green), Family (purple), Business (brown), Unspecified (gray). The donut chart legend features modern colored capsule badges with icons.

### One Stay Per Day
icon: calendar.badge.exclamationmark | color: orange

Batch event creation now prevents duplicate stays on the same date. When creating a multi-day range, existing dates are automatically skipped and an alert shows how many days were skipped vs. created.

### Custom Event Types
icon: tag.fill | color: indigo

Create, edit, and delete custom event types from the new "Manage Event Types" screen in the Settings menu. Each type gets a custom name, SF Symbol icon, and color. Built-in types (Stay, Host, Vacation, Family, Business, Unspecified) can be customized but not deleted. All pickers and display views now use stored event types, so custom types appear consistently across the entire app. Set a default event type in Profile > Preferences to have it pre-selected on every new stay form.

### Smart Add Stay Button
icon: brain.head.profile | color: blue

The Home screen "Add Stay" button is now context-aware. It checks if today has a stay, finds the most recent gap in your timeline, and adapts its label and action accordingly. Tap once to add today's stay, fill a missing date range, or edit today's event when you're all caught up.

### Copy Stay to Dates
icon: doc.on.doc.fill | color: teal

Copy an existing stay's data to a range of other dates. Choose which fields to copy (location, type, people, activities, affirmations, notes) with a Select All option. Same-location dates are merged automatically, while different-location conflicts let you skip or replace per date. Adding a multi-day stay auto-opens the copy view for field selection. Access it from "Copy to Other Dates" when editing any stay, or create a date range when adding a new one.

### Compact Activity Picker
icon: figure.walk | color: green

Activities in event forms now use a compact chip-based design instead of a long toggle list. Selected activities appear as small capsule tags you can tap to remove, and an "Add More" button opens a dedicated picker sheet with all activities displayed as tappable chips. Works consistently across new stay, edit stay, and calendar inline editor forms.

### Event Photos
icon: camera.fill | color: cyan

Add up to 6 photos to any individual stay. Photos are separate from location-level images — capture moments, people, and activities for specific dates. Browse your photos in a horizontal gallery right in the event form, and optionally include them when copying stays to other dates. Photos are automatically cleaned up when events or locations are deleted.

### Photo Backup & Import
icon: archivebox.fill | color: purple

Export and import your photos alongside your travel data. The new "Include Photos" toggle in Backup & Import creates a .zip archive containing your backup.json plus all location and event photos. On import, the app auto-detects .zip vs .json format. If photos already exist on your device, choose to skip, replace, or rename. Selective date-range import applies to photos too — only images referenced by events in your chosen range are imported.

### Seamless Migration
icon: arrow.triangle.2.circlepath | color: teal

Existing users keep all their data — no migration needed. Optionally create an account to secure your data and prepare for future cloud sync. Your backup.json format is completely unchanged.

---

## Bug Fixes in v2.0

### Data Safety Guaranteed
icon: checkmark.shield.fill | color: green

Authentication system is completely isolated from travel data. Deleting your account removes only profile data — all locations, events, trips, and stays remain intact.

### Preferences Sync Fix
icon: gearshape.fill | color: blue

Fixed an issue where setting default location, event type, or transport mode in Profile > Preferences did not persist correctly for guest users or sync with the global defaults used by event forms. All three preferences now save to both UserProfile and UserDefaults consistently.

### Read-Only Location Fields
icon: lock.fill | color: orange

City, state, and country fields in the event form are now read-only when a named location is selected. These fields can only be edited in Manage Locations. For "Other" locations, the fields remain editable as before.

### Smarter "Other" Location Display
icon: mappin.and.ellipse | color: teal

Trips and data enhancement views now show the actual city name instead of "Other" for events at non-standard locations. For example, a trip to Paris now displays "Paris" instead of "Other" in all trip lists and route displays.

### Date Display Timezone Fix
icon: calendar.badge.clock | color: red

Fixed dates appearing off by one day in Enhance Location Data, Travel History details, trip views, and other screens. All date display now uses UTC-pinned formatters to match how dates are stored, preventing timezone drift.

### Smarter Trip Generation
icon: point.topleft.down.to.point.bottomright.curvepath.fill | color: blue

Fixed trip refresh generating phantom trips between "Other" location events in the same city. The trip engine now compares city names before falling back to distance, preventing false 6,000+ mile trips caused by coordinate mismatches. Also fixed a coordinate resolution mismatch where "Other" events could pass validation using the location object's coordinates but then calculate distance using different (event-level) coordinates. Trip refresh now shows full details for each addition, modification, and deletion — including dates, distance, transport mode, and reason for the change.

### Stay Reminder Timezone Fix
icon: bell.badge.clock.fill | color: orange

Fixed stay reminder notification incorrectly reporting missing stays due to timezone mismatch. The reminder now uses UTC calendar to match how event dates are stored, preventing false alerts in negative-UTC timezones (all US timezones). Also fixed stale notification content — the missing-days count now refreshes on every app launch, foreground return, and event change instead of repeating with frozen data.

---

## Architecture

### Authentication System

v2.0 introduces a fully local authentication system with these key design principles:

- **Optional sign-in** — Never blocks app usage
- **Keychain-based credentials** — Secure, encrypted storage
- **Separate profile storage** — `profile.json` is independent from `backup.json`
- **Export-safe** — No auth data leaks into shared exports
- **Rollback-safe** — Delete profile to return to guest mode

### New Files (16 total)

**Services (4):**
- `KeychainHelper.swift` — Keychain read/write/delete wrapper (`com.loctrac.auth`)
- `AuthenticationService.swift` — Auth logic actor (Apple Sign-In, email/password, sessions)
- `BiometricService.swift` — Face ID / Touch ID via LAContext with enable/disable helpers
- `TOTPService.swift` — Real TOTP generation/verification (RFC 6238, HMAC-SHA1, CryptoKit)

**Models (2):**
- `AuthState.swift` — Observable auth state with 2FA gate and computed helpers
- `UserProfile.swift` — Profile model with Codable persistence to `profile.json`

**Auth Views (7) — in `Services/Auth/`:**
- `WelcomeView.swift` — First launch sign-in prompt
- `SignInView.swift` — Email + Apple Sign-In
- `SignUpView.swift` — Account registration
- `ForgotPasswordView.swift` — Password reset flow
- `TwoFactorSetupView.swift` — TOTP setup with QR code + backup codes
- `TwoFactorVerifyView.swift` — TOTP code entry with backup code support
- `BiometricLockView.swift` — Full-screen lock overlay for biometric app lock

**Profile Views (4) — in `Views/Profile/`:**
- `ProfileView.swift` — Account hub (profile, preferences, security, notifications)
- `EditProfileView.swift` — Edit name, photo, email
- `PreferencesView.swift` — Travel-specific preferences (distance, default location, transport)
- `SecuritySettingsView.swift` — Password change, 2FA, biometrics toggles

### Modified Files

- `AppEntry.swift` — AuthState injection, biometric lock overlay via scenePhase monitoring
- `StartTabView.swift` — Profile menu item, sheet, menu reorganization (Notifications moved to Profile, Travel History moved next to Manage Trips)
- `Info.plist` — Added `NSFaceIDUsageDescription` for Face ID access
- `LocTrac.entitlements` — Sign in with Apple capability, push notifications

---

## Privacy & Data

### What's Stored

**Keychain (encrypted, service: `com.loctrac.auth`):**
- Password hash (SHA256 + salt via CryptoKit)
- Apple Sign-In user identifier
- Session token
- TOTP secret (20-byte random Data)
- Backup codes (JSON-encoded `[String]`)

**profile.json (local):**
- Display name, email, photo data
- Preferences (distance unit, default location, transport mode)
- Sign-in method and timestamps

**Info.plist (required keys):**
- `NSFaceIDUsageDescription` — Required for Face ID access (crashes without it)
- Sign in with Apple capability in entitlements

### What's NOT in Exports

- No credentials in backup.json
- No profile data in exports
- No user IDs in shared data
- Exports remain identical to v1.5 format

---

**Thank you for using LocTrac!**

*Version 2.0.0 — Tim Arey*
