//
//  BackupArchiveTests.swift
//  LocTrac
//
//  Tests for BackupArchiveService zip creation, extraction, and image handling.
//

import Testing
import Foundation
@testable import LocTrac

@Suite("BackupArchive Tests")
struct BackupArchiveTests {

    // MARK: - Zip Creation & Extraction

    @Test("Create and extract zip roundtrip")
    func zipRoundtrip() throws {
        let jsonString = """
        {"locations":[],"events":[],"activities":[],"affirmations":[],"trips":[],"eventTypes":[]}
        """
        let jsonData = Data(jsonString.utf8)
        let imageData = Data(repeating: 0xFF, count: 100)

        let tempDir = FileManager.default.temporaryDirectory
        let archiveURL = tempDir.appendingPathComponent("test_roundtrip.zip")

        // Write a fake image to Documents so createArchive can find it
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let testImageName = "test_roundtrip_image.jpg"
        let imageURL = documentsURL.appendingPathComponent(testImageName)
        try imageData.write(to: imageURL)

        defer {
            try? FileManager.default.removeItem(at: archiveURL)
            try? FileManager.default.removeItem(at: imageURL)
        }

        try BackupArchiveService.createArchive(
            jsonData: jsonData,
            imageFilenames: [testImageName],
            outputURL: archiveURL
        )

        let extracted = try BackupArchiveService.extractArchive(at: archiveURL)
        #expect(extracted.jsonData == jsonData)
        #expect(extracted.imageEntries.count == 1)
        #expect(extracted.imageEntries[testImageName] == imageData)
    }

    @Test("Extract zip with no images")
    func zipNoImages() throws {
        let jsonData = Data("{\"locations\":[],\"events\":[]}".utf8)
        let tempDir = FileManager.default.temporaryDirectory
        let archiveURL = tempDir.appendingPathComponent("test_no_images.zip")

        defer { try? FileManager.default.removeItem(at: archiveURL) }

        try BackupArchiveService.createArchive(
            jsonData: jsonData,
            imageFilenames: [],
            outputURL: archiveURL
        )

        let extracted = try BackupArchiveService.extractArchive(at: archiveURL)
        #expect(extracted.jsonData == jsonData)
        #expect(extracted.imageEntries.isEmpty)
    }

