//
//  AuthState.swift
//  LocTrac
//
//  Observable auth state injected via .environmentObject() alongside DataStore.
//  Uses ObservableObject with @Published to match LocTrac's existing pattern.
//

import SwiftUI
import AuthenticationServices

class AuthState: ObservableObject {

    @Published var isAuthenticated: Bool = false
    @Published var currentUser: UserProfile?
    @Published var isLoading: Bool = true
    @Published var authError: String?
    @Published var requiresTwoFactor: Bool = false

    /// Whether the user has dismissed the migration prompt this session.
    @Published var hasDismissedMigrationPrompt: Bool = false

    init() {
        Task {
            await checkSession()
        }
    }

    // MARK: - Session Check

    @MainActor
    func checkSession() async {
        isLoading = true

        let authService = AuthenticationService.shared
        let hasSession = await authService.hasValidSession()

        if hasSession, let profile = UserProfile.load() {
            if profile.signInMethod == .apple {
                let isValid = await authService.validateAppleCredential()
                if isValid {
                    currentUser = profile
                    isAuthenticated = true
                } else {
                    await authService.clearSession()
                    currentUser = nil
                    isAuthenticated = false
                }
            } else {
                currentUser = profile
                isAuthenticated = true
            }
        } else {
            currentUser = nil
            isAuthenticated = false
        }

        isLoading = false

        #if DEBUG
        print("🔐 [AuthState] Session check: authenticated=\(isAuthenticated), user=\(currentUser?.displayName ?? "none")")
        #endif
    }

    // MARK: - Apple Sign-In (from ASAuthorization result)

    @MainActor
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Invalid Apple credential."
                return
            }
            do {
                let profile = try await AuthenticationService.shared.handleAppleSignIn(credential: credential)
                currentUser = profile
                isAuthenticated = true
                authError = nil
            } catch {
                authError = error.localizedDescription
            }
        case .failure(let error):
            // User cancelled is not an error worth showing
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                authError = error.localizedDescription
            }
        }
    }

    // MARK: - Email/Password

    @MainActor
    func signInWithEmail(_ email: String, password: String) async {
        authError = nil
        do {
            let profile = try await AuthenticationService.shared.signInWithEmail(email, password: password)
            currentUser = profile

            // Check if 2FA is enabled — require verification before completing sign-in
            if TOTPService.isEnabled {
                requiresTwoFactor = true
                #if DEBUG
                print("🔐 [AuthState] 2FA required — awaiting verification")
                #endif
            } else {
                isAuthenticated = true
            }
        } catch {
            authError = error.localizedDescription
        }
    }

    @MainActor
    func registerWithEmail(_ email: String, password: String, displayName: String = "") async {
        authError = nil
        let name = displayName.isEmpty ? "LocTrac User" : displayName
        do {
            let profile = try await AuthenticationService.shared.registerWithEmail(email, password: password, displayName: name)
            currentUser = profile
            isAuthenticated = true
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Computed Helpers

    /// The current user's sign-in method, or .none if not signed in.
    var currentAuthProvider: UserProfile.SignInMethod {
        currentUser?.signInMethod ?? .none
    }

    /// The current user's email, if available.
    var currentEmail: String? {
        currentUser?.email
    }

    /// Initials derived from the display name.
    var initials: String {
        guard let name = currentUser?.displayName, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Two-Factor (stub for Phase D)

    @MainActor
    func completeTwoFactorAuth() {
        requiresTwoFactor = false
        isAuthenticated = true
        #if DEBUG
        print("🔐 [AuthState] Two-factor auth completed — user authenticated")
        #endif
    }

    // MARK: - Change Password

    @MainActor
    func changePassword(currentPassword: String, newPassword: String) async {
        authError = nil
        do {
            try await AuthenticationService.shared.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Sign Out & Delete

    @MainActor
    func signOut() async {
        await AuthenticationService.shared.signOut()
        currentUser = nil
        isAuthenticated = false
        authError = nil
        #if DEBUG
        print("🔐 [AuthState] Signed out")
        #endif
    }

    @MainActor
    func deleteAccount() async {
        await AuthenticationService.shared.deleteAccount()
        currentUser = nil
        isAuthenticated = false
        authError = nil
        #if DEBUG
        print("🔐 [AuthState] Account deleted")
        #endif
    }

    // MARK: - Profile Updates

    @MainActor
    func updateProfile(_ profile: UserProfile) {
        currentUser = profile
        try? profile.save()
    }

    @MainActor
    func setError(_ message: String) {
        authError = message
    }

    @MainActor
    func clearError() {
        authError = nil
    }
}
