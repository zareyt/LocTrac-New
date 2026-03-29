//
//  LocationListViewRow.swift
//  LocTrac
//
//  Created by Tim Arey on 4/20/23.
//

import SwiftUI

struct LocationListViewRow: View {
    let location: Location
    @EnvironmentObject var store: DataStore
    @Binding var lformType: LocationFormType?
    
    var body: some View {
        HStack {
            HStack {
                Circle()
                    .fill(location.theme.mainColor)
                    .frame(width: 20, height: 20)
                Text("  " + location.name)
            }
            Spacer()
            Button {
                lformType = .update(location)
            } label: {
                Text("Edit")
            }
            .buttonStyle(.bordered)
        }
    }
}



struct LocationListViewRow_Previews: PreviewProvider {
    static let location = Location(name: "Arrowhead", city: "Edwards", latitude: 0, longitude: 0, theme: .purple)
    static var previews: some View {
        LocationLiistViewRow(location: location, lformType: .constant(.new))
            .environmentObject(DataStore())
    }
}
