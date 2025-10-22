//
//  ExampleUsuageView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/28/24.
//

import Foundation
import SwiftUI
import CoreData

struct ExampleUsageView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Your existing UI elements
                
                Button(action: {
                    saveData()
                }) {
                    Text("Save Data")
                        .font(.title2)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .sheet(isPresented: $showConfirmation) {
                NavigationView {
                    SavedConfirmationView()
                }
                .onDisappear {
                    // Navigate back to the main menu or previous page
                    // Depending on your app structure, you may need to perform specific navigation here
                }
            }
        }
    }
    
    private func saveData() {
        // Perform your save operation here
        
        // After saving, show the confirmation modal
        showConfirmation = true
    }
}

