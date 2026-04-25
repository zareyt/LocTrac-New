//
//  TOTPKeychainTests.swift
//  LocTracTests
//
//  Tests for TOTPService, KeychainHelper, and BiometricService.
//  Uses Swift Testing framework.
//

import Testing
@testable import LocTrac
import Foundation

// MARK: - TOTPService Tests

@Suite("TOTPService Tests")
@MainActor
struct TOTPServiceTests {

    @Test("generateSecret returns 20 bytes")
    func generateSecretLength() {
        let secret = TOTPService.generateSecret()
        #expect(secret.count == 20)
    }

    @Test("base32Encode produces only uppercase A-Z and 2-7")
    func base32EncodeCharacterSet() {
        let secret = TOTPService.generateSecret()
        let encoded = TOTPService.base32Encode(secret)
        let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        let encodedCharacters = CharacterSet(charactersIn: encoded)
        #expect(allowedCharacters.isSuperset(of: encodedCharacters))
        #expect(!encoded.isEmpty)
    }

    @Test("otpAuthURI contains required components")
    func otpAuthURIComponents() {
        let secret = TOTPService.generateSecret()
        let email = "test@example.com"
        let uri = TOTPService.otpAuthURI(secret: secret, email: email)

        #expect(uri.contains("otpauth://totp/"))
        #expect(uri.contains("secret="))
        #expect(uri.contains("issuer=LocTrac"))
        #expect(uri.contains("digits=6"))
        #expect(uri.contains("period=30"))
    }

    @Test("generateBackupCodes returns correct count")
    func generateBackupCodesDefaultCount() {
        let codes = TOTPService.generateBackupCodes()
        #expect(codes.count == 8)
    }

    @Test("generateBackupCodes format is XXXX-XXXX digits and dash")
    func generateBackupCodesFormat() {
        let codes = TOTPService.generateBackupCodes(count: 5)
        #expect(codes.count == 5)
        let pattern = /^\d{4}-\d{4}$/
        for code in codes {
            #expect(code.wholeMatch(of: pattern) != nil, "Code '\(code)' does not match XXXX-XXXX format")
        }
    }

    @Test("generateCode returns 6 digits")
    func generateCodeLength() {
        let secret = TOTPService.generateSecret()
        let code = TOTPService.generateCode(secret: secret)
        #expect(code.count == 6)
        #expect(code.allSatisfy(\.isNumber))
    }

    @Test("generateCode is deterministic for same secret and time")
    func generateCodeDeterministic() {
        let secret = TOTPService.generateSecret()
        let fixedTime = Date(timeIntervalSince1970: 1_700_000_000)
        let code1 = TOTPService.generateCode(secret: secret, time: fixedTime)
        let code2 = TOTPService.generateCode(secret: secret, time: fixedTime)
        #expect(code1 == code2)
    }

    @Test("verifyCode accepts current code")
    func verifyCodeAcceptsCurrent() {
        let secret = TOTPService.generateSecret()
        let currentCode = TOTPService.generateCode(secret: secret, time: Date())
        let result = TOTPService.verifyCode(currentCode, secret: secret)
        #expect(result == true)
    }

    @Test("verifyCode rejects random invalid code")
    func verifyCodeRejectsInvalid() {
        let secret = TOTPService.generateSecret()
        let result = TOTPService.verifyCode("000000", secret: secret)
        // While there is an astronomically small chance this could be the actual code,
        // we use a fixed secret to make collision essentially impossible
        let knownSecret = Data(repeating: 0xAB, count: 20)
        let farFutureCode = TOTPService.generateCode(secret: knownSecret, time: Date(timeIntervalSince1970: 9_999_999_999))
        let invalidResult = TOTPService.verifyCode("999999", secret: knownSecret)
        // Use a code from the far future which cannot match +-1 period from now
        #expect(TOTPService.verifyCode(farFutureCode, secret: secret) == false)
    }

    @Test("saveSecret then loadSecret roundtrips")
    func secretRoundtrip() throws {
        let secret = TOTPService.generateSecret()
        try TOTPService.saveSecret(secret)

        let loaded = TOTPService.loadSecret()
        #expect(loaded == secret)

        // Cleanup
        try TOTPService.removeSecret()
        TOTPService.isEnabled = false
    }

    @Test("saveBackupCodes then loadBackupCodes roundtrips")
    func backupCodesRoundtrip() throws {
        let codes = ["1234-5678", "8765-4321", "1111-2222"]
        try TOTPService.saveBackupCodes(codes)

        let loaded = TOTPService.loadBackupCodes()
        #expect(loaded == codes)

        // Cleanup
        try TOTPService.removeBackupCodes()
    }
}

