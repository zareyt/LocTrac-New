//
//  BackupArchiveService.swift
//  LocTrac
//
//  v2.0: Creates and extracts .zip backup archives containing
//  backup.json + images/ folder for photo-inclusive exports.
//

import Foundation
import zlib

// MARK: - BackupArchiveService

enum BackupArchiveService {

    // MARK: - Archive Creation

    /// Creates a .zip archive containing backup.json and referenced image files.
    /// - Parameters:
    ///   - jsonData: The backup.json data
    ///   - imageFilenames: Array of image filenames to include from Documents
    ///   - outputURL: Where to write the .zip file
    /// - Returns: The URL of the created archive
    @discardableResult
    static func createArchive(jsonData: Data, imageFilenames: [String], outputURL: URL) throws -> URL {
        debugLog( "Creating backup archive with \(imageFilenames.count) images")

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        var entries: [(name: String, data: Data)] = []

        // Add backup.json
        entries.append(("backup.json", jsonData))

        // Add images
        var includedCount = 0
        for filename in imageFilenames {
            let imageURL = documentsURL.appendingPathComponent(filename)
            if let imageData = try? Data(contentsOf: imageURL) {
                entries.append(("images/\(filename)", imageData))
                includedCount += 1
            } else {
                debugLog( "Skipping missing image: \(filename)")
            }
        }

        debugLog( "Including \(includedCount)/\(imageFilenames.count) images in archive")

        let zipData = try ZipWriter.createZip(entries: entries)
        try zipData.write(to: outputURL, options: .atomic)

        debugLog( "Archive created: \(ByteCountFormatter.string(fromByteCount: Int64(zipData.count), countStyle: .file))")

        return outputURL
    }

    // MARK: - Archive Extraction

    /// Extracts a .zip backup archive, returning the JSON data and image file entries.
    /// - Parameter archiveURL: URL of the .zip file
    /// - Returns: Tuple of (jsonData, imageEntries) where imageEntries maps filename to Data
    static func extractArchive(at archiveURL: URL) throws -> (jsonData: Data, imageEntries: [String: Data]) {
        debugLog( "Extracting backup archive")

        let zipData = try Data(contentsOf: archiveURL)
        let entries = try ZipReader.readZip(data: zipData)

        var jsonData: Data?
        var imageEntries: [String: Data] = [:]

        for (name, data) in entries {
            if name == "backup.json" {
                jsonData = data
            } else if name.hasPrefix("images/") {
                let filename = String(name.dropFirst("images/".count))
                if !filename.isEmpty {
                    imageEntries[filename] = data
                }
            }
        }

        guard let json = jsonData else {
            throw ArchiveError.missingBackupJSON
        }

        debugLog( "Extracted: backup.json + \(imageEntries.count) images")

        return (json, imageEntries)
    }

    // MARK: - Size Estimation

