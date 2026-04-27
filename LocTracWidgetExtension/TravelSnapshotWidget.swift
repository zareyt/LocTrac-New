//
//  TravelSnapshotWidget.swift
//  LocTracWidgetExtension
//
//  v2.1: Travel stats widget — countries, cities, days away, top destinations
//

import WidgetKit
import SwiftUI

// MARK: - Widget Configuration

struct TravelSnapshotWidget: Widget {
    let kind = "TravelSnapshotWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TravelSnapshotProvider()) { entry in
            TravelSnapshotWidgetView(entry: entry)
        }
        .configurationDisplayName("Travel Snapshot")
        .description("Countries visited, cities explored, and days on the road.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct TravelSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> TravelSnapshotEntry {
        TravelSnapshotEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TravelSnapshotEntry) -> Void) {
        let data = WidgetData.load() ?? .placeholder
        completion(TravelSnapshotEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TravelSnapshotEntry>) -> Void) {
        let data = WidgetData.load() ?? .placeholder
        let entry = TravelSnapshotEntry(date: Date(), data: data)
        // Refresh every 30 minutes to pick up new saves
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct TravelSnapshotEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Widget Views

struct TravelSnapshotWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: TravelSnapshotEntry

    var body: some View {
        switch family {
        case .systemSmall:
            TravelSmallView(data: entry.data)
        case .systemMedium:
            TravelMediumView(data: entry.data)
        default:
            TravelSmallView(data: entry.data)
        }
    }
}

// MARK: - Small

struct TravelSmallView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "globe.americas.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Spacer()
                Text("LocTrac")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatRow(value: "\(data.totalCountries)", label: "Countries", color: .blue)
            StatRow(value: "\(data.totalCities)", label: "Cities", color: .green)
            StatRow(value: "\(data.daysAwayFromHomeThisYear)", label: "Days Away", color: .orange)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.green.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Medium

struct TravelMediumView: View {
    let data: WidgetData

    var body: some View {
        HStack(spacing: 16) {
            // Left: Key numbers
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "globe.americas.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    Text("Travel")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }

                Spacer()

                HStack(spacing: 16) {
                    BigStat(value: "\(data.totalCountries)", label: "Countries", color: .blue)
                    BigStat(value: "\(data.totalCities)", label: "Cities", color: .green)
                    BigStat(value: "\(data.totalStays)", label: "Stays", color: .purple)
                }
            }

            Divider()
                .frame(height: 60)

            // Right: Top destinations
            VStack(alignment: .leading, spacing: 4) {
                Text("TOP DESTINATIONS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                if data.topCountries.isEmpty {
                    Text("No data yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(data.topCountries.prefix(3), id: \.name) { country in
                        HStack(spacing: 4) {
                            Text(flagEmoji(for: country.name))
                                .font(.caption)
                            Text(country.name)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .lineLimit(1)
                            Spacer()
                            Text("\(country.stayCount)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                if data.daysAwayFromHomeThisYear > 0 {
                    Text("\(data.daysAwayFromHomeThisYear) days away this year")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.blue.opacity(0.06), Color.green.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func flagEmoji(for country: String) -> String {
        let mapping: [String: String] = [
            "United States": "🇺🇸", "Canada": "🇨🇦", "Mexico": "🇲🇽",
            "United Kingdom": "🇬🇧", "France": "🇫🇷", "Germany": "🇩🇪",
            "Spain": "🇪🇸", "Italy": "🇮🇹", "Japan": "🇯🇵",
            "Australia": "🇦🇺", "Brazil": "🇧🇷", "India": "🇮🇳",
            "China": "🇨🇳", "South Korea": "🇰🇷", "Netherlands": "🇳🇱",
            "Switzerland": "🇨🇭", "Ireland": "🇮🇪", "Portugal": "🇵🇹",
            "Greece": "🇬🇷", "Thailand": "🇹🇭", "Colombia": "🇨🇴",
            "Costa Rica": "🇨🇷", "Iceland": "🇮🇸", "Norway": "🇳🇴",
            "Sweden": "🇸🇪", "Denmark": "🇩🇰", "Finland": "🇫🇮",
            "Austria": "🇦🇹", "Belgium": "🇧🇪", "Czech Republic": "🇨🇿",
            "Poland": "🇵🇱", "New Zealand": "🇳🇿", "Argentina": "🇦🇷",
        ]
        return mapping[country] ?? "🌍"
    }
}

// MARK: - Shared Subviews

private struct StatRow: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

private struct BigStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}
