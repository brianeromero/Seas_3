//
//  CustomPin.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import MapKit

struct CustomPin: View {
    let coordinate: CLLocationCoordinate2D
    let title: String
    let imageName: String

    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .padding(5)
                .background(Color.white)
                .cornerRadius(5)
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
        }
    }
}
