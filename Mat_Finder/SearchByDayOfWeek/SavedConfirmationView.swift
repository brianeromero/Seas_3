// SavedConfirmationView.swift
// Mat_Finder
//
// Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI

struct SavedConfirmationView: View {
    @Environment(\.dismiss) var dismiss // ✅ Correct way to use @Environment(\.dismiss)

    var body: some View {
        VStack {
            Text("Data Saved Successfully!")
                .font(.headline)
                .padding()
            Button(action: {
                dismiss()            }) {
                Text("OK")
                    .font(.title2)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .navigationTitle("Saved")
    }
}

// Preview provider for SavedConfirmationView
struct SavedConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { // Added NavigationView to match the actual usage in navigation context
            SavedConfirmationView()
        }
    }
}
