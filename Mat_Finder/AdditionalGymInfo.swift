//
//  AdditionalGymInfo.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreData
import Combine
import CoreLocation
import Foundation


struct AdditionalGymInfo: View {
    var islandName: String // Assuming islandName is passed or provided

    var body: some View {
        VStack {
            Text(islandName)
                .font(.largeTitle)
                .padding()

            // Add more content specific to the next island
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Image(systemName: "info.square.fill")
                        .foregroundColor(.black)
                    Text("Additional Gym Info")
                }
            }
        }
    }
}


struct AdditionalGymInfo_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AdditionalGymInfo(islandName: "Sample Gym Name") // Provide a sample island name for the preview
        }
    }
}
