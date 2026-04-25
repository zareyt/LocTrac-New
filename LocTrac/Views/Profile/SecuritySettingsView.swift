// SecuritySettingsView.swift
// LocTrac
// Password change, 2FA toggle, biometric unlock toggle
// v2.0

import SwiftUI

struct SecuritySettingsView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) private var dismiss

    // Change password
    @State private var showingChangePassword = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var passwordError: String?
    @State private var passwordChangeSuccess = false
    @State private var isChangingPassword = false

    // Biometrics
    @State private var biometricEnabled = BiometricService.isBiometricEnabled
    @State private var biometricError: String?

    // 2FA
    @State private var showingTwoFactorSetup = false
    @State private var showingDisable2FAConfirm = false
    @State private var twoFactorEnabled = TOTPService.isEnabled

    private var isEmailAccount: Bool {
        authState.currentAuthProvider == .email
    }

    private var biometricType: BiometricService.BiometricType {
        BiometricService.availableBiometricType()
    }

    private var isPasswordFormValid: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmNewPassword
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Password section (email accounts only)
                    if isEmailAccount {
                        securitySection("PASSWORD") {
                            Button {
                                showingChangePassword = true
                            } label: {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundStyle(Color.accentColor)
                                    Text("Change Password")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Biometrics section
                    securitySection("BIOMETRIC UNLOCK") {
                        VStack(alignment: .leading, spacing: 8) {
                            if biometricType != .none {
                                Toggle(isOn: $biometricEnabled) {
                                    HStack(spacing: 12) {
                                        Image(systemName: biometricType.systemImage)
                                            .font(.title2)
                                            .foregroundStyle(Color.accentColor)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(biometricType.displayName)
                                                .font(.system(size: 16))
                                                .foregroundStyle(.primary)
                                            Text("Quick unlock when returning to the app")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .tint(Color.accentColor)
                                .onChange(of: biometricEnabled) { _, enabled in
                                    toggleBiometric(enabled)
                                }

                                if let error = biometricError {
                                    Text(error)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.red)
                                }
                            } else {
                                HStack(spacing: 12) {
                                    Image(systemName: "faceid")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Biometrics Unavailable")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.secondary)
                                        Text("This device does not support Face ID or Touch ID")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // 2FA section
                    securitySection("TWO-FACTOR AUTHENTICATION") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "shield.checkered")
                                    .font(.title2)
                                    .foregroundStyle(Color.accentColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Authenticator App")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.primary)
                                    Text(twoFactorEnabled ? "Enabled — your account is protected" : "Add an extra layer of security with TOTP")
                                        .font(.system(size: 12))
                                        .foregroundStyle(twoFactorEnabled ? .green : .secondary)
                                }

                                Spacer()

                                if twoFactorEnabled {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundStyle(.green)
                                        .font(.title3)
                                }
                            }

                            if twoFactorEnabled {
                                Button {
                                    showingDisable2FAConfirm = true
                                } label: {
                                    Text("Disable 2FA")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                            } else {
                                Button {
                                    showingTwoFactorSetup = true
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Set Up 2FA")
                                    }
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }

                    // Auth provider info
                    securitySection("ACCOUNT TYPE") {
                        HStack(spacing: 12) {
                            Image(systemName: authState.currentAuthProvider == .apple ? "apple.logo" : "envelope.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(authState.currentAuthProvider == .apple ? "Apple ID" : "Email & Password")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text(authState.currentEmail ?? "")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .sheet(isPresented: $showingChangePassword) {
            changePasswordSheet
        }
        .sheet(isPresented: $showingTwoFactorSetup, onDismiss: {
            twoFactorEnabled = TOTPService.isEnabled
        }) {
            NavigationStack {
                TwoFactorSetupView()
                    .environmentObject(authState)
            }
        }
        .alert("Password Changed", isPresented: $passwordChangeSuccess) {
            Button("OK") {}
        } message: {
            Text("Your password has been updated successfully.")
        }
        .alert("Disable 2FA", isPresented: $showingDisable2FAConfirm) {
            Button("Disable", role: .destructive) {
                disable2FA()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove two-factor authentication from your account. You can set it up again later.")
        }
        .debugViewName("SecuritySettingsView")
    }

    // MARK: - Change Password Sheet

    private var changePasswordSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 16) {
                            passwordField(label: "CURRENT PASSWORD", text: $currentPassword, isSecure: true)
                            passwordField(label: "NEW PASSWORD", text: $newPassword, placeholder: "Minimum 8 characters", isSecure: true)
                            passwordField(label: "CONFIRM NEW PASSWORD", text: $confirmNewPassword, isSecure: true)
                        }
                        .padding(.horizontal, 32)

                        if let error = passwordError {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 32)
                        }

                        Button {
                            changePassword()
                        } label: {
                            Group {
                                if isChangingPassword {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Update Password")
                                }
                            }
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(isPasswordFormValid ? Color.accentColor : Color.accentColor.opacity(0.4))
                            .cornerRadius(12)
                        }
                        .disabled(!isPasswordFormValid || isChangingPassword)
                        .padding(.horizontal, 32)
                    }
                    .padding(.top, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetPasswordFields()
                        showingChangePassword = false
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private func passwordField(label: String, text: Binding<String>, placeholder: String = "", isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .tracking(1.2)

            if isSecure {
                SecureField(placeholder.isEmpty ? label.capitalized : placeholder, text: text)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    )
            }
        }
    }

    private func changePassword() {
        passwordError = nil
        isChangingPassword = true
        Task {
            await authState.changePassword(currentPassword: currentPassword, newPassword: newPassword)
            isChangingPassword = false

            if let error = authState.authError {
                passwordError = error
                authState.clearError()
            } else {
                resetPasswordFields()
                showingChangePassword = false
                passwordChangeSuccess = true
            }
        }
    }

    private func resetPasswordFields() {
        currentPassword = ""
        newPassword = ""
        confirmNewPassword = ""
        passwordError = nil
    }

    // MARK: - Biometric Toggle

    private func toggleBiometric(_ enabled: Bool) {
        biometricError = nil
        if enabled {
            Task {
                do {
                    let success = try await BiometricService.authenticate(reason: "Enable biometric unlock for LocTrac")
                    if success {
                        try BiometricService.enableBiometric()
                        #if DEBUG
                        print("✅ Biometric unlock enabled")
                        #endif
                    } else {
                        biometricEnabled = false
                    }
                } catch {
                    biometricEnabled = false
                    biometricError = error.localizedDescription
                }
            }
        } else {
            do {
                try BiometricService.disableBiometric()
                #if DEBUG
                print("✅ Biometric unlock disabled")
                #endif
            } catch {
                biometricError = error.localizedDescription
            }
        }
    }

    // MARK: - 2FA

    private func disable2FA() {
        do {
            try TOTPService.removeSecret()
            try TOTPService.removeBackupCodes()
            twoFactorEnabled = false
            #if DEBUG
            print("✅ 2FA disabled")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to disable 2FA: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Helpers

    private func securitySection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .tracking(1.5)
                .padding(.horizontal, 8)

            VStack {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
            )
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    NavigationStack {
        SecuritySettingsView()
    }
    .environmentObject(AuthState())
}