    /// Estimates the total size of images that would be included in an archive.
    /// - Parameter imageFilenames: Array of image filenames in Documents
    /// - Returns: Total size in bytes
    static func estimateImageSize(imageFilenames: [String]) -> Int64 {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var total: Int64 = 0

        for filename in imageFilenames {
            let url = documentsURL.appendingPathComponent(filename)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    /// Collects all unique image filenames referenced by locations and events.
    static func allReferencedImageFilenames(locations: [Location], events: [Event]) -> [String] {
        var filenames = Set<String>()
        for location in locations {
            if let ids = location.imageIDs {
                filenames.formUnion(ids)
            }
        }
        for event in events {
            filenames.formUnion(event.imageIDs)
        }
        return Array(filenames)
    }

    /// Collects image filenames referenced only by events in a date range.
    static func imageFilenames(for events: [Event], locations: [Location]) -> [String] {
        var filenames = Set<String>()

        // Event-level images
        for event in events {
            filenames.formUnion(event.imageIDs)
        }

        // Location-level images for locations referenced by these events
        let locationIDs = Set(events.map { $0.location.id })
        for location in locations where locationIDs.contains(location.id) {
            if let ids = location.imageIDs {
                filenames.formUnion(ids)
            }
        }

        return Array(filenames)
    }

    // MARK: - Image Import with Conflict Resolution

    enum ConflictResolution {
        case rename    // Import with a new filename
        case skip      // Don't import, keep existing
        case replace   // Overwrite existing
    }

    /// Imports image data to the Documents directory with conflict resolution.
    /// - Parameters:
    ///   - imageEntries: Map of filename -> Data
    ///   - resolution: How to handle filename conflicts
    /// - Returns: Map of original filename -> actual saved filename (for remapping references)
    static func importImages(_ imageEntries: [String: Data], resolution: ConflictResolution) -> [String: String] {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var filenameMap: [String: String] = [:]

        for (filename, data) in imageEntries {
            let targetURL = documentsURL.appendingPathComponent(filename)
            let exists = FileManager.default.fileExists(atPath: targetURL.path)

            if exists {
                switch resolution {
                case .skip:
                    filenameMap[filename] = filename
                    debugLog( "Skipping existing image: \(filename)")
                    continue

                case .replace:
                    try? data.write(to: targetURL, options: .atomic)
                    filenameMap[filename] = filename
                    debugLog( "Replaced image: \(filename)")

                case .rename:
                    let newFilename = generateUniqueFilename(for: filename)
                    let newURL = documentsURL.appendingPathComponent(newFilename)
                    try? data.write(to: newURL, options: .atomic)
                    filenameMap[filename] = newFilename
                    debugLog( "Renamed image: \(filename) -> \(newFilename)")
                }
            } else {
                try? data.write(to: targetURL, options: .atomic)
                filenameMap[filename] = filename
            }
        }

        debugLog( "Imported \(filenameMap.count) images")
        return filenameMap
    }

    /// Detects which image filenames from an archive already exist on disk.
    static func detectConflicts(imageFilenames: [String]) -> [String] {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return imageFilenames.filter { filename in
            FileManager.default.fileExists(atPath: documentsURL.appendingPathComponent(filename).path)
        }
    }

    /// Checks if a URL points to a .zip archive (vs plain .json).
    static func isZipArchive(at url: URL) -> Bool {
        // Check extension first
        if url.pathExtension.lowercased() == "zip" || url.pathExtension.lowercased() == "loctrac" {
            return true
        }
        // Check magic bytes for .json files that might actually be zips
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count >= 4 else {
            return false
        }
        // ZIP magic number: PK\x03\x04
        return data[0] == 0x50 && data[1] == 0x4B && data[2] == 0x03 && data[3] == 0x04
    }

    // MARK: - Helpers

    private static func debugLog(_ message: String) {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "Debug.isEnabled"),
           UserDefaults.standard.bool(forKey: "Debug.logPhotos") {
            print("📷 [photos] [BackupArchive] \(message)")
        }
        #endif
    }

    private static func generateUniqueFilename(for original: String) -> String {
        let ext = (original as NSString).pathExtension
        let base = UUID().uuidString
        return ext.isEmpty ? base : "\(base).\(ext)"
    }

    // MARK: - Errors

    enum ArchiveError: LocalizedError {
        case missingBackupJSON
        case invalidArchive
        case writeError(String)

        var errorDescription: String? {
            switch self {
            case .missingBackupJSON:
                return "The archive does not contain a backup.json file."
            case .invalidArchive:
                return "The file is not a valid backup archive."
            case .writeError(let msg):
                return "Failed to write archive: \(msg)"
            }
        }
    }
}

// MARK: - Minimal ZIP Writer (Stored Method, No Compression)

private enum ZipWriter {

