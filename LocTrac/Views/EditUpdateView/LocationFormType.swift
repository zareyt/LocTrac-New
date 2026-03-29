//
//  LocationFormType.swift
//  Locations
//
//  Created by Tim Arey on 2/1/23.
//

import SwiftUI

enum LocationFormType: Identifiable, View {
    case new
    case update(Location)
    var id: String {
        switch self {
        case .new:
            return "new"
        case .update:
            return "update"
        }
    }

    var body: some View {
        switch self {
        case .new:
            return LocationFormView(viewModel: LocationFormViewModel())
        case .update(let location):
            return LocationFormView(viewModel: LocationFormViewModel(location))
        }
    }
}
