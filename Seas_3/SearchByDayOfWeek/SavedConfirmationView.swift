// SavedConfirmationView.swift
// Seas_3
//
// Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI

struct SavedConfirmationView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text("Data Saved Successfully!")
                .font(.headline)
                .padding()
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
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
