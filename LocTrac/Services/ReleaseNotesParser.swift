//
//  ReleaseNotesParser.swift
//  LocTrac
//
//  Parses VERSION_x.x_RELEASE_NOTES.md files to dynamically generate
//  WhatsNewFeature pages. Falls back to hardcoded features if parsing fails.
//
//  Expected markdown format:
//  ```markdown
//  ## 🎉 What's New in vX.X
//
//  ### Feature Title
//  icon: symbol.name | color: blue
//  
//  Feature description goes here. Can be multiple sentences.
//  ```
//

import Foundation
import SwiftUI

/// Parses release notes markdown files to extract feature information.
struct ReleaseNotesParser {
    
    // MARK: - Parsed Feature
    
    /// Intermediate representation of a parsed feature before converting to WhatsNewFeature.
    struct ParsedFeature {
        let title: String
        let symbolName: String
        let colorName: String
        let description: String
    }
    
    /// Result containing both features and bug fixes
    struct ParseResult {
        let features: [WhatsNewFeature]
        let bugFixes: [WhatsNewFeature]
        
        /// All items combined (for backward compatibility)
        var all: [WhatsNewFeature] {
            features + bugFixes
        }
    }
    
    // MARK: - Public API
    
    /// Attempts to parse features and bugs from VERSION_x.x_RELEASE_NOTES.md file.
    /// Returns nil if file doesn't exist or parsing fails.
    static func parse(forVersion version: String) -> ParseResult? {
        #if DEBUG
        print("📝 [Parser] parse called for version: \(version)")
        #endif
        
        guard let markdownContent = loadReleaseNotes(forVersion: version) else {
            #if DEBUG
            print("📝 [Parser] No release notes file found for version \(version)")
            #endif
            return nil
        }
        
        #if DEBUG
        print("📝 [Parser] Markdown content loaded, length: \(markdownContent.count)")
        print("📝 [Parser] Calling parseMarkdown...")
        #endif
        
        let result = parseMarkdown(markdownContent)
        
        #if DEBUG
        print("📝 [Parser] Parsed \(result.features.count) features and \(result.bugFixes.count) bug fixes")
        #endif
        
        return result
    }
    
    /// Legacy method for backward compatibility - returns all items combined
    static func parseFeatures(forVersion version: String) -> [WhatsNewFeature]? {
        return parse(forVersion: version)?.all
    }
    
    // MARK: - File Loading
    
    /// Loads the contents of VERSION_x.x_RELEASE_NOTES.md from the app bundle.
    private static func loadReleaseNotes(forVersion version: String) -> String? {
        // Try different naming patterns
        let fileNames = [
            "VERSION_\(version)_RELEASE_NOTES",
            "VERSION_v\(version)_RELEASE_NOTES",
            "V\(version)_RELEASE_NOTES",
        ]
        
        // Try different locations (root and Documentation subdirectory)
        let subdirectories = ["", "Documentation"]
        
        for subdirectory in subdirectories {
            for fileName in fileNames {
                // Try with subdirectory
                let path: String?
                if subdirectory.isEmpty {
                    path = Bundle.main.path(forResource: fileName, ofType: "md")
                } else {
                    path = Bundle.main.path(forResource: fileName, ofType: "md", inDirectory: subdirectory)
                }
                
                if let path = path,
                   let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                    #if DEBUG
                    print("📝 [Parser] Loaded release notes from: \(subdirectory.isEmpty ? "" : "\(subdirectory)/")\(fileName).md")
                    #endif
                    return contents
                }
            }
        }
        
