//
//  RestrictionsView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 4/8/25.
//

import Foundation
import SwiftUI

struct RestrictionsView: View {
    @Binding var restrictions: Bool
    @Binding var restrictionDescriptionInput: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Restrictions")
                InfoTooltip(
                    text: "",
                    tooltipMessage: "e.g., White Gis Only, Competition Class, Mat Fees Required, etc."
                )
                .padding(.leading, 4)

                Spacer()

                ToggleView(title: "", isOn: $restrictions)
            }

            if restrictions {
                TextField("Restriction Description (required)", text: $restrictionDescriptionInput)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                restrictionDescriptionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.red
                                    : Color.secondary.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            }
        }
    }
}