// MARK: - KeychainHelper Tests

@Suite("KeychainHelper Tests")
@MainActor
struct KeychainHelperTests {

    @Test("save and read roundtrip for raw Data")
    func dataRoundtrip() throws {
        let key = "test_\(UUID().uuidString)"
        defer { KeychainHelper.delete(forKey: key) }
        let data = Data("hello keychain".utf8)

        try KeychainHelper.save(data: data, forKey: key)
        let result = KeychainHelper.read(forKey: key)
        #expect(result == data)
    }

    @Test("readString returns nil for nonexistent key")
    func readStringNonexistent() {
        let key = "test_nonexistent_\(UUID().uuidString)"
        let result = KeychainHelper.readString(forKey: key)
        #expect(result == nil)
    }

    @Test("exists returns false for nonexistent key")
    func existsNonexistent() {
        let key = "test_nonexistent_\(UUID().uuidString)"
        #expect(KeychainHelper.exists(forKey: key) == false)
    }

    @Test("saveString and readString roundtrip")
    func stringRoundtrip() throws {
        let key = "test_\(UUID().uuidString)"
        defer { KeychainHelper.delete(forKey: key) }
        let value = "LocTrac test string"

        try KeychainHelper.saveString(value, forKey: key)
        let result = KeychainHelper.readString(forKey: key)
        #expect(result == value)
    }

    @Test("delete removes item")
    func deleteRemovesItem() throws {
        let key = "test_\(UUID().uuidString)"
        try KeychainHelper.saveString("to be deleted", forKey: key)
        #expect(KeychainHelper.exists(forKey: key) == true)

        KeychainHelper.delete(forKey: key)
        #expect(KeychainHelper.exists(forKey: key) == false)
    }

    @Test("saveCodable and readCodable roundtrip")
    func codableRoundtrip() throws {
        struct TestModel: Codable, Equatable {
            let name: String
            let value: Int
        }

        let key = "test_\(UUID().uuidString)"
        defer { KeychainHelper.delete(forKey: key) }
        let model = TestModel(name: "LocTrac", value: 42)

        try KeychainHelper.saveCodable(model, forKey: key)
        let result = KeychainHelper.readCodable(forKey: key, as: TestModel.self)
        #expect(result == model)
    }

    @Test("save overwrites existing value")
    func saveOverwrites() throws {
        let key = "test_\(UUID().uuidString)"
        defer { KeychainHelper.delete(forKey: key) }
        let original = Data("original".utf8)
        let updated = Data("updated".utf8)

        try KeychainHelper.save(data: original, forKey: key)
        #expect(KeychainHelper.read(forKey: key) == original)

        try KeychainHelper.save(data: updated, forKey: key)
        #expect(KeychainHelper.read(forKey: key) == updated)
    }
}

// MARK: - BiometricService Tests

@Suite("BiometricService Tests")
@MainActor
struct BiometricServiceTests {

    @Test("BiometricType displayName values are correct")
    func displayNames() {
        #expect(BiometricService.BiometricType.faceID.displayName == "Face ID")
        #expect(BiometricService.BiometricType.touchID.displayName == "Touch ID")
        #expect(BiometricService.BiometricType.none.displayName == "None")
    }

    @Test("BiometricType systemImage values are correct")
    func systemImages() {
        #expect(BiometricService.BiometricType.faceID.systemImage == "faceid")
        #expect(BiometricService.BiometricType.touchID.systemImage == "touchid")
        #expect(BiometricService.BiometricType.none.systemImage == "lock")
    }

    @Test("enableBiometric sets isEnabled to true")
    func enableBiometric() throws {
        // Reset state first
        BiometricService.isEnabled = false

        try BiometricService.enableBiometric()
        #expect(BiometricService.isEnabled == true)

        // Cleanup
        BiometricService.isEnabled = false
    }

    @Test("disableBiometric sets isEnabled to false")
    func disableBiometric() throws {
        // Set enabled first
        BiometricService.isEnabled = true

        try BiometricService.disableBiometric()
        #expect(BiometricService.isEnabled == false)
    }

    @Test("isBiometricEnabled is alias for isEnabled")
    func isBiometricEnabledAlias() {
        BiometricService.isEnabled = true
        #expect(BiometricService.isBiometricEnabled == true)

        BiometricService.isEnabled = false
        #expect(BiometricService.isBiometricEnabled == false)

        BiometricService.isBiometricEnabled = true
        #expect(BiometricService.isEnabled == true)

        // Cleanup
        BiometricService.isEnabled = false
    }
}
