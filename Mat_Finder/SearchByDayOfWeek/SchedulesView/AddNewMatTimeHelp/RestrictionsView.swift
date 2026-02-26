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

        VStack(alignment: .leading, spacing: 12) {

            Toggle(isOn: $restrictions) {

                Label {

                    Text("Restrictions")

                } icon: {

                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.orange)

                }

            }

            if restrictions {

                TextField(
                    "White Gis Only, Competition Class, etc.",
                    text: $restrictionDescriptionInput
                )
                .textFieldStyle(.roundedBorder)

            }

        }

    }

}