        #if DEBUG
        print("📝 [Parser] Could not find release notes file for version \(version)")
        print("📝 [Parser] Tried locations: root and Documentation/")
        print("📝 [Parser] Tried files: \(fileNames.map { "\($0).md" }.joined(separator: ", "))")
        #endif
        return nil
    }
    
    // MARK: - Markdown Parsing
    
    /// Parses markdown content and extracts WhatsNewFeature objects, separated into features and bug fixes.
    private static func parseMarkdown(_ markdown: String) -> ParseResult {
        var features: [WhatsNewFeature] = []
        var bugFixes: [WhatsNewFeature] = []
        
        #if DEBUG
        print("📝 [Parser] Markdown length: \(markdown.count) characters")
        #endif
        
        // Split into lines for processing
        let lines = markdown.components(separatedBy: .newlines)
        
        #if DEBUG
        print("📝 [Parser] Total lines: \(lines.count)")
        print("📝 [Parser] First 20 lines of markdown:")
        for (index, line) in lines.prefix(20).enumerated() {
            print("📝 [Parser]   Line \(index): \(line)")
        }
        #endif
        
        var currentTitle: String?
        var currentSymbol: String?
        var currentColor: String?
        var currentDescription: [String] = []
        var inFeatureSection = false
        var inBugFixesSection = false
        var savedFinalFeature = false  // Track if we saved in the end section block
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for "What's New" section start
            if trimmed.contains("What's New") && trimmed.hasPrefix("#") {
                #if DEBUG
                print("📝 [Parser] Found 'What's New' section: \(trimmed)")
                #endif
                inFeatureSection = true
                inBugFixesSection = false
                continue
            }
            
            // Check for "Bug Fixes" section start
            if trimmed.contains("Bug Fixes") && trimmed.hasPrefix("#") {
                #if DEBUG
                print("📝 [Parser] Found 'Bug Fixes' section: \(trimmed)")
                #endif
                // Save any pending feature from What's New section
                if let title = currentTitle,
                   let symbol = currentSymbol,
                   let color = currentColor,
                   !currentDescription.isEmpty {
                    let description = currentDescription.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    if let feature = createFeature(title: title, symbolName: symbol, colorName: color, description: description) {
                        // Add to features array (we're transitioning from features to bugs)
                        features.append(feature)
                    }
                }
                
                // Reset for bug fixes section
                currentTitle = nil
                currentSymbol = nil
                currentColor = nil
                currentDescription = []
                
                inFeatureSection = false
                inBugFixesSection = true
                continue
            }
            
            // Stop at other major sections (not What's New or Bug Fixes)
            // Check for exactly ## (not ###)
            if (inFeatureSection || inBugFixesSection) && 
               trimmed.hasPrefix("##") && !trimmed.hasPrefix("###") &&
               !trimmed.contains("What's New") && !trimmed.contains("Bug Fixes") {
                #if DEBUG
                print("📝 [Parser] Found end section: \(trimmed)")
                #endif
                // Save any pending feature
                if let title = currentTitle,
                   let symbol = currentSymbol,
                   let color = currentColor,
                   !currentDescription.isEmpty {
                    let description = currentDescription.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    if let feature = createFeature(title: title, symbolName: symbol, colorName: color, description: description) {
                        // Add to appropriate array based on current section
                        if inBugFixesSection {
                            bugFixes.append(feature)
                        } else {
                            features.append(feature)
                        }
                        savedFinalFeature = true  // Mark that we saved the last feature
                    }
                }
                break
            }
            
            guard (inFeatureSection || inBugFixesSection) else { continue }
            
            // Feature/Bug title (### heading)
            if trimmed.hasPrefix("###") {
                // Save previous feature if exists
                if let title = currentTitle,
                   let symbol = currentSymbol,
                   let color = currentColor,
                   !currentDescription.isEmpty {
                    let description = currentDescription.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    if let feature = createFeature(title: title, symbolName: symbol, colorName: color, description: description) {
                        #if DEBUG
                        print("📝 [Parser] Created \(inBugFixesSection ? "bug fix" : "feature"): \(title)")
                        #endif
                        // Add to appropriate array based on current section
                        if inBugFixesSection {
                            bugFixes.append(feature)
                        } else {
                            features.append(feature)
                        }
                    }
                }
                
                // Start new feature
                currentTitle = trimmed.replacingOccurrences(of: "###", with: "").trimmingCharacters(in: .whitespaces)
                #if DEBUG
                print("📝 [Parser] Found feature title: \(currentTitle ?? "nil")")
                #endif
                currentSymbol = nil
                currentColor = nil
                currentDescription = []
                continue
            }
            
            // Icon metadata line: "icon: symbol.name | color: blue"
            if trimmed.contains("icon:") {
                let components = trimmed.components(separatedBy: "|")
                
                // Extract symbol
                if let iconPart = components.first {
                    let symbolPart = iconPart.replacingOccurrences(of: "icon:", with: "").trimmingCharacters(in: .whitespaces)
                    currentSymbol = symbolPart
                    #if DEBUG
                    print("📝 [Parser] Found symbol: \(symbolPart)")
                    #endif
                }
                
                // Extract color
                if components.count > 1 {
                    let colorPart = components[1].replacingOccurrences(of: "color:", with: "").trimmingCharacters(in: .whitespaces)
                    currentColor = colorPart
                    #if DEBUG
                    print("📝 [Parser] Found color: \(colorPart)")
                    #endif
                }
                continue
            }
            
            // Description text (non-empty lines that aren't headings or metadata)
            if !trimmed.isEmpty &&
               !trimmed.hasPrefix("#") &&
               !trimmed.hasPrefix("**") &&
               !trimmed.hasPrefix("---") &&
               !trimmed.hasPrefix("```") &&
               currentTitle != nil {
                // Remove markdown formatting
                let cleaned = trimmed
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "✨", with: "")
                    .replacingOccurrences(of: "🌍", with: "")
                    .replacingOccurrences(of: "⚡", with: "")
                    .replacingOccurrences(of: "🔄", with: "")
                    .replacingOccurrences(of: "🐛", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                if !cleaned.isEmpty {
                    currentDescription.append(cleaned)
                }
            }
        }
        
        // Save final feature if exists (handles last feature in the file)
        // Only if we didn't already save it in the "end section" block
        if !savedFinalFeature,
           let title = currentTitle,
           let symbol = currentSymbol,
           let color = currentColor,
           !currentDescription.isEmpty {
            let description = currentDescription.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if let feature = createFeature(title: title, symbolName: symbol, colorName: color, description: description) {
                #if DEBUG
                print("📝 [Parser] Created final \(inBugFixesSection ? "bug fix" : "feature"): \(title)")
                #endif
                // Add to appropriate array based on current section
                if inBugFixesSection {
                    bugFixes.append(feature)
                } else {
                    features.append(feature)
                }
            }
        }
        
        #if DEBUG
        print("📝 [Parser] Parsed \(features.count) features and \(bugFixes.count) bug fixes from release notes")
        #endif
        
        return ParseResult(features: features, bugFixes: bugFixes)
    }
    
    // MARK: - Feature Creation
    
    /// Creates a WhatsNewFeature from parsed components.
    private static func createFeature(title: String, symbolName: String, colorName: String, description: String) -> WhatsNewFeature? {
        let color = mapColor(from: colorName)
        
        return WhatsNewFeature(
            symbolName: symbolName,
            symbolColor: color,
            title: title,
            description: description
        )
    }
    
    // MARK: - Color Mapping
    
    /// Maps color name strings to SwiftUI Color values.
    private static func mapColor(from name: String) -> Color {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        
        switch normalized {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "pink": return .pink
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "indigo": return .indigo
        case "teal": return .teal
        case "mint": return .mint
        case "brown": return .brown
        case "gray", "grey": return .gray
        default:
            #if DEBUG
            print("📝 [Parser] Unknown color '\(name)', defaulting to blue")
            #endif
            return .blue
        }
    }
}
