//
//  LocationsListView.swift
//  SwiftMapApp
//
//  Created by Tim Arey on 3/23/23.
//

import SwiftUI

struct LocationsMapListView: View {
    
    @EnvironmentObject private var vm: LocationsMapViewModel
    
    var body: some View {
        List {
            ForEach(vm.locations.filter { $0.name != "Other" }) { location in
                Button {
                    vm.showNextLocation(location: location)
                } label: {
                    mapListRowView(location: location)
                }
                .padding(.vertical, 4)
                //.listRowBackground(Color.clear)
            }
        }
        .listStyle(PlainListStyle())
    }
}



struct LocationsMapListView_Previews: PreviewProvider {
    static var previews: some View {
        LocationsListView()
            .environmentObject(LocationsMapViewModel())
    }
}

extension LocationsMapListView{
    
    private func mapListRowView(location:  Location) -> some View  {
        
        HStack{
//            if let imageName = location.imageNames.first {
//                Image(imageName)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 45, height: 45)
//                    .cornerRadius(10)
//            }
            
            VStack(alignment:  .leading){
                Text(location.name)
                    .font(.headline)
//                Text(location.city ?? "None")
//                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
