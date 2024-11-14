//
//  MFBACKGROUND.swift
//  Seas_3
//
//  Created by Brian Romero on 11/12/24.
//

import Foundation
import SwiftUI

struct MFBACKGROUND: View {
    var body: some View {
        ZStack {
            // Background image
            Image("MF_little_trans")
                .resizable() // Make the image resizable
                .scaledToFill() // Scale the image to fill the screen, may crop if needed
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Stretch image to cover the screen
                .clipped() // Clip anything outside the frame
                .edgesIgnoringSafeArea(.all) // Ensure the image goes edge to edge
            
            // Content on top of the image (you can add other views here)
            VStack {
                Text("Welcome to MF-inder!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()

                Spacer() // Push the content to the top

                // Add other UI elements as needed
            }
            .padding()
        }
    }
}

struct MFBACKGROUND_Previews: PreviewProvider {
    static var previews: some View {
        MFBACKGROUND()
    }
}
