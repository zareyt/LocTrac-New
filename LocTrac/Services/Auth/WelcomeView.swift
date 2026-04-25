// WelcomeView.swift
// LocTrac
// Optional first-launch sign-in screen
// v2.0

import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @EnvironmentObject var authState: AuthState

    var onSkip: () -> Void

    @State private var showingSignIn = false
    @State private var showingSignUp = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Hero
                VStack(spacing: 16) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(Color.accentColor)

                    Text("LocTrac")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color.accentColor)

                    Text("Your personal travel journal\nand adventure companion")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                // Auth buttons
                VStack(spacing: 14) {
                    // Sign In with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        Task {
                            await authState.handleAppleSignIn(result: result)
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)

                    // Email sign in
                    Button {
                        showingSignIn = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Sign In with Email")
                        }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }

                    // Create account
                    Button {
                        showingSignUp = true
                    } label: {
                        Text("Create Account")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentColor, lineWidth: 2)
                            )
                    }
                }
                .padding(.horizontal, 32)

                // Skip
                Button {
                    #if DEBUG
                    print("🔘 User skipped sign-in")
                    #endif
                    onSkip()
                } label: {
                    Text("Skip for Now")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)
                }

                Spacer()
                    .frame(height: 40)
            }
        }
        .sheet(isPresented: $showingSignIn) {
            NavigationStack {
                SignInView()
                    .environmentObject(authState)
            }
        }
        .sheet(isPresented: $showingSignUp) {
            NavigationStack {
                SignUpView()
                    .environmentObject(authState)
            }
        }
        // Error alert
        .alert("Sign-In Error", isPresented: .init(
            get: { authState.authError != nil },
            set: { if !$0 { authState.authError = nil } }
        )) {
            Button("OK") { authState.authError = nil }
        } message: {
            if let error = authState.authError {
                Text(error)
            }
        }
        .debugViewName("WelcomeView")
    }
}

#Preview {
    WelcomeView(onSkip: {})
        .environmentObject(AuthState())
}
