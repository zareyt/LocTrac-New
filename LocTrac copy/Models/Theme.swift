/*
See LICENSE folder for this sample’s licensing information.
*/

import SwiftUI

enum Theme: String, CaseIterable, Identifiable, Codable {
    case magenta
    case navy
    case orange
    case mint
    case brown
    case purple
    case red
    case green
    case teal
    case yellow

    var mainColor: Color {
        switch self {
        case .magenta:
            return Color(.magenta)
        case .navy:
            return Color(.systemBlue)
        case .orange:
            return Color(.orange)
        case .mint:
            return Color(.systemMint)
        case .brown:
            return Color(.brown)
        case .purple:
            return Color(.purple)
        case .red:
            return Color(.red)
        case .green:
            return Color(.green)
        case .teal:
            return Color(.systemTeal)
        case .yellow:
            return Color(.yellow)
        }
    }
    
    var uiColor: UIColor {
        switch self {
        case .magenta:
            return UIColor(ciColor: .magenta)
        case .navy:
            return .systemBlue
        case .orange:
            return .systemOrange
        case .mint:
            return .systemMint
        case .brown:
            return .systemBrown
        case .purple:
            return .systemPurple
        case .red:
            return .systemRed
        case .green:
            return .systemGreen
        case .teal:
            return .systemTeal
        case .yellow:
            return .systemYellow
        }
    }
    
    var accentColor: Color {
        switch self {
        case .mint, .teal, .yellow: return .black
        case .brown, .magenta, .navy, .orange, .purple, .green, .red: return .white
        }
    }

    var name: String {
        rawValue.capitalized
    }
    var id: String {
        name
    }
}

