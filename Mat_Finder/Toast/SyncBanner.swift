//
//  SyncBanner.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/19/26.
//

import SwiftUI

struct SyncBanner: View {
    enum State {
        case syncing
        case success
    }

    let state: State
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            switch state {
            case .syncing:
                ProgressView()
                    .controlSize(.small)

            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
            }

            Text(message)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
    }
}
