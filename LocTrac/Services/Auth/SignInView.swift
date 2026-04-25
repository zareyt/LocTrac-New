// SignInView.swift
// LocTrac
// Email + password login view with Apple Sign-In option
// v2.0

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var showPassword = false
    @State private var showingTwoFactor = false
    @State private var showingForgotPassword = false

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && password.count >= 8
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.accentColor)

                        Text("Sign In")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.accentColor)

                        Text("Welcome back to LocTrac")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Form fields
                    VStack(spacing: 16) {
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
                                    TextField("Password", text: $password)
                                        .font(.system(size: 16))
                                        .textContentType(.password)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("Password", text: $password)
                                        .font(.system(size: 16))
                                        .textContentType(.password)
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

                    // Sign In button
                    Button {
                        signIn()
                    } label: {
                        Group {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
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

                    // Forgot password
                    Button {
                        showingForgotPassword = true
                    } label: {
                        Text("Forgot Password?")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.accentColor)
                    }

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

                    // Apple Sign-In
                    SignInWithAppleButton(.signIn) { request in
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
        .onChange(of: authState.requiresTwoFactor) { _, requires2FA in
            if requires2FA { showingTwoFactor = true }
        }
        .sheet(isPresented: $showingForgotPassword) {
            NavigationStack {
                ForgotPasswordView()
                    .environmentObject(authState)
            }
        }
        .sheet(isPresented: $showingTwoFactor) {
            NavigationStack {
                TwoFactorVerifyView {
                    authState.completeTwoFactorAuth()
                    showingTwoFactor = false
                }
            }
        }
        .debugViewName("SignInView")
    }

    private func signIn() {
        isSubmitting = true
        Task {
            await authState.signInWithEmail(email.trimmingCharacters(in: .whitespaces), password: password)
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationStack {
        SignInView()
    }
    .environmentObject(AuthState())
}
