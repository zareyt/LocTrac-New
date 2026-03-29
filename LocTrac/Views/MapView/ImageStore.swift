//
//  ImageStore.swift
//  LocTrac
//
//  Created by Assistant on 12/24/25.
//

import UIKit

enum ImageStore {
    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    static func save(image: UIImage, preferredExtension: String = "jpg", quality: CGFloat = 0.9) throws -> String {
        let id = UUID().uuidString
        let filename = id + "." + preferredExtension
        let url = documentsURL.appendingPathComponent(filename)
        
        let data: Data
        if preferredExtension.lowercased() == "png" {
            guard let d = image.pngData() else { throw NSError(domain: "ImageStore", code: 1) }
            data = d
        } else {
            guard let d = image.jpegData(compressionQuality: quality) else { throw NSError(domain: "ImageStore", code: 2) }
            data = d
        }
        try data.write(to: url, options: .atomic)
        return filename
    }
    
    static func load(filename: String) -> UIImage? {
        let url = documentsURL.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
    
    static func delete(filename: String) {
        let url = documentsURL.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}

