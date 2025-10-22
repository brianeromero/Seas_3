//
//  RadiusPicker.swift
//  Mat_Finder
//
//  Created by Brian Romero on 9/6/24.
//

import Foundation
import SwiftUI

struct RadiusPicker: View {
    @Binding var selectedRadius: Double
    private let radiusOptions: [Double] = [1, 5, 10, 15, 20]

    var body: some View {
        VStack {
            Text("Select Radius: \(String(format: "%.1f", selectedRadius)) miles")
            Slider(value: $selectedRadius, in: 1...50, step: 1)
                .padding(.horizontal)
        
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
}
