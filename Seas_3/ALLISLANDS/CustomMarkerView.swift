//
//  CustomMarkerView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI

struct CustomMarkerView: View {
    var body: some View {
        Image(systemName: "mappin.circle.fill") // You can use any shape or content for your marker
            .foregroundColor(.blue) // Customize the color if needed
    }
}

struct CustomMarkerView_Previews: PreviewProvider {
    static var previews: some View {
        CustomMarkerView()
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.white) // Add background color for better visibility
            .previewDisplayName("Custom Marker Preview")
    }
}
