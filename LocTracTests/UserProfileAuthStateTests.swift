//
//  UserProfileAuthStateTests.swift
//  LocTracTests
//
//  Swift Testing unit tests for UserProfile and AuthState models.
//

import Testing
@testable import LocTrac

// MARK: - UserProfile Tests

@Suite("UserProfile Tests")
@MainActor
struct UserProfileTests {

    // MARK: - Initialization

    @Test("Init with defaults: signInMethod is .none, distanceUnit is .miles")
    func initWithDefaults() {
        let profile = UserProfile(displayName: "Test User")

        #expect(profile.signInMethod == .none)
        #expect(profile.distanceUnit == .miles)
        #expect(profile.email == nil)
        #expect(profile.photoData == nil)
        #expect(profile.defaultLocationID == nil)
        #expect(profile.defaultTransportMode == nil)
        #expect(profile.defaultEventType == nil)
    }

    // MARK: - Codable

    @Test("Codable roundtrip preserves all fields")
    func codableRoundtrip() throws {
        let original = UserProfile(
            id: "test-id-123",
            displayName: "Tim Arey",
            email: "tim@example.com",
            photoData: Data([0x01, 0x02, 0x03]),
            signInMethod: .email,
            createdDate: Date(timeIntervalSince1970: 1_000_000),
            lastLoginDate: Date(timeIntervalSince1970: 2_000_000),
            defaultLocationID: "loc-456",
            distanceUnit: .kilometers,
            defaultTransportMode: "car",
            defaultEventType: "vacation"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UserProfile.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.displayName == original.displayName)
        #expect(decoded.email == original.email)
        #expect(decoded.photoData == original.photoData)
        #expect(decoded.signInMethod == original.signInMethod)
        #expect(decoded.createdDate == original.createdDate)
        #expect(decoded.lastLoginDate == original.lastLoginDate)
        #expect(decoded.defaultLocationID == original.defaultLocationID)
        #expect(decoded.distanceUnit == original.distanceUnit)
        #expect(decoded.defaultTransportMode == original.defaultTransportMode)
        #expect(decoded.defaultEventType == original.defaultEventType)
    }

    // MARK: - Initials

    @Test("Initials from two-word name: 'Tim Arey' returns 'TA'")
    func initialsTwoWordName() {
        let profile = UserProfile(displayName: "Tim Arey")
        #expect(profile.initials == "TA")
    }

    @Test("Initials from single-word name: 'Tim' returns 'TI'")
    func initialsSingleWordName() {
        let profile = UserProfile(displayName: "Tim")
        #expect(profile.initials == "TI")
    }

    // MARK: - hasProfilePhoto

    @Test("hasProfilePhoto is false when photoData is nil")
    func hasProfilePhotoFalse() {
        let profile = UserProfile(displayName: "Test", photoData: nil)
        #expect(profile.hasProfilePhoto == false)
    }

    @Test("hasProfilePhoto is true when photoData has data")
    func hasProfilePhotoTrue() {
        let profile = UserProfile(displayName: "Test", photoData: Data([0xFF]))
        #expect(profile.hasProfilePhoto == true)
    }

    // MARK: - DistanceUnit

    @Test("DistanceUnit abbreviations: miles='mi', kilometers='km'")
    func distanceUnitAbbreviations() {
        #expect(UserProfile.DistanceUnit.miles.abbreviation == "mi")
        #expect(UserProfile.DistanceUnit.kilometers.abbreviation == "km")
    }

    @Test("DistanceUnit displayNames: miles='Miles', kilometers='Kilometers'")
    func distanceUnitDisplayNames() {
        #expect(UserProfile.DistanceUnit.miles.displayName == "Miles")
        #expect(UserProfile.DistanceUnit.kilometers.displayName == "Kilometers")
    }

    // MARK: - SignInMethod

    @Test("SignInMethod raw values: apple='apple', email='email', none='none'")
    func signInMethodRawValues() {
        #expect(UserProfile.SignInMethod.apple.rawValue == "apple")
        #expect(UserProfile.SignInMethod.email.rawValue == "email")
        #expect(UserProfile.SignInMethod.none.rawValue == "none")
    }

    // MARK: - Optional Fields in Codable

