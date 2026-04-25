// BiometricLockView.swift
// LocTrac
// Lock screen overlay shown when biometric unlock is enabled
// v2.0

import SwiftUI

struct BiometricLockView: View {
    @Binding var isLocked: Bool

    @State private var errorMessage: String?

    private var biometricType: BiometricService.BiometricType {
        BiometricService.availableBiometricType()
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.accentColor)

                Text("LocTrac is Locked")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Tap to unlock with \(biometricType.displayName)")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    unlock()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: biometricType.systemImage)
                        Text("Unlock")
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 48)

                Spacer()
            }
        }
        .transition(.opacity)
        .debugViewName("BiometricLockView")
    }

    private func unlock() {
        errorMessage = nil
        Task {
            do {
                let success = try await BiometricService.authenticate(
                    reason: "Unlock LocTrac"
                )
                if success {
                    await MainActor.run {
                        withAnimation {
                            isLocked = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Authentication failed. Tap to try again."
                }
            }
        }
    }
}

#Preview {
    BiometricLockView(isLocked: .constant(true))
}
