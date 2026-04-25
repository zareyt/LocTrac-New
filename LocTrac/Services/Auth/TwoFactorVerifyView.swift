// TwoFactorVerifyView.swift
// LocTrac
// TOTP code entry screen shown during login when 2FA is enabled
// v2.0

import SwiftUI

struct TwoFactorVerifyView: View {
    @Environment(\.dismiss) private var dismiss

    var onVerified: () -> Void

    @State private var code = ""
    @State private var errorMessage: String?
    @State private var isVerifying = false
    @State private var showingBackupEntry = false
    @State private var backupCode = ""

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "shield.checkered")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)

                Text("Two-Factor Authentication")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.accentColor)

                Text("Enter the 6-digit code from\nyour authenticator app")
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                // Code entry
                TextField("000000", text: $code)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 220)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    )
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.filter(\.isNumber).prefix(6))
                        if code.count == 6 {
                            verify()
                        }
                    }

                // Error
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                // Verify button
                Button {
                    verify()
                } label: {
                    Group {
                        if isVerifying {
                            ProgressView().tint(.white)
                        } else {
                            Text("Verify")
                        }
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(code.count == 6 ? Color.accentColor : Color.accentColor.opacity(0.4))
                    .cornerRadius(12)
                }
                .disabled(code.count != 6 || isVerifying)
                .padding(.horizontal, 32)

                Spacer()

                // Backup code option
                Button {
                    showingBackupEntry = true
                } label: {
                    Text("Use a backup code instead")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 32)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color.accentColor)
            }
        }
        .alert("Enter Backup Code", isPresented: $showingBackupEntry) {
            TextField("XXXX-XXXX", text: $backupCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {
                backupCode = ""
            }
            Button("Verify") {
                verifyBackupCode()
            }
        } message: {
            Text("Enter one of your backup codes. Each code can only be used once.")
        }
        .debugViewName("TwoFactorVerifyView")
    }

    private func verify() {
        errorMessage = nil
        isVerifying = true

        guard let secret = TOTPService.loadSecret() else {
            errorMessage = "2FA configuration error. Please contact support."
            isVerifying = false
            return
        }

        if TOTPService.verifyCode(code, secret: secret) {
            #if DEBUG
            print("✅ 2FA verification successful")
            #endif
            isVerifying = false
            onVerified()
        } else {
            errorMessage = "Invalid code. Please try again."
            code = ""
            isVerifying = false
        }
    }

    private func verifyBackupCode() {
        if TOTPService.useBackupCode(backupCode) {
            #if DEBUG
            print("✅ Backup code accepted")
            #endif
            backupCode = ""
            onVerified()
        } else {
            errorMessage = "Invalid backup code."
            backupCode = ""
        }
    }
}

#Preview {
    NavigationStack {
        TwoFactorVerifyView(onVerified: {})
    }
}
