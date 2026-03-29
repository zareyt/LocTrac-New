/*
See LICENSE folder for this sample’s licensing information.
*/

import SwiftUI

struct CardView: View {
    let location: Location
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(location.name)
                .accessibilityAddTraits(.isHeader)
                .font(.headline)
            Spacer()
            HStack {
                Text(location.city!)
                Spacer()
            }
            .font(.caption)
        }
        .padding()
        .foregroundColor(location.theme.accentColor)
    }
}

struct CardView_Previews: PreviewProvider {
    static var location = Location.sampleData[0]
    static var previews: some View {
        CardView(location: location)
            .background(location.theme.mainColor)
            .previewLayout(.fixed(width: 400, height: 60))
    }
}
