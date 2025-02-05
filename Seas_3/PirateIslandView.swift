//
//  PirateIslandView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData
import Combine


struct PirateIslandView: View {
    @State private var showWelcomePage = true
    
    var body: some View {
        if showWelcomePage {
            Text("Mat_Finder")
                .font(.largeTitle)
                .padding()
                .onAppear {
                    // Use Timer to hide the welcome page after 5 seconds
                    Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                        showWelcomePage = false
                    }
                }
        } else {
            // Placeholder view or navigate to the next screen
            // You can replace this with your actual main content
            Text("Where All Your Mat Dreams Come True!!!")
                .padding()
                .onAppear {
                    // Use Timer to perform some action after 5 seconds
                    Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { _ in
                        // Add your action here
                    }
                }
        }
    }
}

struct PirateIslandView_Previews: PreviewProvider {
    static var previews: some View {
        PirateIslandView()
    }
}



