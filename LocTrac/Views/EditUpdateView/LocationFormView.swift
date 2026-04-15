//
//  LocationFormView.swift
//  Locations
//
//  Created by Tim Arey on 2/1/23.
//

import SwiftUI
import CoreLocation
import CoreLocationUI

struct LocationFormView: View {
    @EnvironmentObject var store: DataStore
    @StateObject var viewModel: LocationFormViewModel
    @Environment(\.dismiss) var dismiss

    // Get edit GPS location
    @State private var locationButtonPressed = false
    @StateObject var locationManager = LocationManager()

    // Text fields for coordinates
    @State private var latitudeText = ""
    @State private var longitudeText = ""

    // Set cursor to Note (kept for parity; not currently used here)
    @FocusState private var focus: Bool?

    // Simple alert for location errors
    @State private var showLocationError = false
    @State private var locationErrorMessage = ""
    
    // Coordinate review for large changes
    @State private var showCoordinateReview = false
    @State private var coordinateReviewAnalysis: LocationCoordinateUpdater.UpdateAnalysis?
    @State private var pendingLocation: Location?

    var body: some View {
        // Bindings for coordinate text fields
        let latitudeBinding = Binding<String>(
            get: { latitudeText },
            set: { newValue in
                latitudeText = newValue
                if let doubleValue = Double(newValue) {
                    viewModel.latitude = doubleValue
                }
            }
        )

        let longitudeBinding = Binding<String>(
            get: { longitudeText },
            set: { newValue in
                longitudeText = newValue
                if let doubleValue = Double(newValue) {
                    viewModel.longitude = doubleValue
                }
            }
        )

        // NEW: Direct color binding for custom colors (no theme snapping)
        let colorBinding = Binding<Color>(
            get: { viewModel.effectiveColor },
            set: { newColor in
                viewModel.customColorHex = newColor.toHex()
            }
        )

        NavigationStack {
            Form {

                // MARK: - Details
                Section {
                    HStack {
                        Label("Name", systemImage: "mappin.circle.fill")
                            .foregroundColor(.blue)
                        Spacer()
                        TextField("Required", text: $viewModel.name)
                            .textInputAutocapitalization(.words)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Location Name")
                } footer: {
                    Text("A unique name for this location")
                }

                Section {
                    HStack {
                        Label("City", systemImage: "building.2.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        TextField("e.g., Denver", text: $viewModel.city)
                            .textInputAutocapitalization(.words)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Location City")
                } footer: {
                    Text("City name only (no state or country)")
                }

                Section {
                    HStack {
                        Label("State", systemImage: "map.fill")
                            .foregroundColor(.green)
                        Spacer()
                        TextField("e.g., Colorado", text: $viewModel.state)
                            .textInputAutocapitalization(.words)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("State / Province")
                } footer: {
                    Text("State, province, territory, or region")
                }

                Section {
                    HStack {
                        Label("Country", systemImage: "globe")
                            .foregroundColor(.purple)
                        Spacer()
                        TextField("e.g., United States", text: $viewModel.country)
                            .textInputAutocapitalization(.words)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Country")
                } footer: {
                    Text("Country name for location organization")
                }

                // MARK: - Coordinates
                Section {
                    HStack {
                        Label("Latitude", systemImage: "location.fill")
                            .foregroundColor(.red)
                        Spacer()
                        TextField("0.0", text: latitudeBinding)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Label("Longitude", systemImage: "location.fill")
                            .foregroundColor(.red)
                        Spacer()
                        TextField("0.0", text: longitudeBinding)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }

                    VStack(spacing: 8) {
                        LocationButton {
                            locationManager.requestCurrentLocation(timeout: 10)
                            locationButtonPressed = true
                        }
                        .frame(height: 44)
                        .padding(.top, 4)

                        if locationManager.isRequestInFlight {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Getting your location…")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // MARK: - Theme (Color Picker with custom colors)
                Section(header: Text("Theme Color")) {
                    ColorPicker("Color", selection: colorBinding, supportsOpacity: false)

                    HStack {
                        Text("Preview")
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.effectiveColor)
                            .frame(width: 30, height: 30)
                    }
                }

                // MARK: - Actions
                Section {
                    HStack {
                        Spacer()
                        Button {
                            if viewModel.updating {
                                let location = Location(
                                    id: viewModel.id!,
                                    name: viewModel.name,
                                    city: viewModel.city,
                                    state: viewModel.state.isEmpty ? nil : viewModel.state,  // v1.5: Save state
                                    latitude: viewModel.latitude,
                                    longitude: viewModel.longitude,
                                    country: viewModel.country.isEmpty ? nil : viewModel.country,
                                    theme: viewModel.theme,
                                    imageIDs: nil,
                                    customColorHex: viewModel.customColorHex // NEW: Save custom color
                                )
                                
                                // DISABLED: Coordinate propagation system
                                // Use standard update for now
                                store.update(location)
                                dismiss()
                                
                                // TODO: Re-enable once use case is clarified
                                // store.updateLocationWithCoordinatePropagation(location) { analysis in
                                //     coordinateReviewAnalysis = analysis
                                //     pendingLocation = location
                                //     showCoordinateReview = true
                                // }
                                // if !showCoordinateReview {
                                //     dismiss()
                                // }
                            } else {
                                let newLocation = Location(
                                    name: viewModel.name,
                                    city: viewModel.city,
                                    state: viewModel.state.isEmpty ? nil : viewModel.state,  // v1.5: Save state
                                    latitude: viewModel.latitude,
                                    longitude: viewModel.longitude,
                                    country: viewModel.country.isEmpty ? nil : viewModel.country,
                                    theme: viewModel.theme,
                                    imageIDs: nil,
                                    customColorHex: viewModel.customColorHex // NEW: Save custom color
                                )
                                store.add(newLocation)
                                dismiss()
                            }
                        } label: {
                            Text(viewModel.updating ? "Update Location" : "Add Location")
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                }
            }
            .navigationTitle(viewModel.updating ? "Update" : "New Location")
            // iOS 17+ onChange overload with two parameters (oldValue, newValue)
            .onChange(of: locationManager.location) { oldValue, newValue in
                guard let newLocation = newValue else {
                    print("onChange(location): newValue is nil")
                    return
                }
                print("onChange(location): received new location:", newLocation.coordinate)

                viewModel.latitude = newLocation.coordinate.latitude
                viewModel.longitude = newLocation.coordinate.longitude
                latitudeText = String(viewModel.latitude)
                longitudeText = String(viewModel.longitude)

                // Attempt reverse geocode to get city and country
                let trimmed = viewModel.city.trimmingCharacters(in: .whitespacesAndNewlines)
                let isPlaceholder = trimmed.lowercased() == "none" || trimmed.lowercased() == "unknown"
                if trimmed.isEmpty || isPlaceholder {
                    Task { @MainActor in
                        print("ReverseGeocoder: starting lookup…")
                        do {
                            if let city = try await ReverseGeocoder.cityString(from: newLocation, format: .cityState),
                               !city.isEmpty {
                                print("ReverseGeocoder: got city:", city)
                                viewModel.city = city
                            } else {
                                print("ReverseGeocoder: no city found")
                            }
                            
                            // Also get country
                            if let country = try await ReverseGeocoderHelper.countryString(
                                latitude: viewModel.latitude,
                                longitude: viewModel.longitude
                            ) {
                                print("ReverseGeocoder: got country:", country)
                                viewModel.country = country
                            } else {
                                print("ReverseGeocoder: no country found")
                            }
                        } catch {
                            print("ReverseGeocoder error:", error.localizedDescription)
                        }
                    }
                } else {
                    print("ReverseGeocoder: skipping (city already set to '\(viewModel.city)')")
                }
            }
            // Observe an Equatable derived value (String?) to avoid Equatable on Error
            .onChange(of: locationManager.error.map { ($0 as NSError).localizedDescription }) { _, message in
                if let message = message {
                    locationErrorMessage = message
                    showLocationError = true
                }
            }
            .alert("Location Error", isPresented: $showLocationError) {
                Button("OK", role: .cancel) { }
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } message: {
                Text(locationErrorMessage)
            }
            .sheet(isPresented: $showCoordinateReview) {
                if let analysis = coordinateReviewAnalysis,
                   let location = pendingLocation {
                    LocationCoordinateReviewView(
                        analysis: analysis,
                        location: location,
                        onApprove: {
                            dismiss()
                        },
                        onCancel: {
                            // User chose to keep original coordinates
                            // Location was already updated, nothing more to do
                        }
                    )
                    .environmentObject(store)
                }
            }
        }
        .onAppear {
            focus = true
            latitudeText = String(viewModel.latitude)
            longitudeText = String(viewModel.longitude)
        }
    }

    // MARK: - Theme mapping helpers

    // Find the nearest Theme to a picked Color by comparing sRGB components via UIColor
    private func nearestTheme(to color: Color) -> Theme? {
        guard let target = UIColorResolver.rgba(from: color) else { return nil }
        var best: (theme: Theme, distance: CGFloat)?
        for theme in Theme.allCases {
            if let c = UIColorResolver.rgba(from: theme.uiColor) {
                let d = squaredDistance(lhs: target, rhs: c)
                if best == nil || d < best!.distance {
                    best = (theme, d)
                }
            }
        }
        return best?.theme
    }

    private func squaredDistance(lhs: RGBA, rhs: RGBA) -> CGFloat {
        let dr = lhs.r - rhs.r
        let dg = lhs.g - rhs.g
        let db = lhs.b - rhs.b
        return dr*dr + dg*dg + db*db
    }
}

// MARK: - Utilities for extracting RGBA from UIColor/Color (iOS)

private struct RGBA {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat
}

private enum UIColorResolver {
    // Extract RGBA from a SwiftUI Color by resolving to UIColor
    static func rgba(from color: Color) -> RGBA? {
        #if canImport(UIKit)
        let ui = ColorToUIColorResolver.resolve(color)
        return rgba(from: ui)
        #else
        return nil
        #endif
    }

    // Extract RGBA from a UIColor
    static func rgba(from ui: UIColor) -> RGBA? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return RGBA(r: r, g: g, b: b, a: a)
    }
}

// Helper that converts SwiftUI.Color to UIColor using the most compatible path
private enum ColorToUIColorResolver {
    static func resolve(_ color: Color) -> UIColor {
        #if canImport(UIKit)
        // Preferred: direct initializer if available on your SDK
        if let ui = tryUIColorInit(color) {
            return ui
        }
        // Fallback: host a tiny UIView and set backgroundColor via UIColor(Color)
        let host = UIHostingController(rootView: ColorUIView(color: color))
        host.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        _ = host.view // force load
        return host.view.backgroundColor ?? .clear
        #else
        return .clear
        #endif
    }

    private static func tryUIColorInit(_ color: Color) -> UIColor? {
        #if canImport(UIKit)
        return UIColor(color)
        #else
        return nil
        #endif
    }
}

// A tiny UIViewRepresentable that assigns UIColor(Color) to backgroundColor
private struct ColorUIView: UIViewRepresentable {
    let color: Color
    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.backgroundColor = UIColor(color)
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.backgroundColor = UIColor(color)
    }
}

struct LocationFormView_Previews: PreviewProvider {
    static var previews: some View {
        LocationFormView(viewModel: LocationFormViewModel())
            .environmentObject(DataStore())
    }
}
