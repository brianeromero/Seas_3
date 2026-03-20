//
//  SyncBanner.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/19/26.
//

import SwiftUI

struct SyncBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 6)
        .padding(.top, 8)
    }
}
