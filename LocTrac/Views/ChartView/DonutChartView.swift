//
//  DonutChartView.swift
//  LocTrac
//
//  Created by Tim Arey on 3/6/23.
//

import SwiftUI

enum RegionFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case us = "US"
    case outsideUS = "Outside US"
    var id: String { self.rawValue }
}

struct DonutChartView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var debugConfig: DebugConfig
    @State var indexOfTappedSlice = -1
    @State var yearSelection: String = "Total"
    @State var regionFilter: RegionFilter = .all    // New: region filter
    @State private var refreshID = UUID()  // Force refresh when needed

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private var allYears: [Int] {
        let years = store.events.map { utcCalendar.component(.year, from: $0.date) }
        return Array(Set(years)).sorted()
    }

    // Filtered events by year/region
    private var filteredEvents: [Event] {
        let eventsByYear: [Event]
        if yearSelection != "Total" {
            if let y = Int(yearSelection) {
                eventsByYear = store.events.filter { utcCalendar.component(.year, from: $0.date) == y }
            } else {
                eventsByYear = store.events
            }
        } else {
            eventsByYear = store.events
        }
        switch regionFilter {
        case .all:
            return eventsByYear
        case .us:
            return eventsByYear.filter {
                guard let country = $0.country?.lowercased() else { return false }
                return country == "united states" || country == "usa"
            }
        case .outsideUS:
            return eventsByYear.filter {
                guard let country = $0.country?.lowercased() else { return false }
                return country != "united states" && country != "usa"
            }
        }
    }

    // Pass filteredEvents to ChartDataContainer
    private var charDataObj: ChartDataContainer {
        let container = ChartDataContainer(store: store)
        container.calc(selectedYear: yearSelection, filteredEvents: filteredEvents)
        return container
    }
    
    // Calculate totals for display
    private var totals: (total: Int, us: Int, outsideUS: Int) {
        let yearEvents: [Event]
        if yearSelection != "Total" {
            if let y = Int(yearSelection) {
                yearEvents = store.events.filter { utcCalendar.component(.year, from: $0.date) == y }
            } else {
                yearEvents = store.events
            }
        } else {
            yearEvents = store.events
        }
        
        // Use event.country for filtering
        let usEvents = yearEvents.filter {
            guard let country = $0.country?.lowercased() else {
                return false
            }
            return country == "united states" || country == "usa"
        }
        
        let outsideUSEvents = yearEvents.filter {
            guard let country = $0.country?.lowercased() else {
                return false
            }
            return country != "united states" && country != "usa"
        }
        
        let eventsWithoutCountry = yearEvents.count - usEvents.count - outsideUSEvents.count
        if eventsWithoutCountry > 0 {
            print("⚠️ \(eventsWithoutCountry) events without country data for year \(yearSelection)")
        }
        
        return (total: yearEvents.count, us: usEvents.count, outsideUS: outsideUSEvents.count)
    }

    // Add a helper method to present the activity view controller
    private var activityItemsSource: ChartActivityItemsSource {
        return ChartActivityItemsSource(charDataObj: charDataObj)
    }

    // Add a helper method to present the activity view controller
    private func presentActivityViewController() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }

        UIGraphicsBeginImageContextWithOptions(window.bounds.size, false, UIScreen.main.scale)
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)

        let shareButtonFrame = window.convert(CGRect(x: 0, y: 0, width: 100, height: 44), from: nil)
        let clearRect = CGRect(x: shareButtonFrame.origin.x,
                               y: shareButtonFrame.origin.y,
                               width: shareButtonFrame.size.width,
                               height: shareButtonFrame.size.height)
        UIColor.systemBackground.setFill()
        UIRectFill(clearRect)

        guard let snapshot = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return
        }
        UIGraphicsEndImageContext()

        let activityViewController = UIActivityViewController(activityItems: [snapshot], applicationActivities: nil)
        window.rootViewController?.present(activityViewController, animated: true, completion: nil)
    }

    var body: some View {
        VStack(spacing: 8) {
            header
            donut
            pickerSection
            regionPickerSection   // New region filter picker
            legendList
            totalsSummary        // New totals summary
        }
        .id(refreshID)  // Force view refresh when ID changes
        .onChange(of: store.dataUpdateToken) { _, _ in
            #if DEBUG
            print("📊 [DonutChartView] Data update token changed - forcing chart refresh")
            #endif
            refreshID = UUID()  // Force recomputation of charDataObj
        }
        .debugViewName("DonutChartView")
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text(yearSelection)
                .font(.title)
                .bold()
            Spacer()
            Button(action: {
                presentActivityViewController()
            }) {
                Image(systemName: "square.and.arrow.up")
                    .padding(.trailing)
            }
        }
        .padding(.top, 30)
        .padding(.horizontal, 20)
    }

    private var donut: some View {
        ZStack {
            ForEach(Array(charDataObj.chartData.enumerated()), id: \.offset) { pair in
                let index = pair.offset
                let item = pair.element
                let from = index == 0 ? 0.0 : Double(charDataObj.chartData[index - 1].value) / 100.0
                let to = Double(item.value) / 100.0

                Circle()
                    .trim(from: from, to: to)
                    .stroke(item.color, lineWidth: 50)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            indexOfTappedSlice = indexOfTappedSlice == index ? -1 : index
                        }
                    }
                    .scaleEffect(index == indexOfTappedSlice ? 1.1 : 1.0)
            }
            
            // Display totals in center
            VStack(spacing: 4) {
                if indexOfTappedSlice != -1 {
                    // Show tapped slice count
                    let count = charDataObj.chartData[indexOfTappedSlice].count
                    Text(String(format: "%.f", Double(count)))
                        .font(.title)
                } else {
                    // Show totals based on region filter
                    switch regionFilter {
                    case .all:
                        Text("\(totals.total)")
                            .font(.title)
                            .bold()
                        Text("Total Days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .us:
                        Text("\(totals.us)")
                            .font(.title)
                            .bold()
                        Text("US Days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .outsideUS:
                        Text("\(totals.outsideUS)")
                            .font(.title)
                            .bold()
                        Text("Outside US")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(width: 200, height: 250)
        .padding(.bottom, 4)
    }

    private var pickerSection: some View {
        Section {
            Picker("Year", selection: $yearSelection) {
                Text("Total").tag("Total")
                ForEach(allYears, id: \.self) { year in
                    Text(String(year)).tag(String(year))
                }
            }
            .pickerStyle(.segmented)
        }
        .onChange(of: yearSelection) { _,_  in
            // ChartDataObj will recalc on next access due to filteredEvents change
        }
    }

    // New: Region picker
    private var regionPickerSection: some View {
        Section {
            Picker("Region", selection: $regionFilter) {
                ForEach(RegionFilter.allCases) { region in
                    Text(region.rawValue).tag(region)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .onChange(of: regionFilter) { _,_ in
            // ChartDataObj will recalc on next access due to filteredEvents change
        }
    }

    private var legendList: some View {
        VStack(spacing: 4) {
            ForEach(Array(charDataObj.chartData.enumerated()), id: \.offset) { pair in
                let index = pair.offset
                let item = pair.element
                LegendRow(
                    name: item.locationName,
                    percent: item.percent,
                    color: item.color,
                    isHighlighted: indexOfTappedSlice == index
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring()) {
                        indexOfTappedSlice = indexOfTappedSlice == index ? -1 : index
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(width: 320, alignment: .trailing)
    }
    
    private var totalsSummary: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(totals.total)")
                        .font(.title2)
                        .bold()
                    Text("Total Days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("\(totals.us)")
                        .font(.title2)
                        .bold()
                    Text("US Days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("\(totals.outsideUS)")
                        .font(.title2)
                        .bold()
                    Text("Outside US")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

private struct LegendRow: View {
    let name: String
    let percent: CGFloat // 0...100
    let color: Color
    let isHighlighted: Bool

    var body: some View {
        let percentText = String(format: "%.0f%%", Double(percent))

        HStack(spacing: 8) {
            Text(name)
                .lineLimit(1)
                .truncationMode(.tail)
                .lineSpacing(0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(isHighlighted ? .headline : .subheadline)

            Text(percentText)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
                .lineSpacing(0)
                .frame(width: 66, alignment: .trailing)

            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 22, height: 22)
        }
    }
}

struct DonutChartView_Previews: PreviewProvider {
    static var previews: some View {
        DonutChartView()
            .environmentObject(DataStore())
    }
}
