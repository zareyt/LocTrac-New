//
//  AuthenticationService.swift
//  LocTrac
//
//  Auth logic actor handling Apple Sign-In, email/password, and session management.
//  All credentials stored in Keychain via KeychainHelper.
//  All methods are async — no Combine, no GCD.
//

import Foundation
import AuthenticationServices
import CryptoKit

actor AuthenticationService {

    // MARK: - Keychain Keys

    private enum Keys {
        static let sessionToken = "session_token"
        static let passwordHash = "password_hash"
        static let passwordSalt = "password_salt"
        static let appleUserID = "apple_user_id"
        static let userEmail = "user_email"
    }

    // MARK: - Singleton

    static let shared = AuthenticationService()
    private init() {}

    // MARK: - Session Management

    /// Checks if a valid session exists in the Keychain.
    func hasValidSession() -> Bool {
        return KeychainHelper.readString(forKey: Keys.sessionToken) != nil
    }

    /// Creates a new session token and stores it in the Keychain.
    private func createSession() throws -> String {
        let token = UUID().uuidString
        try KeychainHelper.saveString(token, forKey: Keys.sessionToken)
        return token
    }

    /// Clears the current session from the Keychain.
    func clearSession() {
        KeychainHelper.delete(forKey: Keys.sessionToken)
        #if DEBUG
        print("🔐 [Auth] Session cleared")
        #endif
    }

    // MARK: - Apple Sign-In

    /// Handles a successful Apple Sign-In authorization.
    /// Returns a UserProfile created from the Apple credential.
    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) throws -> UserProfile {
        let userID = credential.user

        // Store Apple user ID for future validation
        try KeychainHelper.saveString(userID, forKey: Keys.appleUserID)

        // Extract name and email (only provided on first sign-in)
        let fullName = [
            credential.fullName?.givenName,
            credential.fullName?.familyName
        ].compactMap { $0 }.joined(separator: " ")

        let displayName = fullName.isEmpty ? "Apple User" : fullName
        let email = credential.email

        if let email = email {
            try KeychainHelper.saveString(email, forKey: Keys.userEmail)
        }

        // Create session
        _ = try createSession()

        // Create or update profile
        var profile: UserProfile
        if let existing = UserProfile.load() {
            profile = existing
            profile.lastLoginDate = Date()
            if profile.signInMethod == .none {
                profile.signInMethod = .apple
            }
            if let email = email {
                profile.email = email
            }
        } else {
            profile = UserProfile(
                displayName: displayName,
                email: email,
                signInMethod: .apple
            )
        }

        try profile.save()

        #if DEBUG
        print("🔐 [Auth] Apple Sign-In successful for \(displayName)")
        #endif

        return profile
    }

    /// Validates that the Apple Sign-In credential is still valid.
    func validateAppleCredential() async -> Bool {
        guard let appleUserID = KeychainHelper.readString(forKey: Keys.appleUserID) else {
            return false
        }

        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: appleUserID)
            return state == .authorized
        } catch {
            #if DEBUG
            print("🔐 [Auth] Apple credential validation failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Email/Password

    /// Registers a new email/password account.
    /// Password is hashed with SHA256 + random salt before storage.
    func registerWithEmail(_ email: String, password: String, displayName: String) throws -> UserProfile {
        let salt = generateSalt()
        let hash = hashPassword(password, salt: salt)

        try KeychainHelper.saveString(hash, forKey: Keys.passwordHash)
        try KeychainHelper.saveString(salt, forKey: Keys.passwordSalt)
        try KeychainHelper.saveString(email, forKey: Keys.userEmail)

        _ = try createSession()

        let profile = UserProfile(
            displayName: displayName,
            email: email,
            signInMethod: .email
        )
        try profile.save()

        #if DEBUG
        print("🔐 [Auth] Email registration successful for \(email)")
        #endif

        return profile
    }

    /// Signs in with email and password.
    /// Returns the UserProfile on success, throws on failure.
    func signInWithEmail(_ email: String, password: String) throws -> UserProfile {
        guard let storedHash = KeychainHelper.readString(forKey: Keys.passwordHash),
              let storedSalt = KeychainHelper.readString(forKey: Keys.passwordSalt),
              let storedEmail = KeychainHelper.readString(forKey: Keys.userEmail) else {
            throw AuthError.noAccountFound
        }

        guard email.lowercased() == storedEmail.lowercased() else {
            throw AuthError.invalidCredentials
        }

        let hash = hashPassword(password, salt: storedSalt)
        guard hash == storedHash else {
            throw AuthError.invalidCredentials
        }

        _ = try createSession()

        guard var profile = UserProfile.load() else {
            throw AuthError.noAccountFound
        }
        profile.lastLoginDate = Date()
        try profile.save()

        #if DEBUG
        print("🔐 [Auth] Email sign-in successful for \(email)")
        #endif

        return profile
    }

    /// Changes the password for an email account.
    func changePassword(currentPassword: String, newPassword: String) throws {
        guard let storedHash = KeychainHelper.readString(forKey: Keys.passwordHash),
              let storedSalt = KeychainHelper.readString(forKey: Keys.passwordSalt) else {
            throw AuthError.noAccountFound
        }

        let currentHash = hashPassword(currentPassword, salt: storedSalt)
        guard currentHash == storedHash else {
            throw AuthError.invalidCredentials
        }

        let newSalt = generateSalt()
        let newHash = hashPassword(newPassword, salt: newSalt)

        try KeychainHelper.saveString(newHash, forKey: Keys.passwordHash)
        try KeychainHelper.saveString(newSalt, forKey: Keys.passwordSalt)

        #if DEBUG
        print("🔐 [Auth] Password changed successfully")
        #endif
    }

    /// Resets password for an email account (after biometric verification).
    func resetPassword(email: String, newPassword: String) throws {
        guard let storedEmail = KeychainHelper.readString(forKey: Keys.userEmail) else {
            throw AuthError.noAccountFound
        }

        guard email.lowercased() == storedEmail.lowercased() else {
            throw AuthError.noAccountFound
        }

        let newSalt = generateSalt()
        let newHash = hashPassword(newPassword, salt: newSalt)

        try KeychainHelper.saveString(newHash, forKey: Keys.passwordHash)
        try KeychainHelper.saveString(newSalt, forKey: Keys.passwordSalt)

        #if DEBUG
        print("🔐 [Auth] Password reset for \(email)")
        #endif
    }

    // MARK: - Sign Out & Account Deletion

    /// Signs out the current user. Clears session but preserves credentials.
    func signOut() {
        clearSession()
        #if DEBUG
        print("🔐 [Auth] User signed out")
        #endif
    }

    /// Deletes the account entirely. Clears Keychain and profile.json.
    /// Travel data (backup.json) is NOT affected.
    func deleteAccount() {
        KeychainHelper.deleteAll()
        UserProfile.deleteProfile()
        #if DEBUG
        print("🔐 [Auth] Account deleted (travel data preserved)")
        #endif
    }

    // MARK: - Password Hashing

    private func generateSalt() -> String {
        let saltData = (0..<32).map { _ in UInt8.random(in: 0...255) }
        return Data(saltData).base64EncodedString()
    }

    private func hashPassword(_ password: String, salt: String) -> String {
        let input = password + salt
        guard let data = input.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case noAccountFound
        case invalidCredentials
        case accountAlreadyExists

        var errorDescription: String? {
            switch self {
            case .noAccountFound:
                return "No account found. Please create an account first."
            case .invalidCredentials:
                return "Invalid email or password."
            case .accountAlreadyExists:
                return "An account already exists."
            }
        }
    }
}
