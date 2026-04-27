import Testing
import Foundation
@testable import LocTrac

@Suite("AuthenticationService Tests")
struct AuthenticationServiceTests {

    // MARK: - Session Tests

    @Test("No session initially after cleanup")
    @MainActor func noSessionInitially() async throws {
        let auth = AuthenticationService.shared

        await auth.deleteAccount()

        let hasSession = await auth.hasValidSession()
        #expect(hasSession == false)

        await auth.deleteAccount()
    }

    @Test("Register creates a valid session")
    @MainActor func registerCreatesSession() async throws {
        let auth = AuthenticationService.shared

        await auth.deleteAccount()

        _ = try await auth.registerWithEmail("test@example.com", password: "Password123", displayName: "Test User")
        let hasSession = await auth.hasValidSession()
        #expect(hasSession == true)

        await auth.deleteAccount()
    }

    @Test("Register returns correct profile fields")
    @MainActor func registerReturnsCorrectProfile() async throws {
        let auth = AuthenticationService.shared

        await auth.deleteAccount()

        let profile = try await auth.registerWithEmail("test@example.com", password: "SecurePass1", displayName: "Jane Doe")
        #expect(profile.displayName == "Jane Doe")
        #expect(profile.email == "test@example.com")
        #expect(profile.signInMethod == .email)

        await auth.deleteAccount()
    }

    // MARK: - Sign In Tests

    @Test("Sign in with valid credentials succeeds")
    @MainActor func signInWithValidCredentials() async throws {
        let auth = AuthenticationService.shared

        await auth.deleteAccount()

        _ = try await auth.registerWithEmail("user@example.com", password: "MyPass99", displayName: "User One")
        await auth.clearSession()

        let profile = try await auth.signInWithEmail("user@example.com", password: "MyPass99")
        #expect(profile.email == "user@example.com")
        let hasSession = await auth.hasValidSession()
        #expect(hasSession == true)

        await auth.deleteAccount()
    }

    @Test("Sign in with wrong password throws invalidCredentials")
    @MainActor func signInWithWrongPassword() async throws {
        let auth = AuthenticationService.shared

        await auth.deleteAccount()

        _ = try await auth.registerWithEmail("user@example.com", password: "CorrectPass1", displayName: "User Two")
        await auth.clearSession()

        await #expect(throws: AuthenticationService.AuthError.invalidCredentials) {
            try await auth.signInWithEmail("user@example.com", password: "WrongPass1")
        }

        await auth.deleteAccount()
    }

    @Test("Sign in with wrong email throws invalidCredentials")
    @MainActor func signInWithWrongEmail() async throws {
        let auth = AuthenticationService.shared

        await auth.deleteAccount()

        _ = try await auth.registerWithEmail("real@example.com", password: "Pass1234", displayName: "User Three")
        await auth.clearSession()

        await #expect(throws: AuthenticationService.AuthError.invalidCredentials) {
            try await auth.signInWithEmail("wrong@example.com", password: "Pass1234")
        }

        await auth.deleteAccount()
    }

    @Test("Sign in with no account throws noAccountFound")
    @MainActor func signInWithNoAccount() async throws {
        let auth = AuthenticationService.shared

        await auth.deleteAccount()

        await #expect(throws: AuthenticationService.AuthError.noAccountFound) {
            try await auth.signInWithEmail("nobody@example.com", password: "Whatever1")
        }

        await auth.deleteAccount()
    }

    // MARK: - Password Management Tests

    @Test("Change password works and allows sign in with new password")
    @MainActor func changePasswordWorks() async throws {
        let auth = AuthenticationService.shared

        await auth.deleteAccount()

        _ = try await auth.registerWithEmail("change@example.com", password: "OldPass1", displayName: "Changer")
        try await auth.changePassword(currentPassword: "OldPass1", newPassword: "NewPass1")
        await auth.clearSession()

        let profile = try await auth.signInWithEmail("change@example.com", password: "NewPass1")
        #expect(profile.email == "change@example.com")

        await auth.deleteAccount()
    }

    @Test("Change password with wrong current password throws invalidCredentials")
    @MainActor func changePasswordWrongCurrent() async throws {
        let auth = AuthenticationService.shared

        await auth.deleteAccount()

        _ = try await auth.registerWithEmail("change2@example.com", password: "RealPass1", displayName: "Changer2")

        await #expect(throws: AuthenticationService.AuthError.invalidCredentials) {
            try await auth.changePassword(currentPassword: "FakePass1", newPassword: "NewPass1")
        }

        await auth.deleteAccount()
    }

    @Test("Reset password allows sign in with new password")
    @MainActor func resetPasswordWorks() async throws {
        let auth = AuthenticationService.shared

        await auth.deleteAccount()

        _ = try await auth.registerWithEmail("reset@example.com", password: "Original1", displayName: "Resetter")
        try await auth.resetPassword(email: "reset@example.com", newPassword: "Reset1234")
        await auth.clearSession()

        let profile = try await auth.signInWithEmail("reset@example.com", password: "Reset1234")
        #expect(profile.email == "reset@example.com")

        await auth.deleteAccount()
    }

    // MARK: - Sign Out & Delete Tests

    @Test("Sign out clears the session")
    @MainActor func signOutClearsSession() async throws {
        let auth = AuthenticationService.shared

        await auth.deleteAccount()

        _ = try await auth.registerWithEmail("signout@example.com", password: "Pass1234", displayName: "SignOuter")
        let beforeSignOut = await auth.hasValidSession()
        #expect(beforeSignOut == true)

        await auth.signOut()

        let afterSignOut = await auth.hasValidSession()
        #expect(afterSignOut == false)

        await auth.deleteAccount()
    }

    @Test("Delete account clears session and profile data")
    @MainActor func deleteAccountClearsEverything() async throws {
        let auth = AuthenticationService.shared

        await auth.deleteAccount()

        _ = try await auth.registerWithEmail("delete@example.com", password: "Pass1234", displayName: "Deleter")

        await auth.deleteAccount()

        let hasSession = await auth.hasValidSession()
        #expect(hasSession == false)

        let profile = UserProfile.load()
        #expect(profile == nil)

        await auth.deleteAccount()
    }
}
