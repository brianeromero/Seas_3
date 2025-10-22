//
//  ToggleView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 4/8/25.
//

import Foundation
import SwiftUI

struct ToggleView: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
        }
        .onChange(of: isOn) { oldValue, newValue in
            print("\(title): \(newValue ? "Enabled" : "Disabled")")
        }
    }
}
