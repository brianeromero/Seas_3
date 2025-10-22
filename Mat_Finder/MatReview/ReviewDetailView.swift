//
//  ReviewDetailView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 9/22/24.
//

import Foundation
import SwiftUI

struct ReviewDetailView: View {
    var review: Review

    var body: some View {
        VStack {
            Text(review.review)
                .font(.body)
                .padding()

            HStack {
                ForEach(0..<Int(review.stars), id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }

                Spacer()

                Text(review.createdTimestamp, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()

            Spacer()
        }
        .navigationTitle("Review Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
