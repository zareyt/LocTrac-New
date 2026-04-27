//
//  ActivityPulseWidget.swift
//  LocTracWidgetExtension
//
//  v2.1: Exercise/fitness widget — active days, minutes, calories, workouts this week
//

import WidgetKit
import SwiftUI

// MARK: - Widget Configuration

struct ActivityPulseWidget: Widget {
    let kind = "ActivityPulseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActivityPulseProvider()) { entry in
            ActivityPulseWidgetView(entry: entry)
        }
        .configurationDisplayName("Activity Pulse")
        .description("Your weekly exercise stats at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct ActivityPulseProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActivityPulseEntry {
        ActivityPulseEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ActivityPulseEntry) -> Void) {
        let data = WidgetData.load() ?? .placeholder
        completion(ActivityPulseEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActivityPulseEntry>) -> Void) {
        let data = WidgetData.load() ?? .placeholder
        let entry = ActivityPulseEntry(date: Date(), data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct ActivityPulseEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Widget Views

struct ActivityPulseWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: ActivityPulseEntry

    var body: some View {
        switch family {
        case .systemSmall:
            ActivitySmallView(data: entry.data)
        case .systemMedium:
            ActivityMediumView(data: entry.data)
        default:
            ActivitySmallView(data: entry.data)
        }
    }
}

// MARK: - Small

struct ActivitySmallView: View {
    let data: WidgetData

    private var ringProgress: Double {
        // 150 min/week is the CDC recommendation
        min(data.activeMinutesThisWeek / 150.0, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Ring
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(data.activeMinutesThisWeek))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("min")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 70, height: 70)

            HStack(spacing: 12) {
                Label("\(data.activeDaysThisWeek)", systemImage: "calendar")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.green)
                Label("\(data.workoutCountThisWeek)", systemImage: "flame.fill")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.orange.opacity(0.06), Color.red.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Medium

struct ActivityMediumView: View {
    let data: WidgetData

    private var ringProgress: Double {
        min(data.activeMinutesThisWeek / 150.0, 1.0)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: Ring
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(data.activeMinutesThisWeek))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("min")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            // Right: Stats
            VStack(alignment: .leading, spacing: 6) {
                Text("THIS WEEK")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                ActivityStatRow(icon: "calendar", label: "Active Days", value: "\(data.activeDaysThisWeek) / 7", color: .green)
                ActivityStatRow(icon: "flame.fill", label: "Workouts", value: "\(data.workoutCountThisWeek)", color: .red)
                ActivityStatRow(icon: "bolt.fill", label: "Calories", value: "\(Int(data.totalCaloriesThisWeek))", color: .pink)

                if let topType = data.topWorkoutTypeThisWeek {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                        Text("Top: \(topType)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.orange.opacity(0.06), Color.red.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct ActivityStatRow: View {
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
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}
