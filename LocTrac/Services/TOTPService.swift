//
//  TOTPService.swift
//  LocTrac
//
//  TOTP generation and verification using CryptoKit.
//  Stub implementation — full logic will be added in Phase D.
//

import Foundation
import CryptoKit

struct TOTPService {

    private static let secretKey = "totp_secret"
    private static let backupCodesKey = "totp_backup_codes"

    /// Whether 2FA is currently enabled for the user.
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "totp_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "totp_enabled") }
    }

    // MARK: - Secret Generation

    /// Generates a new TOTP secret as raw Data for setup.
    static func generateSecret() -> Data {
        let bytes = (0..<20).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes)
    }

    /// Base32-encodes a secret for manual entry in authenticator apps.
    static func base32Encode(_ data: Data) -> String {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let chars = Array(alphabet)
        var result = ""
        var buffer: UInt64 = 0
        var bitsLeft = 0

        for byte in data {
            buffer = (buffer << 8) | UInt64(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                let index = Int((buffer >> (bitsLeft - 5)) & 0x1F)
                result.append(chars[index])
                bitsLeft -= 5
            }
        }
        if bitsLeft > 0 {
            let index = Int((buffer << (5 - bitsLeft)) & 0x1F)
            result.append(chars[index])
        }
        return result
    }

    /// Generates an otpauth:// URI for QR code generation.
    static func otpAuthURI(secret: Data, email: String) -> String {
        let base32 = base32Encode(secret)
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        return "otpauth://totp/LocTrac:\(encodedEmail)?secret=\(base32)&issuer=LocTrac&digits=6&period=30"
    }

    // MARK: - Backup Codes

    /// Generates backup codes for account recovery.
    static func generateBackupCodes(count: Int = 8) -> [String] {
        return (0..<count).map { _ in
            let part1 = String(format: "%04d", Int.random(in: 0..<10000))
            let part2 = String(format: "%04d", Int.random(in: 0..<10000))
            return "\(part1)-\(part2)"
        }
    }

    // MARK: - Persistence (Keychain)

    /// Saves the TOTP secret to Keychain.
    static func saveSecret(_ secret: Data) throws {
        try KeychainHelper.save(data: secret, forKey: secretKey)
        isEnabled = true
        #if DEBUG
        print("🔐 [TOTP] Secret saved to Keychain")
        #endif
    }

    /// Loads the TOTP secret from Keychain.
    static func loadSecret() -> Data? {
        return KeychainHelper.read(forKey: secretKey)
    }

    /// Removes the TOTP secret from Keychain.
    static func removeSecret() throws {
        KeychainHelper.delete(forKey: secretKey)
        isEnabled = false
        #if DEBUG
        print("🔐 [TOTP] Secret removed from Keychain")
        #endif
    }

    /// Saves backup codes to Keychain as JSON.
    static func saveBackupCodes(_ codes: [String]) throws {
        let data = try JSONEncoder().encode(codes)
        try KeychainHelper.save(data: data, forKey: backupCodesKey)
        #if DEBUG
        print("🔐 [TOTP] Backup codes saved (\(codes.count) codes)")
        #endif
    }

    /// Loads backup codes from Keychain.
    static func loadBackupCodes() -> [String] {
        guard let data = KeychainHelper.read(forKey: backupCodesKey),
              let codes = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return codes
    }

    /// Removes backup codes from Keychain.
    static func removeBackupCodes() throws {
        KeychainHelper.delete(forKey: backupCodesKey)
        #if DEBUG
        print("🔐 [TOTP] Backup codes removed")
        #endif
    }

    // MARK: - TOTP Generation (RFC 6238)

    /// Generates the current TOTP code for a given secret.
    static func generateCode(secret: Data, time: Date = Date(), period: Int = 30, digits: Int = 6) -> String {
        let counter = UInt64(time.timeIntervalSince1970) / UInt64(period)

        // Convert counter to big-endian 8-byte array
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: 8)

        // HMAC-SHA1
        let key = SymmetricKey(data: secret)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let hmacBytes = Array(hmac)

        // Dynamic truncation
        let offset = Int(hmacBytes[hmacBytes.count - 1] & 0x0F)
        let truncated = (UInt32(hmacBytes[offset]) & 0x7F) << 24
            | UInt32(hmacBytes[offset + 1]) << 16
            | UInt32(hmacBytes[offset + 2]) << 8
            | UInt32(hmacBytes[offset + 3])

        let otp = truncated % UInt32(pow(10, Float(digits)))
        return String(format: "%0\(digits)d", otp)
    }

    // MARK: - Verification

    /// Verifies a TOTP code against a given secret.
    /// Allows a 1-period window in each direction to account for clock drift.
    static func verifyCode(_ code: String, secret: Data) -> Bool {
        guard code.count == 6, code.allSatisfy(\.isNumber) else { return false }

        let now = Date()
        let period: TimeInterval = 30

        // Check current period and +/- 1 period for clock drift
        for offset in -1...1 {
            let checkTime = now.addingTimeInterval(TimeInterval(offset) * period)
            let expected = generateCode(secret: secret, time: checkTime)
            if code == expected {
                #if DEBUG
                print("🔐 [TOTP] Code verified (offset: \(offset))")
                #endif
                return true
            }
        }

        #if DEBUG
        print("🔐 [TOTP] Code verification failed")
        #endif
        return false
    }

    /// Uses a backup code (removes it from the stored list if valid).
    static func useBackupCode(_ code: String) -> Bool {
        var codes = loadBackupCodes()
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard let index = codes.firstIndex(of: trimmed) else {
            return false
        }
        codes.remove(at: index)
        if let data = try? JSONEncoder().encode(codes) {
            try? KeychainHelper.save(data: data, forKey: backupCodesKey)
        }
        #if DEBUG
        print("🔐 [TOTP] Backup code used, \(codes.count) remaining")
        #endif
        return true
    }
}
