import SwiftUI
import MapKit
import PhotosUI

struct LocationDetailView: View {
    @EnvironmentObject var vm: LocationsMapViewModel
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @Binding var lformType: LocationFormType?

    let locationID: String

    private var liveLocation: Location? {
        store.locations.first(where: { $0.id == locationID })
    }

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isShowingDeleteConfirm = false
    @State private var imageToDelete: String?

    var body: some View {
        Group {
            if let location = liveLocation {
                ScrollView {
                    VStack {
                        imageSection(location)
                            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                        VStack(alignment: .leading, spacing: 16) {
                            titleSection(location)
                            Divider()
                            statisticsSection(location)
                            Divider()
                            descriptionSection(location)
                            Divider()
                            mapLayer(location)
                        }
                    }
                }
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .overlay(backButton, alignment: .topLeading)
                Spacer()
                Button {
                    lformType = .update(location)
                } label: {
                    Text("Edit")
                }
                .buttonStyle(.bordered)
                .sheet(item: $lformType) { $0 }
                .confirmationDialog("Delete Photo?", isPresented: $isShowingDeleteConfirm, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        if let filename = imageToDelete {
                            deleteImage(filename: filename, from: location)
                        }
                    }
                    Button("Cancel", role: .cancel) { imageToDelete = nil }
                }
                .onChange(of: photoItems) { oldItems, newItems in
                    Task {
                        await savePhotos(newItems, to: location)
                    }
                }
            } else {
                VStack {
                    Text("This location is no longer available.")
                        .foregroundColor(.secondary)
                    Button("Close") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                }
                .padding()
            }
        }
    }
}

struct LocationDetailView_Previews: PreviewProvider {
    static var previews: some View {
        LocationDetailView(lformType: .constant(.new), locationID: DataStore().locations.first!.id)
            .environmentObject(LocationsMapViewModel())
            .environmentObject(DataStore())
    }
}

