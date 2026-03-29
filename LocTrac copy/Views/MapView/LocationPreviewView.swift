//
//  LocationPreviewView.swift
//  SwiftMapApp
//
//  Created by Tim Arey on 3/25/23.
//

import SwiftUI

struct LocationPreviewView: View {
    
    @EnvironmentObject private var vm: LocationsMapViewModel
    
    let location: Location
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                titleSection
            }
            
            Spacer()
            
            // Vertically centered Info button
            learnMoreButton
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .cornerRadius(10)
    }
}

struct LocationPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.green.ignoresSafeArea()
            LocationPreviewView(location: DataStore().locations.first!)
                .padding()
        }
        .environmentObject(LocationsMapViewModel())
    }
}

extension LocationPreviewView {
    private var titleSection: some View {
        VStack (alignment: .leading, spacing: 4) {
            Text(location.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if let city = location.city, !city.isEmpty, city.lowercased() != "none" {
                Text(city)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var learnMoreButton: some View {
        Button{
            vm.sheetLocation = location
        } label: {
            Text("Info")
                .font(.headline)
                .frame(width: 100, height: 40)
        }
        .buttonStyle(.borderedProminent)
    }
}
