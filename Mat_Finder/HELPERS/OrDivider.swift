//
//  OrDivider.swift
//  Mat_Finder
//
//  Created by Brian Romero on 2/2/26.
//

import Foundation
import SwiftUI


struct OrDivider: View {
    var body: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.5))
            Text("OR")
                .foregroundColor(.gray)
                .font(.caption)
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.vertical, 10)
    }
}
