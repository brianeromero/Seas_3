//
//  MatTypeTogglesView.swift
//  Seas_3
//
//  Created by Brian Romero on 4/8/25.
//

import Foundation
import SwiftUI

struct MatTypeTogglesView: View {
    @Binding var gi: Bool
    @Binding var noGi: Bool
    @Binding var openMat: Bool
    @Binding var goodForBeginners: Bool
    @Binding var kids: Bool

    var body: some View {
        VStack {
            ToggleView(title: "Gi", isOn: $gi)
            ToggleView(title: "No Gi", isOn: $noGi)
            ToggleView(title: "Open Mat", isOn: $openMat)
            ToggleView(title: "Good for Beginners", isOn: $goodForBeginners)
            ToggleView(title: "Kids Class", isOn: $kids)
        }
    }
}
