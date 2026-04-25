// ForgotPasswordView.swift
// LocTrac
// Password reset flow — uses biometric verification since auth is fully local
// v2.0

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authState: AuthState

    @State private var email = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isVerified = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isSubmitting = false

    private var biometricType: BiometricService.BiometricType {
        BiometricService.availableBiometricType()
    }

    private var isResetFormValid: Bool {
        newPassword.count >= 8 && newPassword == confirmPassword
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.accentColor)

                        Text("Reset Password")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.top, 20)

                    if let success = successMessage {
                        // Success state
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green)

                            Text(success)
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Button("Done") {
                                dismiss()
                            }
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentColor)
                            .cornerRadius(12)
                            .padding(.horizontal, 32)
                        }
                    } else if !isVerified {
                        // Step 1: Verify identity
                        identityVerificationSection
                    } else {
                        // Step 2: Set new password
                        newPasswordSection
                    }

                    Spacer(minLength: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(Color.accentColor)
            }
        }
        .debugViewName("ForgotPasswordView")
    }

    // MARK: - Step 1: Identity Verification

    private var identityVerificationSection: some View {
        VStack(spacing: 20) {
            if biometricType != .none {
                // Biometric verification available
                Text("Verify your identity to reset your password.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Email field
                VStack(alignment: .leading, spacing: 6) {
                    Text("ACCOUNT EMAIL")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                        .tracking(1.2)

                    TextField("your@email.com", text: $email)
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        )
                }
                .padding(.horizontal, 32)

                // Biometric verify button
                Button {
                    verifyWithBiometrics()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: biometricType.systemImage)
                        Text("Verify with \(biometricType.displayName)")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(!email.isEmpty ? Color.accentColor : Color.accentColor.opacity(0.4))
                    .cornerRadius(12)
                }
                .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 32)
            } else {
                // No biometrics available
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("Password Reset Unavailable")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("LocTrac stores your credentials securely on this device. To reset your password, you need \(BiometricService.BiometricType.faceID.displayName) or \(BiometricService.BiometricType.touchID.displayName) enabled.\n\nIf you can't remember your password, you can delete your account and create a new one. Your travel data will be preserved.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 24)
                }
                .padding(.horizontal, 16)
            }

            // Error
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Step 2: New Password

    private var newPasswordSection: some View {
        VStack(spacing: 20) {
            Text("Enter your new password.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEW PASSWORD")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                        .tracking(1.2)

                    SecureField("At least 8 characters", text: $newPassword)
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                        .textContentType(.newPassword)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("CONFIRM PASSWORD")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                        .tracking(1.2)

                    SecureField("Re-enter password", text: $confirmPassword)
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                        .textContentType(.newPassword)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        )
                }

                // Validation hints
                VStack(alignment: .leading, spacing: 4) {
                    validationRow("At least 8 characters", met: newPassword.count >= 8)
                    validationRow("Passwords match", met: !confirmPassword.isEmpty && newPassword == confirmPassword)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 32)

            // Error
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Reset button
            Button {
                resetPassword()
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Reset Password")
                    }
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isResetFormValid ? Color.accentColor : Color.accentColor.opacity(0.4))
                .cornerRadius(12)
            }
            .disabled(!isResetFormValid || isSubmitting)
            .padding(.horizontal, 32)
        }
    }

    private func validationRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(met ? .green : .secondary)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(met ? .primary : .secondary)
        }
    }

    // MARK: - Actions

    private func verifyWithBiometrics() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()

        // Verify the account email matches stored email
        guard KeychainHelper.readString(forKey: "user_email")?.lowercased() == trimmedEmail else {
            errorMessage = "No account found with this email."
            return
        }

        Task {
            let success = try? await BiometricService.authenticate(
                reason: "Verify your identity to reset your password"
            )
            if success == true {
                errorMessage = nil
                withAnimation { isVerified = true }
            } else {
                errorMessage = "Biometric verification failed. Please try again."
            }
        }
    }

    private func resetPassword() {
        isSubmitting = true
        errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()

        Task {
            do {
                try await AuthenticationService.shared.resetPassword(email: trimmedEmail, newPassword: newPassword)
                successMessage = "Your password has been reset. You can now sign in with your new password."
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
    .environmentObject(AuthState())
}
