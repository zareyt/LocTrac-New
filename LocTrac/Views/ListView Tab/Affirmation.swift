//
//  Affirmation.swift
//  LocTrac
//
//  Affirmations model for positive mindset tracking
//

import Foundation

struct Affirmation: Identifiable, Codable, Hashable, Equatable {
    var id: String = UUID().uuidString
    var text: String
    var category: Category
    var createdDate: Date = Date()
    var color: String = "blue" // For visual distinction
    var isFavorite: Bool = false
    
    enum Category: String, Codable, CaseIterable {
        case health = "Health & Wellness"
        case success = "Success & Abundance"
        case relationships = "Relationships"
        case confidence = "Confidence"
        case gratitude = "Gratitude"
        case peace = "Peace & Calm"
        case creativity = "Creativity"
        case custom = "Custom"
        
        var icon: String {
            switch self {
            case .health: return "heart.fill"
            case .success: return "star.fill"
            case .relationships: return "person.2.fill"
            case .confidence: return "flame.fill"
            case .gratitude: return "hands.sparkles.fill"
            case .peace: return "cloud.fill"
            case .creativity: return "paintbrush.fill"
            case .custom: return "sparkles"
            }
        }
        
        var defaultColor: String {
            switch self {
            case .health: return "green"
            case .success: return "yellow"
            case .relationships: return "pink"
            case .confidence: return "orange"
            case .gratitude: return "purple"
            case .peace: return "blue"
            case .creativity: return "indigo"
            case .custom: return "gray"
            }
        }
    }
    
    // Preset affirmations for quick start
    static let presets: [Affirmation] = [
        Affirmation(text: "I am worthy of love and respect", category: .confidence, color: "orange", isFavorite: true),
        Affirmation(text: "I am grateful for this moment", category: .gratitude, color: "purple", isFavorite: true),
        Affirmation(text: "I attract success and abundance", category: .success, color: "yellow"),
        Affirmation(text: "I am healthy, strong, and vibrant", category: .health, color: "green"),
        Affirmation(text: "I choose peace and calm", category: .peace, color: "blue"),
        Affirmation(text: "My relationships are loving and supportive", category: .relationships, color: "pink"),
        Affirmation(text: "I am creative and inspired", category: .creativity, color: "indigo"),
        Affirmation(text: "I trust the journey of my life", category: .peace, color: "blue"),
        Affirmation(text: "I am capable of achieving my goals", category: .confidence, color: "orange"),
        Affirmation(text: "Abundance flows to me effortlessly", category: .success, color: "yellow")
    ]
}
