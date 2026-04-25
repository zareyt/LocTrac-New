//
//  BiometricService.swift
//  LocTrac
//
//  Face ID / Touch ID via LocalAuthentication framework.
//  Stub implementation — full logic will be added in Phase D.
//

import Foundation
import LocalAuthentication

struct BiometricService {

    enum BiometricType {
        case faceID
        case touchID
        case none

        var displayName: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .none: return "None"
            }
        }

        var systemImage: String {
            switch self {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .none: return "lock"
            }
        }
    }

    /// Returns the available biometric type on this device.
    static func availableBiometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .none
        }
    }

    /// Whether biometrics are available on this device.
    static var isAvailable: Bool {
        availableBiometricType() != .none
    }

    /// Whether the user has enabled biometric unlock for LocTrac.
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "biometric_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "biometric_enabled") }
    }

    /// Alias for isEnabled (used by SecuritySettingsView).
    static var isBiometricEnabled: Bool {
        get { isEnabled }
        set { isEnabled = newValue }
    }

    /// Authenticates the user with biometrics.
    static func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Password"

        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }

    /// Enables biometric unlock after successful authentication.
    static func enableBiometric() throws {
        isEnabled = true
        #if DEBUG
        print("🔐 [Biometric] Biometric unlock enabled")
        #endif
    }

    /// Disables biometric unlock.
    static func disableBiometric() throws {
        isEnabled = false
        #if DEBUG
        print("🔐 [Biometric] Biometric unlock disabled")
        #endif
    }
}
