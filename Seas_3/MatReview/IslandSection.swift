//
//  IslandSection.swift
//  Seas_3
//
//  Created by Brian Romero on 9/22/24.
//

import Foundation
import SwiftUI
import CoreData

/// A SwiftUI View representing a Picker for selecting a `PirateIsland`.
struct IslandSection: View {
    var islands: [PirateIsland]
    @Binding var selectedIsland: PirateIsland?
    @Binding var showReview: Bool

    var body: some View {
        Section(header: Text("Select Gym")) {
            Picker("Select a Gym", selection: $selectedIsland) {
                Text("Select a Gym").tag(nil as PirateIsland?) // Default option

                ForEach(islands, id: \.self) { island in
                    Text(island.islandName ?? "Unknown Gym")
                        .tag(island as PirateIsland?)
                }
            }
            .onChange(of: selectedIsland) { newIsland in
                print("Selected Gym: \(newIsland?.islandName ?? "Unknown Gym")")
                showReview = true
            }
        }
    }
}

struct IslandSection_Previews: PreviewProvider {
    static var previews: some View {
        @State var selectedIsland: PirateIsland? = nil
        @State var showReview: Bool = false
        let islands = PersistenceController.preview.fetchAllPirateIslands()

        return Group {
            IslandSection(islands: islands, selectedIsland: $selectedIsland, showReview: $showReview)
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Gym Section Preview")
        }
    }
}