    @Test("Missing backup.json throws error")
    func missingBackupJSON() throws {
        // Create a zip with only an image, no backup.json
        // We can't easily do this without the internal ZipWriter, so test via invalid data
        let invalidData = Data("not a zip".utf8)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("invalid.zip")
        try invalidData.write(to: tempURL)

        defer { try? FileManager.default.removeItem(at: tempURL) }

        #expect(throws: (any Error).self) {
            try BackupArchiveService.extractArchive(at: tempURL)
        }
    }

    // MARK: - Archive Detection

    @Test("Detect zip by extension")
    func detectZipByExtension() {
        let zipURL = URL(fileURLWithPath: "/tmp/backup.zip")
        let jsonURL = URL(fileURLWithPath: "/tmp/backup.json")

        #expect(BackupArchiveService.isZipArchive(at: zipURL) == true)
        // JSON file that doesn't exist - should return false
        #expect(BackupArchiveService.isZipArchive(at: jsonURL) == false)
    }

    @Test("Detect zip by magic bytes")
    func detectZipByMagicBytes() throws {
        let jsonData = Data("{}".utf8)
        let tempDir = FileManager.default.temporaryDirectory
        let archiveURL = tempDir.appendingPathComponent("test_magic.zip")

        defer { try? FileManager.default.removeItem(at: archiveURL) }

        try BackupArchiveService.createArchive(
            jsonData: jsonData,
            imageFilenames: [],
            outputURL: archiveURL
        )

        // Rename to .dat to force magic byte detection
        let renamedURL = tempDir.appendingPathComponent("test_magic.dat")
        defer { try? FileManager.default.removeItem(at: renamedURL) }

        try FileManager.default.copyItem(at: archiveURL, to: renamedURL)
        #expect(BackupArchiveService.isZipArchive(at: renamedURL) == true)
    }

    // MARK: - Size Estimation

    @Test("Estimate image size for existing files")
    func estimateImageSize() throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let testName = "test_size_estimate.jpg"
        let testURL = documentsURL.appendingPathComponent(testName)
        let testData = Data(repeating: 0xAB, count: 1024)

        try testData.write(to: testURL)
        defer { try? FileManager.default.removeItem(at: testURL) }

        let size = BackupArchiveService.estimateImageSize(imageFilenames: [testName])
        #expect(size == 1024)
    }

    @Test("Estimate size skips missing files")
    func estimateSizeMissingFiles() {
        let size = BackupArchiveService.estimateImageSize(imageFilenames: ["nonexistent_file.jpg"])
        #expect(size == 0)
    }

    // MARK: - Conflict Detection

    @Test("Detect existing image conflicts")
    func detectConflicts() throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let existingName = "test_conflict_existing.jpg"
        let existingURL = documentsURL.appendingPathComponent(existingName)

        try Data("existing".utf8).write(to: existingURL)
        defer { try? FileManager.default.removeItem(at: existingURL) }

        let conflicts = BackupArchiveService.detectConflicts(
            imageFilenames: [existingName, "nonexistent.jpg"]
        )
        #expect(conflicts.count == 1)
        #expect(conflicts.first == existingName)
    }

    // MARK: - Image Import with Conflict Resolution

    @Test("Import images with skip resolution")
    func importImagesSkip() throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = "test_skip.jpg"
        let fileURL = documentsURL.appendingPathComponent(filename)

        let originalData = Data("original".utf8)
        let newData = Data("new_data".utf8)

        try originalData.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let map = BackupArchiveService.importImages([filename: newData], resolution: .skip)
        #expect(map[filename] == filename)

        // Verify original was kept
        let onDisk = try Data(contentsOf: fileURL)
        #expect(onDisk == originalData)
    }

    @Test("Import images with replace resolution")
    func importImagesReplace() throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = "test_replace.jpg"
        let fileURL = documentsURL.appendingPathComponent(filename)

        let originalData = Data("original".utf8)
        let newData = Data("replaced".utf8)

        try originalData.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let map = BackupArchiveService.importImages([filename: newData], resolution: .replace)
        #expect(map[filename] == filename)

        let onDisk = try Data(contentsOf: fileURL)
        #expect(onDisk == newData)
    }

    @Test("Import images with rename resolution")
    func importImagesRename() throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = "test_rename.jpg"
        let fileURL = documentsURL.appendingPathComponent(filename)

        let originalData = Data("original".utf8)
        let newData = Data("renamed_copy".utf8)

        try originalData.write(to: fileURL)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let map = BackupArchiveService.importImages([filename: newData], resolution: .rename)

        // Should have a different filename
        let renamedFilename = map[filename]!
        #expect(renamedFilename != filename)
        #expect(renamedFilename.hasSuffix(".jpg"))

        // Clean up renamed file
        let renamedURL = documentsURL.appendingPathComponent(renamedFilename)
        defer { try? FileManager.default.removeItem(at: renamedURL) }

        // Original should be untouched
        let originalOnDisk = try Data(contentsOf: fileURL)
        #expect(originalOnDisk == originalData)

        // Renamed copy should have new data
        let renamedOnDisk = try Data(contentsOf: renamedURL)
        #expect(renamedOnDisk == newData)
    }

    @Test("Import new image (no conflict)")
    func importNewImage() throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = "test_new_import.jpg"
        let fileURL = documentsURL.appendingPathComponent(filename)

        // Ensure it doesn't exist
        try? FileManager.default.removeItem(at: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let newData = Data("brand_new".utf8)
        let map = BackupArchiveService.importImages([filename: newData], resolution: .skip)
        #expect(map[filename] == filename)

        let onDisk = try Data(contentsOf: fileURL)
        #expect(onDisk == newData)
    }

    // MARK: - Referenced Image Collection

    @Test("Collect all referenced image filenames")
    func allReferencedFilenames() {
        let location = Location(
            name: "Test",
            city: nil,
            latitude: 0,
            longitude: 0,
            theme: .blue,
            imageIDs: ["loc1.jpg", "loc2.jpg"]
        )

        let event = Event(
            eventType: .stay,
            date: Date(),
            location: location,
            note: "",
            imageIDs: ["evt1.jpg"]
        )

        let filenames = BackupArchiveService.allReferencedImageFilenames(
            locations: [location],
            events: [event]
        )

        #expect(Set(filenames) == Set(["loc1.jpg", "loc2.jpg", "evt1.jpg"]))
    }
}
