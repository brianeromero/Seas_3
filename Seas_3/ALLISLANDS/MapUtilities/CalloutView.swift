//
//  CalloutView.swift
//  Seas_3
//
//  Created by Brian Romero on 9/4/24.
//

import Foundation
import SwiftUI
import CoreLocation

struct CalloutView: View {
    let title: String
    let subtitle: String
    let additionalInfo: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
            Text(additionalInfo)
                .font(.callout)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
    }
}
