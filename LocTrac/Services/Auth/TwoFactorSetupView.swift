// TwoFactorSetupView.swift
// LocTrac
// TOTP setup — shows secret key, QR URI, and backup codes
// v2.0

import SwiftUI
import CoreImage.CIFilterBuiltins

struct TwoFactorSetupView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) private var dismiss

    @State private var secret: Data?
    @State private var backupCodes: [String] = []
    @State private var verificationCode = ""
    @State private var verificationError: String?
    @State private var step: SetupStep = .showQR
    @State private var copiedBackupCodes = false

    enum SetupStep {
        case showQR
        case verify
        case showBackupCodes
        case done
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    switch step {
                    case .showQR:
                        qrStep
                    case .verify:
                        verifyStep
                    case .showBackupCodes:
                        backupCodesStep
                    case .done:
                        doneStep
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Set Up 2FA")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if step != .done {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .onAppear {
            if secret == nil {
                secret = TOTPService.generateSecret()
            }
        }
        .interactiveDismissDisabled(step == .showBackupCodes)
        .debugViewName("TwoFactorSetupView")
    }

    // MARK: - Step 1: Show QR Code

    private var qrStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 50))
                .foregroundStyle(Color.accentColor)

            Text("Scan QR Code")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.accentColor)

            Text("Open your authenticator app (Google Authenticator, 1Password, etc.) and scan this QR code.")
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            // QR Code
            if let secret, let email = authState.currentEmail {
                let uri = TOTPService.otpAuthURI(secret: secret, email: email)
                if let qrImage = generateQRCode(from: uri) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        )
                }

                // Manual entry key
                VStack(spacing: 6) {
                    Text("Or enter this key manually:")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Text(TOTPService.base32Encode(secret))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.06))
                        )
                }
            }

            Button {
                step = .verify
            } label: {
                Text("Next")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Step 2: Verify Code

    private var verifyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "number.circle")
                .font(.system(size: 50))
                .foregroundStyle(Color.accentColor)

            Text("Enter Verification Code")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.accentColor)

            Text("Enter the 6-digit code from your authenticator app to confirm setup.")
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            TextField("000000", text: $verificationCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .frame(maxWidth: 200)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
                .onChange(of: verificationCode) { _, newValue in
                    verificationCode = String(newValue.filter(\.isNumber).prefix(6))
                }

            if let error = verificationError {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
            }

            Button {
                verifyAndActivate()
            } label: {
                Text("Verify & Activate")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(verificationCode.count == 6 ? Color.accentColor : Color.accentColor.opacity(0.4))
                    .cornerRadius(12)
            }
            .disabled(verificationCode.count != 6)

            Button {
                step = .showQR
            } label: {
                Text("Back to QR Code")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: - Step 3: Backup Codes

    private var backupCodesStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 50))
                .foregroundStyle(Color.accentColor)

            Text("Save Backup Codes")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.accentColor)

            Text("Store these codes in a safe place. Each code can only be used once if you lose access to your authenticator app.")
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            // Backup codes grid
            VStack(spacing: 8) {
                ForEach(backupCodes, id: \.self) { code in
                    Text(code)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
            )

            // Copy button
            Button {
                let codesText = backupCodes.joined(separator: "\n")
                UIPasteboard.general.string = codesText
                copiedBackupCodes = true
            } label: {
                HStack {
                    Image(systemName: copiedBackupCodes ? "checkmark" : "doc.on.clipboard")
                    Text(copiedBackupCodes ? "Copied!" : "Copy Codes")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                )
            }

            Button {
                step = .done
            } label: {
                Text("I've Saved My Codes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Step 4: Done

    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("2FA Enabled")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.accentColor)

            Text("Your account is now protected with two-factor authentication.")
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Actions

    private func verifyAndActivate() {
        guard let secret else { return }
        verificationError = nil

        if TOTPService.verifyCode(verificationCode, secret: secret) {
            do {
                try TOTPService.saveSecret(secret)
                backupCodes = TOTPService.generateBackupCodes()
                try TOTPService.saveBackupCodes(backupCodes)
                step = .showBackupCodes
                #if DEBUG
                print("✅ 2FA activated successfully")
                #endif
            } catch {
                verificationError = "Failed to save 2FA settings: \(error.localizedDescription)"
            }
        } else {
            verificationError = "Invalid code. Please try again."
        }
    }

    // MARK: - QR Code Generation

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = 10.0
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    NavigationStack {
        TwoFactorSetupView()
    }
    .environmentObject(AuthState())
}
