// ProfileView.swift
// LocTrac
// Account hub — shows profile info when signed in, sign-in prompt when not
// v2.0

import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject var authState: AuthState

    @State private var showingEditProfile = false
    @State private var showingPreferences = false
    @State private var showingSecurity = false
    @State private var showingSignIn = false
    @State private var showingSignUp = false
    @State private var showingDeleteConfirm = false
    @State private var showingSignOutConfirm = false
    @State private var showingNotifications = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if authState.isAuthenticated {
                        signedInContent
                    } else {
                        signedOutContent
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            NavigationStack {
                EditProfileView()
                    .environmentObject(authState)
            }
        }
        .sheet(isPresented: $showingPreferences) {
            NavigationStack {
                PreferencesView()
                    .environmentObject(authState)
            }
        }
        .sheet(isPresented: $showingSecurity) {
            NavigationStack {
                SecuritySettingsView()
                    .environmentObject(authState)
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationSettingsView()
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
        .alert("Sign Out", isPresented: $showingSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Task { await authState.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data will remain on this device. You can sign back in anytime.")
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    await authState.deleteAccount()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your account credentials. Your travel data will be preserved.")
        }
        .debugViewName("ProfileView")
    }

    // MARK: - Signed In Content

    @ViewBuilder
    private var signedInContent: some View {
        // Avatar & name
        VStack(spacing: 12) {
            if let photoData = authState.currentUser?.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.accentColor.opacity(0.3), lineWidth: 2))
            } else {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .overlay {
                        Text(authState.initials)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
            }

            Text(authState.currentUser?.displayName ?? "Traveler")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                Image(systemName: authState.currentAuthProvider == .apple ? "apple.logo" : "envelope.fill")
                    .font(.system(size: 13))
                Text(authState.currentEmail ?? "")
                    .font(.system(size: 14))
            }
            .foregroundStyle(.secondary)
        }

        // Menu sections
        VStack(spacing: 2) {
            profileSectionHeader("ACCOUNT")

            ProfileMenuButton(icon: "person.circle", title: "Edit Profile") {
                showingEditProfile = true
            }
            ProfileMenuButton(icon: "gearshape", title: "Preferences") {
                showingPreferences = true
            }
            ProfileMenuButton(icon: "lock.shield", title: "Security") {
                showingSecurity = true
            }
            ProfileMenuButton(icon: "bell.fill", title: "Notifications") {
                showingNotifications = true
            }
        }
        .padding(.horizontal, 24)

        // Sign out / delete
        VStack(spacing: 12) {
            Button {
                showingSignOutConfirm = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                )
            }

            Button {
                showingDeleteConfirm = true
            } label: {
                Text("Delete Account")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
    }

    // MARK: - Signed Out Content

    @ViewBuilder
    private var signedOutContent: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 100, height: 100)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.accentColor)
                }

            Text("Traveler")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)

            Text("Sign in to manage your profile,\npreferences, and security settings")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }

        VStack(spacing: 14) {
            // Apple Sign-In
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

        // Settings available without sign-in
        VStack(spacing: 2) {
            profileSectionHeader("SETTINGS")

            ProfileMenuButton(icon: "bell.fill", title: "Notifications") {
                showingNotifications = true
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func profileSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .tracking(1.5)
            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
        .padding(.horizontal, 8)
    }
}

// MARK: - Profile Menu Button

struct ProfileMenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Signed Out") {
    ProfileView()
        .environmentObject(AuthState())
}
