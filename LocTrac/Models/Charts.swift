//
//  Charts.swift
//  LocTrac
//
//  Created by Tim Arey on 3/6/23.
//

import Foundation
import SwiftUI

//Chart Data
struct ChartData {
    var id = UUID()
    var value: CGFloat         // cumulative percent in 0...100 used for trim "to"
    var color: Color
    var percent: CGFloat       // slice percent in 0...100 for labels
    var count: Int
    var locationName: String
}

struct ColorData {
    static let colors: [Color] = [
        Color(red: 0.476841867, green: 0.5048075914, blue: 1), //blue
        Color(red: 1, green: 0.4932718873, blue: 0.4739984274), //red
        Color(red: 0.345, green: 0.337, blue: 0.839), //purple
        Color(red: 0.4508578777, green: 0.9882974029, blue: 0.8376303315), //green
        Color(red: 1, green: 0.8323456645, blue: 0.4732058644)//yellow
    ]
}

class ChartDataContainer: ObservableObject {
    @Published var chartData: [ChartData] = []
    var allYears: [Int] = []
    
    var store: DataStore
    
    init(store: DataStore) {
        self.store = store
        calc(selectedYear: "Total", filteredEvents: store.events)
    }
 
    func calc(selectedYear: String?, filteredEvents: [Event]) {
        var percentByLocation: [Location: Float] = [:]
        var countByLocation: [Location: Int] = [:]
        let locations = store.locations
        let events = filteredEvents

        // Avoid division by zero downstream
        guard !events.isEmpty else {
            chartData = locations.map { loc in
                ChartData(value: 0, color: loc.theme.mainColor, percent: 0, count: 0, locationName: loc.name)
            }
            return
        }

        // UTC calendar for consistent grouping
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Calculate percent by location for selected year if a year is selected, or for all years otherwise
        if let year = selectedYear, year != "Total" {
            let targetYear = Int(year) ?? 0
            let filteredEventsByYear = events.filter { utcCalendar.component(.year, from: $0.date) == targetYear }
            if filteredEventsByYear.isEmpty {
                chartData = locations.map { loc in
                    ChartData(value: 0, color: loc.theme.mainColor, percent: 0, count: 0, locationName: loc.name)
                }
                return
            }
            for location in locations {
                let results = store.eventPercentByLocation(location, events: filteredEventsByYear)
                percentByLocation[location] = results.percent
                countByLocation[location] = results.count
            }
        } else {
            for location in locations {
                let results = store.eventPercentByLocation(location, events: events)
                percentByLocation[location] = results.percent
                countByLocation[location] = results.count
            }
        }

        // Generate chart data using unrounded percents for accumulation
        chartData.removeAll()
        var runningPercent: CGFloat = 0 // cumulative 0...100
        for (_, location) in store.locations.enumerated() {
            guard let percent = percentByLocation[location] else { continue }
            guard let count = countByLocation[location] else { continue }
            
            // Use effectiveColor to respect custom colors
            let color = location.effectiveColor

            // percent is 0...1 (Float). Convert to 0...100 (CGFloat) for display and accumulation.
            let slicePercentValue = CGFloat(percent) * 100.0
            runningPercent += slicePercentValue

            // Append with current cumulative value (will be clamped for last slice later)
            let data = ChartData(
                value: runningPercent,
                color: color,
                percent: slicePercentValue,
                count: count,
                locationName: location.name
            )
            chartData.append(data)
        }

        // Clamp the last cumulative value to exactly 100 to eliminate gaps due to floating-point
        if let lastIndex = chartData.indices.last {
            chartData[lastIndex].value = 100.0
        }
    }
    
}

class ChartActivityItemsSource: NSObject, UIActivityItemSource {
    let charDataObj: ChartDataContainer

    init(charDataObj: ChartDataContainer) {
        self.charDataObj = charDataObj
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return ""
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return charDataObj.chartData.map { $0.locationName }.joined(separator: ", ")
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Chart data"
    }
}
