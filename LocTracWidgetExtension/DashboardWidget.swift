//
//  DashboardWidget.swift
//  LocTracWidgetExtension
//
//  v2.1: All-in-one dashboard — travel, fitness, environment, affirmation
//

import WidgetKit
import SwiftUI

// MARK: - Widget Configuration

struct DashboardWidget: Widget {
    let kind = "DashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardProvider()) { entry in
            DashboardWidgetView(entry: entry)
        }
        .configurationDisplayName("LocTrac Dashboard")
        .description("Travel, fitness, and environmental stats all in one.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Timeline Provider

struct DashboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DashboardEntry) -> Void) {
        let data = WidgetData.load() ?? .placeholder
        completion(DashboardEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardEntry>) -> Void) {
        let data = WidgetData.load() ?? .placeholder
        let entry = DashboardEntry(date: Date(), data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct DashboardEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Widget Views

struct DashboardWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: DashboardEntry

    var body: some View {
        switch family {
        case .systemMedium:
            DashboardMediumView(data: entry.data)
        case .systemLarge:
            DashboardLargeView(data: entry.data)
        default:
            DashboardMediumView(data: entry.data)
        }
    }
}

// MARK: - Medium (3 columns)

struct DashboardMediumView: View {
    let data: WidgetData

    var body: some View {
        HStack(spacing: 0) {
            // Travel
            DashboardColumn(
                icon: "globe.americas.fill",
                iconColor: .blue,
                title: "Travel",
                mainValue: "\(data.totalCountries)",
                mainLabel: "countries",
                subValue: "\(data.totalCities) cities"
            )

            Divider().frame(height: 50)

            // Fitness
            DashboardColumn(
                icon: "figure.run",
                iconColor: .orange,
                title: "Fitness",
                mainValue: "\(Int(data.activeMinutesThisWeek))",
                mainLabel: "min/week",
                subValue: "\(data.activeDaysThisWeek) active days"
            )

            Divider().frame(height: 50)

            // Environment
            DashboardColumn(
                icon: "leaf.fill",
                iconColor: .green,
                title: "Green",
                mainValue: String(format: "%.0f", data.cyclingCO2SavedLbsAllTime),
                mainLabel: "lbs saved",
                subValue: String(format: "%.0f mi cycled", data.totalMilesCycledAllTime)
            )
        }
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.green.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Large (4 quadrants)

struct DashboardLargeView: View {
    let data: WidgetData

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("LocTrac")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                if let name = data.recentLocationName {
                    Label(name, systemImage: "mappin")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // Top row: Travel + Fitness
            HStack(spacing: 12) {
                // Travel quadrant
                QuadrantView(
                    icon: "globe.americas.fill",
                    iconColor: .blue,
                    title: "TRAVEL"
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        QuadrantStat(value: "\(data.totalCountries)", label: "Countries", color: .blue)
                        QuadrantStat(value: "\(data.totalCities)", label: "Cities", color: .cyan)
                        QuadrantStat(value: "\(data.daysAwayFromHomeThisYear)", label: "Days Away", color: .orange)
                    }
                }

                // Fitness quadrant
                QuadrantView(
                    icon: "figure.run",
                    iconColor: .orange,
                    title: "FITNESS"
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        QuadrantStat(value: "\(Int(data.activeMinutesThisWeek))", label: "Min/Week", color: .orange)
                        QuadrantStat(value: "\(data.workoutCountThisWeek)", label: "Workouts", color: .red)
                        QuadrantStat(value: "\(Int(data.totalCaloriesThisWeek))", label: "Calories", color: .pink)
                    }
                }
            }

            // Bottom row: Environment + Affirmation
            HStack(spacing: 12) {
                // Environment quadrant
                QuadrantView(
                    icon: "leaf.fill",
                    iconColor: .green,
                    title: "ENVIRONMENT"
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        QuadrantStat(
                            value: String(format: "%.1f", data.cyclingCO2SavedLbsAllTime),
                            label: "lbs CO\u{2082} Saved",
                            color: .green
                        )
                        QuadrantStat(
                            value: String(format: "%.0f", data.totalMilesCycledAllTime),
                            label: "Miles Cycled",
                            color: .mint
                        )
                        QuadrantStat(
                            value: String(format: "%.0f", data.drivingCO2ThisMonthLbs),
                            label: "Driving CO\u{2082}/mo",
                            color: .orange
                        )
                    }
                }

                // Affirmation quadrant
                QuadrantView(
                    icon: affirmationIcon,
                    iconColor: affirmationColor,
                    title: "TODAY"
                ) {
                    if let text = data.todaysAffirmationText {
                        Text(text)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(4)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text("No affirmation set")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.blue.opacity(0.04), Color.green.opacity(0.03), Color.orange.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var affirmationIcon: String {
        switch data.todaysAffirmationCategory {
        case "Health & Wellness": return "heart.fill"
        case "Success & Abundance": return "star.fill"
        case "Relationships": return "person.2.fill"
        case "Confidence": return "bolt.fill"
        case "Gratitude": return "hands.sparkles.fill"
        case "Peace & Calm": return "leaf.fill"
        case "Creativity": return "paintbrush.fill"
        default: return "quote.bubble.fill"
        }
    }

    private var affirmationColor: Color {
        switch data.todaysAffirmationColor {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "yellow": return .yellow
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

// MARK: - Shared Subviews

private struct DashboardColumn: View {
    let icon: String
    let iconColor: Color
    let title: String
    let mainValue: String
    let mainLabel: String
    let subValue: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)

            Text(mainValue)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(iconColor)

            Text(mainLabel)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text(subValue)
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct QuadrantView<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            content
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct QuadrantStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