    static func createZip(entries: [(name: String, data: Data)]) throws -> Data {
        var output = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0

        for (name, data) in entries {
            let nameData = Data(name.utf8)
            let crc = crc32Checksum(data)
            let size = UInt32(data.count)

            // Local file header
            var local = Data()
            local.appendUInt32(0x04034b50)          // signature
            local.appendUInt16(20)                   // version needed (2.0)
            local.appendUInt16(0)                    // flags
            local.appendUInt16(0)                    // compression: stored
            local.appendUInt16(0)                    // mod time
            local.appendUInt16(0)                    // mod date
            local.appendUInt32(crc)                  // CRC-32
            local.appendUInt32(size)                 // compressed size
            local.appendUInt32(size)                 // uncompressed size
            local.appendUInt16(UInt16(nameData.count)) // filename length
            local.appendUInt16(0)                    // extra field length
            local.append(nameData)                   // filename
            local.append(data)                       // file data

            // Central directory entry
            var central = Data()
            central.appendUInt32(0x02014b50)         // signature
            central.appendUInt16(20)                 // version made by
            central.appendUInt16(20)                 // version needed
            central.appendUInt16(0)                  // flags
            central.appendUInt16(0)                  // compression: stored
            central.appendUInt16(0)                  // mod time
            central.appendUInt16(0)                  // mod date
            central.appendUInt32(crc)                // CRC-32
            central.appendUInt32(size)               // compressed size
            central.appendUInt32(size)               // uncompressed size
            central.appendUInt16(UInt16(nameData.count)) // filename length
            central.appendUInt16(0)                  // extra field length
            central.appendUInt16(0)                  // file comment length
            central.appendUInt16(0)                  // disk number start
            central.appendUInt16(0)                  // internal file attributes
            central.appendUInt32(0)                  // external file attributes
            central.appendUInt32(offset)             // relative offset of local header
            central.append(nameData)                 // filename

            output.append(local)
            centralDirectory.append(central)
            offset += UInt32(local.count)
        }

        let centralDirOffset = offset
        let centralDirSize = UInt32(centralDirectory.count)
        output.append(centralDirectory)

        // End of central directory record
        var eocd = Data()
        eocd.appendUInt32(0x06054b50)               // signature
        eocd.appendUInt16(0)                         // disk number
        eocd.appendUInt16(0)                         // disk with central dir
        eocd.appendUInt16(UInt16(entries.count))     // entries on this disk
        eocd.appendUInt16(UInt16(entries.count))     // total entries
        eocd.appendUInt32(centralDirSize)            // central directory size
        eocd.appendUInt32(centralDirOffset)          // central directory offset
        eocd.appendUInt16(0)                         // comment length
        output.append(eocd)

        return output
    }

    private static func crc32Checksum(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { buffer in
            let bytes = buffer.bindMemory(to: UInt8.self)
            return UInt32(zlib.crc32(0, bytes.baseAddress, uInt(data.count)))
        }
    }
}

// MARK: - Minimal ZIP Reader

private enum ZipReader {

    static func readZip(data: Data) throws -> [(name: String, data: Data)] {
        // Find End of Central Directory record by scanning backwards
        guard let eocdOffset = findEOCD(in: data) else {
            throw BackupArchiveService.ArchiveError.invalidArchive
        }

        let centralDirOffset = data.readUInt32(at: eocdOffset + 16)
        let entryCount = data.readUInt16(at: eocdOffset + 10)

        var entries: [(String, Data)] = []
        var pos = Int(centralDirOffset)

        for _ in 0..<entryCount {
            guard pos + 46 <= data.count else { break }

            let sig = data.readUInt32(at: pos)
            guard sig == 0x02014b50 else { break }

            let compressedSize = Int(data.readUInt32(at: pos + 20))
            let nameLength = Int(data.readUInt16(at: pos + 28))
            let extraLength = Int(data.readUInt16(at: pos + 30))
            let commentLength = Int(data.readUInt16(at: pos + 32))
            let localHeaderOffset = Int(data.readUInt32(at: pos + 42))

            let nameStart = pos + 46
            guard nameStart + nameLength <= data.count else { break }
            let nameData = data[nameStart..<nameStart + nameLength]
            let name = String(data: nameData, encoding: .utf8) ?? ""

            // Read file data from local file header
            let localNameLength = Int(data.readUInt16(at: localHeaderOffset + 26))
            let localExtraLength = Int(data.readUInt16(at: localHeaderOffset + 28))
            let fileDataOffset = localHeaderOffset + 30 + localNameLength + localExtraLength

            guard fileDataOffset + compressedSize <= data.count else { break }
            let fileData = data[fileDataOffset..<fileDataOffset + compressedSize]

            entries.append((name, Data(fileData)))

            pos = nameStart + nameLength + extraLength + commentLength
        }

        return entries
    }

    private static func findEOCD(in data: Data) -> Int? {
        // EOCD is at least 22 bytes, search backwards from end
        let minSize = 22
        guard data.count >= minSize else { return nil }

        let searchStart = max(0, data.count - 65557) // max comment = 65535
        for i in stride(from: data.count - minSize, through: searchStart, by: -1) {
            if data.readUInt32(at: i) == 0x06054b50 {
                return i
            }
        }
        return nil
    }
}

// MARK: - Data Helpers for Binary Read/Write

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }

    mutating func appendUInt32(_ value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }

    func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return self[offset..<offset + 2].withUnsafeBytes {
            $0.loadUnaligned(as: UInt16.self).littleEndian
        }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return self[offset..<offset + 4].withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self).littleEndian
        }
    }
}
