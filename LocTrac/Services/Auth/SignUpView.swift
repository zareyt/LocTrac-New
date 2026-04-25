// SignUpView.swift
// LocTrac
// Email + password registration view
// v2.0

import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSubmitting = false
    @State private var showPassword = false

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
        && password.count >= 8
        && passwordsMatch
    }

    private var passwordStrengthMessage: String? {
        if password.isEmpty { return nil }
        if password.count < 8 { return "Must be at least 8 characters" }
        if !confirmPassword.isEmpty && !passwordsMatch { return "Passwords do not match" }
        return nil
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.accentColor)

                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.accentColor)

                        Text("Start tracking your travels")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Form fields
                    VStack(spacing: 16) {
                        // Display Name (optional)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("DISPLAY NAME")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.accentColor)
                                    .tracking(1.2)
                                Text("optional")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }

                            TextField("Your name", text: $displayName)
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                                .textContentType(.name)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.white)
                                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                                )
                        }

                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EMAIL")
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

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PASSWORD")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.accentColor)
                                .tracking(1.2)

                            HStack {
                                if showPassword {
                                    TextField("Minimum 8 characters", text: $password)
                                        .font(.system(size: 16))
                                        .textContentType(.newPassword)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("Minimum 8 characters", text: $password)
                                        .font(.system(size: 16))
                                        .textContentType(.newPassword)
                                        .textInputAutocapitalization(.never)
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 16))
                                }
                            }
                            .foregroundStyle(.primary)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                            )
                        }

                        // Confirm Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CONFIRM PASSWORD")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.accentColor)
                                .tracking(1.2)

                            SecureField("Re-enter password", text: $confirmPassword)
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                                .textContentType(.newPassword)
                                .textInputAutocapitalization(.never)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.white)
                                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                                )
                        }

                        // Validation feedback
                        if let message = passwordStrengthMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 12))
                                Text(message)
                                    .font(.system(size: 13))
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 32)

                    // Error message
                    if let error = authState.authError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Create Account button
                    Button {
                        createAccount()
                    } label: {
                        Group {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                            }
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isFormValid ? Color.accentColor : Color.accentColor.opacity(0.4))
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isSubmitting)
                    .padding(.horizontal, 32)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                        Text("or")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 40)

                    // Apple Sign-Up
                    SignInWithAppleButton(.signUp) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        Task {
                            await authState.handleAppleSignIn(result: result)
                            if authState.isAuthenticated {
                                dismiss()
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)

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
        .onChange(of: authState.isAuthenticated) { _, isAuth in
            if isAuth { dismiss() }
        }
        .debugViewName("SignUpView")
    }

    private func createAccount() {
        isSubmitting = true
        Task {
            await authState.registerWithEmail(
                email.trimmingCharacters(in: .whitespaces),
                password: password,
                displayName: displayName
            )
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
    .environmentObject(AuthState())
}