    @Test("Codable preserves optional fields when nil")
    func codablePreservesNilOptionals() throws {
        let original = UserProfile(
            displayName: "Minimal User",
            email: nil,
            photoData: nil,
            defaultLocationID: nil,
            defaultTransportMode: nil,
            defaultEventType: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UserProfile.self, from: data)

        #expect(decoded.email == nil)
        #expect(decoded.photoData == nil)
        #expect(decoded.defaultLocationID == nil)
        #expect(decoded.defaultTransportMode == nil)
        #expect(decoded.defaultEventType == nil)
    }
}

// MARK: - AuthState Tests

@Suite("AuthState Tests")
@MainActor
struct AuthStateTests {

    /// Creates an AuthState and resets it to a clean default state,
    /// avoiding side effects from the async checkSession() in init.
    private func makeCleanAuthState() async -> AuthState {
        let authState = AuthState()
        // Allow the async init to settle
        try? await Task.sleep(nanoseconds: 100_000_000)
        authState.isLoading = false
        authState.isAuthenticated = false
        authState.currentUser = nil
        authState.authError = nil
        authState.requiresTwoFactor = false
        authState.hasDismissedMigrationPrompt = false
        return authState
    }

    // MARK: - Default State

    @Test("Default state: isAuthenticated false, currentUser nil, requiresTwoFactor false")
    func defaultState() async {
        let authState = await makeCleanAuthState()

        #expect(authState.isAuthenticated == false)
        #expect(authState.currentUser == nil)
        #expect(authState.requiresTwoFactor == false)
        #expect(authState.hasDismissedMigrationPrompt == false)
    }

    // MARK: - Computed: currentAuthProvider

    @Test("currentAuthProvider returns .none when no user")
    func currentAuthProviderNoUser() async {
        let authState = await makeCleanAuthState()
        #expect(authState.currentAuthProvider == .none)
    }

    @Test("currentAuthProvider returns correct method when user is set")
    func currentAuthProviderWithUser() async {
        let authState = await makeCleanAuthState()
        authState.currentUser = UserProfile(displayName: "Tim Arey", signInMethod: .apple)
        #expect(authState.currentAuthProvider == .apple)
    }

    // MARK: - Computed: currentEmail

    @Test("currentEmail returns nil when no user")
    func currentEmailNoUser() async {
        let authState = await makeCleanAuthState()
        #expect(authState.currentEmail == nil)
    }

    @Test("currentEmail returns email when user is set")
    func currentEmailWithUser() async {
        let authState = await makeCleanAuthState()
        authState.currentUser = UserProfile(displayName: "Tim", email: "tim@example.com")
        #expect(authState.currentEmail == "tim@example.com")
    }

    // MARK: - Computed: initials

    @Test("initials returns '?' when no user")
    func initialsNoUser() async {
        let authState = await makeCleanAuthState()
        #expect(authState.initials == "?")
    }

    @Test("initials returns correct initials when user is set")
    func initialsWithUser() async {
        let authState = await makeCleanAuthState()
        authState.currentUser = UserProfile(displayName: "Tim Arey")
        #expect(authState.initials == "TA")
    }

    // MARK: - completeTwoFactorAuth

    @Test("completeTwoFactorAuth sets isAuthenticated true and requiresTwoFactor false")
    func completeTwoFactorAuth() async {
        let authState = await makeCleanAuthState()
        authState.requiresTwoFactor = true
        authState.isAuthenticated = false

        authState.completeTwoFactorAuth()

        #expect(authState.isAuthenticated == true)
        #expect(authState.requiresTwoFactor == false)
    }

    // MARK: - setError / clearError

    @Test("setError and clearError work correctly")
    func setAndClearError() async {
        let authState = await makeCleanAuthState()
        #expect(authState.authError == nil)

        authState.setError("Something went wrong")
        #expect(authState.authError == "Something went wrong")

        authState.clearError()
        #expect(authState.authError == nil)
    }

    // MARK: - updateProfile

    @Test("updateProfile sets currentUser")
    func updateProfileSetsUser() async {
        let authState = await makeCleanAuthState()
        #expect(authState.currentUser == nil)

        let profile = UserProfile(displayName: "New User", email: "new@example.com", signInMethod: .email)
        authState.updateProfile(profile)

        #expect(authState.currentUser != nil)
        #expect(authState.currentUser?.displayName == "New User")
        #expect(authState.currentUser?.email == "new@example.com")
        #expect(authState.currentUser?.signInMethod == .email)
    }
}
