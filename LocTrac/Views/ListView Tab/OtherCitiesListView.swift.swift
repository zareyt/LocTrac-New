//
//  OtherCitiesListView.swift.swift
//  LocTrac
//
//  Created by Tim Arey on 12/19/25.
//

import SwiftUI

struct OtherCitiesListView: View {
    @EnvironmentObject var store: DataStore
    let location: Location
    
    // UTC calendar for consistent sorting/grouping with stored UTC-midnight dates
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    // Date formatter pinned to GMT so dates display as their canonical stored day (UTC)
    private static let gmtFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!
            return cal
        }()
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateStyle = .medium // similar to .abbreviated; adjust if you prefer .long/short
        df.timeStyle = .none
        return df
    }()
    
    // Group events for this "Other" location by city, with dates sorted descending
    private var grouped: [(city: String, dates: [Date])] {
        let events = store.events
            .filter { $0.location.id == location.id }
            // explicit sort using UTC calendar (though Date comparison is absolute, this keeps intent clear)
            .sorted { $0.date > $1.date }
        
        var dict: [String: [Date]] = [:]
        for e in events {
            let city = (e.city?.isEmpty == false) ? e.city! : "Unknown"
            dict[city, default: []].append(e.date)
        }
        // Sort cities alphabetically; you can change to by count if preferred
        return dict
            .map { ($0.key, $0.value) }
            .sorted { $0.city < $1.city }
    }
    
    // MARK: - Snapshot of full content (offscreen rendering)
    // Use a plain VStack without ScrollView/LazyVStack to ensure intrinsic height is computable.
    @ViewBuilder
    private var snapshotContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Cities & Dates")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            if grouped.isEmpty {
                Text("No city stays recorded yet.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(grouped, id: \.city) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(group.city)
                                .font(.subheadline).bold()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        
                        ForEach(group.dates, id: \.self) { date in
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.secondary)
                                Text(OtherCitiesListView.gmtFormatter.string(from: date))
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        Divider()
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    // Render SwiftUI view to UIImage at full intrinsic size by hosting it in an offscreen window
    private func renderFullSizeImage<V: View>(of view: V, maxWidth: CGFloat) -> UIImage? {
        // Create an offscreen window and VC so layout works reliably
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: maxWidth, height: 1))
        window.isHidden = false
        let rootVC = UIViewController()
        window.rootViewController = rootVC
        window.makeKeyAndVisible() // ensure UIKit performs layout/draw
        
        // Host the SwiftUI view
        let hosting = UIHostingController(rootView: view)
        hosting.view.backgroundColor = .systemBackground
        rootVC.view.backgroundColor = .systemBackground
        
        rootVC.addChild(hosting)
        rootVC.view.addSubview(hosting.view)
        hosting.didMove(toParent: rootVC)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Constrain width and leading/top; let height be determined by content
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: rootVC.view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: rootVC.view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: rootVC.view.topAnchor),
            hosting.view.widthAnchor.constraint(equalToConstant: maxWidth)
        ])
        
        // First layout pass
        rootVC.view.setNeedsLayout()
        rootVC.view.layoutIfNeeded()
        
        // Ask for the size that fits at this width
        let targetSize = hosting.sizeThatFits(in: CGSize(width: maxWidth, height: UIView.layoutFittingExpandedSize.height))
        let finalHeight = max(targetSize.height, 1)
        let finalSize = CGSize(width: maxWidth, height: finalHeight)
        
        // Update frames to final size and layout again
        window.frame = CGRect(origin: .zero, size: finalSize)
        rootVC.view.frame = CGRect(origin: .zero, size: finalSize)
        hosting.view.frame = CGRect(origin: .zero, size: finalSize)
        rootVC.view.setNeedsLayout()
        rootVC.view.layoutIfNeeded()
        
        // Render using layer.render to avoid white/black frames offscreen
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: finalSize, format: format)
        var image = renderer.image { ctx in
            rootVC.view.layer.render(in: ctx.cgContext)
        }
        
        // Fallback: if somehow blank, try drawHierarchy
        if image.size.height == 0 {
            image = renderer.image { _ in
                rootVC.view.drawHierarchy(in: CGRect(origin: .zero, size: finalSize), afterScreenUpdates: true)
            }
        }
        
        // Clean up (optional)
        hosting.willMove(toParent: nil)
        hosting.view.removeFromSuperview()
        hosting.removeFromParent()
        window.isHidden = true
        
        return image
    }
    
    private func shareFullContent() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }
        let maxWidth = window.bounds.width
        guard let snapshot = renderFullSizeImage(of: snapshotContentView, maxWidth: maxWidth) else {
            return
        }
        let activityVC = UIActivityViewController(activityItems: [snapshot], applicationActivities: nil)
        // iPad popover anchor
        activityVC.popoverPresentationController?.sourceView = window
        activityVC.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.safeAreaInsets.top + 44, width: 1, height: 1)
        window.rootViewController?.present(activityVC, animated: true, completion: nil)
    }
    
    var body: some View {
        List {
            if grouped.isEmpty {
                Text("No city stays recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(grouped, id: \.city) { group in
                    Section(header: Text(group.city)) {
                        ForEach(group.dates, id: \.self) { date in
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.secondary)
                                Text(OtherCitiesListView.gmtFormatter.string(from: date))
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Cities & Dates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareFullContent()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
    }
}
