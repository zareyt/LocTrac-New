//
//  LocTracWidget.swift
//  LocTrac
//
//  Daily affirmation widget for home screen
//  Updates automatically at midnight, displays one affirmation per day
//

import WidgetKit
import SwiftUI

// MARK: - Widget Configuration

struct LocTracWidget: Widget {
    let kind: String = "LocTracWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyAffirmationProvider()) { entry in
            DailyAffirmationWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Affirmation")
        .description("A calming daily affirmation that updates at midnight.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct DailyAffirmationProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyAffirmationEntry {
        DailyAffirmationEntry(
            date: Date(),
            affirmation: Affirmation.presets[0]
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (DailyAffirmationEntry) -> Void) {
        let entry = DailyAffirmationEntry(
            date: Date(),
            affirmation: getTodaysAffirmation()
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyAffirmationEntry>) -> Void) {
        let currentDate = Date()
        let affirmation = getTodaysAffirmation()
        
        // Create entry for today
        let entry = DailyAffirmationEntry(date: currentDate, affirmation: affirmation)
        
        // Schedule next update at midnight tomorrow
        let midnight = Calendar.current.startOfDay(for: currentDate)
        let tomorrowMidnight = Calendar.current.date(byAdding: .day, value: 1, to: midnight)!
        
        // Create timeline that refreshes at midnight
        let timeline = Timeline(entries: [entry], policy: .after(tomorrowMidnight))
        completion(timeline)
    }
    
    /// Returns the affirmation for today based on day-of-week rotation
    private func getTodaysAffirmation() -> Affirmation {
        // Load user's affirmations from App Group (if available)
        if let userAffirmations = loadUserAffirmations(), !userAffirmations.isEmpty {
            // Use day of year to rotate through user's affirmations
            let calendar = Calendar.current
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
            let index = (dayOfYear - 1) % userAffirmations.count
            return userAffirmations[index]
        }
        
        // Fallback: Use preset affirmations with day-of-week rotation
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: Date()) // 1 = Sunday, 7 = Saturday
        let index = (dayOfWeek - 1) % Affirmation.presets.count
        return Affirmation.presets[index]
    }
    
    /// Load user's affirmations from shared App Group storage
    private func loadUserAffirmations() -> [Affirmation]? {
        // TODO: Implement App Group shared data when iCloud sync is added
        // For now, use presets
        return nil
    }
}

// MARK: - Timeline Entry

struct DailyAffirmationEntry: TimelineEntry {
    let date: Date
    let affirmation: Affirmation
}

// MARK: - Widget Views

struct DailyAffirmationWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: DailyAffirmationProvider.Entry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(affirmation: entry.affirmation)
        case .systemMedium:
            MediumWidgetView(affirmation: entry.affirmation)
        default:
            SmallWidgetView(affirmation: entry.affirmation)
        }
    }
}

// MARK: - Small Widget (Square)

struct SmallWidgetView: View {
    let affirmation: Affirmation
    
    private var backgroundColor: Color {
        switch affirmation.color {
        case "blue": return Color.blue.opacity(0.2)
        case "green": return Color.green.opacity(0.2)
        case "purple": return Color.purple.opacity(0.2)
        case "orange": return Color.orange.opacity(0.2)
        case "pink": return Color.pink.opacity(0.2)
        case "yellow": return Color.yellow.opacity(0.2)
        case "indigo": return Color.indigo.opacity(0.2)
        default: return Color.gray.opacity(0.2)
        }
    }
    
    private var accentColor: Color {
        switch affirmation.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "yellow": return .orange // Yellow text is hard to read
        case "indigo": return .indigo
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Category icon
            Image(systemName: affirmation.category.icon)
                .font(.title2)
                .foregroundColor(accentColor)
            
            // Affirmation text
            Text(affirmation.text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(5)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            // Date indicator (subtle)
            Text(formattedDate)
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            // Soft gradient background
            LinearGradient(
                colors: [backgroundColor, backgroundColor.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Day name (e.g., "Monday")
        return formatter.string(from: Date())
    }
}

// MARK: - Medium Widget (Rectangular)

struct MediumWidgetView: View {
    let affirmation: Affirmation
    
    private var backgroundColor: Color {
        switch affirmation.color {
        case "blue": return Color.blue.opacity(0.15)
        case "green": return Color.green.opacity(0.15)
        case "purple": return Color.purple.opacity(0.15)
        case "orange": return Color.orange.opacity(0.15)
        case "pink": return Color.pink.opacity(0.15)
        case "yellow": return Color.yellow.opacity(0.15)
        case "indigo": return Color.indigo.opacity(0.15)
        default: return Color.gray.opacity(0.15)
        }
    }
    
    private var accentColor: Color {
        switch affirmation.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "yellow": return .orange
        case "indigo": return .indigo
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side: Icon
            VStack {
                Image(systemName: affirmation.category.icon)
                    .font(.system(size: 36))
                    .foregroundColor(accentColor)
                
                Spacer()
                
                // App branding
                Text("LocTrac")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            
            // Right side: Content
            VStack(alignment: .leading, spacing: 8) {
                // Day name
                Text(formattedDate)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(accentColor)
                    .textCase(.uppercase)
                
                // Affirmation text
                Text(affirmation.text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                // Category label
                Text(affirmation.category.rawValue)
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .containerBackground(for: .widget) {
            // Soft gradient background
            LinearGradient(
                colors: [backgroundColor, backgroundColor.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Day name (e.g., "Monday")
        return formatter.string(from: Date())
    }
}

// MARK: - Preview

struct LocTracWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Small widget preview
            DailyAffirmationWidgetView(
                entry: DailyAffirmationEntry(
                    date: Date(),
                    affirmation: Affirmation.presets[0]
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small Widget")
            
            // Medium widget preview
            DailyAffirmationWidgetView(
                entry: DailyAffirmationEntry(
                    date: Date(),
                    affirmation: Affirmation.presets[1]
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium Widget")
        }
    }
}