extension LocationDetailView {
    private func imageSection(_ location: Location) -> some View {
        VStack(spacing: 8) {
            if let ids = location.imageIDs, !ids.isEmpty {
                TabView {
                    ForEach(ids, id: \.self) { filename in
                        ZStack(alignment: .topTrailing) {
                            if let ui = ImageStore.load(filename: filename) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: UIScreen.main.bounds.width, height: 500)
                                    .clipped()
                            } else {
                                Color.gray.opacity(0.2)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .imageScale(.large)
                                            .foregroundColor(.secondary)
                                    )
                                    .frame(width: UIScreen.main.bounds.width, height: 500)
                            }
                            Button {
                                imageToDelete = filename
                                isShowingDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.red.opacity(0.8))
                                    .clipShape(Capsule())
                                    .padding()
                            }
                            .accessibilityLabel("Delete Photo")
                        }
                    }
                }
                .frame(height: 500)
                .tabViewStyle(PageTabViewStyle())
            } else {
                ZStack {
                    Color(.secondarySystemBackground)
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 40, weight: .regular))
                            .foregroundColor(.secondary)
                        Text("No photos yet")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            PhotosPicker(selection: $photoItems,
                         maxSelectionCount: 6,
                         matching: .images) {
                Label("Add Photos", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
    }

    private func deleteImage(filename: String, from location: Location) {
        var updated = location
        if let idx = updated.imageIDs?.firstIndex(of: filename) {
            updated.imageIDs?.remove(at: idx)
        }
        if updated.imageIDs?.isEmpty == true {
            updated.imageIDs = nil
        }
        ImageStore.delete(filename: filename)
        store.update(updated)
    }

    private func titleSection(_ location: Location) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(location.name)
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text(location.city ?? "None")
                .font(.title)
                .foregroundColor(.secondary)
            if let country = location.country, !country.isEmpty {
                Text(country)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func descriptionSection(_ location: Location) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("latitude: \(location.latitude)")
            Text("longitude: \(location.longitude)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func mapLayer(_ location: Location) -> some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )) {
            Annotation("Location", coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                LocationMapAnnotationView()
                    .shadow(radius: 10)
            }
        }
        .allowsHitTesting(false)
        .aspectRatio(1, contentMode: .fit)
        .cornerRadius(30)
    }

    private var backButton: some View {
        Button {
            vm.sheetLocation = nil
        } label: {
            Image(systemName: "xmark")
                .font(.headline)
                .padding(16)
                .foregroundColor(.primary)
                .background(.thickMaterial)
                .cornerRadius(10)
                .shadow(radius: 4)
                .padding()
        }
    }
    
    // MARK: - Statistics Section
    
    private func statisticsSection(_ location: Location) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stay Statistics")
                .font(.title3)
                .fontWeight(.semibold)
            
            // Total stays
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.accentColor)
                Text("Total Stays: \(store.eventCount(location, events: store.events))")
                    .font(.headline)
            }
            
            // Per-year breakdown
            VStack(alignment: .leading, spacing: 8) {
                ForEach(yearsSortedDescending(for: location), id: \.self) { year in
                    let (count, percent) = perYearStats(for: year, location: location)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(String(year))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(count) stays (\(percentString(percent)))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Types for this location in this year
                        let typeBreakdown = perYearTypeBreakdown(for: year, location: location)
                        ForEach(typeBreakdown, id: \.type.id) { entry in
                            HStack(spacing: 6) {
                                Text(entry.type.icon)
                                Text("\(entry.type.rawValue.capitalized): \(entry.count) (\(percentString(entry.percent)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 16)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
    
    // MARK: - Statistics Helpers
    
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    private func yearsSortedDescending(for location: Location) -> [Int] {
        let locationEvents = store.events.filter { $0.location.id == location.id }
        let years = locationEvents.map { utcCalendar.component(.year, from: $0.date) }
        return Array(Set(years)).sorted(by: >)
    }
    
    private func perYearStats(for year: Int, location: Location) -> (count: Int, percent: Float) {
        let eventsInYear = store.events.filter { utcCalendar.component(.year, from: $0.date) == year }
        let totalInYear = eventsInYear.count
        let locationEventsInYear = eventsInYear.filter { $0.location.id == location.id }
        let count = locationEventsInYear.count
        guard totalInYear > 0 else { return (0, 0) }
        let percent = Float(count) / Float(totalInYear)
        return (count, percent)
    }
    
    private func perYearTypeBreakdown(for year: Int, location: Location) -> [(type: Event.EventType, count: Int, percent: Float)] {
        let locationEventsInYear = store.events.filter {
            utcCalendar.component(.year, from: $0.date) == year && $0.location.id == location.id
        }
        let totalForLocationInYear = locationEventsInYear.count
        guard totalForLocationInYear > 0 else { return [] }
        
        var result: [(type: Event.EventType, count: Int, percent: Float)] = []
        for t in Event.EventType.allCases {
            let count = locationEventsInYear.filter { Event.EventType(rawValue: $0.eventType) == t }.count
            let percent = totalForLocationInYear > 0 ? Float(count) / Float(totalForLocationInYear) : 0
            if count > 0 {
                result.append((t, count, percent))
            }
        }
        result.sort { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.type.rawValue < rhs.type.rawValue
            }
            return lhs.count > rhs.count
        }
        return result
    }
    
    private func percentString(_ value: Float) -> String {
        String(format: "%.0f%%", value * 100)
    }
    
    // MARK: - Photo Saving
    
    private func savePhotos(_ items: [PhotosPickerItem], to location: Location) async {
        var updated = location
        var currentIDs = updated.imageIDs ?? []
        
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { continue }
            
            // Save image with proper error handling
            if let filename = try? ImageStore.save(image: uiImage) {
                currentIDs.append(filename)
            }
        }
        
        updated.imageIDs = currentIDs.isEmpty ? nil : currentIDs
        store.update(updated)
        
        // Clear the picker selection
        photoItems = []
    }
}
