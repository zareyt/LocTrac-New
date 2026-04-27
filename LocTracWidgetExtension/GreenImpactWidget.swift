//
//  GreenImpactWidget.swift
//  LocTracWidgetExtension
//
//  v2.1: Environmental impact widget — CO2 saved from cycling, driving emissions
//

import WidgetKit
import SwiftUI

// MARK: - Widget Configuration

struct GreenImpactWidget: Widget {
    let kind = "GreenImpactWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GreenImpactProvider()) { entry in
            GreenImpactWidgetView(entry: entry)
        }
        .configurationDisplayName("Green Impact")
        .description("Your cycling CO2 savings and environmental footprint.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct GreenImpactProvider: TimelineProvider {
    func placeholder(in context: Context) -> GreenImpactEntry {
        GreenImpactEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (GreenImpactEntry) -> Void) {
        let data = WidgetData.load() ?? .placeholder
        completion(GreenImpactEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GreenImpactEntry>) -> Void) {
        let data = WidgetData.load() ?? .placeholder
        let entry = GreenImpactEntry(date: Date(), data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct GreenImpactEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Widget Views

struct GreenImpactWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: GreenImpactEntry

    var body: some View {
        switch family {
        case .systemSmall:
            GreenSmallView(data: entry.data)
        case .systemMedium:
            GreenMediumView(data: entry.data)
        default:
            GreenSmallView(data: entry.data)
        }
    }
}

// MARK: - Small

struct GreenSmallView: View {
    let data: WidgetData

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.title)
                .foregroundStyle(.green)

            VStack(spacing: 2) {
                Text(String(format: "%.1f", data.cyclingCO2SavedLbsAllTime))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                Text("lbs CO\u{2082} saved")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "bicycle")
                    .font(.system(size: 9))
                    .foregroundStyle(.green)
                Text(String(format: "%.0f mi cycled", data.totalMilesCycledAllTime))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.green.opacity(0.08), Color.mint.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Medium

struct GreenMediumView: View {
    let data: WidgetData

    var body: some View {
        HStack(spacing: 16) {
            // Left: CO2 saved highlight
            VStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)

                Text(String(format: "%.1f", data.cyclingCO2SavedLbsAllTime))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)

                Text("lbs CO\u{2082} saved")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 110)

            Divider()
                .frame(height: 60)

            // Right: Breakdown
            VStack(alignment: .leading, spacing: 8) {
                Text("ENVIRONMENTAL")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                GreenStatRow(
                    icon: "bicycle",
                    label: "Miles Cycled",
                    value: String(format: "%.0f mi", data.totalMilesCycledAllTime),
                    color: .green
                )

                GreenStatRow(
                    icon: "car.fill",
                    label: "Driving CO\u{2082} (month)",
                    value: String(format: "%.0f lbs", data.drivingCO2ThisMonthLbs),
                    color: .orange
                )

                Spacer()

                if data.cyclingCO2SavedLbsAllTime > 0 {
                    let treeDays = data.cyclingCO2SavedLbsAllTime / 48.0 // A tree absorbs ~48 lbs CO2/year
                    Text("Equivalent to \(String(format: "%.1f", treeDays * 365)) tree-days of absorption")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.green.opacity(0.8))
                }
            }

            Spacer()
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.green.opacity(0.06), Color.mint.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct GreenStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}
